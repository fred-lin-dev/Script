#!/bin/bash

# Formate récursivement tous les fichiers .c et .h du dossier courant
# Usage: ./clang_format_c.sh (lancer depuis la racine du projet)
# Dépendances: clang-format, config dans ~/.config/clang-format/clang-format-c-current

find . -type f \( -name "*.c" -o -name "*.h" \) -exec clang-format -i -style="file:$HOME/.config/clang-format/clang-format-c-current" {} +
