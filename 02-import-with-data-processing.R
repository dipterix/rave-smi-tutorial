#' @title Download iEEG data from OpenNeuro and apply signal pipelines
#' 
#' @author Zhengjia Wang
#' @date May 17, 2025
#' @license CC-BY
#' 
#' @description
#' Download iEEG data from public data archive. The dataset must be BIDS 
#' compliant. Supported signal formats include `EDF` (`*.edf`) or 
#' `BrainVision` (`*.eeg`). Other non-official BIDS format might be supported
#' upon request.
#' 
#' The downloaded subjects will be imported into RAVE, with automatic 
#' preprocessing, including Notch filter, Channel re-reference, Morlet wavelet
#' The re-reference will be common average reference by default based on 
#' choices of `good_channels`
#' 
#' Once imported, the RAVE project name will be identical to the accession 
#' number, and the RAVE subject code will be a concaternation of 
#' `{project_name}_{subject_number}`
#' 
#' 
#' @param project_name character, OpenNeuro accession number
#' @param subject_number character, subject code
#' @param good_channels integer vector, good channel numbers, or NA (derived 
#' from dataset automatically)
#' @param freesurfer_name if the subject data comes with surface models,
#' please specify the surface derivative name. The data files are usually 
#' located at `/derivatives/<freesurfer_name>/sub-xx/anat`; default is
#' 'surface'. Please check the dataset as different labs have their own 
#' conventions
#' @param notch_filter_lb,notch_filter_ub Notch (band-stop) filter settings
#' @param wavelet_frequencies frequencies from which the spectrogram will be
#' computed; recommended frequencies are 2, 4, 6, ..., 200 Hz. 
#' 
#' @references 
#' Paper: Hermes D, Miller KJ, Wandell BA, 
#' Winawer J. Stimulus Dependence of Gamma Oscillations in Human Visual Cortex. 
#' Cereb Cortex. 2015 Sep;25(9):2951-9. doi: 10.1093/cercor/bhu091. 
#' 
#' Dataset: https://openneuro.org/datasets/ds005953/versions/1.0.0
#' 
NULL

# ---- Global inputs -----------------------------------------------------------
project_name <- "ds005953"
subject_number <- "01"
good_channels <- NA
freesurfer_name <- "surface"  # "freesurfer"

# Notch filter
notch_filter_lb <- c(59, 118, 178)
notch_filter_ub <- c(61, 122, 182)

# Wavelet frequencies
wavelet_frequencies <- seq(2, 200, by = 4)

# ---- Initialize subject ------------------------------------------------------
# In RAVE, the imported subject code will be project + "_" + sub_number
subject_code <- sprintf("%s_%s", project_name, subject_number)

# Create subject, strict = FALSE to ignore checks
rave_subject <- raveio::RAVESubject$new(
  project_name = project_name, subject_code = subject_code, strict = FALSE)


# ---- Download from openneuro -------------------------------------------------
# This code block only need to run once
openneuro <- raveio::load_snippet("download-openneuro")

# The data should be at ~/rave_data/bids_dir/<project_name> by default
# you will need to import it into RAVE
target_path <- openneuro(dataset = project_name)

# ---- Import subject from downloads (~ 2 min) ---------------------------------
import_bids <- raveio::load_snippet("import-bids")

# target_path <- file.path(raveio::raveio_getopt("bids_data_dir"), project_name)
import_bids(
  bids_project_path = target_path,
  bids_subject_code = subject_number,
  freesurfer_name = freesurfer_name
)

# Find `good_channels` from BIDS data
if(isTRUE(is.na(good_channels))) {
  
  bids_subject <- bidsr::bids_subject(project = target_path, subject_code = subject_number)
  bids_table <- bidsr::query_bids(bids_subject, "ieeg")
  bids_channel_files <- bids_table$parsed[bids_table$suffix == "channels"]
  if(length(bids_channel_files)) {
    bids_channel_file <- bids_channel_files[[length(bids_channel_files)]]
    channel_file <- file.path(
      bidsr::resolve_bids_path(bids_subject@project, storage = "raw"),
      format(bids_channel_file))
    tabular <- bidsr::as_bids_tabular(channel_file)
    status <- tabular$content$status
    if(length(status)) {
      good_channels <- tabular$content$name[status == "good"]
    }
  }
}

# Clean
good_channels <- as.integer(good_channels)
good_channels <- good_channels[!is.na(good_channels) & good_channels > 0]

if(!length(good_channels)) {
  # At this moment, you need to manually set good_channels,
  # or all channels will be assumed to be good channels
  rave_subject <- raveio::RAVESubject$new(
    project_name = project_name, subject_code = subject_code)
  good_channels <- rave_subject$preprocess_settings$electrodes
}

# ---- Preprocessing: Notch filter (20 s) --------------------------------------

# Notch filter pipeline
pipeline_notch_filter <- ravepipeline::pipeline("notch_filter")

# Get current settings
# dput(pipeline_notch_filter$get_settings())

# set inputs
pipeline_notch_filter$set_settings(
  subject_code = subject_code,
  project_name = project_name,
  notch_filter_lowerbound = notch_filter_lb,
  notch_filter_upperbound = notch_filter_ub
)

# Run notch filter
pipeline_notch_filter$run("apply_notch")

# ---- Preprocessing: Wavelet (2-4 min) ----------------------------------------
pipeline_wavelet <- ravepipeline::pipeline("wavelet_module")
# dput(pipeline_wavelet$get_settings())

# Get recommended wavelet cycles
kernel_table <- ravetools::wavelet_cycles_suggest(
  freqs = wavelet_frequencies,
  frequency_range = c(2, 200),
  cycle_range = c(3, 20)
)
pipeline_wavelet$set_settings(
  subject_code = subject_code,
  project_name = project_name,
  kernel_table = kernel_table, 
  pre_downsample = 4, 
  precision = "float", 
  target_sample_rate = 100
)

# Run wavelet
pipeline_wavelet$run("wavelet_params")


# ---- Re-reference: generate references from `good_channels` (30 s) -----------
raveio::generate_reference(rave_subject, electrodes = good_channels)

# load reference template and set the "Common Average Reference"
rave_subject <- raveio::RAVESubject$new(project_name = project_name, subject_code = subject_code)
reference_table <- data.frame(
  Electrode = rave_subject$preprocess_settings$electrodes,
  Group = "Default",
  Reference = sprintf("ref_%s", dipsaus::deparse_svec(good_channels)),
  Type = "Common Average Reference"
)

# Save to default reference
raveio::safe_write_csv(
  x = reference_table,
  file = file.path(rave_subject$meta_path, "reference_default.csv")
)

# Now start RAVE GUI or continue analysis
message(
  "Subject imported and preprocess has finished. \n\tRAVE project: `",
  rave_subject$project_name,
  "` \n\tSubject code: `",
  rave_subject$subject_code,
  "`."
)
