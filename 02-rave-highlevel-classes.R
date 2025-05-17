#' @title High-level RAVE functions
#' 
#' @author Zhengjia Wang
#' @date May 17, 2025
#' @license CC-BY
#' 
#' @description
#' Introduction to RAVE high-level functions using the built-in subject 
#' [demo/DemoSubject] (project: `demo`, subject code: `DemoSubject`)
#' The high-level classes/functions include:
#' 
#'  * RAVE Subject class
#'  * Subject brain class
#'  * Functions to load subject data repository
#'    - `raveio::prepare_subject_power`: load power spectrogram
#'    - `raveio::prepare_subject_voltage_with_epoch`: load voltage data
#'  * Export repository to HDF5 for future analyses
#'    - `raveio::rave_export`
#' 
NULL


# ---- RAVE subject ------------------------------------------------------------
rave_subject <- raveio::RAVESubject$new(project_name = "demo", subject_code = "DemoSubject")

# alternatively
rave_subject <- raveio::as_rave_subject("demo/DemoSubject")

#### subject paths

# subject path within the project
rave_subject$path

# meta path (stores electrode coordinates, references, epoch table)
rave_subject$meta_path

# image path (all image pipeline data)
rave_subject$imaging_path

#### Get meta information from the subject

# Get available reference and epoch table names
rave_subject$reference_names
rave_subject$epoch_names

# Get electrode coordinate table
electrode_table <- rave_subject$get_electrode_table()
head(electrode_table)

# Get epoch table
epoch <- rave_subject$get_epoch("auditory_onset")
head(epoch$table)

# Get reference table
reference_table <- rave_subject$get_reference("default")
head(reference_table)

# ---- RAVE Brain object -------------------------------------------------------

brain <- raveio::rave_brain(rave_subject)
brain

# Set electrode values (e.g., using the electrode table)
brain$set_electrode_values(brain$electrodes$raw_table)

# Must check if the brain is NULL (missing image files)

# if(!is.null(brain)) {

brain$plot()

# Render brain with options
brain$plot(
  background = "#000000",
  controllers = list(
    "Display Data" = "LabelPrefix"
  )
)


# }

# ---- RAVE data repository - power --------------------------------------------

# Load power spectrogram
repository_power <- raveio::prepare_subject_power(
  subject = rave_subject,
  electrodes = c(14, 15), 
  reference_name = "default", 
  epoch_name = "auditory_onset", 
  time_windows = c(-1, 2)
)

# Get data sample rate
repository_power$subject$power_sample_rate

# get loaded electrode (channels)
repository_power$electrode_list

# get loaded time window
repository_power$time_windows

# Get meta table
repository_power$electrode_table |> head()
repository_power$epoch$table |> head()
repository_power$reference_table |> head()

# baseline correction (create contrast)
raveio::power_baseline(repository_power, baseline_windows = c(-1, -0.5), method = "decibel")

# obtain baseline power spectrogram
baselined <- repository_power$power$baselined

# Frequency x Time x Trial x Electrode
dim(baselined)

# Subset by epoch
epoch_table <- repository_power$epoch$table

audio_visual_trials <- epoch_table$Trial[endsWith(epoch_table$Condition, "_av")]

# Load audio-visual trials and electrode 14
baselined_subset <- subset(baselined, Trial ~ Trial %in% audio_visual_trials, Electrode ~ Electrode == 14)

# Calculate mean over trial
power_avg_trial <- ravetools::collapse(baselined_subset, keep = c(2, 1))

# Visualize
# generate color pallete
pal <- colorRampPalette(c("#053061", "#2166ac", "#4393c3", "#92c5de", "#d1e5f0", "#ffffff", 
                          "#fddbc7", "#f4a582", "#d6604d", "#b2182b", "#67001f"))(255)
zlim <- max(abs(range(power_avg_trial)))
image(
  x = repository_power$power$dimnames$Time,
  y = repository_power$power$dimnames$Frequency,
  z = power_avg_trial,
  col = pal,
  zlim = zlim * c(-1, 1),
  xlab = "Time (s)",
  ylab = "Frequency (Hz)",
  main = sprintf("Condition: audio-visual, Electrode 14, Range=\U00B1%.2f dB", zlim),
  las = 1
)

# ---- Export repository to HDF5 for further analysis --------------------------

raveio::rave_export(repository_power, '~/rave_data/export_dir/')

# ---- RAVE data repository - voltage ------------------------------------------

# Load voltage signals
repository_voltage <- raveio::prepare_subject_voltage_with_epoch(
  subject = rave_subject,
  electrodes = 13:16, 
  reference_name = "default",
  epoch_name = "auditory_onset", 
  time_windows = c(-1, 2)
)

# Get data sample rate
repository_voltage$sample_rate

# get loaded electrode (channels)
repository_voltage$electrode_list

# get loaded time window
repository_voltage$time_windows

# Get meta table
repository_voltage$electrode_table |> head()
repository_voltage$epoch$table |> head()
repository_voltage$reference_table |> head()


# get voltage data
voltage_data <- repository_voltage$voltage$data_list
time_points <- repository_voltage$voltage$dimnames$Time

# Get data from electrode channel 14:
channel_voltage <- voltage_data[["e_14"]]

# channel_voltage is a file array with dimension time x trial x 1
channel_voltage

# Load first 60 trials into memory and plot
ravetools::plot_signals(
  signals = t(channel_voltage[, 1:60, ]),
  sample_rate = repository_voltage$sample_rate, 
  time_shift = time_points[[1]], 
  ylab = "Trial number"
)



