# Scripts

Collection de scripts shell et Python pour automatiser des tâches courantes.

## Table des scripts

| Script | Description | Dépendances | Usage |
|---|---|---|---|
| `audio_convert.sh` | Convertit des fichiers audio en lot vers mp3, flac, ogg, wav, m4a ou opus | `ffmpeg` | `./audio_convert.sh <format> [dossier] [qualité_kbps]` |
| `batch_rename.sh` | Renomme des fichiers en lot avec preview et confirmation (supporte les regex) | `fzf` *(optionnel)* | `./batch_rename.sh [dossier] [pattern] [remplacement]` |
| `cleanup.sh` | Nettoie les fichiers temporaires, caches et corbeille pour libérer de l'espace | `pacman`, `trash-cli` *(optionnel)* | `./cleanup.sh [--dry-run]` |
| `clip_history.sh` | Historique de presse-papiers navigable avec fzf (mode démon + sélection) | `xclip`, `fzf` | `./clip_history.sh [--daemon]` |
| `csv_view.sh` | Affiche un fichier CSV proprement aligné dans le terminal | `column` (util-linux), `less` | `./csv_view.sh <fichier.csv> [séparateur] [lignes_max]` |
| `delete_anki_note.py` | Supprime des notes Anki via l'API AnkiConnect | Anki + addon `AnkiConnect` | `python delete_anki_note.py <note_id> [note_id ...]` |
| `disk_usage.sh` | Visualise l'espace disque par dossier, navigable avec fzf | `fzf` *(optionnel)* | `./disk_usage.sh [dossier] [profondeur]` |
| `encrypt_file.sh` | Chiffre/déchiffre un fichier avec mot de passe (GPG AES-256) | `gpg` | `./encrypt_file.sh enc\|dec <fichier> [-d]` |
| `extract.sh` | Extrait n'importe quelle archive en une seule commande | `tar`, `unzip`, `7z`, `unrar` *(selon format)* | `./extract.sh <archive> [dossier_destination]` |
| `find_dupes.sh` | Trouve les fichiers en double par hash MD5 dans un dossier | `md5sum` *(builtin)* | `./find_dupes.sh [dossier]` |
| `img_compress.sh` | Compresse des images en lot (jpg/png/webp) avec affichage du gain de taille | `imagemagick`, `optipng` *(optionnel)* | `./img_compress.sh [dossier] [qualité] [format_sortie]` |
| `ip_info.sh` | Affiche l'IP publique, locale et les infos de géolocalisation | `curl` | `./ip_info.sh` |
| `mirror.sh` | Fait un miroir complet d'un site web (pages statiques + vidéos) | `wget`, `yt-dlp` | `./mirror.sh <URL> [cookies.txt]` |
| `mkpasswd.sh` | Génère des mots de passe forts aléatoires (longueur, quantité, prononçable) | `xclip` ou `wl-copy` *(optionnel)* | `./mkpasswd.sh [longueur] [nombre] [-s\|-p]` |
| `network_scan.sh` | Scanne les appareils connectés sur le réseau local | `nmap` | `./network_scan.sh [plage_réseau]` |
| `portswigger_dl.py` | Mirror hors-ligne de la Web Security Academy (cours, labs, learning paths) avec index de navigation | `python3` *(stdlib uniquement)* | `python3 portswigger_dl.py [dossier_sortie] [cookies.txt]` |
| `screenshot_ocr.sh` | Capture une zone d'écran, extrait le texte (OCR) et le copie dans le presse-papiers | `scrot`, `tesseract`, `xclip` | `./screenshot_ocr.sh [langue]` |
| `serve.sh` | Lance un serveur HTTP local instantané depuis un dossier | `python3` | `./serve.sh [dossier] [port]` |
| `vtt_to_txt.sh` | Convertit un fichier `.vtt` (ou `.srt`) en texte brut sans timings ni balises | `xclip` ou `wl-copy` *(optionnel)* | `./vtt_to_txt.sh <fichier.vtt> [sortie.txt]` |
| `ssh_setup.sh` | Génère une clé SSH et l'installe sur un serveur distant | `ssh-keygen`, `ssh-copy-id` | `./ssh_setup.sh [user@host] [-p port]` |
| `sys_info.sh` | Affiche un résumé système rapide (CPU, RAM, disque, GPU, réseau, batterie) | `lscpu`, `free`, `lsblk`, `lspci`, `xrandr`, `upower` *(tous optionnels)* | `./sys_info.sh` |
| `timer.sh` | Minuteur / Pomodoro en terminal avec notification desktop | `notify-send`, `paplay` ou `aplay` *(optionnel)* | `./timer.sh <25m\|1h30m\|90\|pomodoro>` |
| `transcribe.sh` | Transcrit un fichier audio/vidéo local **ou** une URL (YouTube, etc.) en `.txt` + `.vtt` | `whisper-cli`, `ffmpeg`, `yt-dlp` *(pour les URL)* | `./transcribe.sh <fichier|URL> [langue]` |
| `yt_audio_dl.sh` | Télécharge l'audio d'une vidéo YouTube en mp3 | `yt-dlp` | `./yt_audio_dl.sh <URL> [dossier_sortie]` |
| `yt_playlist_dl.sh` | Télécharge une playlist YouTube complète avec numérotation | `yt-dlp` | `./yt_playlist_dl.sh <URL_playlist> [dossier_sortie]` |
| `yt_subtitles_dl.sh` | Télécharge les sous-titres/transcriptions d'une vidéo YouTube | `yt-dlp` | `./yt_subtitles_dl.sh <URL> [langue] [dossier_sortie]` |
