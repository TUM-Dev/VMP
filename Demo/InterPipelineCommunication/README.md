# Intervideosrc/Intervideosink Test Application

## Build
Dependencies: gstreamer-1.0

``` sh
clang -o gst_intervideo_test gst_intervideo_test.c $(pkg-config --cflags --libs gstreamer-1.0)
```