/* gst_intervideo_udp_test - An intervideo udp test application
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include <gst/gst.h>
#include <gst/rtsp-server/rtsp-server.h>

#ifdef __APPLE__
#include <TargetConditionals.h>
#endif

// #define AUTOMATIC_PARSE

int intervideo_test(int argc, char *argv[])
{
    GstElement *pipeline1;
    GstBus *bus1;
    GstMessage *msg1;
    GstStateChangeReturn ret1;
    GError *error = NULL;

    GstRTSPServer *server;
    GstRTSPMountPoints *mounts;
    GstRTSPMediaFactory *factory;

    gst_init(&argc, &argv);

#ifdef AUTOMATIC_PARSE
    /* Parse the pipeline description */
    pipeline1 = gst_parse_launch(
        "audiotestsrc ! queue ! interaudiosink channel=test",
        &error);
    if (error)
    {
        g_printerr("Failed to parse pipeline: %s\n", error->message);
        g_error_free(error);
        return -1;
    }
#else
    /* Create the elements */
    pipeline1 = gst_pipeline_new("test-pipeline");
    GstElement *audiotestsrc = gst_element_factory_make("audiotestsrc", "audiotestsrc");
    GstElement *queue = gst_element_factory_make("queue", "queue");
    GstElement *interaudiosink = gst_element_factory_make("interaudiosink", "interaudiosink");
    g_object_set(G_OBJECT(interaudiosink), "channel", "test", NULL);

    gst_bin_add_many(GST_BIN(pipeline1), audiotestsrc, queue, interaudiosink, NULL);
    gst_element_link_many(audiotestsrc, queue, interaudiosink, NULL);
#endif

    /* Create the RTSP server */
    server = gst_rtsp_server_new();
    mounts = gst_rtsp_server_get_mount_points(server);
    factory = gst_rtsp_media_factory_new();
    gst_rtsp_media_factory_set_launch(
        factory,
        "( interaudiosrc channel=test ! queue ! audioconvert ! avenc_aac ! "
        "rtpmp4apay name=pay0 pt=97 )");
    gst_rtsp_mount_points_add_factory(mounts, "/test", factory);
    g_object_unref(mounts);

    /* Attach the server to the default main context */
    gst_rtsp_server_attach(server, NULL);

    /* Start the first pipeline */
    gst_element_set_state(pipeline1, GST_STATE_PLAYING);

    /* Run the main loop */
    GMainLoop *loop = g_main_loop_new(NULL, FALSE);

    g_print("RTSP Stream ready at rtsp://127.0.0.1:8554/test\n");

    g_main_loop_run(loop);

    /* Free resources */
    g_main_loop_unref(loop);
    g_object_unref(server);
    gst_element_set_state(pipeline1, GST_STATE_NULL);
    gst_object_unref(pipeline1);
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
