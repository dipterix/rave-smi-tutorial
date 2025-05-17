#' @title RAVE Basics
#' 
#' @author Zhengjia Wang
#' @date May 17, 2025
#' @license MIT
#' 
#' @description
#' Basic RAVE functions. These functions might subject to change in the future.
#' It is always recommended to check the documentations from
#'
#'                      https://rave.wiki
#' 
NULL


# ---- Installation script -----------------------------------------------------

# Install ravemanager
install.packages('ravemanager', repos = 'https://rave-ieeg.r-universe.dev')

# install RAVE and pipeline scripts
ravemanager::install()

# configure python for RAVE
ravemanager::configure_python()

# ---- Upgrade script ----------------------------------------------------------

# Always update ravemanager first
lib_path <- Sys.getenv("RAVE_LIB_PATH", unset = Sys.getenv("R_LIBS_USER", unset = .libPaths()[[1]]))
install.packages('ravemanager', repos = 'https://rave-ieeg.r-universe.dev', lib = lib_path)

# IMPORTANT: restart R

# Check if RAVE needs update
ravemanager::version_info()

# If so, update RAVE
ravemanager::update_rave()


# ---- Launch RAVE GUI ---------------------------------------------------------

# Launch GUI
rave::start_rave()

# Launch GUI in the RStudio background
rave::start_rave(as_job = TRUE)

# ---- Python for RAVE ---------------------------------------------------------

# install from pip
ravemanager::add_py_package("openneuro-py", method = "pip")

# launch interactive python prompt for RAVE (via reticulate)
rpymat::repl_python()

# ---- Housekeeping ------------------------------------------------------------

# Clear cache files (sometimes can be very big)
raveio::clear_cached_files()

# Uninstall RAVE
ravemanager::uninstall(components = "all")


