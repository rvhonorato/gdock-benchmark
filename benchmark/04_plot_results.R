#!/usr/bin/env Rscript
# Generate benchmark plots for gdock
#
# Usage: Rscript 04_plot_results.R
# Input: results/<version>/results.csv, results/<version>/timing.tsv

# Set working directory to script location
args <- commandArgs(trailingOnly = FALSE)
script_path <- sub("--file=", "", args[grep("--file=", args)])
if (length(script_path) > 0) {
  setwd(dirname(script_path))
}

version <- Sys.getenv("GDOCK_VERSION")
if (nchar(version) == 0) stop("GDOCK_VERSION is not set. Run: export GDOCK_VERSION=v2.0.0-rc.2")
results_dir <- file.path("results", version)

# Read data
results <- read.csv(file.path(results_dir, "results.csv"), stringsAsFactors = FALSE)
timing <- read.delim(file.path(results_dir, "timing.tsv"), sep = "\t", stringsAsFactors = FALSE)

# DockQ thresholds
ACCEPTABLE <- 0.23
MEDIUM <- 0.49
HIGH <- 0.80

# --- Plot 1: DockQ category barplot ---
# Get best DockQ per complex
best_dockq <- aggregate(dockq ~ complex, data = results, FUN = max)

# Categorize
best_dockq$category <- cut(
  best_dockq$dockq,
  breaks = c(-Inf, ACCEPTABLE, MEDIUM, HIGH, Inf),
  labels = c("Incorrect", "Acceptable", "Medium", "High"),
  right = FALSE
)

category_counts <- table(best_dockq$category)

pdf(file.path(results_dir, "plot_dockq_categories.pdf"), width = 6, height = 5)
par(mar = c(5, 4, 4, 2))
bp <- barplot(
  category_counts,
  col = c("gray60", "#c7e9c0", "#74c476", "#238b45"),
  main = "DockQ Quality Distribution",
  ylab = "Number of complexes",
  xlab = "DockQ category",
  ylim = c(0, max(category_counts) * 1.15)
)
abline(h = seq(25, max(category_counts), by = 25), col = "gray80", lty = 2)
barplot(category_counts, col = c("gray60", "#c7e9c0", "#74c476", "#238b45"), add = TRUE)
bar_labels <- sprintf("%d (%.1f%%)", category_counts, 100 * category_counts / sum(category_counts))
text(bp, category_counts + max(category_counts) * 0.03, labels = bar_labels, cex = 0.9)
n_total <- nrow(best_dockq)
n_success <- sum(best_dockq$dockq >= ACCEPTABLE)
legend("top",
       legend = sprintf("Success rate: %.1f%% (%d/%d)", 100 * n_success / n_total, n_success, n_total),
       bty = "n", inset = c(0, -0.05), xpd = TRUE)
dev.off()

# --- Plot 2: Timing histogram ---
avg_time <- mean(timing$time_s)
median_time <- median(timing$time_s)

# Create bins: 0-10, 10-20, ..., 100+
time_breaks <- c(seq(0, 100, by = 10), Inf)
time_labels <- c(paste0(seq(0, 90, by = 10), "-", seq(10, 100, by = 10)), ">100")
timing$bin <- cut(timing$time_s, breaks = time_breaks, labels = time_labels, right = FALSE)
bin_counts <- table(timing$bin)

pdf(file.path(results_dir, "plot_timing_histogram.pdf"), width = 8, height = 5)
par(mar = c(6, 4, 4, 2))
bp <- barplot(
  bin_counts,
  col = "steelblue",
  main = "Distribution of Docking Times",
  xlab = "",
  ylab = "Number of complexes",
  ylim = c(0, max(bin_counts) * 1.15),
  names.arg = rep("", length(time_labels))
)
abline(h = seq(20, max(bin_counts), by = 20), col = "gray80", lty = 2)
barplot(bin_counts, col = "steelblue", add = TRUE, names.arg = rep("", length(time_labels)))
text(bp, bin_counts + max(bin_counts) * 0.03, labels = bin_counts, cex = 0.8)
text(bp, par("usr")[3] - max(bin_counts) * 0.02, labels = time_labels, srt = 45, adj = 1, xpd = TRUE, cex = 0.9)
mtext("Time (seconds)", side = 1, line = 4.5)
legend("topright",
       legend = c(sprintf("Mean: %.1f s", avg_time),
                  sprintf("Median: %.1f s", median_time)),
       bty = "n")
