#' @title Example: Reproduce Figure 1 in the reference paper
#' 
#' @author Zhengjia Wang
#' @date May 17, 2025
#' @license CC-BY
#' 
#' @description
#' Please run `03-import-with-data-processing.R` first, to download and 
#' preprocess the data
#' 
#' 
#' @references 
#' Paper: Hermes D, Miller KJ, Wandell BA, 
#' Winawer J. Stimulus Dependence of Gamma Oscillations in Human Visual Cortex. 
#' Cereb Cortex. 2015 Sep;25(9):2951-9. doi: 10.1093/cercor/bhu091. 
#' 
#' Dataset: https://openneuro.org/datasets/ds005953/versions/1.0.0
#' 
NULL

rave_subject <- raveio::as_rave_subject("ds005953/ds005953_01")

repository <- raveio::prepare_subject_power(
  subject = rave_subject,
  electrodes = 114, 
  reference_name = "default", 
  epoch_name = "status_good", 
  time_windows = c(-0.2, 1)
)

# baseline correction
raveio::power_baseline(repository, baseline_windows = c(0.75, 1), method = "decibel")

# obtain baseline power spectrogram
baselined <- repository$power$baselined

# Frequency x Time x Trial x Electrode
dim(baselined)

# Subset by epoch
epoch_table <- repository$epoch$table

# generate color pallete
pal <- ravebuiltins::get_heatmap_palette("BlueGrayRed")
pal <- colorRampPalette(c("cyan", "navy", "gray", "darkred", "yellow"))(255)

# Plot average baselined power spectrogram from condition 
plot_cond <- function(strimuli, zlim = c(-15, 15), main = "") {
  selected_trials <- epoch_table$Trial[epoch_table$Condition %in% strimuli]
  
  # subset power spectrogram with selected trials
  baselined_subset <- subset(baselined, Trial ~ Trial %in% selected_trials)
  
  # calculate mean spectrogram over electrodes and trials
  # result is time x frequency
  power_over_freq_time <- ravetools::collapse(baselined_subset, keep = c(2, 1))
  
  # get axis
  time_points <- repository$time_points
  frequencies <- repository$frequency
  # zlim <- max(abs(range(power_over_freq_time))) * c(-1, 1)
  power_over_freq_time[power_over_freq_time < zlim[[1]]] <- zlim[[1]]
  power_over_freq_time[power_over_freq_time >= zlim[[2]]] <- zlim[[2]]
  
  image(
    x = time_points,
    y = frequencies,
    z = power_over_freq_time,
    col = pal,
    zlim = zlim,
    axes = FALSE,
    xlab = "Time (s)",
    ylab = "Frequency (Hz)",
    main = main
  )
  axis(1, pretty(time_points))
  axis(2, pretty(frequencies), las = 1)
}

plot_cond("1")

par(mfrow = c(2, 4), mar = c(4.1, 4.1, 4.1, 0.1))
zlim <- c(-13, 13)

# Bars
plot_cond("4", zlim = zlim, main = "0.16 cycles/deg")
plot_cond("5", zlim = zlim, main = "0.32 cycles/deg")
plot_cond("6", zlim = zlim, main = "0.64 cycles/deg")
plot_cond("7", zlim = zlim, main = "1.28 cycles/deg")

# Noises
plot_cond("3", zlim = zlim, main = "Brown noise")
plot_cond("2", zlim = zlim, main = "Pink noise")
plot_cond("1", zlim = zlim, main = "White noise")

par(mar = c(4.1, 8.1, 4.1, 4.1))
legend_y <- seq(zlim[[1]], zlim[[2]], length.out = length(pal))
image(x = 0, y = legend_y, matrix(legend_y, nrow = 1), 
      col = pal, axes = FALSE, asp = 1, xlab = "", ylab = "")
axis(2, c(zlim, 0), las = 1)


