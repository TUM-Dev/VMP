project('vmpserverd', ['objc', 'c'], version : '0.1.0')

fs = import('fs')

isNVJetson = false

# Ensure clang is used for Objective-C
objc_compiler = meson.get_compiler('objc')
if objc_compiler.get_id() != 'clang'
  error('Clang is required for this project. Please set CC=clang, and OBJC=clang before running Meson.')
endif

# Check if the build type is debug
if get_option('buildtype').startswith('debug')
  add_global_arguments('-DDEBUG', language : 'objc')
endif

# Find GStreamer and GStreamer RTSP Server libraries using pkg-config
glib_dep = dependency('glib-2.0')
gstreamer_dep = dependency('gstreamer-1.0')
gstreamer_rtsp_dep = dependency('gstreamer-rtsp-1.0')
gstreamer_rtsp_server_dep = dependency('gstreamer-rtsp-server-1.0')
# For linux device monitoring
udev_dep = dependency('libudev')
# For logging
systemd_dep = dependency('libsystemd')

# Detect Nvidia Jetson Hardware with /proc/device-tree/model file and set NV_JETSON flag
if fs.exists('/proc/device-tree/model')
    message('Detecting Nvidia Jetson Hardware')
    model = fs.read('/proc/device-tree/model')
    if model.contains('NVIDIA Jetson')
        message('Found Nvidia Jetson in device-tree model description')
        isNVJetson = true
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
    'src/main.m',
    'src/VMPServerMain.m',
    'src/VMPRTSPServer.m',
    'src/VMPProfileManager.m',
    'src/VMPUdevClient.m',
    'src/VMPPipelineManager.m',
    'src/VMPErrors.m',
    'src/VMPJournal.m',
    'src/VMPHTTPServer.m',
    'src/NSString+substituteVariables.m',
    # Models
    'src/models/VMPConfigChannelModel.m',
    'src/models/VMPConfigMountpointModel.m',
    'src/models/VMPProfileModel.m',
    'src/models/VMPConfigModel.m',
]

include_dirs = include_directories(
    'src',
    'src/models'
)

dependencies = [
    glib_dep,
    gstreamer_dep,
    gstreamer_rtsp_dep,
    gstreamer_rtsp_server_dep,
    udev_dep,
    systemd_dep,
]

 # Get version from project and split into major, minor, and patch
version = meson.project_version()
version_split = version.split('.')

major_version = version_split[0]
minor_version = version_split[1]
patch_version = version_split[2]

# Add version to configuration data
conf_data = configuration_data()
conf_data.set('MAJOR_VERSION', major_version)
conf_data.set('MINOR_VERSION', minor_version)
conf_data.set('PATCH_VERSION', patch_version)
conf_data.set('PROJECT_NAME', '"' + meson.project_name() + '"')

if isNVJetson
    conf_data.set('NV_JETSON', 1)
else
    conf_data.set('NV_JETSON', 0)
endif

configure_file(input : 'config.h.in',
               output : 'config.h',
               configuration : conf_data)

executable('vmpserverd', source, dependencies: dependencies, include_directories: include_dirs)