dev.off()

# --- Plot 3: Complex size vs time boxplot ---
timing$total_atoms <- timing$rec_atoms + timing$lig_atoms

# Bin by 5000 atoms
max_atoms <- max(timing$total_atoms)
size_breaks <- seq(0, ceiling(max_atoms / 5000) * 5000, by = 5000)
size_labels <- paste0(size_breaks[-length(size_breaks)] / 1000, "-", size_breaks[-1] / 1000, "k")
timing$size_bin <- cut(timing$total_atoms, breaks = size_breaks, labels = size_labels, right = FALSE)

pdf(file.path(results_dir, "plot_size_vs_time.pdf"), width = 8, height = 6)
par(mar = c(6, 4, 4, 2))
boxplot(
  time_s ~ size_bin, data = timing,
  col = "steelblue",
  main = "Docking Time by Complex Size",
  xlab = "",
  ylab = "Time (seconds)",
  las = 2
)
mtext("Complex size (atoms)", side = 1, line = 4.5)
dev.off()

# --- Plot 4: DockQ heatmap table ---
# Reshape data to wide format: complex x model
dockq_wide <- reshape(
  results[, c("complex", "model", "dockq")],
  idvar = "complex",
  timevar = "model",
  direction = "wide"
)
names(dockq_wide) <- gsub("dockq\\.", "", names(dockq_wide))

# Sort by best DockQ
dockq_wide$best <- apply(dockq_wide[, -1], 1, function(x) {
  vals <- x[!is.na(x)]
  if (length(vals) == 0) return(-Inf)
  max(vals)
})
dockq_wide <- dockq_wide[order(dockq_wide$best, decreasing = TRUE), ]
dockq_wide$best <- NULL

# Create matrix for heatmap
row_names <- dockq_wide$complex
dockq_matrix <- as.matrix(dockq_wide[, -1])
rownames(dockq_matrix) <- row_names

# Rename columns for clarity
colnames(dockq_matrix) <- gsub("model_", "M", colnames(dockq_matrix))
colnames(dockq_matrix) <- gsub("ranked_", "R", colnames(dockq_matrix))

# Color function: gray for incorrect, green shades for acceptable/medium/high
get_color <- function(x) {
  if (is.na(x)) return("white")
  if (x < ACCEPTABLE) return("gray85")
  if (x < MEDIUM) return("#c7e9c0")
  if (x < HIGH) return("#74c476")
  return("#238b45")
}

n_complexes <- nrow(dockq_matrix)
n_models <- ncol(dockq_matrix)
cell_height <- 0.25  # inches per row

pdf(file.path(results_dir, "plot_dockq_heatmap.pdf"), width = 12, height = n_complexes * cell_height + 1.5)
par(mar = c(4, 5, 2, 1))
plot(NULL, xlim = c(0, n_models), ylim = c(0, n_complexes),
     xlab = "", ylab = "", xaxt = "n", yaxt = "n", bty = "n",
     main = "DockQ Scores by Complex and Model")

# Draw cells
for (i in 1:n_complexes) {
  for (j in 1:n_models) {
    val <- dockq_matrix[i, j]
    rect(j - 1, n_complexes - i, j, n_complexes - i + 1,
         col = get_color(val), border = "white", lwd = 0.5)
    text(j - 0.5, n_complexes - i + 0.5, sprintf("%.2f", val), cex = 0.55, font = 1)
  }
}

# Add complex names on left
axis(2, at = (n_complexes:1) - 0.5, labels = row_names, las = 2, cex.axis = 0.55, tick = FALSE, line = -0.5)

# Add model headers on top
text((1:n_models) - 0.5, n_complexes + 0.3, labels = colnames(dockq_matrix), cex = 0.7, xpd = TRUE)


