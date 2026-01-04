#!/usr/bin/env bash

###############################################################################
# SCRIPT : add-frontmatter.sh
# OBJECTIF : Compléter front-matter YAML et générer _category_.json
# OPTIONS :
#   --update-md       : Met à jour sidebar_position dans les fichiers .md
#   --update-category : Met à jour position dans _category_.json
#   --update-slug     : Met à jour le champ slug dans les fichiers .md
###############################################################################

if [ $# -lt 1 ]; then
  echo "Usage: $0 <docs_directory> [--update-md] [--update-category] [--update-slug]"
  exit 1
fi

ROOT_DIR="${1%/}"

if [ ! -d "$ROOT_DIR" ]; then
  echo "Erreur: '$ROOT_DIR' n'est pas un dossier valide"
  exit 1
fi

# Flags
UPDATE_MD=false
UPDATE_CATEGORY=false
UPDATE_SLUG=false

shift
while [[ $# -gt 0 ]]; do
  case $1 in
    --update-md) UPDATE_MD=true ;;
    --update-category) UPDATE_CATEGORY=true ;;
    --update-slug) UPDATE_SLUG=true ;;
    *) echo "Option inconnue: $1"; exit 1 ;;
  esac
  shift
done

TODAY="$(date +%Y-%m-%d)"

###############################################################################
# FONCTION : traiter un dossier et ses fichiers
###############################################################################
process_dir() {
  local dir="$1"
  local file_pos=1       # sidebar_position des fichiers .md
  local cat_pos=1        # position des sous-dossiers (_category_.json)

  # 1️⃣ Traiter fichiers Markdown
  find "$dir" -maxdepth 1 -type f -name "*.md" \
    -not -name "index.md" -not -name ".*" | sort | while read -r file; do

    rel_path="${file#$ROOT_DIR/}"
    slug="/${rel_path%.md}"
    filename="$(basename "$file" .md)"
    title="$(echo "$filename" | sed 's/[-_]/ /g' | sed 's/\b\(.\)/\u\1/g')"

    tmpfile="$(mktemp)"

    # Front-matter existant ou création
    if head -n 1 "$file" | grep -q "^---"; then
      awk -v title="$title" -v slug="$slug" -v pos="$file_pos" -v date="$TODAY" \
          -v update_md="$UPDATE_MD" -v update_slug="$UPDATE_SLUG" '
      BEGIN { in_fm=0; has_title=0; has_slug=0; has_pos=0; has_update=0 }
      /^---$/ {
        if (in_fm==0) { in_fm=1; print; next }
        else {
          if (!has_title) print "title: " title
          if (!has_slug && update_slug=="true") print "slug: " slug
          if (!has_pos && update_md=="true") print "sidebar_position: " pos
          if (!has_update) { print "last_update:\n  date: " date "\n  author: Anis" }
          print; in_fm=2; next
        }
      }
      {
        if (in_fm==1) {
          if ($0 ~ /^title:/) has_title=1
          if ($0 ~ /^slug:/) has_slug=1
          if ($0 ~ /^sidebar_position:/) has_pos=1
          if ($0 ~ /^last_update:/) has_update=1
          # Mise à jour conditionnelle
          if ($0 ~ /^slug:/ && update_slug=="true") { $0="slug: " slug }
          if ($0 ~ /^sidebar_position:/ && update_md=="true") { $0="sidebar_position: " pos }
        }
        print
      }' "$file" > "$tmpfile"
    else
      # Pas de front-matter : création complète
      cat <<EOF > "$tmpfile"
---
title: $title
slug: $slug
sidebar_position: $file_pos
last_update:
  date: $TODAY
  author: Anis
---

EOF
      cat "$file" >> "$tmpfile"
    fi

    mv "$tmpfile" "$file"
    echo "✔ Fichier MD mis à jour : $file"
    file_pos=$((file_pos + 1))
  done

  # 2️⃣ Mettre à jour _category_.json
  if [ "$UPDATE_CATEGORY" = true ]; then
    folder_name="$(basename "$dir")"
    category_file="$dir/_category_.json"

    cat <<EOF > "$category_file"
{
  "label": "$folder_name",
  "position": $cat_pos,
  "link": {
    "type": "generated-index",
    "description": "This folder '$folder_name' documentation"
  }
}
EOF
    echo "✔ _category_.json mis à jour : $dir (position=$cat_pos)"
  fi

  # 3️⃣ Parcours récursif des sous-dossiers (exclut node_modules et cachés)
  find "$dir" -maxdepth 1 -type d \
    -not -path "$dir" \
    -not -path '*/node_modules*' \
    -not -path '*/.*' | sort | while read -r subdir; do
      process_dir "$subdir"
      cat_pos=$((cat_pos + 1))
  done
}

# Début traitement
process_dir "$ROOT_DIR"
