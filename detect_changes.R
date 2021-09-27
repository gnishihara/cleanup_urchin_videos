# Look for bad pngs
# This script was desiged to identify frames that show only 
# video noise.

# Packages required. 
library(tidyverse)
library(imager)
library(furrr)
plan(multisession, workers = 10)
furrr_options(seed = 2021)

# This is the function to calculate the variation in the 
# FFT of the image. I designed it so that it does not use 
# the entire image, only an area focused on the center, with
# dimensions of 1024 x 1024. Otherwise, the FFT will take a 
# very long time to run.

calc_var = function(fnames) {
  img = load.image(fnames)
  # This section creates the 1024 x 1024 subsection of the image
  N = dim(img)[c(1,2)] |> log2() |> floor()
  M = dim(img)[c(1,2)] - 2^N
  M = M / 2
  X = c(M[1], M[1] + 2^N[1]-1)
  Y = c(M[2], M[2] + 2^N[2]-1)
  img = imsub(img, x %inr% X, y %inr% Y)
  
  # Run the FFT and calculate the variation in the power,
  # real component, and imaginary components of the FFT.
  img = img |> FFT() 
  power = sqrt(img$real^2 + img$imag^2) |> var()
  real = img$real |> var()
  imag = img$imag |> var()
  tibble(power, real, imag)
}

# This can take some time. If there are problems with 
# future_map() change in to map().
z = tibble(fnames = dir("temp", "png", full=T)) |> 
  mutate(variation = future_map(fnames, calc_var)) |> 
  unnest(variation)

# I ended up only using the imaginary component. 
# I am extracting the id numbers from the image filenames,
# calculating the log of the imaginary component, 
# and calculating the difference in the log values between
# successive pairs of images. This is good for detecting when
# there is a clear change in the image (i.e., from a good image
# to an image with just noise or black).
z2 = z |> 
  mutate(id = str_extract(fnames, "[0-9]+") |> as.numeric()) |> 
  mutate(limag = log(imag)) |> 
  mutate(dlimag = abs(limag - lead(limag))) 

# The last value of the lagged values is NA so just fill it with 
# the value prior to it.
z2 = z2 |> tidyr::fill(dlimag) 

# Take a look a the lagged differences.
# The greater the value, the larger the difference between two
# successive pairs of images. If the value is small, then the 
# pair of images should be similar.
z2 |> 
  ggplot() + 
  geom_point(aes(x = id, y = dlimag))

# This is where the filtering is done, and you will need to
# play with the values. If the image is good then ok is TRUE,
# if the image is bad then ok is FALSE.
z2 = z2 |> 
  mutate(ok = ifelse(is.na(dlimag), T, F)) |> 
  mutate(ok = ifelse(dlimag < 0.8, T, ok)) |> 
  mutate(ok = ifelse(limag < 9.35, F, ok))

z2 |> 
  ggplot() + 
  geom_point(aes(x = id, y = dlimag, color = ok))

z2 |> 
  ggplot() + 
  geom_point(aes(x = id, y = limag, color = ok)) 

#################################################
# Build the file list for ffmpeg.
dset |> filter(ok) |> 
  select(file) |> 
  mutate(file = sprintf("file 'temp/%s'\nduration 1", file)) |> 
  write_tsv("mylist.txt", col_names = F)

dset |> filter(ng) |> 
  select(file) |> 
  slice_tail() |> 
  mutate(file = sprintf("file 'temp/%s'", file)) |> 
  write_lines("mylist.txt", append = T)

# Run the following code to compile the list.
# ffmpeg -r 20 -f concat -i mylist.txt -framerate 20 -pix_fmt yuv420p -c:v libx264 test.mp4 -y



