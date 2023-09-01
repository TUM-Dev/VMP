/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include <gst/gst.h>

// Device Monitoring
#include <gudev/gudev.h>

#include "vmp-error.h"
#include "vmp-common.h"
#include "vmp-pipeline-manager.h"

// For V4L2 device detection
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/videodev2.h>
#include <unistd.h>

// For ALSA device detection
#include <sound/asound.h>

/*
 * MARK: Functions
 */

// Basic prefix check
static inline gboolean prevalidate_dev_path(gchar *path, GError **err)
{
    if (!(strncmp(path, "/dev/", 5) == 0))
    {
        g_set_error(err, vmp_error_quark(), VMP_ERROR_INVALID_DEVICE_PATH, "Path does not have valid /dev/ prefix!");
        return FALSE;
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
        close(fd);
        return;
    }

    // TODO: Check V4L2 Flags

    close(fd);
}

static void check_alsa_device(gchar *device, GError **error)
{
    errno = 0;
    int fd = open(device, O_RDWR);
    if (fd == -1)
    {
        g_set_error(error, vmp_error_quark(), VMP_ERROR_DEVICE_NOT_AVAILABLE, "Could not open device %s: %s", device, g_strerror(errno));
        return;
    }

    // Check if device is a sound card
    errno = 0;
    int isSoundCard = ioctl(fd, SNDRV_CTL_IOCTL_CARD_INFO, NULL);
    if (isSoundCard < 0)
    {
        g_set_error(error, vmp_error_quark(), VMP_ERROR_ALSA_ERRNO, "Could not query device %s: %s", device, g_strerror(errno));
        close(fd);
        return;
    }
}

enum _VMPPipelineManagerProperty
{
    PROP_0,
    PROP_SRC_DEVICE,
    PROP_CHANNEL,
    PROP_CONFIG,
    N_PROPERTIES
};

static GParamSpec *obj_properties[N_PROPERTIES] = {
    NULL,
};

typedef struct _VMPPipelineManagerPrivate
{
    gchar *src_device_name;
    gchar *channel;
    GstElement *pipeline;
    GstBus *bus;
    GUdevClient *udev_client;
    gboolean deviceConnected;
    VMPPipelineConfig config;
} VMPPipelineManagerPrivate;

G_DEFINE_TYPE_WITH_PRIVATE(VMPPipelineManager, vmp_pipeline_manager, G_TYPE_OBJECT);

// Forward Declarations
static void vmp_pipeline_manager_set_property(GObject *object, guint property_id, const GValue *value, GParamSpec *pspec);
static void vmp_pipeline_manager_get_property(GObject *object, guint property_id, GValue *value, GParamSpec *pspec);
static void vmp_pipeline_manager_finalize(GObject *object);
static void vmp_pipeline_manager_constructed(GObject *object);
static void vmp_pipeline_manager_build_pipeline(VMPPipelineManager *mgr);
static void vmp_pipeline_manager_restart_pipeline(VMPPipelineManager *mgr);

static gboolean vmp_pipeline_manager_bus_cb(GstBus *bus, GstMessage *message, VMPPipelineManager *mgr);
static void vmp_pipeline_manager_uevent_cb(GUdevClient *client, const gchar *action,
                                           GUdevDevice *device, VMPPipelineManager *mgr);

static void vmp_pipeline_manager_init(VMPPipelineManager *self)
{
    VMPPipelineManagerPrivate *priv = vmp_pipeline_manager_get_instance_private(self);

    /* NULL-terminated array of the udev subsystems we want to monitor
     * for device changes.
     * TODO: Generalise this
     */
    const gchar *const subsystems[] = {"video4linux", NULL};

    priv->src_device_name = NULL;
    priv->channel = NULL;
    priv->config = VMP_PIPELINE_CONFIG_V4L2;
    priv->pipeline = NULL;
    priv->bus = NULL;
    // Transfer: Full
    priv->udev_client = g_udev_client_new(subsystems);
    priv->deviceConnected = FALSE;
}

