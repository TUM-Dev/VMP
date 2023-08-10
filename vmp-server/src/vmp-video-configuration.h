/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#ifndef VMP_VIDEO_CONFIGURATION_H
#define VMP_VIDEO_CONFIGURATION_H

#include <glib-object.h>

G_BEGIN_DECLS

#define VMP_TYPE_VIDEO_CONFIGURATION (vmp_video_configuration_get_type())

typedef struct _VMPVideoConfiguration
{
    gint height;
    gint width;
} VMPVideoConfiguration;

GType vmp_video_configuration_get_type(void);
VMPVideoConfiguration *vmp_video_configuration_copy(VMPVideoConfiguration *configuration);
void vmp_video_configuration_free(VMPVideoConfiguration *configuration);

G_END_DECLS

#endif // VMP_VIDEO_CONFIGURATION_H
