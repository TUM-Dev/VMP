# vmp-server: The virtual streaming processor server

This subproject implements the core of the VMP: The RTSP Server, and a HTTP Server for status updates. 

## Issues
- RTSP Media Reuse broken

## TODO
- Single Camera, and presentation View
- Use IPC (interpipe) to avoid reencoding for each pipeline that serves a mountpoint
- CLI Parsing, Default Configuration, and Daemon Configuration
- Centralised Logging (Preparation for HTTP API)
- HTTP API
- Hardware Specific Encoder Selection
- V4L2 Device Detection