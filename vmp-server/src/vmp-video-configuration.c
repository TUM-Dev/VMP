/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include "vmp-video-configuration.h"
#include <glib-object.h>

G_DEFINE_BOXED_TYPE(VMPVideoConfiguration,
                    vmp_video_configuration,
                    vmp_video_configuration_copy,
                    vmp_video_configuration_free);

VMPVideoConfiguration *vmp_video_configuration_copy(VMPVideoConfiguration *configuration)
{
    VMPVideoConfiguration *copy = g_new(VMPVideoConfiguration, 1);
    *copy = *configuration;
    return copy;
}

void vmp_video_configuration_free(VMPVideoConfiguration *configuration)
{
    g_free(configuration);
}
