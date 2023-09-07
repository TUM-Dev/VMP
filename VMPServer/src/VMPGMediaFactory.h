/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

/* VMPGMediaFactory: A Subclass of the GSTRTSPMediaFactory for compositing the combined stream
 * NOTE: This is a GObject subclass, and not a Objective-C class. Prepare yourself for lots of macros!
 */

#ifndef VMP_MEDIA_FACTORY_H
#define VMP_MEDIA_FACTORY_H

#include <gst/rtsp-server/rtsp-media-factory.h>
#include "VMPGVideoConfig.h"

G_BEGIN_DECLS

#define VMP_TYPE_MEDIA_FACTORY (vmp_media_factory_get_type())
G_DECLARE_FINAL_TYPE(VMPMediaFactory, vmp_media_factory, VMP, MEDIA_FACTORY, GstRTSPMediaFactory)

struct _VMPMediaFactoryClass
{
    GstRTSPMediaFactoryClass parent_class;

    // Additional virtual functions and signals here
};

struct _VMPMediaFactory
{
    GstRTSPMediaFactory parent;
};

VMPMediaFactory *vmp_media_factory_new(const gchar *camera_channel, const gchar *presentation_channel, const gchar *audio_channel, VMPVideoConfig *output_configuration, VMPVideoConfig *camera_configuration, VMPVideoConfig *presentation_configuration);

G_END_DECLS

#endif // VMP_MEDIA_FACTORY_H