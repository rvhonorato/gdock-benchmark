#!/usr/bin/env Rscript
# Extract benchmark results into a single CSV file
#
# Usage: Rscript 03_extract_results.R
# Output: results/<version>/results.csv

# Set working directory to script location
args <- commandArgs(trailingOnly = FALSE)
script_path <- sub("--file=", "", args[grep("--file=", args)])
if (length(script_path) > 0) {
  setwd(dirname(script_path))
}

version <- Sys.getenv("GDOCK_VERSION")
if (nchar(version) == 0) stop("GDOCK_VERSION is not set. Run: export GDOCK_VERSION=v2.0.0-rc.2")

results_dir <- file.path("results", version)
result_dirs <- list.dirs(results_dir, recursive = FALSE, full.names = TRUE)

all_results <- do.call(rbind, lapply(result_dirs, function(dir_path) {
  complex <- basename(dir_path)
  metrics_file <- file.path(dir_path, "metrics.tsv")

  if (!file.exists(metrics_file)) return(NULL)

  df <- read.delim(metrics_file, sep = "\t", stringsAsFactors = FALSE)
  df$complex <- complex
  df <- df[, c("complex", names(df)[names(df) != "complex"])]
  df
}))

out_csv <- file.path(results_dir, "results.csv")
write.csv(all_results, out_csv, row.names = FALSE)
cat(sprintf("Wrote %d rows to %s\n", nrow(all_results), out_csv))
