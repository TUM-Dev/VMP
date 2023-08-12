
#include <glib.h>
#include <gst/rtsp-server/rtsp-server.h>

#include "vmp-media-factory.h"
#include "vmp-combined-bin.h"
#include "vmp-video-config.h"

#define DEFAULT_RTSP_PORT "8554"

int main(int argc, char *argv[])
{
    GMainLoop *loop;
    GstRTSPServer *server;
    GstRTSPMountPoints *mounts;
    VMPMediaFactory *factory;

    // Initialize GStreamer
    gst_init(&argc, &argv);

    loop = g_main_loop_new(NULL, FALSE);

    server = gst_rtsp_server_new();
    g_object_set(server, "service", DEFAULT_RTSP_PORT, NULL);

    mounts = gst_rtsp_server_get_mount_points(server);

    // Create a dummy pipeline
    GstElement *camera_mock = gst_element_factory_make("videotestsrc", "camera_videotestsrc");
    GstElement *presentation_mock = gst_element_factory_make("videotestsrc", "presentation_videotestsrc");
    GstElement *audio_mock = gst_element_factory_make("audiotestsrc", "audiotestsrc");
    VMPVideoConfig *camera_config = vmp_video_config_new(480, 270);
    VMPVideoConfig *presentation_config = vmp_video_config_new(1440, 810);
    VMPVideoConfig *output_config = vmp_video_config_new(1920, 1080);

    if (!camera_mock || !presentation_mock || !camera_config || !presentation_config || !output_config)
    {
        g_error("Dummy pipeline was not correctly initialised!");
    }

    GstElement *element = GST_ELEMENT(vmp_combined_bin_new(output_config, camera_mock, camera_config, presentation_mock, presentation_config, audio_mock));

    // Full transfer to VMPCombinedBin
    g_object_unref(camera_config);
    g_object_unref(presentation_config);
    g_object_unref(output_config);

    // Initialise the custom rtsp media factory for managing our own pipeline
    factory = vmp_media_factory_new(element);

    // attach the test factory to the /comb url
    gst_rtsp_mount_points_add_factory(mounts, "/comb", GST_RTSP_MEDIA_FACTORY(factory));

    g_object_unref(mounts);
    /* attach the server to the default maincontext */
    gst_rtsp_server_attach(server, NULL);

    g_print("stream ready at rtsp://127.0.0.1:%s/comb\n", DEFAULT_RTSP_PORT);
    g_main_loop_run(loop);

    return 0;
}