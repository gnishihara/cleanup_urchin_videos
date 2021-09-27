library(tidyverse)
library(imager)
library(furrr)
plan(multisession, workers = 10)
furrr_options(seed = 2021)

calc_var = function(fnames) {
  img = load.image(fnames)
  N = dim(img)[c(1,2)] |> log2() |> floor()
  M = dim(img)[c(1,2)] - 2^N
  M = M / 2
  X = c(M[1], M[1] + 2^N[1]-1)
  Y = c(M[2], M[2] + 2^N[2]-1)
  img = imsub(img, x %inr% X, y %inr% Y)
  img = img |> FFT() 
  power = sqrt(img$real^2 + img$imag^2) |> var()
  real = img$real |> var()
  imag = img$imag |> var()
  tibble(power, real, imag)
}

z = tibble(fnames = dir("temp", "png", full=T)) |> 
  mutate(variation = future_map(fnames, calc_var)) |> 
  unnest(variation)

z2 = z |> 
  mutate(id = str_extract(fnames, "[0-9]+") |> as.numeric()) |> 
  mutate(limag = log(imag)) |> 
  mutate(dlimag = abs(limag - lead(limag))) 

z2 = z2 |> tidyr::fill(dlimag) 

z2 |> 
  ggplot() + 
  geom_point(aes(x = id, y = dlimag))

z2 = z2 |> 
  mutate(ok = ifelse(is.na(dlimag), T, F)) |> 
  mutate(ok = ifelse(dlimag < 0.8, T, ok)) |> 
  mutate(ok = ifelse(limag < 9.35, F, ok))

z2 |> 
  ggplot() + 
  geom_point(aes(x = id, y = dlimag, color = ok))

z2 |> filter(!ok)

z2 |> 
  ggplot() + 
  geom_point(aes(x = id, y = limag, color = ok)) +
  ylim(5,12)

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



