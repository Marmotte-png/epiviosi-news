# epiviosi-news-redaction — interface graphique du coffre « Rédaction ».

# Rendu logiciel pour les fenêtres GTK4 de zenity : sans accélération Vulkan
# (cartes graphiques anciennes ou virtuelles), elles restaient invisibles.
export GSK_RENDERER="${GSK_RENDERER:-cairo}"

titre="Rédaction — EPIVÍOSI NEWS"
clair="$(epiviosi-news-coffre dossier)"
# Supports amovibles montés par XFCE (cartes mémoire, clés, téléphones).
amovibles="/run/media/$USER"
[ -d "$amovibles" ] || amovibles="$HOME"

erreur() { zenity --error --title="$titre" --width=420 --text="$1"; }

# Exécute une commande en affichant une barre d'attente, puis son compte rendu.
avec_progression() {  # TEXTE COMMANDE...
  local texte="$1" sortie rc
  shift
  sortie="$(mktemp -p "${XDG_RUNTIME_DIR:-/tmp}")"
  "$@" >"$sortie" 2>&1 &
  local pid=$!
  while kill -0 "$pid" 2>/dev/null; do sleep 0.5; echo "#$texte"; done \
    | zenity --progress --pulsate --auto-close --no-cancel --title="$titre" --width=420 --text="$texte"
  wait "$pid"; rc=$?
  zenity --text-info --title="$titre" --width=640 --height=420 --filename="$sortie"
  rm -f "$sortie"
  return "$rc"
}

importer() {
  local src sujet
  src="$(zenity --file-selection --directory --multiple --separator=$'\n' \
           --title="Dossier à importer (carte mémoire, téléphone…)" --filename="$amovibles/")" || return 0
  sujet="$(zenity --entry --title="$titre" --width=420 \
             --text="Sujet (facultatif, ex. « marché-nord ») :")" || return 0
  local args=()
  [ -n "$sujet" ] && args+=(--sujet "$sujet")
  mapfile -t sources <<<"$src"
  avec_progression "Import et nettoyage des métadonnées…" epiviosi-news-import "${args[@]}" "${sources[@]}"
}

envoyer() {
  local sel dest nom p1 p2
  sel="$(zenity --file-selection --multiple --separator=$'\n' \
           --title="Fichiers à envoyer (Ctrl pour en choisir plusieurs)" --filename="$clair/")" || return 0
  dest="$(zenity --file-selection --directory \
            --title="Où écrire l'archive (autre clé USB…)" --filename="$amovibles/")" || return 0
  case "$dest" in
    "$clair"|"$clair"/*) erreur "Choisissez une destination hors du coffre (une autre clé USB, par exemple)."; return 1 ;;
  esac
  nom="$(zenity --entry --title="$titre" --width=420 --text="Nom de l'archive :" \
           --entry-text="envoi-$(date +%Y%m%d-%H%M)")" || return 0
  zenity --info --title="$titre" --width=440 \
    --text="L'archive sera chiffrée par une phrase de passe.\n\nTransmettez-la au destinataire <b>par un autre canal</b> que l'archive." || return 0
  p1="$(zenity --password --title="Phrase de passe de l'archive")" || return 0
  p2="$(zenity --password --title="Confirmer la phrase de passe")" || return 0
  [ "$p1" = "$p2" ] || { erreur "Les deux phrases de passe sont différentes."; return 1; }
  mapfile -t fichiers <<<"$sel"
  envoi_avec_phrase() { printf '%s\n' "$p1" | epiviosi-news-envoi --dest "$dest" --nom "$nom" "${fichiers[@]}"; }
  avec_progression "Nettoyage des métadonnées et chiffrement…" envoi_avec_phrase
}

menu() {
  while true; do
    choix="$(zenity --list --title="$titre" --width=480 --height=380 \
               --text="Le coffre est ouvert : <tt>$clair</tt>" \
               --column="" --column="Action" --hide-column=1 --print-column=1 \
               dossier "Ouvrir le dossier Rédaction" \
               import "Importer des photos (originaux + copies sans métadonnées)" \
               retouche "Retoucher une photo (flouter visages, plaques…)" \
               envoi "Préparer un envoi chiffré" \
               guide "Guide de sécurité terrain" \
               verrou "Verrouiller le coffre")" || return 0
    case "$choix" in
      dossier) xdg-open "$clair" & ;;
      import) importer ;;
      retouche)
        f="$(zenity --file-selection --title="Photo à retoucher" --filename="$clair/Photos/Publiables/")" \
          && { gimp "$f" >/dev/null 2>&1 & }
        ;;
      envoi) envoyer ;;
      guide) epiviosi-news & ;;
      verrou)
        msg="$(epiviosi-news-coffre fermer 2>&1)" || {
          if zenity --question --title="$titre" --width=440 --ok-label="Verrouiller quand même" --cancel-label="Annuler" \
               --text="$msg\n\nForcer le verrouillage ? Les modifications non enregistrées seront perdues."; then
            epiviosi-news-coffre fermer --force >/dev/null 2>&1
          else
            continue
          fi
        }
        zenity --info --title="$titre" --width=300 --text="Coffre verrouillé."
        return 0
        ;;
    esac
  done
}

case "$(epiviosi-news-coffre etat)" in
  ouvert)
    menu
    ;;
  ferme)
    phrase="$(zenity --password --title="$titre")" || exit 0
    msg="$(printf '%s\n' "$phrase" | epiviosi-news-coffre ouvrir 2>&1)" || { erreur "$msg"; exit 1; }
    menu
    ;;
  absent)
    if [ ! -d "$HOME/Persistant" ]; then
      zenity --question --title="$titre" --width=440 --ok-label="Continuer" --cancel-label="Annuler" \
        --text="Aucune partition de persistance : photos et articles seront <b>perdus au redémarrage</b>.\n\nPour les conserver : <tt>sudo epiviosi-persist-setup</tt>, puis redémarrer." \
        || exit 0
    fi
    zenity --info --title="$titre" --width=440 \
      --text="Création du coffre chiffré « Rédaction ».\n\nChoisissez une phrase de passe longue (plusieurs mots), que vous ne notez nulle part sur vous. <b>Sans elle, le contenu est irrécupérable.</b>" || exit 0
    p1="$(zenity --password --title="Nouvelle phrase de passe")" || exit 0
    p2="$(zenity --password --title="Confirmer la phrase de passe")" || exit 0
    [ "$p1" = "$p2" ] || { erreur "Les deux phrases de passe sont différentes."; exit 1; }
    msg="$(printf '%s\n' "$p1" | epiviosi-news-coffre creer 2>&1)" || { erreur "$msg"; exit 1; }
    menu
    ;;
esac
