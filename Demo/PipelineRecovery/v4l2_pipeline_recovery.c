/* v4l2_pipeline_recovery - Implementing a basic pipeline recovery mechanism
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include <stdlib.h>

#include <gst/gst.h>

// For signal handling
#include <glib-unix.h>

// For V4L2 device detection
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/videodev2.h>

// Simple error quark
GQuark vmp_error_quark(void)
{
    return g_quark_from_static_string("vmp-error-quark");
}

typedef enum _VMPError
{
    VMP_ERROR_UNKNOWN = 0,
    VMP_ERROR_ARGUMENTS_MISSING,
    VMP_ERROR_V4L2_ERRNO,
    VMP_ERROR_V4L2_NOT_SUPPORTED
} VMPError;

// SIGINT and SIGTERM handler
static gboolean termination_callback(gpointer userdata)
{
    GMainLoop *loop;

    g_print("Termination signal received, quitting main loop...\n");
    loop = (GMainLoop *)userdata;
    g_main_loop_quit(loop);

    // Remove signal handler, as the mainloop is about to quit anyway
    return FALSE;
}

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

static GstElement *build_pipeline_with_video_device(gchar *device)
{
    return NULL;
}

int main(int argc, char *argv[])
{
    GMainLoop *loop;

    gst_init(&argc, &argv);
    loop = g_main_loop_new(NULL, FALSE);

    // Register SIGINT, and SIGTERM signal handler
    g_unix_signal_add(SIGINT, termination_callback, loop);

    g_main_loop_run(loop);

    return EXIT_SUCCESS;
}