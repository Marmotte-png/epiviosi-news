# Modèles d'articles et de fiches (HTML → ODT LibreOffice, convertis à la construction).
{ runCommand, libreoffice-fresh }:
runCommand "epiviosi-news-modeles" { nativeBuildInputs = [ libreoffice-fresh ]; } ''
  export HOME=$TMPDIR
  mkdir -p $out
  for f in ${./.}/*.html; do
    soffice --headless --infilter=HTML --convert-to odt:writer8 --outdir $out "$f" >/dev/null
  done
  ls $out/*.odt >/dev/null
''
