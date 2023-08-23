/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#define DEFAULT_RTSP_PORT "8554"
// TODO: Remove QT Mock from the project
#define LOCATION "/Users/hugo/Downloads/blade_runner.mp4"

#include <glib.h>
#include <gst/rtsp-server/rtsp-server.h>

// For V4L2 device detection
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/videodev2.h>

// For setting up the RTSP server
#include "vmp-media-factory.h"
#include "vmp-video-config.h"

// For error handling
#include "vmp-error.h"

GOptionEntry entries[] = {
    {"verbose", 'v', 0, G_OPTION_ARG_NONE, NULL, "Be verbose", NULL},
    {"mock", 'm', 0, G_OPTION_ARG_NONE, NULL, "Use mock audio, and video elements", NULL},
    {"presentation-dev", 'p', 0, G_OPTION_ARG_STRING, NULL, "V4L2 device for the presentation stream", "DEVICE"},
    {"camera-dev", 'p', 0, G_OPTION_ARG_STRING, NULL, "V4L2 device for the camera stream", "DEVICE"},
    {NULL}};

// Forward declarations
static void start(gchar *camera_interpipe_name, gchar *presentation_interpipe_name, gchar *audio_interpipe_name);

static void check_v4l2_device(gchar *device, GError **error)
{
    errno = 0;
    int fd = open(device, O_RDWR);
    if (fd == -1)
    {
        g_set_error(error, vmp_error_quark(), VMP_ERROR_V4L2_ERRNO, "Could not open device %s: %s", device, g_strerror(errno));
        return;
    }

    errno = 0;
    struct v4l2_capability cap;
    if (ioctl(fd, VIDIOC_QUERYCAP, &cap) == -1)
    {
        g_set_error(error, vmp_error_quark(), VMP_ERROR_V4L2_ERRNO, "Could not query device %s: %s", device, g_strerror(errno));
        return;
    }

    if (!(cap.capabilities & V4L2_CAP_VIDEO_OUTPUT))
    {
        g_set_error(error, vmp_error_quark(), VMP_ERROR_V4L2_NOT_SUPPORTED, "Device %s is not a video output device", device);
        return;
    }

    close(fd);
}

int main(int argc, char *argv[])
{
    // Initialize GStreamer
    gst_init(&argc, &argv);

    GMainLoop *loop;
    loop = g_main_loop_new(NULL, FALSE);

    gboolean verbose = FALSE;
    gboolean mock = FALSE;
    gchar *presentation_dev = NULL;
    gchar *camera_dev = NULL;

    entries[0].arg_data = &verbose;
    entries[1].arg_data = &mock;
    entries[2].arg_data = &presentation_dev;
    entries[3].arg_data = &camera_dev;

    GError *error = NULL;
    GOptionContext *context;

    context = g_option_context_new("- A multimedia processor for lecture halls");
    g_option_context_add_main_entries(context, entries, NULL);
    if (!g_option_context_parse(context, &argc, &argv, &error))
    {
        g_print("option parsing failed: %s\n", error->message);
        exit(1);
    }

    if (!mock)
    {
        if (!presentation_dev)
        {
            g_set_error(&error, vmp_error_quark(), VMP_ERROR_ARGUMENTS_MISSING, "No presentation device specified");
            g_print("option parsing failed: %s\n", error->message);
            exit(1);
        }
        else if (!camera_dev)
        {
            g_set_error(&error, vmp_error_quark(), VMP_ERROR_ARGUMENTS_MISSING, "No camera device specified");
            g_print("option parsing failed: %s\n", error->message);
            exit(1);
        }

        // Check if the devices are valid
        check_v4l2_device(presentation_dev, &error);
        if (error)
        {
            g_print("option parsing failed: %s\n", error->message);
            exit(1);
        }

        check_v4l2_device(camera_dev, &error);
        if (error)
        {
            g_print("option parsing failed: %s\n", error->message);
            exit(1);
        }
    }
    else
    {
        gchar *aux_pipeline;

        aux_pipeline = g_strdup_printf(
            "v4l2src ! queue ! videoconvert ! queue ! intervideosink channel=presentation "
            "videotestsrc pattern=smpte ! video/x-raw,width=480,height=270 ! queue ! intervideosink channel=camera");
        // TODO: Proper auxillary pipeline state management

        /* Parse the pipeline description */
        GstElement *pipeline1 = gst_parse_launch(aux_pipeline, &error);
        if (error)
        {
            g_printerr("Failed to parse pipeline: %s\n", error->message);
            g_error_free(error);
            return -1;
        }

        gst_element_set_state(pipeline1, GST_STATE_PLAYING);

        // Currently interpipelinesink pipelines started externally
        start("camera", "presentation", "audio");

        g_object_unref(pipeline1);
        g_free(aux_pipeline);
    }

    // Clean up
    g_free(presentation_dev);
    g_free(camera_dev);
    g_option_context_free(context);

    g_main_loop_run(loop);
    return 0;
}

static void start(gchar *camera_interpipe_name, gchar *presentation_interpipe_name, gchar *audio_interpipe_name)
{
    GstRTSPServer *server;
    GstRTSPMountPoints *mounts;
    VMPMediaFactory *factory;
    // GstRTSPMediaFactory *factory;

    server = gst_rtsp_server_new();
    g_object_set(server, "service", DEFAULT_RTSP_PORT, NULL);
    g_object_set(server, "address", "0.0.0.0", NULL);

    mounts = gst_rtsp_server_get_mount_points(server);

    VMPVideoConfig *camera_config = vmp_video_config_new(480, 270);
    VMPVideoConfig *presentation_config = vmp_video_config_new(1440, 810);
    VMPVideoConfig *output_config = vmp_video_config_new(1920, 1080);

    // Initialise the custom rtsp media factory for managing our own pipeline
    factory = vmp_media_factory_new(camera_interpipe_name, presentation_interpipe_name, audio_interpipe_name, output_config, camera_config, presentation_config);
    gst_rtsp_media_factory_set_shared(GST_RTSP_MEDIA_FACTORY(factory), TRUE);

    GstRTSPMediaFactory *fac2 = gst_rtsp_media_factory_new();
    gst_rtsp_media_factory_set_launch(fac2, "intervideosrc channel=presentation ! queue ! videoconvert ! x264enc ! rtph264pay name=pay0 pt=96 "
                                            "interaudiosrc channel=audio ! queue ! audioconvert ! queue ! voaacenc ! rtpmp4apay name=pay1 pt=97");

    // Full transfer to VMPMediaFactory
    g_object_unref(camera_config);
    g_object_unref(presentation_config);
    g_object_unref(output_config);

    // attach the test factory to the /comb url
    gst_rtsp_mount_points_add_factory(mounts, "/comb", GST_RTSP_MEDIA_FACTORY(factory));
    gst_rtsp_mount_points_add_factory(mounts, "/presentation", fac2);

    g_object_unref(mounts);
    /* attach the server to the default maincontext */
    gst_rtsp_server_attach(server, NULL);

    g_print("stream ready at rtsp://127.0.0.1:%s/comb\n", DEFAULT_RTSP_PORT);
}