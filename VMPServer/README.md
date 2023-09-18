# vmp-server: The virtual streaming processor server

This subproject implements the core of the VMP: The RTSP Server, and a HTTP Server for status updates. 


## IN PROGRESS

- Centralised Logging (Preparation for HTTP API)
- HTTP API

## DONE
- RTSP Media Reuse
- Single Camera, and presentation View
- Use IPC (interpipe) to avoid reencoding for each pipeline that serves a mountpoint
- CLI Parsing 
- V4L2 Device Detection
- Hardware Specific Encoder Selection
- V4L2 Device Monitoring and Pipeline Restart Mechanism
- Default Configuration
- 
## TODO
- systemd Daemon Configuration
