project('vmp-server', ['objc', 'c'])

fs = import('fs')

# Ensure clang is used for Objective-C
objc_compiler = meson.get_compiler('objc')
if objc_compiler.get_id() != 'clang'
  error('Clang is required for this project. Please set CC=clang, and OBJC=clang before running Meson.')
endif

# Find GStreamer and GStreamer RTSP Server libraries using pkg-config
glib_dep = dependency('glib-2.0')
gstreamer_dep = dependency('gstreamer-1.0')
gstreamer_rtsp_dep = dependency('gstreamer-rtsp-1.0')
gstreamer_rtsp_server_dep = dependency('gstreamer-rtsp-server-1.0')
# For linux device monitoring
# TODO: Remove as we use VMPUdevClient
gudev_dep = dependency('gudev-1.0')

udev_dep = dependency('libudev')

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

# Objective-C (GNUstep) support from gnustep-config
gnustep_config = find_program('gnustep-config', required: true)
if not gnustep_config.found()
    error('GNUstep is required for this project. Please install GNUstep and ensure gnustep-config is in your PATH. You might want to source GNUstep.sh before running Meson.')
endif

gnustep_flags = run_command(gnustep_config, '--objc-flags', check: true).stdout().strip().split()
gnustep_base_libs = run_command(gnustep_config, '--base-libs', check: true).stdout().strip().split()

# Filter out flags that are handled by Meson's built-in options
filtered_objc_flags = []
foreach flag : gnustep_flags
if flag != '-Wall' and flag != '-g' and flag != '-O2'
    filtered_objc_flags += flag
endif
endforeach

# Enable ARC (Automatic Reference Counting)
filtered_objc_flags += '-fobjc-arc'

# Add Objective-C flags and libraries
add_project_arguments(filtered_objc_flags, language: 'objc')
add_project_link_arguments(gnustep_base_libs, language: 'objc')

source = [
    'src/main.c',
    'src/vmp-media-factory.c',
    'src/vmp-video-config.c',
    'src/vmp-error.c',
    'src/vmp-common.c',
    'src/vmp-pipeline-manager.c',
    'src/vmp-pipeline-config.c',
    # Objc files
    'src/VMPUdevClient.m',
    'src/VMPErrors.m',
    'src/VMPPipelineManager.m'
]



dependencies = [
    glib_dep,
    gstreamer_dep,
    gstreamer_rtsp_dep,
    gstreamer_rtsp_server_dep,
    gudev_dep,
    udev_dep]

executable('vmp-server', source, dependencies: dependencies)