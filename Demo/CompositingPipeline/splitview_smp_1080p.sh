#!/bin/bash

# Config for 720p:
# output_width=1280
# output_height=720

# presentation_width=960
# presentation_height=540
# presentation_x=0
# presentation_y=0

# camera_width=320
# camera_height=180

# PAL 576p 4:3 Test for correct scaling and keeping of aspect ratio
input1="videotestsrc pattern=0 ! video/x-raw, width=704, height=576"
# 1080p 16:9 The usual subject
#input1="videotestsrc pattern=0 ! video/x-raw, width=1920, height=1080"
# 2160p 16:9 (Maximum what Elgato Cam-Link supports)
#input1="videotestsrc pattern=0 ! video/x-raw, width=3840, height=2160"
input2="videotestsrc pattern=17 ! video/x-raw, width=1280, height=720"

output_width=1920
output_height=1080

# This is what the combined stream seems to be using
presentation_width=1440
presentation_height=810
presentation_x=0
presentation_y=0

camera_width=480
camera_height=270
camera_x=$((output_width-camera_width))
camera_y=0

presentation="$input1 ! c.sink_0"
camera="$input2 ! c.sink_1"

gst-launch-1.0 compositor background=1 name=c \
    sink_0::xpos=$presentation_x sink_0::ypos=$presentation_y sink_0::width=$presentation_width sink_0::height=$presentation_height sink_0::sizing-policy=1 \
    sink_1::xpos=$camera_x sink_1::ypos=$camera_y sink_1::width=$camera_width sink_1::height=$camera_height sink_1::sizing-policy=1 \
    ! video/x-raw,width=$output_width,height=$output_height ! autovideosink \
    $presentation \
    $camera
