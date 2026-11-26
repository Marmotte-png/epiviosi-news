# EPIVÍOSI NEWS

Espace de travail chiffré pour journalistes en zone de conflit, hors-ligne, pour
[EPIVÍOSI OS](https://github.com/Marmotte-png/epiviosi) : articles et photos rangés dans la
persistance de la clé USB, métadonnées retirées avant publication, envois chiffrés.

> En cas de danger : menu → **Verrouiller la rédaction**. Le coffre se ferme immédiatement, même
> si des fichiers sont ouverts.

## Contenu

- **Rédaction** (menu) : coffre chiffré [gocryptfs](https://nuetzlich.net/gocryptfs/) rangé dans
  `~/Persistant/.redaction`, ouvert avec une phrase de passe dans `~/Rédaction` :

  | Dossier | Contenu |
  | --- | --- |
  | `Articles/` | Textes |
  | `Photos/Originaux/` | Fichiers intacts (métadonnées comprises) et `empreintes.sha256` |
  | `Photos/Publiables/` | Copies sans métadonnées, à utiliser pour publier |
  | `Envois/` | `journal.txt` des envois préparés |
  | `Modèles/` | LibreOffice : **article**, **dépêche**, **journal de terrain**, **fiche source ou témoin** |

  Sans partition de persistance, le coffre est perdu au redémarrage (l'interface le signale).
- **Importer des photos** (photos, vidéos, sons, depuis une carte mémoire, un appareil ou un
  téléphone) : l'original est copié intact et son empreinte SHA-256 notée (preuve
  d'authenticité) ; une copie nettoyée par [mat2](https://0xacab.org/jvoisin/mat2) (position GPS,
  appareil, numéro de série, date, auteur…) va dans `Photos/Publiables`. Les doublons sont ignorés ;
  les RAW, impossibles à nettoyer, restent seulement en original.
- **Retoucher une photo** : GIMP, pour pixeliser visages et plaques.
- **Préparer un envoi chiffré** : les fichiers choisis sont nettoyés (photos, vidéos, sons,
  ODT, PDF ; l'envoi est refusé si un fichier ne peut pas l'être), accompagnés de `SHA256SUMS` et
  `MANIFESTE.txt`, puis réunis dans une archive **7-Zip AES-256** dont les noms de fichiers sont
  chiffrés aussi, écrite par exemple sur une autre clé USB avec son empreinte (`.7z.sha256`).
  Elle s'ouvre avec 7-Zip, Keka ou p7zip.
- **Verrouiller la rédaction** (menu) : verrouillage d'urgence ; gocryptfs est arrêté et la clé
  de chiffrement quitte la mémoire.
- **Guide « EPIVÍOSI NEWS »** (menu) : mode d'emploi, sécurité numérique et physique, protection
  des sources, contacts (RSF, CPJ, Access Now, CICR).

Rien n'est écrit en clair hors du coffre : l'import et l'envoi refusent de fonctionner quand il
est verrouillé, et l'envoi se prépare à l'intérieur.

## Ligne de commande

```sh
echo 'phrase de passe' | epiviosi-news-coffre creer     # crée et ouvre le coffre
echo 'phrase de passe' | epiviosi-news-coffre ouvrir
epiviosi-news-coffre fermer            # --force : même avec des fichiers ouverts
epiviosi-news-coffre etat              # absent | ferme | ouvert

epiviosi-news-import --sujet marche-nord /run/media/$USER/CARTE_SD
echo 'phrase de l’archive' | epiviosi-news-envoi --dest /run/media/$USER/CLE --nom envoi-1 \
  ~/Rédaction/Articles/texte.odt ~/Rédaction/Photos/Publiables/2026-11-26_marche-nord

cd ~/Rédaction/Photos/Originaux && sha256sum -c empreintes.sha256   # originaux intacts ?
```

## Utilisation dans un flake

Le module implémente l'option `epiviosi.news.enable`, déclarée par le socle EPIVÍOSI OS :

```nix
inputs.epiviosi-news = {
  url = "github:Marmotte-png/epiviosi-news";
  inputs.nixpkgs.follows = "nixpkgs";
};
# …
modules = [ epiviosi-news.nixosModules.default { epiviosi.news.enable = true; } ];
```

## Tests

```sh
nix flake check                      # modèles, outils, test en VM (KVM dans le bac à sable Nix)
$(nix build --no-link --print-out-paths .#checks.x86_64-linux.vm.driver)/bin/nixos-test-driver
```

Le test importe une photo portant GPS, appareil et auteur, puis vérifie : original identique
et empreinte valide, copie publiable sans métadonnées, RAW conservé seulement en original,
doublons ignorés ; archive d'envoi illisible sans la phrase (contenu et noms), contenu sans GPS,
empreintes valides, fichier non nettoyable refusé ; coffre verrouillé illisible ; verrouillage
d'urgence avec un fichier ouvert.

## Structure

| Chemin | Rôle |
| --- | --- |
| `module.nix` | Module NixOS : guide, lanceurs, GIMP, mat2 |
| `pkgs/epiviosi-news/` | Coffre, import, envoi (ligne de commande) et interface zenity |
| `templates/` | Modèles d'articles et de fiches (HTML converti en ODT à la construction) |
| `assets/guide.html` | Guide EPIVÍOSI NEWS (FR/EN) |
| `tests/news.nix` | Test NixOS en VM |

## Licence

[Hippocratic License 2.1](LICENSE).
