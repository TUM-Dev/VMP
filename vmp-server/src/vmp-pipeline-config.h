/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#ifndef VMP_PIPELINE_CONFIG_H
#define VMP_PIPELINE_CONFIG_H

#include <glib-object.h>

G_BEGIN_DECLS

typedef enum _VMPPipelineConfig
{
    VMP_PIPELINE_CONFIG_V4L2,
    VMP_PIPELINE_CONFIG_SOUND
} VMPPipelineConfig;

GType vmp_pipeline_config_get_type(void);
#define VMP_TYPE_PIPELINE_CONFIG (vmp_pipeline_config_get_type())

G_END_DECLS

#endif // VMP_PIPELINE_CONFIG_H