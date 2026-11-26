# EPIVÍOSI NEWS : espace de travail chiffré pour journalistes en zone de conflit.
#
# - Rédaction (menu) : coffre chiffré (gocryptfs) dans ~/Persistant, ouvert
#   avec une phrase de passe dans ~/Rédaction : Articles, Photos (Originaux et
#   Publiables), Envois, modèles LibreOffice (article, dépêche, journal de
#   terrain, fiche source).
# - Import de photos, vidéos et sons : original conservé avec son empreinte
#   SHA-256, copie publiable sans métadonnées (mat2 : GPS, appareil, date…).
# - Retouche (GIMP) pour flouter visages et plaques.
# - Envoi : archive 7-Zip chiffrée (AES-256), métadonnées retirées, empreintes.
# - « Verrouiller la rédaction » (menu) : verrouillage d'urgence du coffre.
# - Guide « EPIVÍOSI NEWS » : sécurité terrain, protection des sources.
#
# Ce module implémente `epiviosi.news.enable`, déclarée par le socle
# EPIVÍOSI OS (modules/epiviosi-modules.nix).
{ config, lib, pkgs, ... }:
let
  cfg = config.epiviosi.news;

  modeles = pkgs.callPackage ./templates { };
  news = pkgs.callPackage ./pkgs/epiviosi-news { inherit modeles; };

  guide = pkgs.writeShellScriptBin "epiviosi-news" ''
    exec firefox file:///etc/epiviosi/news/guide.html
  '';

  guideItem = pkgs.makeDesktopItem {
    name = "epiviosi-news";
    desktopName = "EPIVÍOSI NEWS";
    genericName = "Guide du journaliste";
    comment = "Sécurité terrain, protection des sources, mode d'emploi de la rédaction";
    exec = "epiviosi-news";
    icon = "help-browser";
    categories = [
      "Office"
      "Documentation"
    ];
    keywords = [
      "journaliste"
      "presse"
      "reportage"
      "sécurité"
      "news"
    ];
  };

  redactionItem = pkgs.makeDesktopItem {
    name = "epiviosi-news-redaction";
    desktopName = "Rédaction";
    genericName = "Coffre chiffré du journaliste";
    comment = "Articles et photos chiffrés : importer sans métadonnées, retoucher, préparer un envoi";
    exec = "epiviosi-news-redaction";
    icon = "folder-documents";
    categories = [
      "Office"
      "Photography"
    ];
    keywords = [
      "article"
      "photo"
      "import"
      "envoi"
      "chiffré"
    ];
  };

  verrouItem = pkgs.makeDesktopItem {
    name = "epiviosi-news-verrouiller";
    desktopName = "Verrouiller la rédaction";
    genericName = "Verrouillage d'urgence";
    comment = "Verrouille immédiatement le coffre « Rédaction », même si des fichiers sont ouverts";
    exec = "epiviosi-news-coffre fermer --force";
    icon = "system-lock-screen";
    categories = [ "Office" ];
    keywords = [
      "urgence"
      "panique"
      "verrou"
    ];
  };
in
{
  config = lib.mkIf cfg.enable {
    environment.etc."epiviosi/news/guide.html".source = ./assets/guide.html;

    environment.systemPackages = [
      news
      guide
      guideItem
      redactionItem
      verrouItem
      pkgs.gimp
      pkgs.mat2
    ];
  };
}
