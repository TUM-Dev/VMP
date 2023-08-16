/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include <gst/gst.h>
#include "vmp-media-factory.h"

enum _VMPMediaFactoryProperty
{
    PROP_0,
    PROP_OUTPUT_CONFIGURATION,
    PROP_CAMERA_CONFIGURATION,
    PROP_PRESENTATION_CONFIGURATION,
    PROP_CAMERA_INTERPIPE_NAME,
    PROP_PRESENTATION_ITERPIPE_NAME,
    PROP_AUDIO_INTERPIPE_NAME,
    N_PROPERTIES
};

enum _VMPMediaFactoryConfigurationType
{
    VMP_MEDIA_FACTORY_OUTPUT_CONFIGURATION,
    VMP_MEDIA_FACTORY_CAMERA_CONFIGURATION,
    VMP_MEDIA_FACTORY_PRESENTATION_CONFIGURATION
};

static GParamSpec *obj_properties[N_PROPERTIES] = {
    NULL,
};

typedef struct _VMPMediaFactoryPrivate
{
    gchar *camera_interpipe_name;
    gchar *presentation_interpipe_name;
    gchar *audio_interpipe_name;

    // Configuration for the camera, and presentation sources used when composing the combined output
    VMPVideoConfig *output_configuration;
    VMPVideoConfig *camera_configuration;
    VMPVideoConfig *presentation_configuration;
} VMPMediaFactoryPrivate;

G_DEFINE_TYPE_WITH_PRIVATE(VMPMediaFactory, vmp_media_factory, GST_TYPE_RTSP_MEDIA_FACTORY);

// Forward Declarations
GstElement *vmp_media_factory_create_element(GstRTSPMediaFactory *factory, const GstRTSPUrl *url);
static void vmp_media_factory_constructed(GObject *object);
static void vmp_media_factory_set_property(GObject *object, guint prop_id, const GValue *value, GParamSpec *pspec);
static void vmp_media_factory_add_configuration(VMPMediaFactory *bin, enum _VMPMediaFactoryConfigurationType type, VMPVideoConfig *output);
static void vmp_media_factory_finalize(GObject *object);

static void vmp_media_factory_init(VMPMediaFactory *self)
{
    // Set the media factory to be shared
    g_object_set(GST_RTSP_MEDIA_FACTORY(self), "shared", TRUE, NULL);
}

static void vmp_media_factory_class_init(VMPMediaFactoryClass *self)
{
    GObjectClass *gobject_class = G_OBJECT_CLASS(self);
    GstRTSPMediaFactoryClass *factory_class = GST_RTSP_MEDIA_FACTORY_CLASS(self);

    gobject_class->constructed = vmp_media_factory_constructed;
    gobject_class->set_property = vmp_media_factory_set_property;
    gobject_class->finalize = vmp_media_factory_finalize;
    factory_class->create_element = vmp_media_factory_create_element;

    obj_properties[PROP_CAMERA_INTERPIPE_NAME] = g_param_spec_string("camera-interpipe-name",
                                                                     "Camera Interpipe Name",
                                                                     "Name of the interpipe for the camera source",
                                                                     NULL,
                                                                     G_PARAM_WRITABLE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);

    obj_properties[PROP_PRESENTATION_ITERPIPE_NAME] = g_param_spec_string("presentation-interpipe-name",
                                                                          "Presentation Interpipe Name",
                                                                          "Name of the interpipe for the presentation source",
                                                                          NULL,
                                                                          G_PARAM_WRITABLE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);

    obj_properties[PROP_AUDIO_INTERPIPE_NAME] = g_param_spec_string("audio-interpipe-name",
                                                                    "Audio Interpipe Name",
                                                                    "Name of the interpipe for the audio source",
                                                                    NULL,
                                                                    G_PARAM_WRITABLE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);

    obj_properties[PROP_OUTPUT_CONFIGURATION] = g_param_spec_object("output-configuration",
                                                                    "Output Configuration",
                                                                    "Configuration for the combined output",
                                                                    VMP_TYPE_VIDEO_CONFIG,
                                                                    G_PARAM_WRITABLE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);

    obj_properties[PROP_CAMERA_CONFIGURATION] = g_param_spec_object("camera-configuration",
                                                                    "Camera Configuration",
                                                                    "Configuration for the camera source",
                                                                    VMP_TYPE_VIDEO_CONFIG,
                                                                    G_PARAM_WRITABLE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);

    obj_properties[PROP_PRESENTATION_CONFIGURATION] = g_param_spec_object("presentation-configuration",
                                                                          "Presentation Configuration",
                                                                          "Configuration for the presentation source",
                                                                          VMP_TYPE_VIDEO_CONFIG,
                                                                          G_PARAM_WRITABLE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS);

    g_object_class_install_properties(gobject_class, N_PROPERTIES, obj_properties);
}

