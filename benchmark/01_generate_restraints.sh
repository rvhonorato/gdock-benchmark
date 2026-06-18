#!/bin/bash
# Generate interface restraints for all complexes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="data"
CUTOFF="${1:-5.0}" # Default 5.0A, can be overridden via argument

if [[ -z "${GDOCK_VERSION:-}" ]]; then
  echo "ERROR: GDOCK_VERSION is not set. Run: export GDOCK_VERSION=v2.0.0-rc.2"
  exit 1
fi
GDOCK="${SCRIPT_DIR}/../binary/gdock-${GDOCK_VERSION}"
if [[ ! -x "$GDOCK" ]]; then
  echo "ERROR: Binary not found or not executable: $GDOCK"
  exit 1
fi

echo "Generating restraints with cutoff=${CUTOFF}A"
echo ""

for complex_dir in "$DATA_DIR"/*/; do
  pdb_id=$(basename "$complex_dir")
  if [[ -n "${TARGET_COMPLEXES:-}" ]]; then
    IFS=',' read -ra _targets <<< "${TARGET_COMPLEXES}"
    _match=0
    for _t in "${_targets[@]}"; do [[ "$_t" == "$pdb_id" ]] && _match=1 && break; done
    [[ $_match -eq 0 ]] && continue
  fi
  receptor="$complex_dir/receptor.pdb"
  ligand="$complex_dir/ligand.pdb"
  output_dir="$complex_dir/$GDOCK_VERSION"
  output="$output_dir/restraints.txt"

  if [[ -f "$output" ]]; then
    echo "  $pdb_id: already done, skipping"
    continue
  fi

  if [[ -f "$receptor" && -f "$ligand" ]]; then
    mkdir -p "$output_dir"
    restraints=$("$GDOCK" restraints --receptor "$receptor" --ligand "$ligand" --cutoff "$CUTOFF")
    echo "$restraints" >"$output"
    n_pairs=$(echo "$restraints" | tr ',' '\n' | wc -l)
    echo "  $pdb_id: $n_pairs pairs"
  else
    echo "  $pdb_id: SKIPPED (missing files)"
  fi
done

echo ""
echo "Done! Restraints saved to {complex}/restraints.txt"
