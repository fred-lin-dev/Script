#!/bin/bash

# Formate récursivement tous les fichiers .c et .h du dossier courant (style C++)
# Usage: ./clang_format_cxx.sh (lancer depuis la racine du projet)
# Dépendances: clang-format, config dans ~/.config/clang-format/clang-format-cxx-current

find . -type f \( -name "*.c" -o -name "*.h" \) -exec clang-format -i -style="file:$HOME/.config/clang-format/clang-format-cxx-current" {} +
