# vmpserverd: The virtual streaming processor server daemon

This subproject implements the core of the VMP: The RTSP Server, and a HTTP Server for status updates. 


## Building
### Dependencies
Currently the following dependencies are required:
- glib 2.0
- gstreamer 1.0
- gstreamer rtsp server 1.0
- gstreamer plugins base 1.0
- gstreamer plugins good 1.0
- gstreamer plugins bad 1.0 (for intervideo{src,sink}, and interaudio{src,sink})
- gstreamer plugins ugly 1.0 (for x264 when not compiling on an Nvidia Jetson Nano)
- gstreamer plugins libav (for aac encoding)
- udev
- libsystemd (for writing to the systemd journal)
- A working GNUstep Objective-C 2.0 toolchain

Additionally, meson is required for building.