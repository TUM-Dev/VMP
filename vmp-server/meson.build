project('vmp-server', 'c')

fs = import('fs')

# Find GStreamer and GStreamer RTSP Server libraries using pkg-config
glib_dep = dependency('glib-2.0')
gstreamer_dep = dependency('gstreamer-1.0')
gstreamer_rtsp_dep = dependency('gstreamer-rtsp-1.0')
gstreamer_rtsp_server_dep = dependency('gstreamer-rtsp-server-1.0')
# For linux device monitoring
gudev_dep = dependency('gudev-1.0')

# Detect Nvidia Jetson Hardware with /proc/device-tree/model file and set NV_JETSON flag
if fs.exists('/proc/device-tree/model')
    message('Detecting Nvidia Jetson Hardware')
    model = fs.read('/proc/device-tree/model')
    if model.contains('NVIDIA Jetson')
        message('Found Nvidia Jetson in device-tree model description')
        add_project_arguments('-DNV_JETSON', language: 'c')
        message('Added NV_JETSON flag')
    endif
endif

source = ['src/main.c', 'src/vmp-media-factory.c', 'src/vmp-video-config.c', 'src/vmp-error.c', 'src/vmp-pipeline-manager.c']

executable('vmp-server', source, dependencies: [glib_dep, gstreamer_dep, gstreamer_rtsp_server_dep, gstreamer_rtsp_dep, gudev_dep])
