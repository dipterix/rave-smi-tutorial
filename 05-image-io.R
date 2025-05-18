#' @title Low-level image functions
#' 
#' @author Zhengjia Wang
#' @date May 17, 2025
#' @license MIT
#' 
#' @description
#' Please check the documentations for each section. Package 
#' `ieegio`, `threeBrain`, `ravetools` are part of RAVE
#' 
NULL

# Set working directory to current project folder
setwd(rstudioapi::getActiveProject())

# ---- Volume data -------------------------------------------------------------
#' This section includes operating on volume files
#'  * 1. Read in NIfTI or MGZ volume files
#'  * 2. Plot anatomical slices
#'  * 3. Create volume & write to files
#'  * 4. Overlay masks
#'  * 5. Convert volume mask to surface with Laplacian smoothing
NULL

#### 1. Read in NIfTI or MGZ volume file
vol <- ieegio::read_volume("data/drag_drop_data/volume/brain.mgz")

#### 2. plot anatomical slices
# Reset graphic state
graphics.off()

plot(vol)

# Plot giving xyz (RAS) position
crosshair_position <- c(-25, -20, -15)
plot(vol, position = crosshair_position)

# Zoom in with higher resolution
plot(vol, position = crosshair_position, zoom = 3, pixel_width = 0.5)

# crosshair gap
plot(vol, position = crosshair_position, zoom = 3, pixel_width = 0.5, crosshair_gap = 20)

#### 3. Create volume & write files

atlas <- ieegio::read_volume("data/drag_drop_data/volume/aparc+aseg.mgz")
vox2ras <- atlas$transforms$vox2ras
x <- atlas[] == 17

# X must be integer or double
storage.mode(x) <- "integer"

volume <- ieegio::as_ieegio_volume(x, vox2ras = vox2ras)
plot(volume, position = c(-25, -20, -15), zoom = 3, pixel_width = 0.5, col = c("black", "white"))

ieegio::write_volume(x = volume, con = 'data/drag_drop_data/volume/lh.hippocampus.nii.gz')

#### 4. overlay left hippocampus
atlas <- ieegio::read_volume('data/drag_drop_data/volume/lh.hippocampus.nii.gz')

# Plot axial, sagittal, coronal
par(mfrow = c(1, 3))
plot(vol, position = crosshair_position, zoom = 2, pixel_width = 0.5,
     crosshair_gap = 20, which = "axial")
plot(atlas, position = crosshair_position, pixel_width = 0.5, add = TRUE, 
     alpha = 0.3, col = c("#000000", "yellow"), crosshair_col = NA, which = "axial")

plot(vol, position = crosshair_position, zoom = 2, pixel_width = 0.5,
     crosshair_gap = 20, which = "sagittal", main = "Hippocampus (L)")
plot(atlas, position = crosshair_position, pixel_width = 0.5, add = TRUE, 
     alpha = 0.3, col = c("#000000", "yellow"), crosshair_col = NA, which = "sagittal")

plot(vol, position = crosshair_position, zoom = 2, pixel_width = 0.5,
     crosshair_gap = 20, which = "coronal")
plot(atlas, position = crosshair_position, pixel_width = 0.5, add = TRUE, 
     alpha = 0.3, col = c("#000000", "yellow"), crosshair_col = NA, which = "coronal")

#### 5. Volume to surface

# Convert left hippocampus volume to surface with Laplacian smoothing

# Read in atlas file, threshold values from 16.5 - 17.5 
# (extract left hippocampus, code = 17)
# Transform into surface, write as GIfTI format
threeBrain::volume_to_surf(
  'data/drag_drop_data/volume/lh.hippocampus.nii.gz',
  threshold_lb = 0.5,
  threshold_ub = Inf,
  save_to = "data/drag_drop_data/surface_geometry/lh.hippocampus.gii"
)

# ---- Surface data ------------------------------------------------------------
#' Handle surface data/files
#'  * 1. Read in surface files (GIfTI, STL, PLY, ...)
#'  * 2. Plot surface object
#'  * 3. Read in surface geometry, annotations from different source and merge 
#'  * 4. plot merged surface object with variable
#'  * 5. surface (Dijkstra) distance, an example
#'  * 6. Save surface attribute
NULL

#### 1. Read in surface files (GIfTI, STL, PLY, ...)
surf <- ieegio::read_surface("data/drag_drop_data/surface_geometry/lh.hippocampus.gii")

#### 2. Plot surface object
plot(surf)

#### 3. Read in surface geometry, annotations from different source and merge 
left_pial <- ieegio::read_surface("data/drag_drop_data/surface_geometry/lh.pial")
left_annot <- ieegio::read_surface("data/drag_drop_data/surface_annotation/lh.aparc.annot")
left_measu <- ieegio::read_surface("data/drag_drop_data/surface_annotation/lh.sulc")

# Merge annotation and measurement into the geometry
merged <- merge(left_pial, left_annot, left_measu)
merged

#### 4. plot merged surface object with annotation
plot(merged, name = "annotations")
# alternatively
# plot(merged, name = c("annotations", "lh.aparc.annot"))

# plot with measurements
plot(merged, name = "measurements", col = c("white", "black"))


#### 5. surface (Dijkstra) distance, an example

left_pial <- ieegio::read_surface("data/drag_drop_data/surface_geometry/lh.pial")
distances <- ravetools::dijkstras_surface_distance(
  positions = t(left_pial$geometry$vertices[1:3, ]),
  faces = t(left_pial$geometry$faces[1:3, ]),
  start_node = 1000
)
shortest_path <- ravetools::surface_path(distances, target_node = 13000)
shortest_path <- shortest_path[order(shortest_path$path), ]

dijkstras_table <- distances$paths
dijkstras_table$shortest_path <- 0
dijkstras_table$shortest_path[dijkstras_table$node_id %in% shortest_path$path] <- shortest_path$distance

left_meas <- ieegio::as_ieegio_surface(measurements = dijkstras_table)

merged <- merge(left_pial, left_meas)

pal <- c("gray20", "#440154FF", "#482173FF", "#433E85FF", "#38598CFF", "#2D708EFF", 
         "#25858EFF", "#1E9B8AFF", "#2BB07FFF", "#51C56AFF", "#85D54AFF", 
         "#C2DF23FF", "#FDE725FF")
plot(merged, name = c("measurements", "shortest_path"), col = pal)

#### 6. Save surface attribute
ieegio::write_surface(
  left_meas,
  "data/drag_drop_data/surface_annotation/lh.custom.curv",
  format = "freesurfer",
  type = "measurements",
  name = "shortest_path"
)
