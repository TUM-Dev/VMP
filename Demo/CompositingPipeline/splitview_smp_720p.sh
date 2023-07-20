#!/bin/bash

# PAL 576p 4:3 Test for correct scaling and keeping of aspect ratio
#input1="videotestsrc pattern=0 ! video/x-raw, width=704, height=576"
# 720p 16:9 The usual subject
input1="videotestsrc pattern=0 ! video/x-raw, width=1280, height=720"
# 2160p 16:9 (Maximum what Elgato Cam-Link supports)
#input1="videotestsrc pattern=0 ! video/x-raw, width=3840, height=2160"
input2="videotestsrc pattern=17 ! video/x-raw, width=1280, height=720"

output_width=1280
output_height=720

# This is what the combined stream seems to be using
presentation_width=960
presentation_height=540
presentation_x=0
presentation_y=0

camera_width=320
camera_height=180
camera_x=$((output_width-camera_width))
camera_y=0

# Bilinear
scaling=1

presentation="$input1 ! videoscale method=$scaling ! video/x-raw, width=$presentation_width, height=$presentation_height, pixel-aspect-ratio=1/1 !  queue ! c.sink_1"
camera="$input2 ! videoscale method=$scaling ! video/x-raw, width=$camera_width, height=$camera_height, pixel-aspect-ratio=1/1 ! queue ! c.sink_2"

gst-launch-1.0 compositor background=1 name=c \
    sink_0::xpos=0 sink_0::ypos=0 \
    sink_1::xpos=$presentation_x sink_1::ypos=$presentation_y \
    sink_2::xpos=$camera_x sink_2::ypos=$camera_y \
    ! videoconvert ! videoscale ! video/x-raw,width=$output_width,height=$output_height ! autovideosink \
    $presentation \
    $camera

