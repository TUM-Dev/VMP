/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include <gst/gst.h>
#include "vmp-media-factory.h"
#include "vmp-combined-bin.h"

struct _VMPMediaFactory
{
    GstRTSPMediaFactory parent_instance;

    // Additional instance members here
};

G_DEFINE_TYPE(VMPMediaFactory, vmp_media_factory, GST_TYPE_RTSP_MEDIA_FACTORY);

// Forward Declarations
GstElement *vmp_media_factory_create_element(GstRTSPMediaFactory *factory, const GstRTSPUrl *url);
static void vmp_media_factory_constructed(GObject *object);

static void vmp_media_factory_init(VMPMediaFactory *self)
{
    // Initialize instance members if necessary
}

static void vmp_media_factory_class_init(VMPMediaFactoryClass *self)
{
    GObjectClass *gobject_class = G_OBJECT_CLASS(self);
    GstRTSPMediaFactoryClass *factory_class = GST_RTSP_MEDIA_FACTORY_CLASS(self);

    gobject_class->constructed = vmp_media_factory_constructed;
    factory_class->create_element = vmp_media_factory_create_element;
}

VMPMediaFactory *vmp_media_factory_new(void)
{
    return g_object_new(VMP_TYPE_MEDIA_FACTORY, NULL);
}

static void vmp_media_factory_constructed(GObject *object)
{
    VMPMediaFactory *self = VMP_MEDIA_FACTORY(object);

    // Call the parent's constructed method
    G_OBJECT_CLASS(vmp_media_factory_parent_class)->constructed(object);

    gst_rtsp_media_factory_set_media_gtype(GST_RTSP_MEDIA_FACTORY(self), GST_TYPE_RTSP_MEDIA);
}

GstElement *vmp_media_factory_create_element(GstRTSPMediaFactory *factory, const GstRTSPUrl *url)
{
    GError *error = NULL;
    GstElement *element = gst_parse_launch("videotestsrc ! x264enc ! rtph264pay name=pay0 pt=96", &error);
    if (error)
    {
        g_printerr("Failed to parse element: %s\n", error->message);
        g_error_free(error);
    }

    return element;
}