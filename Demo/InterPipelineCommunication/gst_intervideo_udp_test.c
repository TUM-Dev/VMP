/* gst_intervideo_udp_test - An intervideo udp test application
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include <gst/gst.h>

#ifdef __APPLE__
#include <TargetConditionals.h>
#endif

int intervideo_test(int argc, char *argv[])
{
    GstElement *pipeline1, *pipeline2;
    GstBus *bus1, *bus2;
    GstMessage *msg1, *msg2;
    GstStateChangeReturn ret1, ret2;
    GError *error = NULL;

    gst_init(&argc, &argv);

    /* Parse the pipeline description */
    pipeline1 = gst_parse_launch(
        "videotestsrc ! queue ! intervideosink channel=test", &error);
    if (error)
    {
        g_printerr("Failed to parse pipeline: %s\n", error->message);
        g_error_free(error);
        return -1;
    }

    pipeline2 = gst_parse_launch(
        "intervideosrc channel=test ! queue ! videoconvert ! x264enc ! "
        "rtph264pay ! udpsink host=127.0.0.1 port=5000",
        &error);
    if (error)
    {
        g_printerr("Failed to parse pipeline: %s\n", error->message);
        g_error_free(error);
        return -1;
    }

    ret1 = gst_element_set_state(pipeline1, GST_STATE_PLAYING);
    ret2 = gst_element_set_state(pipeline2, GST_STATE_PLAYING);
    if (ret1 == GST_STATE_CHANGE_FAILURE ||
        ret2 == GST_STATE_CHANGE_FAILURE)
    {
        g_printerr("Failed to start one or both pipelines.\n");
        return -1;
    }

    g_print("UDP Stream ready at udp://127.0.0.1:5000\n");
    g_print(
        "Get stream with: gst-launch-1.0 udpsrc port=5000 ! "
        "application/"
        "x-rtp,media=video,payload=96,clock-rate=90000,encoding-name=H264 "
        "! rtph264depay ! avdec_h264 ! autovideosink\n");

    /* Wait until error or EOS */
    bus1 = gst_element_get_bus(pipeline1);
    bus2 = gst_element_get_bus(pipeline2);
    msg1 = gst_bus_timed_pop_filtered(bus1, GST_CLOCK_TIME_NONE,
                                      GST_MESSAGE_ERROR | GST_MESSAGE_EOS);
    msg2 = gst_bus_timed_pop_filtered(bus2, GST_CLOCK_TIME_NONE,
                                      GST_MESSAGE_ERROR | GST_MESSAGE_EOS);

    if (msg1 != NULL)
        gst_message_unref(msg1);
    if (msg2 != NULL)
        gst_message_unref(msg2);
    gst_object_unref(bus1);
    gst_object_unref(bus2);
    gst_element_set_state(pipeline1, GST_STATE_NULL);
    gst_element_set_state(pipeline2, GST_STATE_NULL);
    gst_object_unref(pipeline1);
    gst_object_unref(pipeline2);
    return 0;
}

int main(int argc, char *argv[])
{
#if defined(__APPLE__) && TARGET_OS_MAC && !TARGET_OS_IPHONE
    return gst_macos_main(intervideo_test, argc, argv, NULL);
#else
    return intervideo_test(argc, argv);
#endif
}
