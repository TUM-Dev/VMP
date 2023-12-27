## Architecture

The daemon is designed to be modular, and platform-independent. This means that
configuration of the daemon, including source, processing, and output
configuration, is done via a configuration file. Additionally, the underlying
GStreamer pipelines are also configurable via specialised profile files.

We distinguish between two types of streams: - Input streams: These are the raw
streams from different sources - Output streams: These are the processed streams
which are exposed to clients via RTSP

### Channels

An input stream is abstracted by a _channel_, which has a unique channel
name, the type, and type-specific properties like the device path for a v4l2
source.

The channel name is used to map the channel to output streams.
```plaintext
    ┌───────────────────┐
    │  name = present0  │
    │    type = v4l2    │─────────┐         ┌────────────────────────────────────────┐
    └───────────────────┘         │         │            path = /combined            │
    ┌───────────────────┐         │         │            type = combined             │
    │  name = camera0   │         │         │                                        │
    │ type = videoTest  │─────────┼────────▶│        videoChannel = present0         │
    └───────────────────┘         │         │    secondaryVideoChannel = camera0     │
    ┌───────────────────┐         │         │         audioChannel = audio0          │
    │   name = audio0   │         │         │                                        │
    │ type = audioTest  │─────────┘         └────────────────────────────────────────┘
    └───────────────────┘
```

This way, the nitty-gritty details of inter-pipeline communication, buffering, and configuration is
abstracted from the user, and the user can focus on the high-level configuration of the daemon.

The following types of channels are currently supported:
- `v4l2`: A channel which reads from a v4l2 device.
- `videoTest`: A channel which generates a test video stream.
- `audioTest`: A channel which generates a test audio stream.
- `pulse`: A channel which reads from a pulseaudio source.

### Mountpoints

An output stream is abstracted by a _mountpoint_, which has a unique path (used
as the path component of the RTSP URL), the type of mountpoint, and
type-specific properties like channel mappings, or bitrate.

Currently, the following types of mountpoints are supported: - `single`: Exposes
a single video channel, and an audio channel.  - `combined`: Combines two video
channels into a single video stream, and adds an audio channel.

A mountpoint is directly managed by the RTSP server, including the lifetime of
the media pipeline, and negotiation between clients using RTSP. Internally, a
mountpoint pipeline configuration exposes one or more RTP streams.

## Configuration

The daemon is configured via a configuration file, which is a XML property list.

For additional information about property lists see the [Property Lists](property-lists.md) section.

See the [Configuration](configuration.md) section for more information about the configuration file.