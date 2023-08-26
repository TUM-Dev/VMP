/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include <gst/gst.h>
#include "vmp-pipeline-manager.h"

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
} VMPPipelineManagerPrivate;

G_DEFINE_TYPE_WITH_PRIVATE(VMPPipelineManager, vmp_pipeline_manager, G_TYPE_OBJECT);

// Forward Declarations
static void vmp_pipeline_manager_set_property(GObject *object, guint property_id, const GValue *value, GParamSpec *pspec);
static void vmp_pipeline_manager_finalize(GObject *object);

static void vmp_pipeline_manager_init(VMPPipelineManager *self)
{
    VMPPipelineManagerPrivate *priv = vmp_pipeline_manager_get_instance_private(self);
    priv->src_device_name = NULL;
    priv->channel = NULL;
    priv->pipeline = NULL;
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