# TUMmp: TUM Media Processor
TUMmp is an open-source project that aims to reimplement the functionality
of media streaming processors in software, using the GStreamer Multimedia
Framework.

The target hardware is a small single-board computer with accelerated
Multimedia encoding/decoding, and additional HDMI capture capabilities.

The capture cards are accessed via the Video for Linux (v4l2) subsystem.

What Does a Media Processor Do?
A media processor is a purpose-built device that combines multiple input streams,
composits new streams, and exposes them via a network feed. Often additional
features such as remote management, automatic backups, and scheduling are also part of an SMP.

TUMmp Project Goals
Our aim is to bring the above features into a stable, and
software-defined solution that works with industry-standard hardware, reducing
costs significantly.

Current Status
As of now, TUMmp is in the concept phase.

Technology Stack
TUMmp is being built using the GStreamer Multimedia Framework.
