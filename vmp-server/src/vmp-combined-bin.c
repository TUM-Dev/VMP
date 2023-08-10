/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include "vmp-combined-bin.h"
#include "vmp-video-configuration.h"

#include <gst/gst.h>

enum _VMPCombinedBinProperty
{
    PROP_0,
    PROP_OUTPUT_CONFIGURATION,
    PROP_CAMERA_CONFIGURATION,
    PROP_PRESENTATION_CONFIGURATION,
    PROP_CAMERA_ELEMENT,
    PROP_PRESENTATION_ELEMENT,
    N_PROPERTIES
};

static GParamSpec *obj_properties[N_PROPERTIES] = {
    NULL,
};

typedef struct _VMPCombinedBinPrivate
{
    GstElement *camera_element;
    GstElement *presentation_element;

    // Configuration for the camera, and presentation sources used when composing the combined output
    VMPVideoConfiguration *output_configuration;
    VMPVideoConfiguration *camera_configuration;
    VMPVideoConfiguration *presentation_configuration;
} VMPCombinedBinPrivate;

G_DEFINE_TYPE_WITH_PRIVATE(VMPCombinedBin, vmp_combined_bin, GST_TYPE_BIN);

// Forward Declarations
static void vmp_combined_bin_set_property(GObject *object, guint prop_id, const GValue *value, GParamSpec *pspec);
static void vmp_combined_add_camera_element(VMPCombinedBin *bin, GstElement *camera);
static void vmp_combined_add_presentation_element(VMPCombinedBin *bin, GstElement *presentation);
static void vmp_combined_bin_finalize(GObject *object);

static void vmp_combined_bin_init(VMPCombinedBin *self)
{
    GstBin *bin;
    // VMPCombinedBinPrivate *priv;

    // priv = vmp_combined_bin_get_instance_private(self);
    bin = GST_BIN(self);

    // Check if source elements are present (TODO: Fail with warning)
    // g_return_if_fail(GST_IS_ELEMENT(priv->camera_element));
    // g_return_if_fail(GST_IS_ELEMENT(priv->presentation_element));

    // FIXME: Dummy Configuration
    GstElement *videotestsrc = gst_element_factory_make("videotestsrc", "videotestsrc");
    GstElement *x264enc = gst_element_factory_make("x264enc", "x264enc");
    GstElement *rtph264pay = gst_element_factory_make("rtph264pay", "pay0");

    if (!videotestsrc || !x264enc || !rtph264pay)
    {
        g_error("Failed to create elements");
    }

    // Set properties if needed
    g_object_set(rtph264pay, "pt", 96, NULL);

    // Add elements to the bin
    gst_bin_add_many(GST_BIN(bin), videotestsrc, x264enc, rtph264pay, NULL);

    // Link elements
    if (!gst_element_link_many(videotestsrc, x264enc, rtph264pay, NULL))
    {
        g_error("Failed to link elements");
    }
}

static void vmp_combined_bin_class_init(VMPCombinedBinClass *self)
{
    GObjectClass *gobject_class;
    gobject_class = G_OBJECT_CLASS(self);

    gobject_class->set_property = vmp_combined_bin_set_property;
    gobject_class->finalize = vmp_combined_bin_finalize;

    obj_properties[PROP_OUTPUT_CONFIGURATION] = g_param_spec_boxed("output-configuration",
                                                                   "Output Configuration",
                                                                   "Configuration for the combined output",
                                                                   VMP_TYPE_VIDEO_CONFIGURATION,
                                                                   G_PARAM_WRITABLE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);

    obj_properties[PROP_CAMERA_CONFIGURATION] = g_param_spec_boxed("camera-configuration",
                                                                   "Camera Configuration",
                                                                   "Configuration for the camera source",
                                                                   VMP_TYPE_VIDEO_CONFIGURATION,
                                                                   G_PARAM_WRITABLE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);

    obj_properties[PROP_PRESENTATION_CONFIGURATION] = g_param_spec_boxed("presentation-configuration",
                                                                         "Presentation Configuration",
                                                                         "Configuration for the presentation source",
                                                                         VMP_TYPE_VIDEO_CONFIGURATION,
                                                                         G_PARAM_WRITABLE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);

    obj_properties[PROP_CAMERA_ELEMENT] = g_param_spec_object("camera-element",
                                                              "Camera Element",
                                                              "Element for the camera source",
                                                              GST_TYPE_ELEMENT,
                                                              G_PARAM_WRITABLE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);

    obj_properties[PROP_PRESENTATION_ELEMENT] = g_param_spec_object("presentation-element",
                                                                    "Presentation Element",
                                                                    "Element for the presentation source",
                                                                    GST_TYPE_ELEMENT,
                                                                    G_PARAM_WRITABLE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);

    g_object_class_install_properties(gobject_class, N_PROPERTIES, obj_properties);
}

VMPCombinedBin *vmp_combined_bin_new(void)
{
    VMPCombinedBin *result;

    result = g_object_new(VMP_TYPE_COMBINED_BIN, NULL);

    return result;
}

static void vmp_combined_bin_set_property(GObject *object, guint prop_id, const GValue *value, GParamSpec *pspec)
{
    VMPCombinedBin *self = VMP_COMBINED_BIN(object);
    VMPCombinedBinPrivate *priv = vmp_combined_bin_get_instance_private(self);

    switch (prop_id)
    {
        // FIXME: Dup or Boxed?
    case PROP_OUTPUT_CONFIGURATION:
        priv->output_configuration = g_value_dup_object(value);
        break;
    case PROP_CAMERA_CONFIGURATION:
        priv->camera_configuration = g_value_dup_object(value);
        break;
    case PROP_PRESENTATION_CONFIGURATION:
        priv->presentation_configuration = g_value_dup_object(value);
        break;
    case PROP_CAMERA_ELEMENT:
        vmp_combined_add_camera_element(self, GST_ELEMENT(g_value_get_object(value)));
        break;
    case PROP_PRESENTATION_ELEMENT:
        vmp_combined_add_presentation_element(self, GST_ELEMENT(g_value_get_object(value)));
        break;
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
        break;
    }
}

static void vmp_combined_bin_finalize(GObject *object)
{
    VMPCombinedBin *self;
    VMPCombinedBinPrivate *priv;

    self = VMP_COMBINED_BIN(object);
    priv = vmp_combined_bin_get_instance_private(self);

    g_clear_object(&priv->output_configuration);
    g_clear_object(&priv->camera_configuration);
    g_clear_object(&priv->presentation_configuration);
    g_clear_object(&priv->camera_element);
    g_clear_object(&priv->presentation_element);

    G_OBJECT_CLASS(vmp_combined_bin_parent_class)->finalize(object);
}

static void vmp_combined_add_camera_element(VMPCombinedBin *bin, GstElement *camera)
{
    VMPCombinedBinPrivate *priv;

    priv = vmp_combined_bin_get_instance_private(bin);

    // TODO: Print out warning as well
    g_return_if_fail(GST_IS_ELEMENT(camera));

    // Unref previous object when present
    if (priv->camera_element)
        g_object_unref(priv->camera_element);
    g_object_ref(camera);

    priv->camera_element = camera;
}
static void vmp_combined_add_presentation_element(VMPCombinedBin *bin, GstElement *presentation)
{
    VMPCombinedBinPrivate *priv;

    priv = vmp_combined_bin_get_instance_private(bin);

    g_return_if_fail(GST_IS_ELEMENT(presentation));
    if (priv->presentation_element)
        g_object_unref(priv->presentation_element);
    g_object_ref(presentation);

    priv->presentation_element = presentation;
}