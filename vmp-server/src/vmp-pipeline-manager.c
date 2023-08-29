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

enum _VMPPipelineManagerProperty
{
    PROP_0,
    PROP_SRC_DEVICE,
    PROP_CHANNEL,
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
    gboolean receivedEOS;
    gboolean deviceConnected;
} VMPPipelineManagerPrivate;

G_DEFINE_TYPE_WITH_PRIVATE(VMPPipelineManager, vmp_pipeline_manager, G_TYPE_OBJECT);

// Forward Declarations
static void vmp_pipeline_manager_set_property(GObject *object, guint property_id, const GValue *value, GParamSpec *pspec);
static void vmp_pipeline_manager_finalize(GObject *object);
static void vmp_pipeline_manager_build_pipeline(VMPPipelineManager *mgr);
static void vmp_pipeline_manager_restart_pipeline(VMPPipelineManager *mgr);

static void vmp_pipeline_manager_init(VMPPipelineManager *self)
{
    VMPPipelineManagerPrivate *priv = vmp_pipeline_manager_get_instance_private(self);

    priv->src_device_name = NULL;
    priv->channel = NULL;
    priv->pipeline = NULL;
    priv->bus = NULL;
    priv->receivedEOS = FALSE;
    priv->deviceConnected = FALSE;
}

static void vmp_pipeline_manager_class_init(VMPPipelineManagerClass *klass)
{
    GObjectClass *gobject_class = G_OBJECT_CLASS(klass);

    gobject_class->set_property = vmp_pipeline_manager_set_property;
    gobject_class->finalize = vmp_pipeline_manager_finalize;

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

    g_object_class_install_properties(gobject_class, N_PROPERTIES, obj_properties);
}

VMPPipelineManager *vmp_pipeline_manager_new(gchar *src_device, gchar *channel)
{
    return g_object_new(VMP_TYPE_PIPELINE_MANAGER, "src-device", src_device, "channel", channel, NULL);
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

    G_OBJECT_CLASS(vmp_pipeline_manager_parent_class)->finalize(object);
}

/*
 * MARK: Callbacks
 */

/* This callback mechanism is used when the udev monitor callback received a device insertion
 * message, but cannot restart the pipeline immediately, as the GStreamer EOS message was not
 * emitted/processed yet. By defering the restart procedure with a timeout event, we can
 * wait for the GStreamer bus to emit the EOS message via the GMainLoop.
 */
