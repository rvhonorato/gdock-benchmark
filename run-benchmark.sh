#!/bin/bash
#SBATCH --job-name=gdock-bm
#SBATCH --output=benchmark/logs/slurm-%j.out
#SBATCH --error=benchmark/logs/slurm-%j.err
#SBATCH --cpus-per-task=96

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY_DIR="${ROOT_DIR}/binary"
BENCHMARK_DIR="${ROOT_DIR}/benchmark"

mkdir -p "${BENCHMARK_DIR}/logs"

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
