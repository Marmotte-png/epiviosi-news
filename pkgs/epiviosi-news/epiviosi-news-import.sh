# epiviosi-news-import — importe photos, vidéos et sons dans le coffre « Rédaction ».
#
# Usage : epiviosi-news-import [--sujet NOM] SOURCE...
#   SOURCE : dossier (carte mémoire, appareil photo, téléphone…) ou fichier.
#   --sujet : nom ajouté au dossier du jour (ex. « marché-nord »).
#
# Pour chaque fichier :
#   1. l'original, intact (métadonnées comprises), est copié dans
#      Photos/Originaux/AAAA-MM-JJ[_sujet]/ et son empreinte SHA-256 est notée
#      dans Photos/Originaux/empreintes.sha256 (preuve d'authenticité) ;
#   2. une copie nettoyée par mat2 (sans position GPS, appareil, date…) est
#      créée dans Photos/Publiables/, au même endroit.
# Un fichier déjà importé (même empreinte) est ignoré. Les formats que mat2 ne
# sait pas nettoyer (RAW…) sont seulement conservés en original.
# Le coffre doit être ouvert : rien n'est écrit en clair hors du coffre.

die() { echo "Erreur : $*" >&2; exit 1; }

sujet=""
sources=()
while [ $# -gt 0 ]; do
  case "$1" in
    --sujet) [ $# -ge 2 ] || die "--sujet attend un nom."; sujet="$2"; shift ;;
    --sujet=*) sujet="${1#--sujet=}" ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) die "option inconnue : $1" ;;
    *) sources+=("$1") ;;
  esac
  shift
done
[ ${#sources[@]} -gt 0 ] || die "indiquez un dossier ou des fichiers à importer."

[ "$(epiviosi-news-coffre etat)" = ouvert ] || die "le coffre « Rédaction » est verrouillé ; ouvrez-le d'abord."
clair="$(epiviosi-news-coffre dossier)"

# Nom du sujet : pas de chemin ni d'espace (accents conservés).
sujet="${sujet//[\/[:space:][:cntrl:]]/-}"
sujet="$(sed -E 's/^[-.]+//; s/-+$//' <<<"$sujet")"
jour="$(date +%F)${sujet:+_$sujet}"
orig_dir="$clair/Photos/Originaux/$jour"
pub_dir="$clair/Photos/Publiables/$jour"
empreintes="$clair/Photos/Originaux/empreintes.sha256"
touch "$empreintes"

extensions='jpg|jpeg|png|tif|tiff|webp|gif|bmp|heic|heif|avif|dng|cr2|cr3|nef|arw|orf|rw2|raf|mp4|mov|m4v|3gp|avi|mkv|webm|wmv|mp3|m4a|wav|ogg|opus|flac|aac|amr'

importes=0 doublons=0 nettoyes=0 non_nettoyes=0

lister() {
  local s
  for s in "${sources[@]}"; do
    if [ -d "$s" ]; then
      find "$s" -type f -regextype posix-extended -iregex ".*\\.($extensions)" -print0
    elif [ -f "$s" ]; then
      printf '%s\0' "$s"
    else
      echo "Introuvable : $s" >&2
    fi
  done
}

# Nom libre dans le dossier : IMG_0001.jpg, sinon IMG_0001-2.jpg…
nom_libre() {  # DOSSIER NOM
  local base="${2%.*}" ext="${2##*.}" n=2 cand="$2"
  [ "$base" = "$2" ] && ext=""
  while [ -e "$1/$cand" ]; do
    cand="$base-$n${ext:+.$ext}"; n=$((n + 1))
  done
  echo "$cand"
}

while IFS= read -r -d '' f; do
  somme="$(sha256sum "$f" | awk '{print $1}')"
  if grep -q "^$somme " "$empreintes"; then
    doublons=$((doublons + 1))
    continue
  fi
  mkdir -p "$orig_dir"
  nom="$(nom_libre "$orig_dir" "$(basename "$f")")"
  cp --preserve=timestamps "$f" "$orig_dir/$nom"
  # Chemin relatif à Photos/Originaux : « cd Originaux && sha256sum -c empreintes.sha256 ».
  printf '%s  %s\n' "$somme" "$jour/$nom" >> "$empreintes"
  importes=$((importes + 1))

  mkdir -p "$pub_dir"
  pub="$pub_dir/$(nom_libre "$pub_dir" "$nom")"
  cp "$orig_dir/$nom" "$pub"
  if mat2 --inplace "$pub" >/dev/null 2>&1 \
     && [ -z "$(exiftool -q -q -s3 -gps:all "$pub" 2>/dev/null)" ]; then
    nettoyes=$((nettoyes + 1))
    echo "OK : $jour/$nom"
  else
    rm -f "$pub"
    non_nettoyes=$((non_nettoyes + 1))
    echo "Original seulement (métadonnées non nettoyables, à convertir avant publication) : $jour/$nom"
  fi
done < <(lister)

rmdir "$pub_dir" 2>/dev/null || true
echo
echo "Importés : $importes (nettoyés : $nettoyes ; originaux seuls : $non_nettoyes) ; déjà présents : $doublons."
[ "$importes" -eq 0 ] || echo "Originaux : $orig_dir"
[ "$nettoyes" -eq 0 ] || echo "Publiables (sans métadonnées) : $pub_dir"
