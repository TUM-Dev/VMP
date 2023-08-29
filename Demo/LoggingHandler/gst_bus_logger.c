/* gst_bus_logger - Testing logging capabilities of the GStreamer bus, and debug log
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include <stdlib.h>
#include <glib.h>
#include <glib-unix.h>
#include <gst/gst.h>

static gboolean termination_callback(gpointer userdata)
{
    GMainLoop *loop;

    g_print("Termination signal received, quitting main loop...\n");
    loop = (GMainLoop *)userdata;
    g_main_loop_quit(loop);

    // Remove signal handler, as the mainloop is about to quit anyway
    return FALSE;
}

static gboolean bus_callback(GstBus *bus, GstMessage *message, gpointer userdata)
{
    switch (GST_MESSAGE_TYPE(message))
    {
    case GST_MESSAGE_INFO:
    {
        GError *error;
        gchar *debug_info;

        gst_message_parse_info(message, &error, &debug_info);
        g_printerr("INFO from element %s: %s\n", GST_OBJECT_NAME(message->src), error->message);
        g_printerr("Debugging info: %s\n", debug_info);
        g_error_free(error);
        g_free(debug_info);
        break;
    }
    case GST_MESSAGE_STATE_CHANGED:
    {
        GstState old_state, new_state, pending_state;
        gst_message_parse_state_changed(message, &old_state, &new_state, &pending_state);
        g_print("(Src: %s, Type: %s) State changed from %s to %s\n", gst_element_get_name(message->src), G_OBJECT_TYPE_NAME(message->src), gst_element_state_get_name(old_state), gst_element_state_get_name(new_state));
        break;
    }
    case GST_MESSAGE_EOS:
    {
        g_print("End-of-stream reached.\n");
        break;
    }
    case GST_MESSAGE_ERROR:
    {
        GError *error;
        gchar *debug_info;

        gst_message_parse_error(message, &error, &debug_info);
        g_printerr("ERROR from element %s: %s\n", GST_OBJECT_NAME(message->src), error->message);
        g_printerr("Debugging info: %s\n", debug_info);
        g_error_free(error);
        g_free(debug_info);
        break;
    }
    default:
        break;
    }
    return TRUE;
}

int main(int argc, char *argv[])
{
    GMainLoop *loop;
    GstElement *pipeline;
    GstBus *bus;

    gst_init(&argc, &argv);
    loop = g_main_loop_new(NULL, FALSE);

    // Register SIGINT, and SIGTERM signal handler
    g_unix_signal_add(SIGINT, termination_callback, loop);
    g_unix_signal_add(SIGTERM, termination_callback, loop);

    pipeline = gst_parse_launch("videotestsrc ! fakesink", NULL);

    // Get the bus and install bus callback
    bus = gst_pipeline_get_bus(GST_PIPELINE(pipeline));
    gst_bus_add_watch(bus, bus_callback, NULL);
    gst_element_set_state(pipeline, GST_STATE_PLAYING);

    g_print("Starting the main loop!\n");
    g_main_loop_run(loop);

    return EXIT_SUCCESS;
}