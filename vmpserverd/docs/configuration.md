# Daemon Configuration

On startup, the daemon checks for a configuration file at `/usr/share/vmpserverd/config.plist`,
and `~/.config/vmpserverd/config.plist`. The later is preferred for user-specific configuration, and
is prioritized over the system-wide configuration file. Additionally, the daemon can be started
with a custom configuration file via the `-c` command line option.

The configuration file is a property list, with a dictionary as the root object. The following
keys are required:
Key | Type | Description
--- | --- | ---
`name` | String | The name of the configuration
`profileDirectory` | String | The path to the directory containing the platform-specific profiles
`rtspAddress` | String | The address to bind the RTSP server to
`rtspPort` | Number | The port to bind the RTSP server to
`mountpoints` | Array | An array of mountpoint configurations
`channels` | Array | An array of channel configurations

The simplest way to get started is to copy the example configuration file from the `examples`
directory, and modify it to your needs. Below is a description of the different configurations.

## Server Configuration Parameters

Here is a snippet of parameters for the server configuration:
```xml
    <key>name</key>
    <string>Example Configuration</string>
    <key>profileDirectory</key>
    <string>/home/vm/TUMmp/vmpserverd/profiles</string>
    <key>rtspAddress</key>
    <string>0.0.0.0</string>
    <key>rtspPort</key>
    <string>8554</string>
```

### Channels

The channels are configured via an array of channel configurations. Each channel configuration
is a dictionary. Note that keys in the `properties` dictionary are specific to the channel type.

#### `videoTest` channel
Outputs a test video stream based on the GStreamer `videotestsrc` element. It is a SMPTE test pattern.
Available properties:
Key | Required | Description
--- | --- | ---
`width` | Yes | The width of the video stream
`height` | Yes | The height of the video stream

Example:
```xml
<dict>
	<key>name</key>
	<string>test0</string>
	<key>type</key>
	<string>videoTest</string>
	<key>properties</key>
	<dict>
		<key>width</key>
		<integer>1920</integer>
		<key>height</key>
		<integer>1080</integer>
	</dict>
</dict>
```

#### `v4l2` channel
Opens a v4l2 (Video4Linux2) device, and outputs the video stream. Available properties:
Key | Required | Description
--- | --- | ---
device | Yes | The path to the v4l2 device

Example:
```xml
<dict>
	<key>name</key>
	<string>present0</string>
	<key>type</key>
	<string>v4l2</string>
	<key>properties</key>
	<dict>
		<key>device</key>
		<string>/dev/video0</string>
	</dict>
</dict>
```

#### `audioTest` channel
Outputs a test audio stream based on the GStreamer `audiotestsrc` element.
Currently, no properties are available for this channel type.

Example:
```xml
<dict>
    <key>name</key>
    <string>audio0</string>
    <key>type</key>
    <string>audioTest</string>
    <key>properties</key>
    <dict>
    </dict>
</dict>
```

#### `pulse` channel
Opens a pulseaudio source, and outputs the audio stream. Available properties:
Key | Required | Description
--- | --- | ---
device | Yes | The name of the pulseaudio source (e.g. `alsa_input.usb-XXXX.analog-stereo`)

Example:
```xml
<dict>
	<key>name</key>
	<string>audio0</string>
	<key>type</key>
	<string>pulse</string>
	<key>properties</key>
	<dict>
		<key>device</key>
		<string>alsa_input.usb-XXXX.analog-stereo</string>
	</dict>
</dict>
```

### Mountpoints

The mountpoints are configured via an array of mountpoint configurations. Each mountpoint
configuration is a dictionary. Note that keys in the `properties` dictionary are specific to the
mountpoint type.

#### `single` mountpoint

Exposes a single video channel, and an audio channel. Available properties:
Key | Required | Description
--- | --- | ---
`videoChannel` | Yes | The name of the video channel
`audioChannel` | Yes | The name of the audio channel

Example:
```xml
<dict>
	<key>name</key>
	<string>Presentation</string>
	<key>path</key>
	<string>/presentation</string>
	<key>type</key>
	<string>single</string>
	<key>properties</key>
	<dict>
		<key>videoChannel</key>
		<string>present0</string>
		<key>audioChannel</key>
		<string>audio0</string>
	</dict>
</dict>
```

#### `combined` mountpoint

Combines two video channels into a single video stream, and adds an audio channel.
The properties are the same as for the `single` mountpoint, with the addition of a
required `secondaryVideoChannel` property.

Example:
```xml
<dict>
    <key>name</key>
    <string>Combined</string>
    <key>path</key>
    <string>/comb</string>
    <key>type</key>
    <string>combined</string>
    <key>properties</key>
    <dict>
        <key>videoChannel</key>
        <string>present0</string>
        <key>secondaryVideoChannel</key>
        <string>camera0</string>
        <key>audioChannel</key>
        <string>audio0</string>
    </dict>
</dict>
```