VMPMediaFactory *vmp_media_factory_new(gchar *camera_interpipe_name, gchar *presentation_interpipe_name, gchar *audio_interpipe_name, VMPVideoConfig *output_configuration, VMPVideoConfig *camera_configuration, VMPVideoConfig *presentation_configuration)
{
    return g_object_new(VMP_TYPE_MEDIA_FACTORY, "camera-interpipe-name", camera_interpipe_name,
                        "presentation-interpipe-name", presentation_interpipe_name,
                        "audio-interpipe-name", audio_interpipe_name, "output-configuration", output_configuration,
                        "camera-configuration", camera_configuration, "presentation-configuration", presentation_configuration,
                        NULL);
}

static void vmp_media_factory_constructed(GObject *object)
{
    VMPMediaFactory *self = VMP_MEDIA_FACTORY(object);

    // Call the parent's constructed method
    G_OBJECT_CLASS(vmp_media_factory_parent_class)->constructed(object);

    gst_rtsp_media_factory_set_media_gtype(GST_RTSP_MEDIA_FACTORY(self), GST_TYPE_RTSP_MEDIA);
}

static void vmp_media_factory_set_property(GObject *object, guint prop_id, const GValue *value, GParamSpec *pspec)
{
    VMPMediaFactory *self = VMP_MEDIA_FACTORY(object);
    VMPMediaFactoryPrivate *priv = vmp_media_factory_get_instance_private(self);

    switch (prop_id)
    {
    case PROP_OUTPUT_CONFIGURATION:
        vmp_media_factory_add_configuration(self, VMP_MEDIA_FACTORY_OUTPUT_CONFIGURATION, g_value_dup_object(value));
        break;
    case PROP_CAMERA_CONFIGURATION:
        vmp_media_factory_add_configuration(self, VMP_MEDIA_FACTORY_CAMERA_CONFIGURATION, g_value_dup_object(value));
        break;
    case PROP_PRESENTATION_CONFIGURATION:
        vmp_media_factory_add_configuration(self, VMP_MEDIA_FACTORY_PRESENTATION_CONFIGURATION, g_value_dup_object(value));
        break;
    case PROP_CAMERA_INTERPIPE_NAME:
        priv->camera_interpipe_name = g_value_dup_string(value);
        break;
    case PROP_PRESENTATION_ITERPIPE_NAME:
        priv->presentation_interpipe_name = g_value_dup_string(value);
        break;
    case PROP_AUDIO_INTERPIPE_NAME:
        priv->audio_interpipe_name = g_value_dup_string(value);
        break;
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
        break;
    }
}

static void vmp_media_factory_finalize(GObject *object)
{
    VMPMediaFactory *self;
    VMPMediaFactoryPrivate *priv;

    self = VMP_MEDIA_FACTORY(object);
    priv = vmp_media_factory_get_instance_private(self);

    g_free(priv->camera_interpipe_name);
    g_free(priv->presentation_interpipe_name);
    g_free(priv->audio_interpipe_name);
    g_object_unref(priv->output_configuration);
    g_object_unref(priv->camera_configuration);
    g_object_unref(priv->presentation_configuration);

    G_OBJECT_CLASS(vmp_media_factory_parent_class)->finalize(object);
}

/*
 * Construct the combined video bin that composites the camera and presentation sources.
 */
