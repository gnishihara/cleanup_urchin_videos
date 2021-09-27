#!/usr/bin/env bash
set -Eeuo pipefail

IDIR="/home/Lab_Data/videofile/urchin_repellent_experiment/raw_videos/"
ODIR="./temp/"

# Video to be processed
# FILE=${IDIR}"urchin_site1_control.mp4"
FILE=${IDIR}"urchin_site1_treat.mp4"

# Split the video into individual png files.
# Use png because it is lossless and there is no degradation of information.

rm ${ODIR}/*.png
ffmpeg -hide_banner -loglevel error -i ${FILE} ${ODIR}out_%05d.png -y

# Then run the R script detect_changes.R interactively,
# since you will need to choose how to filter the points.

# Finally, run the ffmpeg code below after mylist.txt is complete.
# ffmpeg -r 20 -f concat -i mylist.txt \
# -framerate 20 -pix_fmt yuv420p \
# -c:v libx264 test.mp4

# Not needed anymore, everything can be done in R.
# for f in temp/*; do
#   g=${f%.png}
#   g=${g/temp/temp2}
#   convert ${f} \
#   -colorspace RGB -channel R -separate \
#   -normalize \
#   -edge 1 -scale 1x1!  \
#   -format "%f %[fx:mean]\n" info:
# done > out.txt
# 