static void vmp_pipeline_manager_class_init(VMPPipelineManagerClass *klass)
{
    GObjectClass *gobject_class = G_OBJECT_CLASS(klass);

    gobject_class->set_property = vmp_pipeline_manager_set_property;
    gobject_class->get_property = vmp_pipeline_manager_get_property;
    gobject_class->finalize = vmp_pipeline_manager_finalize;
    gobject_class->constructed = vmp_pipeline_manager_constructed;

    obj_properties[PROP_SRC_DEVICE] = g_param_spec_string(
        "src-device",
        "Source Device",
        "The source device to use",
        NULL,
        G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY);

    obj_properties[PROP_CHANNEL] = g_param_spec_string(
        "channel",
        "Channel",
        "The channel to use",
        NULL,
        G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY);

    obj_properties[PROP_CONFIG] = g_param_spec_enum(
        "config",
        "Source Device Configuration",
        "Type of the source device",
        VMP_TYPE_PIPELINE_CONFIG,
        VMP_PIPELINE_CONFIG_V4L2,
        G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY);

    g_object_class_install_properties(gobject_class, N_PROPERTIES, obj_properties);
}

VMPPipelineManager *vmp_pipeline_manager_new(gchar *src_device, VMPPipelineConfig config, gchar *channel)
{
    return g_object_new(VMP_TYPE_PIPELINE_MANAGER, "src-device", src_device, "config", config, "channel", channel, NULL);
}

static void vmp_pipeline_manager_set_property(GObject *object, guint property_id, const GValue *value, GParamSpec *pspec)
{
    VMPPipelineManager *self = VMP_PIPELINE_MANAGER(object);
    VMPPipelineManagerPrivate *priv = vmp_pipeline_manager_get_instance_private(self);

    switch (property_id)
    {
    case PROP_SRC_DEVICE:
        priv->src_device_name = g_value_dup_string(value);
        break;
    case PROP_CHANNEL:
        priv->channel = g_value_dup_string(value);
        break;
    case PROP_CONFIG:
        priv->config = g_value_get_enum(value);
        break;
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID(object, property_id, pspec);
        break;
    }
}

static void vmp_pipeline_manager_get_property(GObject *object, guint property_id, GValue *value, GParamSpec *pspec)
{
    VMPPipelineManager *self = VMP_PIPELINE_MANAGER(object);
    VMPPipelineManagerPrivate *priv = vmp_pipeline_manager_get_instance_private(self);

    switch (property_id)
    {
    case PROP_SRC_DEVICE:
        g_value_set_string(value, priv->src_device_name);
        break;
    case PROP_CHANNEL:
        g_value_set_string(value, priv->channel);
        break;
    case PROP_CONFIG:
        g_value_set_enum(value, priv->config);
        break;
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID(object, property_id, pspec);
        break;
    }
}

static void vmp_pipeline_manager_finalize(GObject *object)
{
    VMPPipelineManager *self = VMP_PIPELINE_MANAGER(object);
    VMPPipelineManagerPrivate *priv = vmp_pipeline_manager_get_instance_private(self);

    g_free(priv->src_device_name);
    g_free(priv->channel);

    g_object_unref(priv->udev_client);

    if (priv->pipeline)
    {
        // Stop the pipeline if it's not in the NULL state
        gst_element_set_state(priv->pipeline, GST_STATE_NULL);
        // Unreference the pipeline
        gst_object_unref(priv->pipeline);
        priv->pipeline = NULL;
    }

    if (priv->bus)
    {
        // Unreference the bus
        gst_object_unref(priv->bus);
        priv->bus = NULL;
    }

    G_OBJECT_CLASS(vmp_pipeline_manager_parent_class)->finalize(object);
}

static void vmp_pipeline_manager_constructed(GObject *object)
{
    VMPPipelineManager *self;
    VMPPipelineManagerPrivate *priv;

    self = VMP_PIPELINE_MANAGER(object);
    priv = vmp_pipeline_manager_get_instance_private(self);

    // Call the parent's constructed method
    G_OBJECT_CLASS(vmp_pipeline_manager_parent_class)->constructed(object);

    // Properties now available...
    if (!prevalidate_dev_path(priv->src_device_name, NULL))
    {
        g_log(VMP_LOG_DOMAIN, G_LOG_LEVEL_ERROR, "Invalid device path: %s", priv->src_device_name);
        return;
    }

    // Connect uevent callback
    g_signal_connect(priv->udev_client, "uevent", G_CALLBACK(vmp_pipeline_manager_uevent_cb), self);
}

