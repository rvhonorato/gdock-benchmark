# gdock-benchmark

Benchmark and weight calibration pipelines for [gdock](https://github.com/rvhonorato/gdock) `v2.0.0-rc.2`.

## Benchmark

Evaluates gdock on the [Protein-Protein Docking Benchmark 5.5](https://zlab.wenglab.org/benchmark/).

```bash
cd benchmark

# Download and prepare BM5.5
./00_download_bm5.sh

# Generate restraints from native contacts
./01_generate_restraints.sh

# Run docking on all complexes - this step will take a while
nohup ./02_run_benchmark.sh &

# Extract and plot results
Rscript 03_extract_results.R
Rscript 04_plot_results.R
```

Output:

- `results/` — docking output per complex
- `results.csv` — consolidated metrics
- `plot_*.pdf` — benchmark visualizations

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

See [calibration/README.md](calibration/README.md) for details.

## Requirements

- bash, wget, tar
- R (for analysis scripts)
- gdock binary (included as `gdock-v2.0.0-rc.2`)

## License

CC0 1.0 Universal (Public Domain)
