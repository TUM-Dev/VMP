/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#ifndef VMP_PIPELINE_MANAGER_H
#define VMP_PIPELINE_MANAGER_H

#include <glib-object.h>

#include "vmp-pipeline-config.h"

G_BEGIN_DECLS

#define VMP_TYPE_PIPELINE_MANAGER (vmp_pipeline_manager_get_type())
G_DECLARE_FINAL_TYPE(VMPPipelineManager, vmp_pipeline_manager, VMP, PIPELINE_MANAGER, GObject)

struct _VMPPipelineManager
{
    GObject parent_instance;
};

VMPPipelineManager *vmp_pipeline_manager_new(gchar *src_device, VMPPipelineConfig config, gchar *channel);

G_END_DECLS

#endif // VMP_PIPELINE_MANAGER_H