# Legend at bottom
legend("bottom", inset = c(0, -0.03), xpd = TRUE, horiz = TRUE,
       legend = c(sprintf("Incorrect (<%.2f)", ACCEPTABLE),
                  sprintf("Acceptable (%.2f-%.2f)", ACCEPTABLE, MEDIUM),
                  sprintf("Medium (%.2f-%.2f)", MEDIUM, HIGH),
                  sprintf("High (>=%.2f)", HIGH)),
       fill = c("gray85", "#c7e9c0", "#74c476", "#238b45"),
       bty = "n", cex = 0.7)
dev.off()

# --- Plot 5: Cumulative distribution of timing ---
pdf(file.path(results_dir, "plot_timing_cumulative.pdf"), width = 7, height = 5)
par(mar = c(5, 4, 4, 2))
plot(ecdf(timing$time_s),
     main = "Cumulative Distribution of Docking Times",
     xlab = "Time (seconds)",
     ylab = "Fraction of complexes",
     col = "steelblue",
     lwd = 2,
     verticals = TRUE,
     do.points = FALSE)
abline(h = seq(0.25, 0.75, by = 0.25), col = "gray80", lty = 2)
abline(v = c(median_time, avg_time), col = c("red", "orange"), lty = 2, lwd = 1.5)
legend("bottomright",
       legend = c(sprintf("Median: %.1f s", median_time),
                  sprintf("Mean: %.1f s", avg_time)),
       col = c("red", "orange"), lty = 2, lwd = 1.5, bty = "n")
dev.off()

# --- Plot 6: Score vs DockQ correlation ---
# Remove outliers (keep scores within 95th percentile)
score_threshold <- quantile(results$score, 0.95, na.rm = TRUE)
results_filtered <- results[results$score <= score_threshold, ]

pdf(file.path(results_dir, "plot_score_vs_dockq.pdf"), width = 7, height = 6)
par(mar = c(5, 4, 4, 2))

# Color points by quality category
point_colors <- ifelse(results_filtered$dockq >= HIGH, "#238b45",
                ifelse(results_filtered$dockq >= MEDIUM, "#74c476",
                ifelse(results_filtered$dockq >= ACCEPTABLE, "#c7e9c0", "gray60")))

plot(results_filtered$score, results_filtered$dockq,
     pch = 19, col = adjustcolor(point_colors, alpha.f = 0.6),
     xlab = "Energy Score",
     ylab = "DockQ",
     main = "Score vs DockQ Correlation")

# Add threshold lines
abline(h = c(ACCEPTABLE, MEDIUM, HIGH), col = "gray60", lty = 2)

# Correlation (on filtered data)
cor_val <- cor(results_filtered$score, results_filtered$dockq, use = "complete.obs")
n_removed <- nrow(results) - nrow(results_filtered)
legend("topright",
       legend = c(sprintf("r = %.3f", cor_val),
                  sprintf("(%d outliers removed)", n_removed)),
       bty = "n")
dev.off()

# --- Plot 7: Top-N success rate curve ---
# For each complex, sort models by score and calculate success at top-1, top-2, etc.
complexes <- unique(results$complex)
n_complexes <- length(complexes)

# Calculate success rate at each top-N
top_n_success <- data.frame(
  n = 1:10,
  acceptable = numeric(10),
  medium = numeric(10),
  high = numeric(10)
)

for (n in 1:10) {
  n_acceptable <- 0
  n_medium <- 0
  n_high <- 0

  for (cx in complexes) {
    cx_data <- results[results$complex == cx, ]
    cx_data <- cx_data[order(cx_data$score), ]  # Sort by score (lower is better)
    top_n_dockq <- max(cx_data$dockq[1:min(n, nrow(cx_data))], na.rm = TRUE)

    if (!is.na(top_n_dockq) && is.finite(top_n_dockq)) {
      if (top_n_dockq >= ACCEPTABLE) n_acceptable <- n_acceptable + 1
      if (top_n_dockq >= MEDIUM) n_medium <- n_medium + 1
      if (top_n_dockq >= HIGH) n_high <- n_high + 1
    }
  }

  top_n_success$acceptable[n] <- 100 * n_acceptable / n_complexes
  top_n_success$medium[n] <- 100 * n_medium / n_complexes
  top_n_success$high[n] <- 100 * n_high / n_complexes
}