/*
 * MARK: Callbacks
 */

/* Monitor changes to the device using udev, and react accordingly.
 */
static void vmp_pipeline_manager_uevent_cb(GUdevClient *client,
                                           const gchar *action,
                                           GUdevDevice *device,
                                           VMPPipelineManager *mgr)
{
    VMPPipelineManagerPrivate *mgr_priv;
    mgr_priv = vmp_pipeline_manager_get_instance_private(mgr);

    // Transfer: None
    const char *devpath = g_udev_device_get_device_file(device);
    if (!devpath)
    {
        g_log(VMP_LOG_DOMAIN, G_LOG_LEVEL_WARNING, "gudev did not return a valid devpath in uevent callback");
        return;
    }

    if (g_strcmp0(devpath, mgr_priv->src_device_name) == 0)
    {
        g_log(VMP_LOG_DOMAIN, G_LOG_LEVEL_DEBUG, "Processing event for registered device %s ...\n", mgr_priv->src_device_name);
        if (g_strcmp0(action, "remove") == 0)
        {
            vmp_common_event_log("udev callback", "Device %s removed!", devpath);
            mgr_priv->deviceConnected = FALSE;
        }
        else if (g_strcmp0(action, "add") == 0)
        {
            vmp_common_event_log("udev callback", "Device %s added!", devpath);
            if (mgr_priv->pipeline != NULL)
            {
                vmp_common_event_log_debug("udev callback",
                                           "Pipeline was initialised prior. Setting pipeline state to NULL...");
                // Set Pipeline to NULL state
                GstStateChangeReturn ret = gst_element_set_state(mgr_priv->pipeline, GST_STATE_NULL);
                // Transfer: None
                const gchar *stateReturn = gst_element_state_change_return_get_name(ret);
                vmp_common_event_log_debug("udev callback", "Set pipeline to NULL. Response: %s", stateReturn);

                vmp_pipeline_manager_restart_pipeline(mgr);
            }
            else
            {
                vmp_common_event_log_debug("udev callback", "Pipeline was not initialised prior. Building pipeline...");
                vmp_pipeline_manager_build_pipeline(mgr);
            }
        }
        // TODO: Check for other potentially destructive actions
    }
}

/* Handle GStreamer Bus messages.
 */
static gboolean vmp_pipeline_manager_bus_cb(GstBus *bus, GstMessage *message, VMPPipelineManager *mgr)
{
    switch (GST_MESSAGE_TYPE(message))
    {
    case GST_MESSAGE_EOS:
        vmp_common_event_log_debug("bus callback", "Received EOS Event on Pipeline BUS!");
        break;
    case GST_MESSAGE_ERROR:
    {
        GError *err = NULL;
        gst_message_parse_error(message, &err, NULL);
        vmp_common_event_log_debug("bus callback", "Error: %s", err->message);
        g_error_free(err);
        break;
    }
    default:
        break;
    }

    return TRUE;
}

/*
 * MARK: VMethods
 */
void vmp_pipeline_manager_start(VMPPipelineManager *mgr)
{
    // Try to build pipeline
    vmp_pipeline_manager_build_pipeline(mgr);
}