static gboolean vmp_pipeline_manager_defered_restart_cb(VMPPipelineManager *mgr)
{
    VMPPipelineManagerPrivate *mgr_priv;

    mgr_priv = vmp_pipeline_manager_get_instance_private(mgr);

    if (mgr_priv->receivedEOS)
    {
        g_log(VMP_LOG_DOMAIN, G_LOG_LEVEL_DEBUG, "Defered pipeline restart: EOS received! Restarting pipeline...\n");
        vmp_pipeline_manager_restart_pipeline(mgr);
        return FALSE;
    }
    return TRUE;
}

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
        g_log(VMP_LOG_DOMAIN, G_LOG_LEVEL_ERROR, "gudev did not return a valid devpath in uevent callback");
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
                                           "Pipeline was initialised prior. Checking if End-of-Stream event was already sent...");
                if (mgr_priv->receivedEOS)
                {
                    vmp_common_event_log_debug("udev callback", "Immediately restarting pipeline...");
                    vmp_pipeline_manager_restart_pipeline(mgr);
                }
                else
                {
                    vmp_common_event_log_debug("udev callback",
                                               "Defer pipeline creation, as GStreamer bus has not emitted End-of-Stream yet!");

                    // Install Condition Checker in Event Loop
                    g_timeout_add(100, (GSourceFunc)vmp_pipeline_manager_defered_restart_cb, mgr);
                }
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
    VMPPipelineManagerPrivate *mgr_priv;

    mgr_priv = vmp_pipeline_manager_get_instance_private(mgr);

    switch (GST_MESSAGE_TYPE(message))
    {
    case GST_MESSAGE_EOS:
        vmp_common_event_log_debug("bus callback", "Received EOS Event on Pipeline BUS!");

        mgr_priv->receivedEOS = TRUE;

        // Set Pipeline to NULL state
        GstStateChangeReturn ret = gst_element_set_state(mgr_priv->pipeline, GST_STATE_NULL);
        // Transfer: None
        const gchar *stateReturn = gst_element_state_change_return_get_name(ret);
        vmp_common_event_log_debug("bus callback", "Set pipeline to NULL. Response: %s", stateReturn);
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

static void vmp_pipeline_manager_build_pipeline(VMPPipelineManager *mgr)
{
    GError *err = NULL;

    VMPPipelineManagerPrivate *mgr_priv;
    mgr_priv = vmp_pipeline_manager_get_instance_private(mgr);

    // check_v4l2_device(mgr_priv->src_device_name, &err);

    if (err && (g_error_matches(err, vmp_error_quark(), VMP_ERROR_V4L2_ERRNO) || g_error_matches(err, vmp_error_quark(), VMP_ERROR_V4L2_NOT_SUPPORTED)))
    {
        g_log(VMP_LOG_DOMAIN, G_LOG_LEVEL_WARNING,
              "Device %s found but does not have required attributes: %s.\n Monitoring device and waiting...",
              mgr_priv->src_device_name, err->message);
    }
    else if (!err)
    {
        // Transfer: FULL
        // TODO: Generalise pipeline creation process
        gchar *pipeline_desc = g_strdup_printf("v4l2src device=%s ! queue ! videoconvert ! queue ! intervideosink channel=%s", mgr_priv->src_device_name, mgr_priv->channel);
        g_log(VMP_LOG_DOMAIN, G_LOG_LEVEL_DEBUG,
              "Device %s is a valid v4l2 video output device. Starting pipeline with description: %s", mgr_priv->src_device_name, pipeline_desc);

        // Transfer: Floating
        mgr_priv->pipeline = gst_parse_launch(pipeline_desc, &err);

        g_free(pipeline_desc);

        if (err)
        {
            g_log(VMP_LOG_DOMAIN, G_LOG_LEVEL_ERROR, "Failed to create pipeline: %s", err->message);

            mgr_priv->pipeline = NULL;
            return;
        }

        // Transfer: Full
        mgr_priv->bus = gst_element_get_bus(mgr_priv->pipeline);
        // Register Bus Callback
        gst_bus_add_watch(mgr_priv->bus, (GstBusFunc)vmp_pipeline_manager_bus_cb, mgr);

        // Set Internal Status
        mgr_priv->deviceConnected = TRUE;
        mgr_priv->receivedEOS = FALSE;

        gst_element_set_state(mgr_priv->pipeline, GST_STATE_PLAYING);
    }
    else
    {
        g_log(VMP_LOG_DOMAIN, G_LOG_LEVEL_ERROR,
              "Device %s could not be opened: %s. Monitoring v4l2 subsystem and waiting...",
              mgr_priv->src_device_name, err->message);
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
    mgr_priv->receivedEOS = FALSE;

    stateReturnReady = gst_element_set_state(mgr_priv->pipeline, GST_STATE_READY);
    stateReturnReadyName = gst_element_state_change_return_get_name(stateReturnReady);
    g_log(VMP_LOG_DOMAIN, G_LOG_LEVEL_DEBUG, "State after setting pipeline to ready: %s", stateReturnReadyName);

    stateReturnPlaying = gst_element_set_state(mgr_priv->pipeline, GST_STATE_PLAYING);
    stateReturnPlayingName = gst_element_state_change_return_get_name(stateReturnPlaying);
    g_log(VMP_LOG_DOMAIN, G_LOG_LEVEL_DEBUG, "State after setting pipeline to playing: %s", stateReturnPlayingName);
}