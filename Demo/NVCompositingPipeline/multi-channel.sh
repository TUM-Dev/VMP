#!/bin/bash

OUTPUT_WIDTH=1920
OUTPUT_HEIGHT=1080

PRESENT_WIDTH=1440
PRESENT_HEIGHT=810
PRESENT_X=0
PRESENT_Y=0

CAMERA_WIDTH=480
CAMERA_HEIGHT=270
CAMERA_X=$((OUTPUT_WIDTH-CAMERA_WIDTH))
CAMERA_Y=0

PRESENT_PIPE="videotestsrc is-live=true ! video/x-raw,width=1440,height=810 ! intervideosink channel=present"
CAMERA_PIPE="videotestsrc is-live=true pattern=ball ! video/x-raw,width=480,height=270 ! intervideosink channel=camera"
AUDIO_PIPE="audiotestsrc is-live=true ! audio/x-raw,channels=2 ! interaudiosink channel=audio"

PRESENT_INJECT="intervideosrc channel=present ! queue ! nvvidconv ! comp.sink_0"
CAMERA_INJECT="intervideosrc channel=camera ! queue ! nvvidconv ! comp.sink_1"
AUDIO_INJECT="interaudiosrc channel=audio ! queue !  audioconvert ! autoaudiosink"

gst-launch-1.0 nvcompositor name=comp \
	sink_0::xpos=$PRESENT_X sink_0::ypos=$PRESENT_Y sink_0::width=$PRESENT_WIDTH sink_0::height=$PRESENT_HEIGHT \
	sink_1::xpos=$CAMERA_X sink_1::ypos=$CAMERA_Y sink_1::width=$CAMERA_WIDTH sink_1::height=$CAMERA_HEIGHT \
	! "video/x-raw(memory:NVMM),width=$OUTPUT_WIDTH,height=$OUTPUT_HEIGHT" ! nvvidconv ! nvv4l2h264enc maxperf-enable=true ! rtph264pay ! udpsink host=0.0.0.0 port=5000 \
	$PRESENT_PIPE \
	$CAMERA_PIPE \
	$AUDIO_PIPE \
	$PRESENT_INJECT \
	$CAMERA_INJECT \
	$AUDIO_INJECT