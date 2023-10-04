#!/usr/bin/env sh

gst-launch-1.0 nvcompositor name=comp \
	sink_0::xpos=0 sink_0::ypos=0 sink_0::width=1000 sink_0::height=1000 \
	! 'video/x-raw(memory:NVMM),width=1920,height=1080' ! nvoverlaysink \
    videotestsrc ! video/x-raw,width=1000,height=1000 \
	! nvvidconv ! 'video/x-raw(memory:NVMM)' ! comp.sink_0