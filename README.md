# gdock-benchmark

Benchmark and weight calibration pipelines for [gdock](https://github.com/rvhonorato/gdock).

## Setup

Binaries live in `binary/` and are named `gdock-<version>`. The following versions are currently available:

| File | Version |
|------|---------|
| `binary/gdock-v2.0.0-rc.2` | 2.0.0-rc.2 |
| `binary/gdock-v2.0.0-rc.3` | 2.0.0-rc.3 |
| `binary/gdock-v2.0.0` | 2.0.0 |
| `binary/gdock-v2.1.0` | 2.1.0 |

To add a new version, build from source and copy the binary:

```bash
git -C /path/to/gdock checkout <tag>
cargo build --release --manifest-path /path/to/gdock/Cargo.toml
cp /path/to/gdock/target/release/gdock binary/gdock-<tag>
```

## Benchmark

Evaluates gdock on the [Protein-Protein Docking Benchmark 5.5](https://zlab.wenglab.org/benchmark/).

### Run all versions via SLURM

```bash
sbatch run-benchmark.sh
```

This iterates over every binary in `binary/gdock-*` and runs the full pipeline for each version. Works with plain `bash run-benchmark.sh` as well.

### Run a single version manually

```bash
export GDOCK_VERSION=v2.1.0
cd benchmark

./00_download_bm5.sh          # download and prepare BM5.5 (once)
./01_generate_restraints.sh   # generate restraints from native contacts
./02_run_benchmark.sh         # run docking on all complexes
Rscript 03_extract_results.R  # extract metrics
Rscript 04_plot_results.R     # generate plots
```

All scripts are idempotent — safe to re-run; completed complexes are skipped.

Output (all under `results/<version>/`):

- `<PDB_ID>/` — docking output per complex (PDB files gzip-compressed)
- `results.csv` — consolidated metrics
- `plot_*.pdf` — benchmark visualizations
- `timing.tsv` — per-complex timing and atom counts

### Compare versions

```bash
cd benchmark
Rscript 05_compare_versions.R
```

Reads `results/<version>/timing.tsv` for every version present and prints a summary table with DockQ category percentages and median execution time. Also writes `results/version_comparison.csv`.

### Pre-computed results

Results for all benchmark versions are stored in this repository as `.tar.xz` archives under `benchmark/results/` and tracked via [Git LFS](https://git-lfs.com). To use them:

```bash
# fetch LFS content (if not already)
git lfs pull

# decompress a specific version
cd benchmark
./06_archive_results.sh decompress v2.1.0

# compress after a new run
./06_archive_results.sh compress v2.1.0
# or compress all versions at once
./06_archive_results.sh compress
```

## Calibration

Optimizes energy weights (w_vdw, w_elec, w_desolv) using [Dockground](https://dockground.compbio.ku.edu/) decoys.

```bash
cd calibration

# Download dockground decoy set
./00_download_dataset.sh

# Prepare structures
./01_prepare_dataset.sh

# Extract raw energies
./02_extract_raw_energies.sh

# Grid search for optimal weights
Rscript grid_search.R
```

Output:

- `results/raw_energies.tsv` — energy components per decoy
- `results/grid_search_results.tsv` — all weight combinations tested
- `results/optimized_weights.json` — best weights

## Requirements

- bash, wget, tar
- R (for analysis scripts)
- gdock binaries in `binary/` (see Setup above)
- Rust toolchain (`cargo`) to build new versions from source

## License

CC0 1.0 Universal (Public Domain)
