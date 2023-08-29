# Pipeline Recovery Demo

When the pipeline uses a v4l2 capture device, the program must carefully handle the case where the device is disconnected and reconnected. This demo shows how to do that.
We use the v4l2loopback module to emulate attaching and detaching of a v4l2 device, and libudev to monitor the device events.

One can write integration tests based on this demo, to test the robustness of the service.

## Build
``` sh
gcc v4l2_pipeline_recovery.c $(pkg-config --cflags --libs gstreamer-1.0)  $(pkg-config --cflags --libs glib-2.0)
```