static void vmp_pipeline_manager_build_pipeline(VMPPipelineManager *mgr)
{
    GError *err = NULL;

    VMPPipelineManagerPrivate *mgr_priv;
    mgr_priv = vmp_pipeline_manager_get_instance_private(mgr);

    if (mgr_priv->config == VMP_PIPELINE_CONFIG_V4L2)
    {
        check_v4l2_device(mgr_priv->src_device_name, &err);
        if (err && (g_error_matches(err, vmp_error_quark(), VMP_ERROR_V4L2_ERRNO) || g_error_matches(err, vmp_error_quark(), VMP_ERROR_V4L2_NOT_SUPPORTED)))
        {
            g_log(VMP_LOG_DOMAIN, G_LOG_LEVEL_WARNING,
                  "Device %s found but does not have required attributes: %s.\n Monitoring device and waiting...",
                  mgr_priv->src_device_name, err->message);
            return;
        }
    }
    else if (mgr_priv->config == VMP_PIPELINE_CONFIG_SOUND)
    {
        check_alsa_device(mgr_priv->src_device_name, &err);
        if (err && g_error_matches(err, vmp_error_quark(), VMP_ERROR_ALSA_ERRNO))
        {
            g_log(VMP_LOG_DOMAIN, G_LOG_LEVEL_WARNING,
                  "Device %s found but SNDRV_CTL_IOCTL_CARD_INFO returned an error: %s.\n Monitoring device and waiting...",
                  mgr_priv->src_device_name, err->message);
            return;
        }
    }

    if (err && g_error_matches(err, vmp_error_quark(), VMP_ERROR_DEVICE_NOT_AVAILABLE))
    {
        g_log(VMP_LOG_DOMAIN, G_LOG_LEVEL_WARNING,
              "Device %s could not be opened: %s. Monitoring subsystem and waiting...",
              mgr_priv->src_device_name, err->message);
        return;
    }
    else
    {
        gchar *pipeline_desc;

        if (mgr_priv->config == VMP_PIPELINE_CONFIG_V4L2)
        {
            // Transfer: Full
            pipeline_desc = g_strdup_printf("v4l2src device=%s ! queue ! videoconvert ! queue ! intervideosink channel=%s", mgr_priv->src_device_name, mgr_priv->channel);
        }
        else if (mgr_priv->config == VMP_PIPELINE_CONFIG_SOUND)
        {
            // TODO: Enforce S16LE right after alsasrc possible?
            // Transfer: Full
            pipeline_desc = g_strdup_printf("alsasrc device=%s ! queue ! audioconvert ! capsfilter caps=audio/x-raw,format=S16LE,layout=interleaved,channels=2 ! audioresample ! queue ! interaudiosink channel=%s",
                                            mgr_priv->src_device_name, mgr_priv->channel);
        }
        else
        {
            g_log(VMP_LOG_DOMAIN, G_LOG_LEVEL_WARNING, "Unknown configuration type: %d", mgr_priv->config);
            return;
        }

        g_log(VMP_LOG_DOMAIN, G_LOG_LEVEL_DEBUG,
              "Device %s is a valid v4l2 video output device. Starting pipeline with description: %s", mgr_priv->src_device_name, pipeline_desc);

        // Transfer: Floating
        mgr_priv->pipeline = gst_parse_launch(pipeline_desc, &err);

        g_free(pipeline_desc);

        if (err)
        {
            g_log(VMP_LOG_DOMAIN, G_LOG_LEVEL_WARNING, "Failed to create pipeline: %s", err->message);

            mgr_priv->pipeline = NULL;
            return;
        }

        // Transfer: Full
        mgr_priv->bus = gst_element_get_bus(mgr_priv->pipeline);
        // Register Bus Callback
        gst_bus_add_watch(mgr_priv->bus, (GstBusFunc)vmp_pipeline_manager_bus_cb, mgr);

        // Set Internal Status
        mgr_priv->deviceConnected = TRUE;

        gst_element_set_state(mgr_priv->pipeline, GST_STATE_PLAYING);
    }
}

static void vmp_pipeline_manager_restart_pipeline(VMPPipelineManager *mgr)
{
    VMPPipelineManagerPrivate *mgr_priv;

    GstStateChangeReturn stateReturnReady;
    GstStateChangeReturn stateReturnPlaying;
    const gchar *stateReturnReadyName;
    const gchar *stateReturnPlayingName;

    mgr_priv = vmp_pipeline_manager_get_instance_private(mgr);
    g_log(VMP_LOG_DOMAIN, G_LOG_LEVEL_DEBUG, "Restarting existing pipeline!");

    // Set internal state
    mgr_priv->deviceConnected = TRUE;

    stateReturnReady = gst_element_set_state(mgr_priv->pipeline, GST_STATE_READY);
    stateReturnReadyName = gst_element_state_change_return_get_name(stateReturnReady);
    g_log(VMP_LOG_DOMAIN, G_LOG_LEVEL_DEBUG, "State after setting pipeline to ready: %s", stateReturnReadyName);

    stateReturnPlaying = gst_element_set_state(mgr_priv->pipeline, GST_STATE_PLAYING);
    stateReturnPlayingName = gst_element_state_change_return_get_name(stateReturnPlaying);
    g_log(VMP_LOG_DOMAIN, G_LOG_LEVEL_DEBUG, "State after setting pipeline to playing: %s", stateReturnPlayingName);
}