project('pipeline-recovery', 'c')

fs = import('fs')

glib_dep = dependency('glib-2.0')
gstreamer_dep = dependency('gstreamer-1.0')
gudev_dep = dependency('gudev-1.0')

source = ['v4l2_pipeline_recovery.c']

executable('a.out', source, dependencies: [glib_dep, gstreamer_dep, gudev_dep])