pdf(file.path(results_dir, "plot_topn_success.pdf"), width = 7, height = 5)
par(mar = c(5, 4, 4, 2))
plot(top_n_success$n, top_n_success$acceptable, type = "b", pch = 19,
     col = "#c7e9c0", lwd = 2, ylim = c(0, 100),
     xlab = "Top-N models considered",
     ylab = "Success rate (%)",
     main = "Success Rate by Number of Models Considered",
     xaxt = "n")
axis(1, at = 1:10)
lines(top_n_success$n, top_n_success$medium, type = "b", pch = 17, col = "#74c476", lwd = 2)
lines(top_n_success$n, top_n_success$high, type = "b", pch = 15, col = "#238b45", lwd = 2)
abline(h = seq(20, 80, by = 20), col = "gray80", lty = 2)
legend("bottomright",
       legend = c(sprintf("Acceptable (>=%.2f)", ACCEPTABLE),
                  sprintf("Medium (>=%.2f)", MEDIUM),
                  sprintf("High (>=%.2f)", HIGH)),
       col = c("#c7e9c0", "#74c476", "#238b45"),
       pch = c(19, 17, 15), lwd = 2, bty = "n")
dev.off()

# --- Plot 8: Clustered vs Ranked comparison ---
# Get best DockQ from clustered (model_*) and ranked (ranked_*) models for each complex
clustered <- results[grep("^model_", results$model), ]
ranked <- results[grep("^ranked_", results$model), ]

best_clustered <- aggregate(dockq ~ complex, data = clustered, FUN = max, na.rm = TRUE)
best_ranked <- aggregate(dockq ~ complex, data = ranked, FUN = max, na.rm = TRUE)

comparison <- merge(best_clustered, best_ranked, by = "complex", suffixes = c("_clustered", "_ranked"))

pdf(file.path(results_dir, "plot_clustered_vs_ranked.pdf"), width = 6, height = 6)
par(mar = c(5, 4, 4, 2))

# Scatter plot
plot(comparison$dockq_ranked, comparison$dockq_clustered,
     pch = 19, col = adjustcolor("steelblue", alpha.f = 0.6),
     xlab = "Best DockQ (Ranked models)",
     ylab = "Best DockQ (Clustered models)",
     main = "Clustered vs Ranked Model Selection",
     xlim = c(0, 1), ylim = c(0, 1))

# Diagonal line (equal performance)
abline(0, 1, col = "gray40", lty = 2)

# Threshold lines
abline(h = ACCEPTABLE, v = ACCEPTABLE, col = "gray70", lty = 3)

# Count wins
clustered_wins <- sum(comparison$dockq_clustered > comparison$dockq_ranked)
ranked_wins <- sum(comparison$dockq_ranked > comparison$dockq_clustered)
ties <- sum(comparison$dockq_clustered == comparison$dockq_ranked)

legend("bottomright",
       legend = c(sprintf("Clustered better: %d", clustered_wins),
                  sprintf("Ranked better: %d", ranked_wins),
                  sprintf("Equal: %d", ties)),
       bty = "n", cex = 0.9)
dev.off()

# --- Plot 9: DockQ distribution histogram ---
pdf(file.path(results_dir, "plot_dockq_distribution.pdf"), width = 7, height = 5)
par(mar = c(5, 4, 4, 2))

# Use best DockQ per complex
hist_data <- best_dockq$dockq

h <- hist(hist_data, breaks = seq(0, 1, by = 0.05), plot = FALSE)

# Color bars by category
bar_colors <- ifelse(h$mids < ACCEPTABLE, "gray60",
              ifelse(h$mids < MEDIUM, "#c7e9c0",
              ifelse(h$mids < HIGH, "#74c476", "#238b45")))

plot(h, col = bar_colors, border = "white",
     main = "Distribution of Best DockQ Scores",
     xlab = "DockQ",
     ylab = "Number of complexes",
     xlim = c(0, 1))

