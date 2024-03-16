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

## Structure
The `Libraries` folder contains Objective-C libraries that are used across the project.

Binaries are located in the `Daemons` and `Tools` folder respectively. This includes the core of the stack:
the `vmpserverd` daemon, which is responsible for managing the media processing.
`Tools` only contains a proof-of-concept control client.

You might have noticed the `nix` folder. We use NixOS for developing and testing. As we have some libraries
that are not in the nix-pkgs upstream, we provide an overlay which adds the missing dependencies.

Run `nix-shell` in the repository root to fetch all dependencies required for
development. After this, you can develop and build all subprojects.

A Debian rootfs build script with the complete VMP stack installed can be found in the `Deployment` folder. By default, a squashfs image is created.

See the [vmpserverd](Daemons/vmpserverd/README.md) README for more information about the daemon.

## License

The VMP project is licensed under the MIT license. See the [LICENSE](LICENSE) file for more information.