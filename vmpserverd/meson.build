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
# Linux device metadata and monitoring
udev_dep = dependency('libudev')
# For structured logging to the systemd journal
systemd_dep = dependency('libsystemd')
# HTTP server library for the REST API
libmicrohttpkit_dep = dependency('microhttpkit')

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
if flag != '-Wall' and flag != '-g' and flag != '-O2' and flag != '-MMD'
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
    'src/NSString+substituteVariables.m',
    # Models
    'src/models/VMPConfigChannelModel.m',
    'src/models/VMPConfigMountpointModel.m',
    'src/models/VMPProfileModel.m',
    'src/models/VMPConfigModel.m',
    'src/models/VMPElementModel.m',
]

include_dirs = include_directories(
    'src',
    'src/models'
)

# Platform-specific profiles
profiles = [
    'profiles/com.hugomelder.deepstream6.plist',
    'profiles/com.hugomelder.software.plist',
    'profiles/com.hugomelder.vaapi.plist',
]

dependencies = [
    glib_dep,
    gstreamer_dep,
    gstreamer_rtsp_dep,
    gstreamer_rtsp_server_dep,
    udev_dep,
    systemd_dep,
    libmicrohttpkit_dep,
]

 # Get version from project and split into major, minor, and patch
version = meson.project_version()
version_split = version.split('.')

major_version = version_split[0]
minor_version = version_split[1]
patch_version = version_split[2]

prefix = get_option('prefix')
binary_path = join_paths(prefix, get_option('bindir'), meson.project_name())
profiles_directory = join_paths(prefix, get_option('datadir'), meson.project_name(), 'profiles')
default_config_path = join_paths(prefix, get_option('datadir'), meson.project_name())
systemd_service_path = join_paths(get_option('prefix'), 'lib', 'systemd', 'system')

# Configure the systemd service file
conf_data = configuration_data()
conf_data.set('MAJOR_VERSION', major_version)
conf_data.set('MINOR_VERSION', minor_version)
conf_data.set('PATCH_VERSION', patch_version)
conf_data.set('PROJECT_NAME', '"' + meson.project_name() + '"')
conf_data.set('BINARY_PATH', binary_path)
conf_data.set('PROFILES_DIRECTORY', profiles_directory)
conf_data.set('DEFAULT_CONFIG_PATH', join_paths(default_config_path, 'config.plist'))

configure_file(input : 'config.h.in',
               output : 'config.h',
               configuration : conf_data)

configure_file(input : 'vmpserverd.service.in',
               output : 'vmpserverd.service',
               configuration: conf_data)

configure_file(input : 'config.plist.in',
               output : 'config.plist',
               configuration: conf_data)

# Build the executable
executable(meson.project_name(), source, dependencies: dependencies, include_directories: include_dirs, install: true)

install_data(profiles, install_dir : profiles_directory)
# Install a default config file
install_data(join_paths(meson.current_build_dir(), 'config.plist'), install_dir : default_config_path)
# Install the systemd service file
install_data(join_paths(meson.current_build_dir(), 'vmpserverd.service'), install_dir : systemd_service_path)