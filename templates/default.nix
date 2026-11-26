# Modèles d'articles et de fiches (HTML → ODT LibreOffice, convertis à la construction).
# soffice prend la langue de la locale de construction (anglais US) : on force le
# français (France) dans styles.xml, sinon le correcteur souligne chaque mot.
{
  runCommand,
  libreoffice-fresh,
  unzip,
  zip,
}:
runCommand "epiviosi-news-modeles"
  {
    nativeBuildInputs = [
      libreoffice-fresh
      unzip
      zip
    ];
  }
  ''
    export HOME=$TMPDIR
    mkdir -p $out
    for f in ${./.}/*.html; do
      soffice --headless --infilter=HTML --convert-to odt:writer8 --outdir $out "$f" >/dev/null
    done
    for odt in $out/*.odt; do
      d=$(mktemp -d)
      unzip -q "$odt" -d "$d"
      sed -i -e 's/fo:language="[^"]*"/fo:language="fr"/g' \
             -e 's/fo:country="[^"]*"/fo:country="FR"/g' "$d/styles.xml"
      grep -q 'fo:language="fr" fo:country="FR"' "$d/styles.xml"
      rm "$odt"
      # mimetype en premier et non compressé (format OpenDocument)
      (cd "$d" && zip -q -X -0 "$odt" mimetype && zip -q -X -r "$odt" . -x mimetype)
    done
    ls $out/*.odt >/dev/null
  ''
