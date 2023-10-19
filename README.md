# VMP
VMP (Virtual Media Processor) is an open-source project that aims to reimplement the functionality
of media streaming processors in software, using the GStreamer Multimedia
Framework.

The target hardware is a small single-board computer with accelerated
Multimedia encoding/decoding, and additional HDMI capture capabilities.

The capture cards are accessed via the Video for Linux (v4l2) subsystem.

## What Does a Media Processor Do?
A media processor is a purpose-built device that combines multiple input streams,
composits new streams, and exposes them via a network feed.

## Project Goals
Our aim is to bring the above features into a stable, and
software-defined solution that works with industry-standard hardware, reducing
costs significantly.

## Subprojects

As a complex project, VMP is split into multiple subprojects. The core of the software
stack is the `vmpserverd` daemon, which is responsible for managing the media processing,

See the [vmpserverd](vmpserverd/README.md) README for more information.

## License

The VMP project is licensed under the MIT license. See the [LICENSE](LICENSE) file for more information.