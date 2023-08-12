/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include <gst/gst.h>
#include "vmp-media-factory.h"
#include "vmp-combined-bin.h"

enum _VMPMediaFactoryProperty
{
    PROP_0,
    PROP_ELEMENT,
    N_PROPERTIES
};

static GParamSpec *obj_properties[N_PROPERTIES] = {
    NULL,
};

typedef struct _VMPMediaFactoryPrivate
{
    GstElement *element;
} VMPMediaFactoryPrivate;

G_DEFINE_TYPE_WITH_PRIVATE(VMPMediaFactory, vmp_media_factory, GST_TYPE_RTSP_MEDIA_FACTORY);

// Forward Declarations
GstElement *vmp_media_factory_create_element(GstRTSPMediaFactory *factory, const GstRTSPUrl *url);
static void vmp_media_factory_constructed(GObject *object);
static void vmp_media_factory_set_property(GObject *object, guint prop_id, const GValue *value, GParamSpec *pspec);
static void vmp_media_factory_finalize(GObject *object);
static void vmp_media_factory_add_element(VMPMediaFactory *self, GstElement *element);

static void vmp_media_factory_init(VMPMediaFactory *self)
{
    // Set the media factory to be shared
    g_object_set(GST_RTSP_MEDIA_FACTORY(self), "shared", TRUE, NULL);
}

static void vmp_media_factory_class_init(VMPMediaFactoryClass *self)
{
    GObjectClass *gobject_class = G_OBJECT_CLASS(self);
    GstRTSPMediaFactoryClass *factory_class = GST_RTSP_MEDIA_FACTORY_CLASS(self);

    gobject_class->constructed = vmp_media_factory_constructed;
    gobject_class->set_property = vmp_media_factory_set_property;
    gobject_class->finalize = vmp_media_factory_finalize;
    factory_class->create_element = vmp_media_factory_create_element;

    obj_properties[PROP_ELEMENT] = g_param_spec_object("element",
                                                       "Media Element",
                                                       "Element for the media factory",
                                                       GST_TYPE_ELEMENT,
                                                       G_PARAM_WRITABLE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);

    g_object_class_install_properties(gobject_class, N_PROPERTIES, obj_properties);
}

VMPMediaFactory *vmp_media_factory_new(GstElement *element)
{
    return g_object_new(VMP_TYPE_MEDIA_FACTORY, "element", element, NULL);
}

static void vmp_media_factory_constructed(GObject *object)
{
    VMPMediaFactory *self = VMP_MEDIA_FACTORY(object);

    // Call the parent's constructed method
    G_OBJECT_CLASS(vmp_media_factory_parent_class)->constructed(object);

    gst_rtsp_media_factory_set_media_gtype(GST_RTSP_MEDIA_FACTORY(self), GST_TYPE_RTSP_MEDIA);
}

static void vmp_media_factory_set_property(GObject *object, guint prop_id, const GValue *value, GParamSpec *pspec)
{
    VMPMediaFactory *self = VMP_MEDIA_FACTORY(object);

    switch (prop_id)
    {
    case PROP_ELEMENT:
        vmp_media_factory_add_element(self, GST_ELEMENT(g_value_get_object(value)));
        break;
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
        break;
    }
}

static void vmp_media_factory_finalize(GObject *object)
{
    VMPMediaFactory *self;
    VMPMediaFactoryPrivate *priv;

    self = VMP_MEDIA_FACTORY(object);
    priv = vmp_media_factory_get_instance_private(self);

    g_clear_object(&priv->element);

    G_OBJECT_CLASS(vmp_media_factory_parent_class)->finalize(object);
}

static void vmp_media_factory_add_element(VMPMediaFactory *self, GstElement *element)
{
    g_return_if_fail(GST_IS_ELEMENT(element));

    VMPMediaFactoryPrivate *priv;

    priv = vmp_media_factory_get_instance_private(self);

    // Unref previous object when present
    if (priv->element)
        g_object_unref(priv->element);
    g_object_ref(element);

    priv->element = element;
}

GstElement *vmp_media_factory_create_element(GstRTSPMediaFactory *factory, const GstRTSPUrl *url)
{
    VMPMediaFactory *self;
    VMPMediaFactoryPrivate *priv;

    self = VMP_MEDIA_FACTORY(factory);
    priv = vmp_media_factory_get_instance_private(self);

    g_assert(GST_IS_ELEMENT(priv->element));

    return priv->element;
}