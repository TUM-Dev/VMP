/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include "vmp-combined-bin.h"

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
static void vmp_combined_bin_constructed(GObject *object);
static void vmp_combined_bin_finalize(GObject *object);

static void vmp_combined_bin_init(VMPCombinedBin *self)
{
}

static void vmp_combined_bin_class_init(VMPCombinedBinClass *self)
{
    GObjectClass *gobject_class;
    gobject_class = G_OBJECT_CLASS(self);

    gobject_class->set_property = vmp_combined_bin_set_property;
    gobject_class->constructed = vmp_combined_bin_constructed;
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

VMPCombinedBin *vmp_combined_bin_new(VMPVideoConfiguration *output,
                                     GstElement *camera, VMPVideoConfiguration *camera_config,
                                     GstElement *presentation, VMPVideoConfiguration *presentation_config)

{
    VMPCombinedBin *result;

    result = g_object_new(VMP_TYPE_COMBINED_BIN,
                          "output-configuration", output,
                          "camera-configuration", camera_config,
                          "presentation-configuration", presentation_config,
                          "camera-element", camera,
                          "presentation-element", presentation, NULL);

    return result;
}

/*
 * Construct the combined video bin that composites the camera and presentation sources.
 * Properties are presented when vmp_combined_bin_constructed is called.
 */
static void vmp_combined_bin_constructed(GObject *object)
{
    // Call constructed func of GstBin first
    G_OBJECT_CLASS(vmp_combined_bin_parent_class)->constructed(object);

    VMPCombinedBinPrivate *priv;
    GstBin *bin;
    GstElement *compositor;
    GstElement *compositor_caps_filter;
    GstElement *camera_videoscale;
    GstElement *camera_caps_filter;
    GstElement *presentation_videoscale;
    GstElement *presentation_caps_filter;
    GstElement *x264enc;
    GstElement *rtph264pay;

    priv = vmp_combined_bin_get_instance_private(VMP_COMBINED_BIN(object));
    bin = GST_BIN(object);

    // Check if source elements are present (TODO: Fail with warning)
    g_return_if_fail(GST_IS_ELEMENT(priv->camera_element));
    g_return_if_fail(GST_IS_ELEMENT(priv->presentation_element));
    g_return_if_fail(priv->output_configuration);
    g_return_if_fail(priv->camera_configuration);
    g_return_if_fail(priv->presentation_configuration);

    compositor = gst_element_factory_make("compositor", "compositor");
    compositor_caps_filter = gst_element_factory_make("capsfilter", "compositor_capsfilter");
    presentation_videoscale = gst_element_factory_make("videoscale", "presentation_videoscale");
    presentation_caps_filter = gst_element_factory_make("capsfilter", "presentation_capsfilter");
    camera_videoscale = gst_element_factory_make("videoscale", "camera_videoscale");
    camera_caps_filter = gst_element_factory_make("capsfilter", "camera_capsfilter");
    x264enc = gst_element_factory_make("x264enc", "x264enc");
    rtph264pay = gst_element_factory_make("rtph264pay", "pay0");

    if (!compositor || !compositor_caps_filter || !presentation_videoscale ||
        !presentation_caps_filter || !camera_videoscale || !camera_caps_filter || !x264enc || !rtph264pay)
    {
        GST_ERROR("Failed to create elements required for compositing");
        return;
    }

    // Set properties of compositor
    g_object_set(G_OBJECT(compositor), "background", 1, NULL);

    /*
     * Build Caps from VMPVideoConfiguration
     */
    GstCaps *compositor_caps;
    GstCaps *presentation_caps;
    GstCaps *camera_caps;

    compositor_caps = gst_caps_new_simple("video/x-raw",
                                          "width", G_TYPE_INT, priv->output_configuration->width,
                                          "height", G_TYPE_INT, priv->output_configuration->height, NULL);
    presentation_caps = gst_caps_new_simple("video/x-raw",
                                            "width", G_TYPE_INT, priv->presentation_configuration->width,
                                            "height", G_TYPE_INT, priv->presentation_configuration->height,
                                            "pixel-aspect-ratio", GST_TYPE_FRACTION, 1, 1, NULL);
    camera_caps = gst_caps_new_simple("video/x-raw",
                                      "width", G_TYPE_INT, priv->camera_configuration->width,
                                      "height", G_TYPE_INT, priv->camera_configuration->height,
                                      "pixel-aspect-ratio", GST_TYPE_FRACTION, 1, 1, NULL);

    g_object_set(G_OBJECT(compositor_caps_filter), "caps", compositor_caps, NULL);
    g_object_set(G_OBJECT(presentation_caps_filter), "caps", presentation_caps, NULL);
    g_object_set(G_OBJECT(camera_caps_filter), "caps", camera_caps, NULL);

    gst_caps_unref(compositor_caps);
    gst_caps_unref(presentation_caps);
    gst_caps_unref(camera_caps);

    /*
     * Add elements to the bin, and link subcomponents
     */

    // Add elements to the bin
    gst_bin_add_many(GST_BIN(bin), priv->presentation_element, presentation_videoscale, presentation_caps_filter, NULL);
    gst_bin_add_many(GST_BIN(bin), priv->camera_element, camera_videoscale, camera_caps_filter, NULL);
    gst_bin_add_many(GST_BIN(bin), compositor, compositor_caps_filter, x264enc, rtph264pay, NULL);

    /* Set properties of rtp payloader.
     * RTP Payload Format '96' is often used as the default value for H.264 video.
     */
    g_object_set(rtph264pay, "pt", 96, NULL);

    // Link elements
    if (!gst_element_link_many(priv->camera_element, camera_videoscale, camera_caps_filter, NULL))
    {
        GST_ERROR("Failed to link camera elements!");
        return;
    }
    if (!gst_element_link_many(priv->presentation_element, presentation_videoscale, presentation_caps_filter, NULL))
    {
        GST_ERROR("Failed to link presentation elements!");
        return;
    }
    if (!gst_element_link_many(compositor, compositor_caps_filter, x264enc, rtph264pay, NULL))
    {
        GST_ERROR("Failed to link compositor elements!");
        return;
    }

    /*
     * Pad Configuration for Compositor
     */

    GstPad *source_camera_pad;
    GstPad *sink_camera_pad;
    GstPad *source_presentation_pad;
    GstPad *sink_presentation_pad;
    GstPadTemplate *sink_template;

    // Get source pads from the source elements
    source_camera_pad = gst_element_get_static_pad(camera_caps_filter, "src");
    source_presentation_pad = gst_element_get_static_pad(presentation_caps_filter, "src");
    if (!source_camera_pad || !source_presentation_pad)
    {
        GST_ERROR("Failed to acquire source pads from camera_caps_filter or presentation_caps_filter!");
        return;
    }

    // Request sink pads from the compositor
    sink_template = gst_element_class_get_pad_template(GST_ELEMENT_GET_CLASS(compositor), "sink_%u");
    sink_camera_pad = gst_element_request_pad(compositor, sink_template, NULL, NULL);
    sink_presentation_pad = gst_element_request_pad(compositor, sink_template, NULL, NULL);
    if (!sink_camera_pad || !sink_presentation_pad)
    {
        GST_ERROR("Failed to acquire sink pads from compositor!");
        return;
    }

    gint camera_pad_width = priv->output_configuration->width - priv->camera_configuration->width;
    g_object_set(G_OBJECT(sink_camera_pad), "xpos", camera_pad_width, NULL);
    g_object_set(G_OBJECT(sink_camera_pad), "ypos", 0, NULL);

    g_object_set(G_OBJECT(sink_presentation_pad), "xpos", 0, NULL);
    g_object_set(G_OBJECT(sink_presentation_pad), "ypos", 0, NULL);

    GstPadLinkReturn link_camera_ret;
    GstPadLinkReturn link_presentation_ret;

    /* NOTE: Linking pads manually is done AFTER linking the elements automatically.
     * Otherwise the pads will be unlinked by gstreamer.
     */
    link_camera_ret = gst_pad_link(source_camera_pad, sink_camera_pad);
    if (link_camera_ret != GST_PAD_LINK_OK)
    {
        GST_ERROR("Failed to link camera source to compositor! Error: %s", gst_pad_link_get_name(link_camera_ret));
        return;
    }
    link_presentation_ret = gst_pad_link(source_presentation_pad, sink_presentation_pad);
    if (link_presentation_ret != GST_PAD_LINK_OK)
    {
        GST_ERROR("Failed to link presentation source to compositor! Error: %s", gst_pad_link_get_name(link_presentation_ret));
        return;
    }

    g_object_unref(source_camera_pad);
    g_object_unref(sink_camera_pad);
    g_object_unref(source_presentation_pad);
    g_object_unref(sink_presentation_pad);
}

static void vmp_combined_bin_set_property(GObject *object, guint prop_id, const GValue *value, GParamSpec *pspec)
{
    VMPCombinedBin *self = VMP_COMBINED_BIN(object);
    VMPCombinedBinPrivate *priv = vmp_combined_bin_get_instance_private(self);

    switch (prop_id)
    {
        // FIXME: Dup or Boxed?
    case PROP_OUTPUT_CONFIGURATION:
        priv->output_configuration = g_value_dup_boxed(value);
        break;
    case PROP_CAMERA_CONFIGURATION:
        priv->camera_configuration = g_value_dup_boxed(value);
        break;
    case PROP_PRESENTATION_CONFIGURATION:
        priv->presentation_configuration = g_value_dup_boxed(value);
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