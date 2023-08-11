/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#ifndef VMP_COMBINED_BIN_H
#define VMP_COMBINED_BIN_H

#include <gst/gstbin.h>
#include <gst/gstelement.h>

#include "vmp-video-configuration.h"

G_BEGIN_DECLS

#define VMP_TYPE_COMBINED_BIN (vmp_combined_bin_get_type())
G_DECLARE_FINAL_TYPE(VMPCombinedBin, vmp_combined_bin, VMP, COMBINED_BIN, GstBin)

struct _VMPCombinedBin
{
    GstBin parent;
};

VMPCombinedBin *vmp_combined_bin_new(VMPVideoConfiguration *output,
                                     GstElement *camera, VMPVideoConfiguration *camera_config,
                                     GstElement *presentation, VMPVideoConfiguration *presentation_config);

G_END_DECLS

#endif // VMP_COMBINED_BIN_H