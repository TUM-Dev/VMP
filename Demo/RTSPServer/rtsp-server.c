/* rtsp-server.c -- A demo rtsp-server based on gstreamer
 *
 * Copyright (C) 2023 Hugo Melder
 *
 * This software may be modified and distributed under the terms
 * of the MIT license.  See the LICENSE file for details.
 */

#include <glib/gprintf.h>
#include <gst/gst.h>
#include <gst/rtsp-server/rtsp-server.h>

#define TEST_FEED                                                           \
	"http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/" \
	"Sintel.mp4"
#define USE_TEST_FEED 1

int main(int argc, char *argv[]) {
	GMainLoop *loop;
	GstRTSPServer *server;
	GstRTSPMountPoints *mounts;
	GstRTSPMediaFactory *factory;
	GString *launch_args;

	gst_init(&argc, &argv);

	loop = g_main_loop_new(NULL, FALSE);

	server = gst_rtsp_server_new();
	mounts = gst_rtsp_server_get_mount_points(server);

	launch_args = g_string_new(NULL);

	if (USE_TEST_FEED) {
		g_string_printf(launch_args,
				"( uridecodebin uri=%s name=dec "
				"dec. ! videoconvert ! x264enc ! rtph264pay "
				"name=pay0 pt=96 "
				"dec. ! audioconvert ! avenc_aac ! rtpmp4apay "
				"pt=97 name=pay1 )",
				TEST_FEED);
	} else {
		launch_args = g_string_new(
		    "( videotestsrc ! videoconvert ! x264enc ! "
		    "rtph264pay name=pay0 pt=96 "
		    "audiotestsrc ! audioconvert ! avenc_aac ! "
		    "rtpmp4apay pt=97 name=pay1 )");
	}

	factory = gst_rtsp_media_factory_new();

	gst_rtsp_media_factory_set_launch(factory, launch_args->str);

	gst_rtsp_media_factory_set_shared(factory, TRUE);

	gst_rtsp_mount_points_add_factory(mounts, "/tum", factory);

	g_object_unref(mounts);

	gst_rtsp_server_attach(server, NULL);

	g_print("stream ready at rtsp://127.0.0.1:8554/tum\n");
	g_printf("Pipeline: %s\n", launch_args->str);
	g_main_loop_run(loop);

	g_string_free(launch_args, TRUE);

	return 0;
}