GstElement *vmp_media_factory_create_element(GstRTSPMediaFactory *factory, const GstRTSPUrl *url)
{
    VMPMediaFactoryPrivate *priv;
    GstBin *bin;

    GstElement *presentation_interpipe;
    GstElement *presentation_queue;
    GstElement *presentation_videoconvert;
    GstElement *presentation_videoscale;
    GstElement *presentation_caps_filter;

    GstElement *camera_interpipe;
    GstElement *camera_queue;
    GstElement *camera_videoconvert;
    GstElement *camera_videoscale;
    GstElement *camera_caps_filter;

    GstElement *audio_interpipe;
    GstElement *audio_queue;
    GstElement *audio_audioconvert;

    GstElement *compositor;
    GstElement *compositor_caps_filter;
    GstElement *aacenc, *x264enc;
    GstElement *rtph264pay, *rtpmp4apay;

    priv = vmp_media_factory_get_instance_private(VMP_MEDIA_FACTORY(factory));
    bin = GST_BIN(gst_bin_new("combined_bin"));

    // Check if source elements are present (TODO: Fail with warning)
    g_return_val_if_fail(priv->camera_interpipe_name, NULL);
    g_return_val_if_fail(priv->presentation_interpipe_name, NULL);
    g_return_val_if_fail(priv->audio_interpipe_name, NULL);
    g_return_val_if_fail(priv->output_configuration, NULL);
    g_return_val_if_fail(priv->camera_configuration, NULL);
    g_return_val_if_fail(priv->presentation_configuration, NULL);

    presentation_interpipe = gst_element_factory_make("intervideosrc", "presentation_interpipe");
    presentation_queue = gst_element_factory_make("queue", "presentation_queue");
    presentation_videoconvert = gst_element_factory_make("videoconvert", "presentation_videoconvert");
    presentation_videoscale = gst_element_factory_make("videoscale", "presentation_videoscale");
    presentation_caps_filter = gst_element_factory_make("capsfilter", "presentation_capsfilter");

    if (!presentation_interpipe || !presentation_queue || !presentation_videoconvert || !presentation_videoscale || !presentation_caps_filter)
    {
        GST_ERROR("Failed to create elements required for presentation stream processing");
        return NULL;
    }

    camera_interpipe = gst_element_factory_make("intervideosrc", "camera_interpipe");
    camera_queue = gst_element_factory_make("queue", "camera_queue");
    camera_videoconvert = gst_element_factory_make("videoconvert", "camera_videoconvert");
    camera_videoscale = gst_element_factory_make("videoscale", "camera_videoscale");
    camera_caps_filter = gst_element_factory_make("capsfilter", "camera_capsfilter");

    if (!camera_interpipe || !camera_queue || !camera_videoconvert || !camera_videoscale || !camera_caps_filter)
    {
        GST_ERROR("Failed to create elements required for camera stream processing");
        return NULL;
    }

    audio_interpipe = gst_element_factory_make("interaudiosrc", "audio_interpipe");
    audio_queue = gst_element_factory_make("queue", "audio_queue");
    audio_audioconvert = gst_element_factory_make("audioconvert", "audio_audioconvert");

    if (!audio_interpipe || !audio_queue || !audio_audioconvert)
    {
        GST_ERROR("Failed to create elements required for audio stream processing");
        return NULL;
    }

    compositor = gst_element_factory_make("compositor", "compositor");
    compositor_caps_filter = gst_element_factory_make("capsfilter", "compositor_capsfilter");

    // TODO: Conditionally use Nvidia NVENC when on Jetson hardware
    x264enc = gst_element_factory_make("x264enc", "x264enc");
    aacenc = gst_element_factory_make("voaacenc", "aacenc");
    rtph264pay = gst_element_factory_make("rtph264pay", "pay0");
    rtpmp4apay = gst_element_factory_make("rtpmp4apay", "pay1");

    if (!compositor || !compositor_caps_filter || !x264enc || !aacenc || !rtph264pay || !rtpmp4apay)
    {
        GST_ERROR("Failed to create elements required for compositing and output stream processing");
        return NULL;
    }

    // Set properties of compositor
    g_object_set(G_OBJECT(compositor), "background", 1, NULL);

    g_object_set(aacenc, "bitrate", 128000, NULL);

    /* Set properties of rtp payloader.
     * RTP Payload Format '96' is often used as the default value for H.264 video.
     * RTP Payload Format '97' is often used as the default value for AAC audio.
     */
    g_object_set(rtph264pay, "pt", 96, NULL);
    g_object_set(rtpmp4apay, "pt", 97, NULL);

    // Set properties of interpipe elements
    g_object_set(presentation_interpipe, "channel", priv->presentation_interpipe_name, NULL);
    g_object_set(camera_interpipe, "channel", priv->camera_interpipe_name, NULL);
    g_object_set(audio_interpipe, "channel", priv->audio_interpipe_name, NULL);

    /*
     * Build Caps from VMPVideoConfiguration
     */
    GstCaps *compositor_caps;
    GstCaps *presentation_caps;
    GstCaps *camera_caps;

    compositor_caps = gst_caps_new_simple("video/x-raw",
                                          "width", G_TYPE_INT, vmp_video_config_get_width(priv->output_configuration),
                                          "height", G_TYPE_INT, vmp_video_config_get_height(priv->output_configuration), NULL);
    presentation_caps = gst_caps_new_simple("video/x-raw",
                                            "width", G_TYPE_INT, vmp_video_config_get_width(priv->presentation_configuration),
                                            "height", G_TYPE_INT, vmp_video_config_get_height(priv->presentation_configuration),
                                            "pixel-aspect-ratio", GST_TYPE_FRACTION, 1, 1, NULL);
    camera_caps = gst_caps_new_simple("video/x-raw",
                                      "width", G_TYPE_INT, vmp_video_config_get_width(priv->camera_configuration),
                                      "height", G_TYPE_INT, vmp_video_config_get_height(priv->camera_configuration),
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
    gst_bin_add_many(GST_BIN(bin), presentation_interpipe, presentation_queue, presentation_videoconvert, presentation_videoscale, presentation_caps_filter, NULL);
    gst_bin_add_many(GST_BIN(bin), camera_interpipe, camera_queue, camera_videoconvert, camera_videoscale, camera_caps_filter, NULL);
    gst_bin_add_many(GST_BIN(bin), compositor, compositor_caps_filter, x264enc, rtph264pay, NULL);
    gst_bin_add_many(GST_BIN(bin), audio_interpipe, audio_queue, audio_audioconvert, aacenc, rtpmp4apay, NULL);

    // Link elements
    if (!gst_element_link_many(camera_interpipe, camera_queue, camera_videoconvert, camera_videoscale, camera_caps_filter, NULL))
    {
        GST_ERROR("Failed to link camera elements!");
        return NULL;
    }
    if (!gst_element_link_many(presentation_interpipe, presentation_queue, presentation_videoconvert, presentation_videoscale, presentation_caps_filter, NULL))
    {
        GST_ERROR("Failed to link presentation elements!");
        return NULL;
    }
    if (!gst_element_link_many(compositor, compositor_caps_filter, x264enc, rtph264pay, NULL))
    {
        GST_ERROR("Failed to link compositor elements!");
        return NULL;
    }
    if (!gst_element_link_many(audio_interpipe, audio_queue, audio_audioconvert, aacenc, rtpmp4apay, NULL))
    {
        GST_ERROR("Failed to link audio elements!");
        return NULL;
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
        return NULL;
    }

    // Request sink pads from the compositor
    sink_template = gst_element_class_get_pad_template(GST_ELEMENT_GET_CLASS(compositor), "sink_%u");
    sink_camera_pad = gst_element_request_pad(compositor, sink_template, NULL, NULL);
    sink_presentation_pad = gst_element_request_pad(compositor, sink_template, NULL, NULL);
    if (!sink_camera_pad || !sink_presentation_pad)
    {
        GST_ERROR("Failed to acquire sink pads from compositor!");
        return NULL;
    }

    gint camera_pad_width = vmp_video_config_get_width(priv->output_configuration) - vmp_video_config_get_width(priv->camera_configuration);
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
        return NULL;
    }
    link_presentation_ret = gst_pad_link(source_presentation_pad, sink_presentation_pad);
    if (link_presentation_ret != GST_PAD_LINK_OK)
    {
        GST_ERROR("Failed to link presentation source to compositor! Error: %s", gst_pad_link_get_name(link_presentation_ret));
        return NULL;
    }

    g_object_unref(source_camera_pad);
    g_object_unref(sink_camera_pad);
    g_object_unref(source_presentation_pad);
    g_object_unref(sink_presentation_pad);

    return GST_ELEMENT(bin);
}

static void vmp_media_factory_add_configuration(VMPMediaFactory *bin, enum _VMPMediaFactoryConfigurationType type, VMPVideoConfig *output)
{
    VMPMediaFactoryPrivate *priv;

    priv = vmp_media_factory_get_instance_private(bin);

    g_return_if_fail(VMP_IS_VIDEO_CONFIG(output));

    switch (type)
    {
    case VMP_MEDIA_FACTORY_OUTPUT_CONFIGURATION:
        if (priv->output_configuration)
            g_object_unref(priv->output_configuration);
        priv->output_configuration = output;
        break;
    case VMP_MEDIA_FACTORY_CAMERA_CONFIGURATION:
        if (priv->camera_configuration)
            g_object_unref(priv->camera_configuration);
        priv->camera_configuration = output;
        break;
    case VMP_MEDIA_FACTORY_PRESENTATION_CONFIGURATION:
        if (priv->presentation_configuration)
            g_object_unref(priv->presentation_configuration);
        priv->presentation_configuration = output;
        break;
    };

    g_object_ref(output);
}