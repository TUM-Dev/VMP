/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#ifndef VMP_VIDEO_CONFIG_H
#define VMP_VIDEO_CONFIG_H

#include <glib-object.h>

G_BEGIN_DECLS

#define VMP_TYPE_VIDEO_CONFIG (vmp_video_config_get_type())
G_DECLARE_FINAL_TYPE(VMPVideoConfig, vmp_video_config, VMP, VIDEO_CONFIG, GObject)

struct _VMPVideoConfig
{
    GObject parent_instance;
};

VMPVideoConfig *vmp_video_config_new(guint width, guint height);

gint vmp_video_config_get_width(VMPVideoConfig *self);
gint vmp_video_config_get_height(VMPVideoConfig *self);

G_END_DECLS

#endif // VMP_VIDEO_CONFIG_H