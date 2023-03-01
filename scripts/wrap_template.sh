#!/bin/sh
# usage: wrap_template.sh <from> <to>

echo "return [[" > "$2"
cat "$1" >> "$2"
echo "]]" >> "$2"