# Add threshold lines
abline(v = c(ACCEPTABLE, MEDIUM, HIGH), col = "gray40", lty = 2, lwd = 1.5)
text(ACCEPTABLE, max(h$counts) * 0.95, "Acceptable", pos = 4, cex = 0.7)
text(MEDIUM, max(h$counts) * 0.95, "Medium", pos = 4, cex = 0.7)
text(HIGH, max(h$counts) * 0.95, "High", pos = 4, cex = 0.7)

# Add mean/median
abline(v = mean(hist_data), col = "red", lty = 2)
abline(v = median(hist_data), col = "orange", lty = 2)
legend("topright",
       legend = c(sprintf("Mean: %.3f", mean(hist_data)),
                  sprintf("Median: %.3f", median(hist_data))),
       col = c("red", "orange"), lty = 2, bty = "n")
dev.off()

# --- Plot 10: Restraints vs DockQ ---
# Merge timing data (which has restraints) with best_dockq
restraints_data <- merge(timing[, c("complex", "restraints")], best_dockq, by = "complex")

pdf(file.path(results_dir, "plot_restraints_vs_dockq.pdf"), width = 7, height = 5)
par(mar = c(5, 4, 4, 2))

# Color by success
point_colors <- ifelse(restraints_data$dockq >= ACCEPTABLE, "#74c476", "gray60")

plot(restraints_data$restraints, restraints_data$dockq,
     pch = 19, col = adjustcolor(point_colors, alpha.f = 0.6),
     xlab = "Number of restraints",
     ylab = "Best DockQ",
     main = "Effect of Restraints on Docking Quality")

# Add threshold line
abline(h = ACCEPTABLE, col = "gray40", lty = 2)

# Correlation
cor_val <- cor(restraints_data$restraints, restraints_data$dockq, use = "complete.obs")
legend("bottomright",
       legend = c(sprintf("r = %.3f", cor_val),
                  sprintf("Success: %d/%d (%.1f%%)",
                          sum(restraints_data$dockq >= ACCEPTABLE),
                          nrow(restraints_data),
                          100 * sum(restraints_data$dockq >= ACCEPTABLE) / nrow(restraints_data))),
       bty = "n")
dev.off()

# --- Plot 11: Per-complex score-DockQ correlation ---
# Calculate Spearman correlation between score and DockQ within each complex
per_complex_cor <- sapply(complexes, function(cx) {
  cx_data <- results[results$complex == cx, ]
  cx_data <- cx_data[complete.cases(cx_data$score, cx_data$dockq), ]
  if (nrow(cx_data) < 3) return(NA)
  tryCatch(
    cor(cx_data$score, cx_data$dockq, method = "spearman"),
    error = function(e) NA
  )
})
per_complex_cor <- per_complex_cor[!is.na(per_complex_cor)]

pdf(file.path(results_dir, "plot_per_complex_correlation.pdf"), width = 7, height = 5)
par(mar = c(5, 4, 4, 2))

h <- hist(per_complex_cor, breaks = seq(-1, 1, by = 0.1), plot = FALSE)
bar_colors <- ifelse(h$mids < 0, "#74c476", "gray60")

plot(h, col = bar_colors, border = "white",
     main = "Per-Complex Score-DockQ Correlation",
     xlab = "Spearman correlation (score vs DockQ)",
     ylab = "Number of complexes",
     xlim = c(-1, 1))

abline(v = 0, col = "gray40", lty = 2, lwd = 1.5)
abline(v = median(per_complex_cor), col = "red", lty = 2, lwd = 1.5)

# Count negative correlations (good - lower score = better DockQ)
n_negative <- sum(per_complex_cor < 0)
n_total <- length(per_complex_cor)

legend("topleft",
       legend = c(sprintf("Median: %.3f", median(per_complex_cor)),
                  sprintf("Negative correlation: %d/%d (%.1f%%)",
                          n_negative, n_total, 100 * n_negative / n_total)),
       col = c("red", NA), lty = c(2, NA), bty = "n")
dev.off()

