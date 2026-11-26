{
  symlinkJoin,
  writeShellApplication,
  gocryptfs,
  util-linux,
  procps,
  coreutils,
  findutils,
  gnugrep,
  gnused,
  gawk,
  file,
  mat2,
  exiftool,
  _7zz,
  zenity,
  xdg-utils,
  modeles,
}:
let
  coffre = writeShellApplication {
    name = "epiviosi-news-coffre";
    runtimeInputs = [
      gocryptfs
      util-linux
      procps
      coreutils
    ];
    runtimeEnv.EPIVIOSI_NEWS_MODELES = "${modeles}";
    text = builtins.readFile ./epiviosi-news-coffre.sh;
  };
  outils = [
    coffre
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    mat2
    exiftool
  ];
  import' = writeShellApplication {
    name = "epiviosi-news-import";
    runtimeInputs = outils;
    text = builtins.readFile ./epiviosi-news-import.sh;
  };
  envoi = writeShellApplication {
    name = "epiviosi-news-envoi";
    runtimeInputs = outils ++ [
      file
      _7zz
    ];
    text = builtins.readFile ./epiviosi-news-envoi.sh;
  };
  # gimp et le guide (epiviosi-news) sont fournis par le module NixOS.
  redaction = writeShellApplication {
    name = "epiviosi-news-redaction";
    runtimeInputs = [
      coffre
      import'
      envoi
      zenity
      xdg-utils
      coreutils
    ];
    text = builtins.readFile ./epiviosi-news-redaction.sh;
  };
in
symlinkJoin {
  name = "epiviosi-news";
  paths = [
    coffre
    import'
    envoi
    redaction
  ];
  meta.description = "Coffre chiffré « Rédaction », import sans métadonnées et envois chiffrés d'EPIVÍOSI NEWS";
}
