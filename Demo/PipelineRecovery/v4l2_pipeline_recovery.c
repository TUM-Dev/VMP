/* v4l2_pipeline_recovery - Implementing a basic pipeline recovery mechanism
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include <stdlib.h>

#include <glib.h>
#include <gst/gst.h>

// For signal handling
#include <glib-unix.h>

// For V4L2 device detection
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/videodev2.h>

// Device Monitoring
#include <gudev/gudev.h>

// Simple error quark
GQuark vmp_error_quark(void)
{
    return g_quark_from_static_string("vmp-error-quark");
}

typedef enum _VMPError
{
    VMP_ERROR_UNKNOWN = 0,
    VMP_ERROR_ARGUMENTS_MISSING,
    VMP_ERROR_DEVICE_NOT_AVAILABLE,
    VMP_ERROR_V4L2_ERRNO,
    VMP_ERROR_V4L2_NOT_SUPPORTED
} VMPError;

struct Container
{
    GstElement *pipeline;
    GstBus *bus;
    gchar *device;
    gboolean receivedEOS;
    gboolean deviceConnected;
};

// Forward Declarations
static void build_pipeline_with_container(struct Container *con);
static void restart_pipeline_with_container(struct Container *con);

// SIGINT and SIGTERM handler
static gboolean
termination_callback(gpointer userdata)
{
    GMainLoop *loop;

    g_print("Termination signal received, quitting main loop...\n");
    loop = (GMainLoop *)userdata;
    g_main_loop_quit(loop);

    // Remove signal handler, as the mainloop is about to quit anyway
    return FALSE;
}

static gboolean defered_pipeline_start_callback(struct Container *con)
{
    if (con->receivedEOS)
    {
        g_print("Defered pipeline creation, as existing pipeline has received EOS!\n");
        restart_pipeline_with_container(con);
        return FALSE;
    }
    return TRUE;
}

// Device Monitor Callback for video4linux subsystem
static void on_uevent(GUdevClient *client,
                      const gchar *action,
                      GUdevDevice *device,
                      gpointer user_data)
{
    // Transfer: None
    const char *devpath = g_udev_device_get_device_file(device);
    if (!devpath)
    {
        g_print("No devpath was returned!\n");
        return;
    }

    struct Container *con = (struct Container *)user_data;
    if (!con)
    {
        g_print("Invalid User Data!\n");
        return;
    }

    // FIXME: Coordinate between GStreamer Message Bus and UDev Monitor to avoid possible transition from playing -> null
    if (g_strcmp0(devpath, con->device) == 0)
    {
        g_printf("Processing event for registered device %s ...\n", con->device);
        if (g_strcmp0(action, "remove") == 0)
        {
            g_print("Device removal detected!\n");
            con->deviceConnected = FALSE;
        }
        else if (g_strcmp0(action, "add") == 0)
        {
            if (con->pipeline != NULL)
            {
                // Check if Pipeline is in the right state to be restarted
                if (con->receivedEOS)
                {
                    restart_pipeline_with_container(con);
                }
                /* There is no guarantee, that the udev callback happens after the pipeline bus sent the EOS event.
                 * Thus we need to defer the pipeline reset, until an EOS event is sent.
                 */
                else
                {
                    g_print("Defer pipeline creation, as existing pipeline has not received EOS yet!\n");
                    // Install Condition Checker in Event Loop
                    g_timeout_add(100, (GSourceFunc)defered_pipeline_start_callback, con);
                }
            }
            else
            {
                g_print("Building new pipeline!\n");
                build_pipeline_with_container(con);
            }
        }
        // TODO: Check for other potentially destructive actions
    }
}

static gboolean artificial_eos_delay_callback(struct Container *con)
{
    g_print("Artificial EOS delay callback!\n");
    con->receivedEOS = TRUE;
    return FALSE;
}

// Bus Watch for the Pipeline to receive EOS event
static gboolean bus_callback(GstBus *bus, GstMessage *message, gpointer userdata)
{
    struct Container *con = (struct Container *)userdata;
    if (!con)
    {
        g_print("Invalid User Data!\n");
        return;
    }

    switch (GST_MESSAGE_TYPE(message))
    {
    case GST_MESSAGE_EOS:
        g_print("Received EOS Event on Pipeline BUS!\n");

        // Artificial delay to allow for udev callback to happen
        // g_print("Add artificial EOS delay callback!\n");
        // g_timeout_add_seconds(20, (GSourceFunc)artificial_eos_delay_callback, con);
        // Or direct:
        con->receivedEOS = TRUE;

        // Set Pipeline to NULL state
        GstStateChangeReturn ret = gst_element_set_state(con->pipeline, GST_STATE_NULL);
        // Transfer: None
        const gchar *stateReturn = gst_element_state_change_return_get_name(ret);
        g_printf("Set pipeline to NULL. Response: %s\n", stateReturn);
        break;
    case GST_MESSAGE_ERROR:
    {
        GError *err = NULL;
        gchar *debug;
        gst_message_parse_error(message, &err, &debug);
        g_print("Error: %s\n", err->message);
        g_error_free(err);
        g_free(debug);
        break;
    }
    default:
        break;
    }
    return TRUE;
}

