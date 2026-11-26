# epiviosi-news-coffre — coffre chiffré « Rédaction » (gocryptfs).
#
# Usage : epiviosi-news-coffre {creer|ouvrir|fermer [--force]|etat|dossier}
#   creer   : crée le coffre (phrase de passe lue sur l'entrée standard),
#             avec son arborescence et les modèles d'articles ;
#   ouvrir  : déverrouille le coffre dans ~/Rédaction
#             (phrase de passe lue sur l'entrée standard) ;
#   fermer  : verrouille le coffre. --force (verrouillage d'urgence) : même
#             si des fichiers sont ouverts ; les modifications non
#             enregistrées sont perdues ;
#   etat    : affiche « absent », « ferme » ou « ouvert » ;
#   dossier : affiche le chemin du dossier déverrouillé.
#
# Le coffre chiffré est rangé dans ~/Persistant (partition de persistance) ;
# sans persistance, dans ~/.redaction, perdu au redémarrage.
# EPIVIOSI_NEWS_MODELES : dossier des modèles (fourni par le paquet).

die() { echo "Erreur : $*" >&2; exit 1; }

if [ -d "$HOME/Persistant" ]; then
  coffre="$HOME/Persistant/.redaction"
else
  coffre="$HOME/.redaction"
fi
clair="$HOME/Rédaction"

etat() {
  if mountpoint -q "$clair"; then echo ouvert
  elif [ -f "$coffre/gocryptfs.conf" ]; then echo ferme
  else echo absent
  fi
}

lire_phrase() {
  IFS= read -r phrase || true
  [ -n "${phrase:-}" ] || die "phrase de passe vide."
}

case "${1:-}" in
  etat)
    etat
    ;;
  dossier)
    echo "$clair"
    ;;
  creer)
    [ "$(etat)" = absent ] || die "le coffre existe déjà ($coffre)."
    lire_phrase
    [ "${#phrase}" -ge 8 ] || die "phrase de passe trop courte (8 caractères minimum)."
    mkdir -p "$coffre" "$clair"
    gocryptfs -init -q -passfile <(printf '%s\n' "$phrase") "$coffre" >/dev/null \
      || die "création du coffre impossible."
    gocryptfs -q -passfile <(printf '%s\n' "$phrase") "$coffre" "$clair" \
      || die "ouverture du coffre impossible."
    mkdir -p "$clair/Articles" "$clair/Photos/Originaux" "$clair/Photos/Publiables" \
             "$clair/Envois" "$clair/Modèles"
    cp --no-preserve=mode "$EPIVIOSI_NEWS_MODELES"/*.odt "$clair/Modèles/"
    echo "Coffre créé et ouvert : $clair"
    ;;
  ouvrir)
    case "$(etat)" in
      absent) die "aucun coffre ; créez-le d'abord." ;;
      ouvert) echo "Déjà ouvert : $clair"; exit 0 ;;
    esac
    lire_phrase
    mkdir -p "$clair"
    gocryptfs -q -passfile <(printf '%s\n' "$phrase") "$coffre" "$clair" 2>/dev/null \
      || die "phrase de passe incorrecte."
    echo "Ouvert : $clair"
    ;;
  fermer)
    [ "$(etat)" = ouvert ] || { echo "Déjà fermé."; exit 0; }
    if [ "${2:-}" = --force ]; then
      # Démontage paresseux (plus aucun nouvel accès), puis arrêt de gocryptfs :
      # la clé de chiffrement quitte la mémoire même si des fichiers étaient
      # encore ouverts.
      fusermount -uz "$clair" 2>/dev/null || true
      pkill -TERM -u "$(id -u)" -f "gocryptfs.* $coffre " 2>/dev/null || true
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        pgrep -u "$(id -u)" -f "gocryptfs.* $coffre " >/dev/null || break
        sleep 0.3
      done
      pkill -KILL -u "$(id -u)" -f "gocryptfs.* $coffre " 2>/dev/null || true
      mountpoint -q "$clair" && die "verrouillage impossible."
      echo "Coffre verrouillé (urgence)."
    else
      fusermount -u "$clair" 2>/dev/null \
        || die "fermeture impossible : un fichier est encore ouvert. Fermez les applications, ou utilisez le verrouillage d'urgence."
      echo "Coffre verrouillé."
    fi
    ;;
  *)
    echo "Usage : epiviosi-news-coffre {creer|ouvrir|fermer [--force]|etat|dossier}" >&2
    exit 1
    ;;
esac
