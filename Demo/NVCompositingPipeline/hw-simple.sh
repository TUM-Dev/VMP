#!/usr/bin/env sh

src_width=1920
src_height=1080

# gst-launch-1.0 videotestsrc pattern=0 ! \
# 	video/x-raw, width=${src_width}, height=${src_height} !\
# 		nvvidconv ! "video/x-raw(memory:NVMM), width=(int)1920, height=(int)1080" !\
# 		nvv4l2h264enc maxperf-enable=1 bitrate=5000000 ! \
# 	avdec_h264 ! autovideosink


gst-launch-1.0 videotestsrc pattern=0 ! \
	video/x-raw, width=${src_width}, height=${src_height} !\
       	nvvidconv ! "video/x-raw(memory:NVMM), width=(int)1920, height=(int)1080" !\
       	nvvidconv ! "video/x-raw" ! queue ! timeoverlay ! autovideosink