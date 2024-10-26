{ lib
, libdispatch
, microhttpkit
, gnustep
, glib
, gst_all_1
, graphviz
, udev
, meson
, ninja
, clang
, pkg-config
, fetchpatch
}:

gnustep.stdenv.mkDerivation rec {
  pname = "vmpserverd";
  version = "0.1.0";

  src = ../Daemons/vmpserverd;

  nativeBuildInputs = [ gnustep.make meson ninja clang pkg-config ];
  buildInputs = [
    gnustep.base
    libdispatch
    microhttpkit
    glib
    gst_all_1.gstreamer
    gst_all_1.gst-rtsp-server
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-ugly # For x264enc element
    gst_all_1.gst-plugins-bad # For intervideo* elements
    gst_all_1.gst-plugins-good
    gst_all_1.gst-vaapi
    graphviz
    udev
  ];

  meta = with lib; {
    description = "About An open-source lecture streaming processor stack";
    homepage = "https://github.com/hmelder";
    license = licenses.mit;
    maintainers = with maintainers; [ hmelder ];
    platforms = platforms.unix;
  };
}
