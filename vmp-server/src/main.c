
#include <glib.h>
#include <gst/rtsp-server/rtsp-server.h>

#include "vmp-media-factory.h"

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

    // Initialise the custom rtsp media factory for managing our own pipeline
    factory = vmp_media_factory_new();

    // attach the test factory to the /comb url
    gst_rtsp_mount_points_add_factory(mounts, "/comb", GST_RTSP_MEDIA_FACTORY(factory));

    g_object_unref(mounts);
    /* attach the server to the default maincontext */
    gst_rtsp_server_attach(server, NULL);

    g_print("stream ready at rtsp://127.0.0.1:%s/comb\n", DEFAULT_RTSP_PORT);
    g_main_loop_run(loop);

    return 0;
}