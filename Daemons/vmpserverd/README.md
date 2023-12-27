# vmpserverd: The virtual streaming processor server daemon

_vmpserverd_ is the core of the VMP architecture, and is responsible for -
Managing and **multiplexing** incoming AV streams from different subsystems
(v4l2, pulseaudio, etc.) - **Compositing** of video streams - Adding audio from
an audio provider to a video stream - Managing and **RTSP** server, and
endpoints which expose the processed streams to clients.

It is written in Objective-C 2.0, uses GNUstep for the Foundation framework, and
GStreamer for the media processing.

## Documentation
The documentation is available in the `docs` subdirectory.

Entrypoint of the documentation: [Start](docs/start.md)

We try to cover the most important aspects of getting the daemon up and running,
as well as descrinbing the architecture, configuration, customising the underlying
pipeline configuration, and the API.

## Obtaining the software

### From source

Building the _vmpserverd_ daemon from source is easy. The hardest part is getting
the dependencies installed.

#### Dependencies
The daemon is written in _Objective-C 2.0_, but targets a generic Linux system.
This is possible because of the _GNUstep_ project, which provides a
cross-platform, and free implementation of the Objective-C 2.0 runtime, and the
_Foundation_ framework.

Currently the following dependencies are required:
- glib 2.0
- gstreamer 1.0
- gstreamer rtsp server 1.0
- gstreamer plugins base 1.0
- gstreamer plugins good 1.0
- gstreamer plugins bad 1.0 (for intervideo{src,sink}, and interaudio{src,sink})
- gstreamer plugins ugly 1.0 (for x264 when not compiling on an Nvidia Jetson Nano)
- gstreamer plugins libav (for aac encoding)
- udev
- libsystemd (for writing to the systemd journal)
- MicroHTTPKit (https://github.com/hmelder/MicroHTTPKit)
- A working GNUstep Objective-C 2.0 toolchain

Additionally, meson is required for building.

TODO: Add instructions for installing dependencies.

#### Building the daemon

Once the dependencies are installed, building the daemon is as simple as:

```bash
meson setup build
ninja -C build
```

This will create a `build` directory, and build the daemon in it.
If successful, the daemon binary will be available at `build/vmpserverd`.

If you want to install the daemon, you can do so by running:

```bash
ninja -C build install
```