# Test NixOS du module EPIVÍOSI NEWS : coffre chiffré (création, modèles,
# contenu illisible verrouillé, verrouillage d'urgence avec un fichier ouvert),
# import (original intact et empreinte, copie sans GPS, doublons ignorés, RAW
# conservé seulement en original, refus coffre fermé) et envoi chiffré
# (archive illisible sans phrase, contenu sans GPS, empreintes valides).
{ pkgs, module }:
let
  # Photo de test avec position GPS et appareil dans ses métadonnées.
  photos = pkgs.runCommand "photos-test" {
    nativeBuildInputs = [ pkgs.imagemagick pkgs.exiftool ];
  } ''
    mkdir -p $out/DCIM
    magick -size 320x240 gradient:red-blue $out/DCIM/IMG_0001.jpg
    exiftool -q -overwrite_original -Make=TestCam -Model=Reporter-1 -SerialNumber=SN12345 \
      -GPSLatitude=48.8566 -GPSLatitudeRef=N -GPSLongitude=2.3522 -GPSLongitudeRef=E \
      -Artist="Jean Source" $out/DCIM/IMG_0001.jpg
    magick -size 64x64 xc:green $out/DCIM/IMG_0002.png
    head -c 4096 /dev/urandom > $out/DCIM/IMG_0003.dng
    echo "pas une photo" > $out/DCIM/notes.txt
  '';
