project('vmp-server', 'c')

# Find GStreamer and GStreamer RTSP Server libraries using pkg-config
glib_dep = dependency('glib-2.0')
gstreamer_dep = dependency('gstreamer-1.0')
gstreamer_rtsp_server_dep = dependency('gstreamer-rtsp-server-1.0')

source = ['src/main.c', 'src/vmp-media-factory.c', 'src/vmp-combined-bin.c', 'src/vmp-video-config.c', 'src/vmp-error.c']

executable('vmp-server', source, dependencies: [glib_dep, gstreamer_dep, gstreamer_rtsp_server_dep])
