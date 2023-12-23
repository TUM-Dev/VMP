project('CalendarKit', 'objc', version : '0.1.0', default_options : ['warning_level=3'])

pkg = import('pkgconfig')

# Ensure clang is used for Objective-C
objc_compiler = meson.get_compiler('objc')
if objc_compiler.get_id() != 'clang'
  error('Clang is required for this project. Please set CC=clang, and OBJC=clang before running Meson.')
endif
 
dependencies_to_link = []
objc_flags = []

# Objective-C (GNUstep) support from gnustep-config
gnustep_config = find_program('gnustep-config', required: true)
if not gnustep_config.found()
    error('GNUstep is required for this project. Please install GNUstep and ensure gnustep-config is in your PATH. You might want to source GNUstep.sh before running Meson.')
endif

gnustep_flags = run_command(gnustep_config, '--objc-flags', check: true).stdout().strip().split()
gnustep_base_libs = run_command(gnustep_config, '--base-libs', check: true).stdout().strip().split()

# Filter out flags that are handled by Meson's built-in options
foreach flag : gnustep_flags
if flag != '-Wall' and flag != '-g' and flag != '-O2' and flag != '-MMD'
    objc_flags += flag
endif
endforeach

add_project_link_arguments(gnustep_base_libs, language: 'objc')

# Enable ARC (Automatic Reference Counting)
objc_flags += '-fobjc-arc'
 
# Add Objective-C flags
add_project_arguments(objc_flags, language: 'objc')

source = [
  'Source/ICALComponent.m',
  'Source/ICALCalendar.m',
  'Source/ICALEvent.m',
  'Source/ICALTimeZone.m',
  'Source/ICALParser.m',
]

headers = [
  'CalendarKit/CalendarKit.h',
  'CalendarKit/ICALComponent.h',
  'CalendarKit/ICALCalendar.h',
  'CalendarKit/ICALEvent.h',
  'CalendarKit/ICALTimeZone.h',
]

include_dirs = include_directories(
    'CalendarKit',
)

# Build CalendarKit
calendarkit_lib = library(
  'CalendarKit',
  source,
  dependencies: dependencies_to_link,
  include_directories: include_dirs,
  install: true,
)

install_headers(
  headers,
  install_dir: join_paths(get_option('prefix'), get_option('includedir'), 'CalendarKit'),
)

pkg.generate(libraries : calendarkit_lib,
             version : meson.project_version(),
             name : 'CalendarKit',
             filebase : 'CalendarKit',
             description : 'An iCalendar RFC 5545 library for Objective-C',
)