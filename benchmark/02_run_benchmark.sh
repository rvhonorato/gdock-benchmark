#!/bin/bash
# Run gdock on all benchmark complexes
#
# Usage: ./02_run_benchmark.sh [nproc]
#   nproc: number of processors to use (default: total - 2)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="data"

if [[ -z "${GDOCK_VERSION:-}" ]]; then
  echo "ERROR: GDOCK_VERSION is not set. Run: export GDOCK_VERSION=v2.0.0-rc.2"
  exit 1
fi
GDOCK="${SCRIPT_DIR}/../binary/gdock-${GDOCK_VERSION}"
if [[ ! -x "$GDOCK" ]]; then
  echo "ERROR: Binary not found or not executable: $GDOCK"
  exit 1
fi
RESULTS_DIR="results/$GDOCK_VERSION"

# Number of processors - override via command line or edit here for different machines
NPROC="${1:-}"

# Create results directory
mkdir -p "$RESULTS_DIR"

# Determine actual number of processors being used
if [[ -n "$NPROC" ]]; then
  NPROC_USED="$NPROC"
else
  total_cpus=$(nproc)
  NPROC_USED=$((total_cpus - 2))
  [[ $NPROC_USED -lt 1 ]] && NPROC_USED=1
fi

# Initialize timing summary file (only write header if starting fresh)
if [[ ! -f "$RESULTS_DIR/timing.tsv" ]]; then
  echo -e "complex\tdockq\ttime_s\trec_atoms\tlig_atoms\trestraints\tnproc" >"$RESULTS_DIR/timing.tsv"
fi

# Build list of complexes sorted by estimated size (largest first).
# Score = ATOM lines in receptor + ATOM lines in ligand + restraint pairs.
echo "Estimating complex sizes..."
mapfile -t sorted_complexes < <(
  for complex_dir in "$DATA_DIR"/*/; do
    receptor="$complex_dir/receptor.pdb"
    ligand="$complex_dir/ligand.pdb"
    restraints="$complex_dir/$GDOCK_VERSION/restraints.txt"
    n_rec=$(grep -c "^ATOM" "$receptor" 2>/dev/null || echo 0)
    n_lig=$(grep -c "^ATOM" "$ligand" 2>/dev/null || echo 0)
    n_res=$( (grep -o ':' "$restraints" 2>/dev/null || true) | wc -l | awk '{print $1}')
    echo "$((n_rec + n_lig + n_res)) $complex_dir"
  done | sort -rn | awk '{print $2}'
)
total=${#sorted_complexes[@]}
current=0

echo "Running benchmark on $total complexes (largest first)"
echo "Using $NPROC_USED processors per run"
echo ""

for complex_dir in "${sorted_complexes[@]}"; do
  pdb_id=$(basename "$complex_dir")
  ((++current))
  if [[ -n "${TARGET_COMPLEXES:-}" ]]; then
    IFS=',' read -ra _targets <<<"${TARGET_COMPLEXES}"
    _match=0
    for _t in "${_targets[@]}"; do [[ "$_t" == "$pdb_id" ]] && _match=1 && break; done
    [[ $_match -eq 0 ]] && continue
  fi

  receptor="$complex_dir/receptor.pdb"
  ligand="$complex_dir/ligand.pdb"
  restraints="$complex_dir/$GDOCK_VERSION/restraints.txt"
  reference="$complex_dir/reference.pdb"
  output_dir="$RESULTS_DIR/$pdb_id"

  # Skip if already completed
  if [[ -f "$output_dir/metrics.tsv" ]]; then
    echo "[$current/$total] $pdb_id: already done, skipping"
    continue
  fi

  # Skip if missing files
  if [[ ! -f "$receptor" || ! -f "$ligand" || ! -f "$restraints" ]]; then
    echo "[$current/$total] $pdb_id: SKIPPED (missing input files)"
    continue
  fi

  # Create reference by combining receptor + ligand (if not exists)
  if [[ ! -f "$reference" ]]; then
    cat "$receptor" "$ligand" >"$reference"
  fi

  echo -n "[$current/$total] $pdb_id: "

  # Build nproc argument if set
  NPROC_ARGS=()
  if [[ -n "$NPROC" ]]; then
    NPROC_ARGS=(--nproc "$NPROC")
  fi

  # Count atoms and restraints for timing analysis
  n_rec_atoms=$(grep -c "^ATOM" "$receptor" 2>/dev/null || echo 0)
  n_lig_atoms=$(grep -c "^ATOM" "$ligand" 2>/dev/null || echo 0)
  # Count restraints (number of colon-separated pairs, e.g., "39:47,40:48" = 2 pairs)
  n_restraints=$( (grep -o ':' "$restraints" 2>/dev/null || true) | wc -l | awk '{print $1}')

  # Run gdock with timing; log to RESULTS_DIR first, move into output_dir after gdock creates it
  _tmp_log="$RESULTS_DIR/$pdb_id.log"
  start_time=$(date +%s)
  if "$GDOCK" run \
    --receptor "$receptor" \
    --ligand "$ligand" \
    --restraints "$restraints" \
    --reference "$reference" \
    --output-dir "$output_dir" \
    "${NPROC_ARGS[@]}" \
    >"$_tmp_log" 2>&1; then
    elapsed=$(($(date +%s) - start_time))
    mv "$_tmp_log" "$output_dir/$pdb_id.log"

    # Compress PDB output files (viewers support .pdb.gz; ~3-4x size reduction)
    find "$output_dir" -name "*.pdb" -exec gzip -f {} +

    # Extract DockQ from metrics.tsv (column 4: dockq)
    if [[ -f "$output_dir/metrics.tsv" ]]; then
      dockq=$(awk -F'\t' 'NR==2 {print $4}' "$output_dir/metrics.tsv")
      printf "DockQ=%.3f  time=%ds  (rec=%d lig=%d res=%d)\n" "$dockq" "$elapsed" "$n_rec_atoms" "$n_lig_atoms" "$n_restraints"
      # Append to timing summary
      echo -e "$pdb_id\t$dockq\t$elapsed\t$n_rec_atoms\t$n_lig_atoms\t$n_restraints\t$NPROC_USED" >>"$RESULTS_DIR/timing.tsv"
    else
      printf "OK  time=%ds\n" "$elapsed"
    fi
  else
    elapsed=$(($(date +%s) - start_time))
    mkdir -p "$output_dir"
    mv "$_tmp_log" "$output_dir/$pdb_id.log"
    printf "FAILED  time=%ds (see $output_dir/$pdb_id.log)\n" "$elapsed"
  fi
done

echo ""
echo "Results saved to $RESULTS_DIR/"
