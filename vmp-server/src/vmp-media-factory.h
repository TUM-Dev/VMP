/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#ifndef VMP_MEDIA_FACTORY_H
#define VMP_MEDIA_FACTORY_H

#include <gst/rtsp-server/rtsp-media-factory.h>
#include "vmp-video-config.h"

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

VMPMediaFactory *vmp_media_factory_new(gchar *camera_interpipe_name, gchar *presentation_interpipe_name, gchar *audio_interpipe_name,
                                       VMPVideoConfig *output_configuration, VMPVideoConfig *camera_configuration,
                                       VMPVideoConfig *presentation_configuration);

G_END_DECLS

#endif // VMP_MEDIA_FACTORY_H