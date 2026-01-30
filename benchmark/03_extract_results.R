#!/usr/bin/env Rscript
# Extract benchmark results into a single CSV file
#
# Usage: Rscript 03_extract_results.R
# Output: results.csv

# Set working directory to script location
args <- commandArgs(trailingOnly = FALSE)
script_path <- sub("--file=", "", args[grep("--file=", args)])
if (length(script_path) > 0) {
  setwd(dirname(script_path))
}
results_dir <- "results"
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

write.csv(all_results, "results.csv", row.names = FALSE)
cat(sprintf("Wrote %d rows to results.csv\n", nrow(all_results)))
