/* gst_intervideo_test - An intervideo test application
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
    GstElement *pipeline1, *pipeline2, *source, *queue1, *sink1, *src2,
        *queue2, *sink2;
    GstElement *videoconvert;
    GstBus *bus1, *bus2;
    GstMessage *msg1, *msg2;
    GstStateChangeReturn ret1, ret2;

    gst_init(&argc, &argv);

    pipeline1 = gst_pipeline_new("pipeline1");
    source = gst_element_factory_make("videotestsrc", "source");
    queue1 = gst_element_factory_make("queue", "queue1");
    sink1 = gst_element_factory_make("intervideosink", "sink1");
    g_object_set(sink1, "channel", "test", NULL);
    gst_bin_add_many(GST_BIN(pipeline1), source, queue1, sink1, NULL);
    gst_element_link_many(source, queue1, sink1, NULL);

    pipeline2 = gst_pipeline_new("pipeline2");
    src2 = gst_element_factory_make("intervideosrc", "src2");
    g_object_set(src2, "channel", "test", NULL);
    queue2 = gst_element_factory_make("queue", "queue2");
    videoconvert = gst_element_factory_make("videoconvert", "convert");
    sink2 = gst_element_factory_make("glimagesink", "sink2");
    gst_bin_add_many(GST_BIN(pipeline2), src2, queue2, videoconvert, sink2,
                     NULL);
    gst_element_link_many(src2, queue2, videoconvert, sink2, NULL);

    ret1 = gst_element_set_state(pipeline1, GST_STATE_PLAYING);
    ret2 = gst_element_set_state(pipeline2, GST_STATE_PLAYING);
    if (ret1 == GST_STATE_CHANGE_FAILURE ||
        ret2 == GST_STATE_CHANGE_FAILURE)
    {
        g_printerr("Failed to start one or both pipelines.\n");
        return -1;
    }

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
