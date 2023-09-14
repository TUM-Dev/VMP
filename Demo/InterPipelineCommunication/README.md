# Intervideosrc/Intervideosink Test Application

## Build
Dependencies: gstreamer-1.0

``` sh
clang -o gst_intervideo_test gst_intervideo_test.c $(pkg-config --cflags --libs gstreamer-1.0)
clang -o gst_intervideo_udp_test gst_intervideo_udp_test.c $(pkg-config --cflags --libs gstreamer-1.0)
clang -o gst_intervideo_rtsp_test gst_intervideo_rtsp_test.c $(pkg-config --cflags --libs gstreamer-1.0 gstreamer-rtsp-server-1.0)
```

## gst-launch examples

### Server
``` sh
gst-launch-1.0 videotestsrc ! queue ! intervideosink channel=test intervideosrc channel=test ! queue ! videoconvert ! vp8enc ! rtpvp8pay ! udpsink host=127.0.0.1 port=5000
gst-launch-1.0 videotestsrc ! queue ! intervideosink channel=test intervideosrc channel=test ! queue ! videoconvert ! x264enc ! rtph264pay ! udpsink host=127.0.0.1 port=5000
gst-launch-1.0 videotestsrc ! queue ! intervideosink channel=test intervideosrc channel=test ! queue ! videoconvert ! x264enc ! mpegtsmux ! udpsink host=127.0.0.1 port=5000
```

### Client
``` sh
gst-launch-1.0 udpsrc port=5000 ! application/x-rtp,media=video,payload=96,clock-rate=90000,encoding-name=VP8 ! rtpvp8depay ! vp8dec ! autovideosink
gst-launch-1.0 udpsrc port=5000 ! application/x-rtp,media=video,payload=96,clock-rate=90000,encoding-name=H264 ! rtph264depay ! avdec_h264 ! autovideosink
gst-launch-1.0 udpsrc port=5000 ! tsdemux ! h264parse ! avdec_h264 ! autovideosink
```
