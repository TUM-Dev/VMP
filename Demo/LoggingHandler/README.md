# Logging Demo

This demo shows how to tab into the bus of a GStreamer Pipeline and parse the GstMessage object that is emitted by the bus, when a bus watch is installed.
Additionally, the GMainLoop is properly shutdown when the process receives a SIGINT, or SIGTERM signal.

## Compilation
``` sh
gcc gst_bus_logger.c $(pkg-config --cflags --libs gstreamer-1.0)  $(pkg-config --cflags --libs glib-2.0)
```