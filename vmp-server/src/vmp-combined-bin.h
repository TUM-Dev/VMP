/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#ifndef VMP_COMBINED_BIN_H
#define VMP_COMBINED_BIN_H

#include <gst/gstbin.h>
#include <gst/gstelement.h>

#include "vmp-video-config.h"

G_BEGIN_DECLS

#define VMP_TYPE_COMBINED_BIN (vmp_combined_bin_get_type())
G_DECLARE_FINAL_TYPE(VMPCombinedBin, vmp_combined_bin, VMP, COMBINED_BIN, GstBin)

struct _VMPCombinedBin
{
    GstBin parent;
};

/**
 * vmp_combined_bin_new:
 * @output_config: The output video configuration
 * @camera: The camera element
 * @camera_config: The camera video configuration
 * @presentation: The presentation element
 * @presentation_config: The presentation video configuration
 * @audio: The audio element
 *
 * Creates a new #VMPCombinedBin.
 *
 * Description: This class subclasses GstBin and composits a presentation,
 * and a camera stream into one stream. The composited stream is then encoded
 * into x264 fed into an RTP stream.
 *
 * The camera, and presentation streams are scaled according to the camera_config, and
 * presentation_config respectively. The aspect-ratio is maintained (1/1), meaning
 * that black bars will be added if the video stream does not happen to be 16:9.
 *
 * The output stream is setup according to the output_config.
 *
 * Please note that all elements passed as constructor parameters must have a unique
 * name in order to be added to the bin.
 *
 * Returns: (transfer full): a new #VMPCombinedBin
 */
VMPCombinedBin *vmp_combined_bin_new(VMPVideoConfig *output_config,
                                     GstElement *camera, VMPVideoConfig *camera_config,
                                     GstElement *presentation, VMPVideoConfig *presentation_config,
                                     GstElement *audio);

G_END_DECLS

#endif // VMP_COMBINED_BIN_H