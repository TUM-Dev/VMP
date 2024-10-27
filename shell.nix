{ pkgs ? import <nixpkgs> {
    overlays = [ (import ./nix/overlay.nix) ];
  }
}:

let
  #unstablePkgs = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixpkgs-unstable.tar.gz") {};
in
pkgs.mkShell {
  buildInputs = [
    # GStreamer
    pkgs.gst_all_1.gstreamer
    pkgs.gst_all_1.gst-rtsp-server
    pkgs.gst_all_1.gst-plugins-ugly # For x264enc element
    pkgs.gst_all_1.gst-plugins-bad # For intervideo* elements
    pkgs.gst_all_1.gst-plugins-base
    pkgs.gst_all_1.gst-plugins-good
    pkgs.gst_all_1.gst-libav # For avenc_aac
    pkgs.gst_all_1.gst-vaapi

    /*
      pkgs.clang_18
      pkgs.lldb_18
      pkgs.clang-tools_18
    */
    pkgs.llvmPackages_14.llvm
    pkgs.llvmPackages_14.clang
    pkgs.llvmPackages_14.lldb
    pkgs.llvmPackages_14.lld
    pkgs.meson
    pkgs.pkg-config
    pkgs.ninja

    # GNUstep
    pkgs.gnustep.base
    pkgs.gnustep.make

    pkgs.graphviz
    pkgs.udev
    pkgs.libdispatch
    pkgs.microhttpkit
    pkgs.calendarkit
    pkgs.glib
    pkgs.xctest

    # CalendarKit
    pkgs.libical

    # MircroHTTPKit
    pkgs.libmicrohttpd

    # vaapi (vainfo)
    pkgs.libva-utils
  ];

  shellHook = ''
    echo "Entering the vmp development environment..."
    export CC=clang
    export OBJC=clang
    export CXX=clang++
    export LD=ld.lld
  '';
}
