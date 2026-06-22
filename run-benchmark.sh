#!/bin/bash
#SBATCH --job-name=gdock-bm
#SBATCH --cpus-per-task=96
#SBATCH --partition=long

set -euo pipefail

ROOT_DIR="${SLURM_SUBMIT_DIR:-$(cd "$(dirname "$0")" && pwd)}"
BINARY_DIR="${ROOT_DIR}/binary"
BENCHMARK_DIR="${ROOT_DIR}/benchmark"

cd "$BENCHMARK_DIR"

echo "===== Step 0: Download and prepare BM5.5 ====="
./00_download_bm5.sh
echo

for binary in "${BINARY_DIR}"/gdock-*; do
  [[ -x "$binary" ]] || continue
  export GDOCK_VERSION
  GDOCK_VERSION="$(basename "$binary" | sed 's/^gdock-//')"

  echo "===== Running benchmark for gdock ${GDOCK_VERSION} ====="

  echo "--- Step 1: Generate restraints ---"
  ./01_generate_restraints.sh
  echo

  ./02_run_benchmark.sh "${SLURM_CPUS_PER_TASK:-}"
  Rscript 03_extract_results.R
  Rscript 04_plot_results.R

  echo "===== Done: results written to results/${GDOCK_VERSION}/ ====="
  echo
done