static void check_v4l2_device(gchar *device, GError **error)
{
    errno = 0;
    int fd = open(device, O_RDWR);
    if (fd == -1)
    {
        g_set_error(error, vmp_error_quark(), VMP_ERROR_DEVICE_NOT_AVAILABLE, "Could not open device %s: %s", device, g_strerror(errno));
        return;
    }

    errno = 0;
    struct v4l2_capability cap;
    if (ioctl(fd, VIDIOC_QUERYCAP, &cap) == -1)
    {
        g_set_error(error, vmp_error_quark(), VMP_ERROR_V4L2_ERRNO, "Could not query device %s: %s", device, g_strerror(errno));
        return;
    }

    /*
        if (!(cap.capabilities & V4L2_CAP_VIDEO_OUTPUT) || !(cap.capabilities & V4L2_CAP_VIDEO_CAPTURE))
        {
            g_set_error(error, vmp_error_quark(), VMP_ERROR_V4L2_NOT_SUPPORTED, "Device %s is not a video output or capture device", device);
            return;
        }
        */

    close(fd);
}

static void build_pipeline_with_container(struct Container *con)
{
    GError *err = NULL;
    g_return_if_fail(con != NULL);
    g_return_if_fail(con->device != NULL);

    check_v4l2_device(con->device, &err);
    if (err && (g_error_matches(err, vmp_error_quark(), VMP_ERROR_V4L2_ERRNO) || g_error_matches(err, vmp_error_quark(), VMP_ERROR_V4L2_NOT_SUPPORTED)))
    {
        g_printf("Device %s found but does not have required attributes: %s.\n Monitoring device and waiting...\n", con->device, err->message);
    }
    else if (!err)
    {
        // Transfer: FULL
        gchar *pipeline_desc = g_strdup_printf("v4l2src device=%s ! videoconvert ! autovideosink", con->device);
        g_printf("Device %s is a valid v4l2 video output device. Starting pipeline with description: %s\n", con->device, pipeline_desc);

        // Transfer: Floating
        con->pipeline = gst_parse_launch(pipeline_desc, err);

        g_free(pipeline_desc);

        if (err)
        {
            g_printf("Failed to create pipeline: %s", err->message);
            con->pipeline = NULL;
            return;
        }

        // Transfer: Full
        con->bus = gst_element_get_bus(con->pipeline);
        // Register Bus Callback
        gst_bus_add_watch(con->bus, bus_callback, con);

        // Set Internal Status
        con->deviceConnected = TRUE;
        con->receivedEOS = FALSE;

        gst_element_set_state(con->pipeline, GST_STATE_PLAYING);
    }
    else
    {
        g_printf("Device %s could not be opened: %s. Monitoring v4l2 subsystem and waiting...\n", con->device, err->message);
    }
}

static void restart_pipeline_with_container(struct Container *con)
{
    GstStateChangeReturn stateReturnReady;
    GstStateChangeReturn stateReturnPlaying;
    const gchar *stateReturnReadyName;
    const gchar *stateReturnPlayingName;

    g_print("Restarting existing pipeline!\n");

    // Set internal state
    con->deviceConnected = TRUE;
    con->receivedEOS = FALSE;

    stateReturnReady = gst_element_set_state(con->pipeline, GST_STATE_READY);
    stateReturnReadyName = gst_element_state_change_return_get_name(stateReturnReady);
    g_printf("State after setting pipeline to ready: %s\n", stateReturnReadyName);

    stateReturnPlaying = gst_element_set_state(con->pipeline, GST_STATE_PLAYING);
    stateReturnPlayingName = gst_element_state_change_return_get_name(stateReturnPlaying);
    g_printf("State after setting pipeline to playing: %s\n", stateReturnPlayingName);
}

int main(int argc, char *argv[])
{
    GMainLoop *loop;
    GUdevClient *udevClient;
    // NULL-terminated array of the udev subsystems we want to monitor
    const gchar *const subsystems[] = {"video4linux", NULL};
    struct Container *con;

    gst_init(&argc, &argv);
    loop = g_main_loop_new(NULL, FALSE);
    udevClient = g_udev_client_new(subsystems);
    con = g_new(struct Container, 1);

    // Get device from arguments
    if (argc != 2)
    {
        g_print("Expected a video4linux device path as the first argument!\n");
        return EXIT_FAILURE;
    }
    con->device = argv[1];
    con->pipeline = NULL;
    con->bus = NULL;
    con->deviceConnected = FALSE;
    con->receivedEOS = FALSE;

    // Try to start pipeline
    build_pipeline_with_container(con);

    // Register SIGINT, and SIGTERM signal handler
    g_unix_signal_add(SIGINT, termination_callback, loop);
    // Connect uevent callback
    g_signal_connect(udevClient, "uevent", G_CALLBACK(on_uevent), con);

    g_print("Starting main loop...\n");
    g_main_loop_run(loop);

    g_object_unref(udevClient);
    g_main_loop_unref(loop);

    // Free members of con
    if (con->bus)
        g_object_unref(con->bus);
    if (con->pipeline)
        g_object_unref(con->pipeline);
    g_free(con);

    return EXIT_SUCCESS;
}