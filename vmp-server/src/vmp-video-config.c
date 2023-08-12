/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include "vmp-video-config.h"

enum _VMPVideoConfigProperty
{
    PROP_0,
    PROP_HEIGHT,
    PROP_WIDTH,
    N_PROPERTIES
};

static GParamSpec *obj_properties[N_PROPERTIES] = {
    NULL,
};

typedef struct _VMPVideoConfigPrivate
{
    gint height;
    gint width;
} VMPVideoConfigPrivate;

G_DEFINE_TYPE_WITH_PRIVATE(VMPVideoConfig, vmp_video_config, G_TYPE_OBJECT);

// Forward Declarations
static void vmp_video_config_set_property(GObject *object, guint property_id, const GValue *value, GParamSpec *pspec);
static void vmp_video_config_get_property(GObject *object, guint property_id, GValue *value, GParamSpec *pspec);

static void vmp_video_config_init(VMPVideoConfig *self)
{
    VMPVideoConfigPrivate *priv = vmp_video_config_get_instance_private(self);
    priv->height = 0;
    priv->width = 0;
}

static void vmp_video_config_class_init(VMPVideoConfigClass *klass)
{
    GObjectClass *gobject_class = G_OBJECT_CLASS(klass);

    gobject_class->set_property = vmp_video_config_set_property;
    gobject_class->get_property = vmp_video_config_get_property;

    obj_properties[PROP_HEIGHT] = g_param_spec_int(
        "height",
        "Height",
        "Height of the video",
        0,
        G_MAXINT,
        0,
        G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY);

    obj_properties[PROP_WIDTH] = g_param_spec_int(
        "width",
        "Width",
        "Width of the video",
        0,
        G_MAXINT,
        0,
        G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY);

    g_object_class_install_properties(gobject_class, N_PROPERTIES, obj_properties);
}

static void vmp_video_config_set_property(GObject *object, guint property_id, const GValue *value, GParamSpec *pspec)
{
    VMPVideoConfig *self = VMP_VIDEO_CONFIG(object);
    VMPVideoConfigPrivate *priv = vmp_video_config_get_instance_private(self);

    switch (property_id)
    {
    case PROP_HEIGHT:
        priv->height = g_value_get_int(value);
        break;
    case PROP_WIDTH:
        priv->width = g_value_get_int(value);
        break;
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID(object, property_id, pspec);
        break;
    }
}

static void vmp_video_config_get_property(GObject *object, guint property_id, GValue *value, GParamSpec *pspec)
{
    VMPVideoConfig *self = VMP_VIDEO_CONFIG(object);
    VMPVideoConfigPrivate *priv = vmp_video_config_get_instance_private(self);

    switch (property_id)
    {
    case PROP_HEIGHT:
        g_value_set_int(value, priv->height);
        break;
    case PROP_WIDTH:
        g_value_set_int(value, priv->width);
        break;
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID(object, property_id, pspec);
        break;
    }
}

VMPVideoConfig *vmp_video_config_new(guint width, guint height)
{
    return g_object_new(VMP_TYPE_VIDEO_CONFIG, "width", width, "height", height, NULL);
}

gint vmp_video_config_get_width(VMPVideoConfig *self)
{
    VMPVideoConfigPrivate *priv = vmp_video_config_get_instance_private(self);

    return priv->width;
}
gint vmp_video_config_get_height(VMPVideoConfig *self)
{
    VMPVideoConfigPrivate *priv = vmp_video_config_get_instance_private(self);

    return priv->height;
}