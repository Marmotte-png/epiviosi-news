# epiviosi-news-envoi — prépare un envoi : archive chiffrée, sans métadonnées,
# avec les empreintes de son contenu.
#
# Usage : epiviosi-news-envoi --dest DOSSIER [--nom NOM] ÉLÉMENT...
#   (phrase de passe de l'archive lue sur l'entrée standard, 8 caractères min.)
#   --dest : où écrire l'archive (ex. une autre clé USB : /run/media/$USER/CLE).
#   --nom  : nom de l'archive (défaut : envoi-AAAAMMJJ-HHMM).
#   ÉLÉMENT : fichiers ou dossiers, en général pris dans ~/Rédaction.
#
# Résultat dans DOSSIER :
#   NOM.7z        archive 7-Zip AES-256, noms de fichiers chiffrés aussi ;
#                 s'ouvre avec 7-Zip (Windows), Keka (macOS), 7zz/p7zip (Linux) ;
#   NOM.7z.sha256 empreinte de l'archive, à transmettre au destinataire.
# Dans l'archive : les fichiers nettoyés par mat2 (GPS, appareil, auteur…),
# SHA256SUMS et MANIFESTE.txt. Le coffre doit être ouvert ; la préparation se
# fait dans le coffre, et l'envoi est noté dans Envois/journal.txt.
# Un fichier que mat2 ne sait pas nettoyer arrête l'envoi (sauf texte brut).

die() { echo "Erreur : $*" >&2; exit 1; }

dest="" nom=""
elements=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dest) [ $# -ge 2 ] || die "--dest attend un dossier."; dest="$2"; shift ;;
    --dest=*) dest="${1#--dest=}" ;;
    --nom) [ $# -ge 2 ] || die "--nom attend un nom."; nom="$2"; shift ;;
    --nom=*) nom="${1#--nom=}" ;;
    -h|--help) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) die "option inconnue : $1" ;;
    *) elements+=("$1") ;;
  esac
  shift
done
[ -n "$dest" ] || die "indiquez la destination (--dest DOSSIER)."
[ -d "$dest" ] && [ -w "$dest" ] || die "destination inaccessible en écriture : $dest"
[ ${#elements[@]} -gt 0 ] || die "indiquez les fichiers ou dossiers à envoyer."
for e in "${elements[@]}"; do [ -e "$e" ] || die "introuvable : $e"; done

[ "$(epiviosi-news-coffre etat)" = ouvert ] || die "le coffre « Rédaction » est verrouillé ; ouvrez-le d'abord."
clair="$(epiviosi-news-coffre dossier)"

[ -n "$nom" ] || nom="envoi-$(date +%Y%m%d-%H%M)"
nom="${nom//[\/[:space:][:cntrl:]]/-}"
nom="$(sed -E 's/^[-.]+//' <<<"$nom")"
[ -n "$nom" ] || die "nom d'archive invalide."
archive="$dest/$nom.7z"
[ ! -e "$archive" ] || die "$archive existe déjà ; choisissez un autre nom (--nom)."

IFS= read -r phrase || true
[ "${#phrase}" -ge 8 ] || die "phrase de passe de l'archive trop courte (8 caractères minimum)."

# Préparation dans le coffre (chiffré), jamais en clair ailleurs.
mkdir -p "$clair/Envois"
prep="$(mktemp -d "$clair/Envois/.preparation-XXXXXX")"
trap 'rm -rf "$prep"' EXIT
mkdir "$prep/$nom"
for e in "${elements[@]}"; do
  cp -r --no-preserve=mode,ownership,timestamps "$e" "$prep/$nom/"
done

refus=()
n=0
while IFS= read -r -d '' f; do
  n=$((n + 1))
  rel="${f#"$prep/$nom/"}"
  if mat2 --inplace "$f" >/dev/null 2>&1; then
    if [ -n "$(exiftool -q -q -s3 -gps:all "$f" 2>/dev/null)" ]; then
      refus+=("$rel (position GPS encore présente)")
    fi
  else
    case "$(file -b --mime-type "$f")" in
      text/plain|text/markdown|text/csv) ;;  # texte brut : pas de métadonnées
      *) refus+=("$rel") ;;
    esac
  fi
done < <(find "$prep/$nom" -type f -print0)
[ "$n" -gt 0 ] || die "aucun fichier à envoyer."
if [ ${#refus[@]} -gt 0 ]; then
  printf 'Métadonnées impossibles à nettoyer, envoi annulé :\n' >&2
  printf '  %s\n' "${refus[@]}" >&2
  die "convertissez ces fichiers (ex. en JPEG, PDF ou ODT) ou retirez-les de l'envoi."
fi

(cd "$prep/$nom" && find . -type f -print0 | sort -z | xargs -0 sha256sum | sed 's|  \./|  |' > ../SHA256SUMS)
mv "$prep/SHA256SUMS" "$prep/$nom/SHA256SUMS"
cat > "$prep/$nom/MANIFESTE.txt" <<EOF
Envoi : $nom
Préparé le : $(date -u '+%Y-%m-%d %H:%M UTC')
Fichiers : $n
Métadonnées (GPS, appareil, auteur, logiciel…) retirées avec mat2.
Vérifier l'intégrité : sha256sum -c SHA256SUMS
EOF

printf '%s\n%s\n' "$phrase" "$phrase" \
  | (cd "$prep" && 7zz a -t7z -mhe=on -mx=5 -p -bso0 -bsp0 "$archive.part" "$nom" >/dev/null) \
  || { rm -f "$archive.part"; die "création de l'archive impossible (place libre sur la destination ?)."; }
mv "$archive.part" "$archive"
(cd "$dest" && sha256sum "$nom.7z" > "$nom.7z.sha256")
sync -f "$archive" 2>/dev/null || sync

somme="$(awk '{print $1}' "$dest/$nom.7z.sha256")"
printf '%s  %s -> %s  (%s fichiers)\n' "$(date '+%F %T')" "$somme" "$archive" "$n" >> "$clair/Envois/journal.txt"

echo "Archive chiffrée : $archive ($n fichiers, $(du -h "$archive" | cut -f1))"
echo "Empreinte SHA-256 : $somme"
echo "Transmettez la phrase de passe par un autre canal que l'archive."
