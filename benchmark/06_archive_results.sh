#!/bin/bash
# Compress or decompress results/<version>/ directories as individual .tar.xz archives.
#
# Usage:
#   ./archive.sh compress [version]    # compress one or all versions
#   ./archive.sh decompress <version>  # decompress a specific archive

set -euo pipefail

RESULTS_DIR="$(cd "$(dirname "$0")" && pwd)/results"

usage() {
  echo "Usage: $0 compress [version]"
  echo "       $0 decompress <version>"
  exit 1
}

[[ $# -lt 1 ]] && usage

cmd="$1"
version="${2:-}"

case "$cmd" in
compress)
  if [[ -n "$version" ]]; then
    dirs=("$RESULTS_DIR/$version")
  else
    mapfile -t dirs < <(find "$RESULTS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
  fi
  for dir in "${dirs[@]}"; do
    v="$(basename "$dir")"
    archive="$RESULTS_DIR/$v.tar.xz"
    echo -n "Compressing $v ... "
    XZ_OPT="-9e" tar -cJf "$archive" -C "$RESULTS_DIR" "$v/"
    orig=$(du -sh "$dir" | cut -f1)
    comp=$(du -sh "$archive" | cut -f1)
    echo "$orig -> $comp"
  done
  ;;

decompress)
  [[ -z "$version" ]] && usage
  archive="$RESULTS_DIR/$version.tar.xz"
  if [[ ! -f "$archive" ]]; then
    echo "ERROR: archive not found: $archive"
    exit 1
  fi
  echo -n "Decompressing $version ... "
  tar -xJf "$archive" -C "$RESULTS_DIR"
  echo "done -> $RESULTS_DIR/$version/"
  ;;

*)
  usage
  ;;
esac