in
pkgs.testers.runNixOSTest {
  name = "epiviosi-news";

  nodes.machine =
    { lib, ... }:
    {
      imports = [ module ];
      # Options normalement déclarées par le socle EPIVÍOSI OS.
      options.epiviosi.news.enable = lib.mkEnableOption "EPIVÍOSI NEWS";
      config = {
        epiviosi.news.enable = true;
        users.users.epiviosi.isNormalUser = true;
        environment.systemPackages = [ pkgs.exiftool pkgs._7zz ];
        virtualisation.memorySize = 2048;
      };
    };

  testScript = ''
    import shlex

    def u(cmd):
        return machine.succeed("su - epiviosi -c " + shlex.quote(cmd))

    def u_fail(cmd):
        machine.fail("su - epiviosi -c " + shlex.quote(cmd))

    R = "/home/epiviosi/Rédaction"
    machine.wait_for_unit("multi-user.target")

    with subtest("outils, guide et lanceurs installés"):
        for cmd in ["epiviosi-news", "epiviosi-news-redaction", "epiviosi-news-coffre",
                    "epiviosi-news-import", "epiviosi-news-envoi", "gimp", "mat2"]:
            machine.succeed(f"command -v {cmd}")
        machine.succeed("test -s /etc/epiviosi/news/guide.html")
        for d in ["epiviosi-news", "epiviosi-news-redaction", "epiviosi-news-verrouiller"]:
            machine.succeed(f"test -f /run/current-system/sw/share/applications/{d}.desktop")

    with subtest("import refusé tant que le coffre n'existe pas"):
        u("mkdir -p ~/Persistant ~/carte && cp -r ${photos}/DCIM ~/carte/ && chmod -R u+w ~/carte")
        assert u("epiviosi-news-coffre etat").strip() == "absent"
        u_fail("epiviosi-news-import ~/carte")
        u_fail("echo court | epiviosi-news-coffre creer")

    with subtest("création : arborescence et modèles"):
        u("echo 'cheval batterie agrafe' | epiviosi-news-coffre creer")
        assert u("epiviosi-news-coffre etat").strip() == "ouvert"
        for d in ["Articles", "Photos/Originaux", "Photos/Publiables", "Envois", "Modèles"]:
            u(f"test -d ~/Rédaction/{d}")
        for f in ["article", "depeche", "journal-terrain", "fiche-source"]:
            u(f"test -s ~/Rédaction/Modèles/{f}.odt")

    with subtest("import : original intact + empreinte, copie sans métadonnées"):
        out = u("epiviosi-news-import --sujet 'marché nord' ~/carte")
        print(out)
        assert "Importés : 3 (nettoyés : 2 ; originaux seuls : 1)" in out, out
        o = f"{R}/Photos/Originaux"
        day = u("ls ~/Rédaction/Photos/Originaux | grep _march").strip()
        assert day.endswith("_marché-nord"), day
        # Original : identique à la carte, GPS et appareil présents.
        u(f"cmp ~/carte/DCIM/IMG_0001.jpg '{o}/{day}/IMG_0001.jpg'")
        assert "Reporter-1" in u(f"exiftool -s3 -Model '{o}/{day}/IMG_0001.jpg'")
        u(f"cd '{o}' && sha256sum -c empreintes.sha256")
        # Copie publiable : plus de GPS, d'appareil ni d'auteur.
        p = f"{R}/Photos/Publiables/{day}/IMG_0001.jpg"
        meta = u(f"exiftool -s -gps:all -Make -Model -SerialNumber -Artist '{p}'")
        assert meta.strip() == "", meta
        u(f"test -s '{R}/Photos/Publiables/{day}/IMG_0002.png'")
        # RAW (non nettoyable) : original seulement ; texte ignoré.
        u(f"test -f '{o}/{day}/IMG_0003.dng'")
        u(f"test ! -e '{R}/Photos/Publiables/{day}/IMG_0003.dng'")
        u(f"test ! -e '{o}/{day}/notes.txt'")

    with subtest("réimport : doublons ignorés"):
        out = u("epiviosi-news-import --sujet 'marché nord' ~/carte")
        assert "Importés : 0" in out and "déjà présents : 3" in out, out

    with subtest("envoi : archive chiffrée, sans métadonnées, empreintes"):
        u("mkdir -p ~/cle2")
        u("cp ~/Rédaction/Modèles/article.odt ~/Rédaction/Articles/reportage.odt")
        u("echo 'Témoin A : 14 h, convoi vers le nord.' > ~/Rédaction/Articles/notes.txt")
        # Un original avec GPS envoyé par erreur : nettoyé dans l'archive.
        out = u(f"echo 'fleuve lampe orange' | epiviosi-news-envoi --dest ~/cle2 --nom test "
                f"~/Rédaction/Articles '{o}/{day}/IMG_0001.jpg'")
        print(out)
        u("test -s ~/cle2/test.7z && cd ~/cle2 && sha256sum -c test.7z.sha256")
        # Sans la phrase : ni contenu ni noms de fichiers lisibles.
        u_fail("7zz l -p'mauvaise' ~/cle2/test.7z")
        machine.fail("grep -a -q -e reportage -e convoi /home/epiviosi/cle2/test.7z")
        u("cd ~/cle2 && 7zz x -p'fleuve lampe orange' -y -oext test.7z >/dev/null")
        u("cd ~/cle2/ext/test && sha256sum -c SHA256SUMS && test -s MANIFESTE.txt")
        meta = u("exiftool -s -gps:all -Make -Model -Artist ~/cle2/ext/test/IMG_0001.jpg")
        assert meta.strip() == "", meta
        u("grep -q convoi ~/cle2/ext/test/Articles/notes.txt")
        u("test -s ~/cle2/ext/test/Articles/reportage.odt")
        u("grep -q test.7z ~/Rédaction/Envois/journal.txt")
        u("test -z \"$(ls -A ~/Rédaction/Envois | grep preparation)\"")

    with subtest("envoi refusé : fichier non nettoyable, destination absente"):
        u_fail(f"echo 'fleuve lampe orange' | epiviosi-news-envoi --dest ~/cle2 --nom raw '{o}/{day}/IMG_0003.dng'")
        u("test ! -e ~/cle2/raw.7z")
        u_fail(f"echo 'fleuve lampe orange' | epiviosi-news-envoi --dest ~/inexistant '{o}/{day}/IMG_0001.jpg'")

    with subtest("verrouillé : contenu chiffré, illisible"):
        u("epiviosi-news-coffre fermer")
        assert u("epiviosi-news-coffre etat").strip() == "ferme"
        u("test ! -e ~/Rédaction/Articles/notes.txt")
        u("test -f ~/Persistant/.redaction/gocryptfs.conf")
        machine.fail("grep -r -a -q convoi /home/epiviosi/Persistant/.redaction")
        u_fail("epiviosi-news-import ~/carte")

    with subtest("verrouillage d'urgence avec un fichier ouvert"):
        u_fail("echo 'mauvaise phrase' | epiviosi-news-coffre ouvrir")
        u("echo 'cheval batterie agrafe' | epiviosi-news-coffre ouvrir")
        machine.succeed("su - epiviosi -c 'sleep 600 < ~/Rédaction/Articles/notes.txt' >/dev/null 2>&1 &")
        machine.wait_until_succeeds("pgrep -f 'sleep 600'")
        u_fail("epiviosi-news-coffre fermer")
        u("epiviosi-news-coffre fermer --force")
        assert u("epiviosi-news-coffre etat").strip() == "ferme"
        machine.fail("pgrep -u epiviosi -f Persistant/.redaction")
        u("test ! -e ~/Rédaction/Articles/notes.txt")
        u("echo 'cheval batterie agrafe' | epiviosi-news-coffre ouvrir")
        u("grep -q convoi ~/Rédaction/Articles/notes.txt")
  '';
}
