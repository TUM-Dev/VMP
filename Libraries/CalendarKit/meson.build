project('CalendarKit', 'objc', version : '0.2.0', default_options : ['warning_level=3'])

pkg = import('pkgconfig')

# Ensure clang is used for Objective-C
objc_compiler = meson.get_compiler('objc')
if objc_compiler.get_id() != 'clang'
  error('Clang is required for this project. Please set CC=clang, and OBJC=clang before running Meson.')
endif
 
dependencies_to_link = []
# Common Objective-C flags
objc_flags = []

if host_machine.system() != 'darwin'
    # Objective-C (GNUstep) support from gnustep-config
    gnustep_config = find_program('gnustep-config', required: true)
    if not gnustep_config.found()
        error('GNUstep is required for this project. Please install GNUstep and ensure gnustep-config is in your PATH. You might want to source GNUstep.sh before running Meson.')
    endif

    gnustep_flags = run_command(gnustep_config, '--objc-flags', check: true).stdout().strip().split()
    gnustep_base_libs = run_command(gnustep_config, '--base-libs', check: true).stdout().strip().split()

    # Filter out flags that are handled by Meson's built-in options
    # or result in warnings (-MMD)
    foreach flag : gnustep_flags
    if flag != '-Wall' and flag != '-g' and flag != '-O2' and flag != '-MMD'
        objc_flags += flag
    endif
    endforeach

    add_project_link_arguments(gnustep_base_libs, language: 'objc')
else
  # Properly link against the Foundation framework
  foundation_dep = dependency('appleframeworks', modules: ['Foundation'])
  dependencies_to_link += foundation_dep

  add_project_link_arguments('-lobjc', language: 'objc')
endif

# Enable ARC (Automatic Reference Counting)
objc_flags += '-fobjc-arc'

# Add Objective-C flags
add_project_arguments(objc_flags, language: 'objc')

# Add libical dependency
libical_dep = dependency('libical', required: true)
dependencies_to_link += libical_dep

source = [
    # Objc files
    'Source/ICALComponent.m',
    'Source/ICALProperty.m',
    'Source/ICALParameter.m',
    'Source/ICALError.m',
]

headers = [
    'CalendarKit/CalendarKit.h',
    'CalendarKit/ICALComponent.h',
    'CalendarKit/ICALProperty.h',
    'CalendarKit/ICALParameter.h',
    'CalendarKit/ICALError.h',
]

include_dirs = include_directories(
    'CalendarKit',
)

# Build CalendarKit
calendarkit_lib = library(
  'calendarkit',
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
             name : 'libcalendarkit',
             filebase : 'calendarkit',
             description : 'Small ObjC wrapper around libical')


# Testing
xctest_dep = dependency('XCTest', required: false)

if xctest_dep.found()
  subdir('Tests')
else
  message('XCTest not found. Skipping unit tests.')
endif
