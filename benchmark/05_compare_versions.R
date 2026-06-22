#!/usr/bin/env Rscript
# Compare benchmark results across gdock versions.
# Reads results/<version>/timing.tsv for every version directory found.

DOCKQ_ACCEPTABLE <- 0.23
DOCKQ_MEDIUM     <- 0.49
DOCKQ_HIGH       <- 0.80

results_root <- "results"
version_dirs <- list.dirs(results_root, full.names = TRUE, recursive = FALSE)

if (length(version_dirs) == 0) stop("No version directories found under ", results_root)

load_version <- function(vdir) {
  tsv <- file.path(vdir, "timing.tsv")
  if (!file.exists(tsv)) return(NULL)
  df <- read.table(tsv, header = TRUE, sep = "\t", stringsAsFactors = FALSE)
  if (nrow(df) == 0) return(NULL)
  df$version <- basename(vdir)
  df
}

all_data <- Filter(Negate(is.null), lapply(version_dirs, load_version))
if (length(all_data) == 0) stop("No timing.tsv files with data found.")

summarize_version <- function(df) {
  n  <- nrow(df)
  dq <- df$dockq
  data.frame(
    version       = df$version[1],
    n             = n,
    acceptable_pct = round(100 * sum(dq >= DOCKQ_ACCEPTABLE) / n, 1),
    medium_pct    = round(100 * sum(dq >= DOCKQ_MEDIUM)      / n, 1),
    high_pct      = round(100 * sum(dq >= DOCKQ_HIGH)        / n, 1),
    median_time_s = round(median(df$time_s)),
    median_cpu_s  = round(median(df$time_s * df$nproc)),
    stringsAsFactors = FALSE
  )
}

summary_df <- do.call(rbind, lapply(all_data, summarize_version))
summary_df <- summary_df[order(summary_df$version), ]

cat(sprintf(
  "\nDockQ thresholds: Acceptable >= %.2f | Medium >= %.2f | High >= %.2f\n\n",
  DOCKQ_ACCEPTABLE, DOCKQ_MEDIUM, DOCKQ_HIGH
))

colnames(summary_df) <- c(
  "version", "n", "acceptable%", "medium%", "high%", "median_time_s", "median_cpu_s"
)
print(summary_df, row.names = FALSE)

out_csv <- file.path(results_root, "version_comparison.csv")
write.csv(summary_df, out_csv, row.names = FALSE)
cat(sprintf("\nWritten to %s\n", out_csv))
