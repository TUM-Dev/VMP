/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include "vmp-pipeline-config.h"

GType vmp_pipeline_config_get_type(void)
{
    static GType type = 0;

    if (type == 0)
    {
        static const GEnumValue values[] = {

            {VMP_PIPELINE_CONFIG_V4L2, "VMP_PIPELINE_CONFIG_V4L2", "PipelineConfig4L2"},
            {VMP_PIPELINE_CONFIG_SOUND, "VMP_PIPELINE_CONFIG_SOUND", "PipelineConfigSound"},
            {0, NULL, NULL}};

        type = g_enum_register_static("VMPPipelineConfig", values);
    }

    return type;
}