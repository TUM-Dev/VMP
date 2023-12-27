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
    pkgs.gst_all_1.gstreamer.dev
    pkgs.gst_all_1.gst-rtsp-server
    pkgs.gst_all_1.gst-rtsp-server.dev
    pkgs.gst_all_1.gst-plugins-ugly # For x264enc element
    pkgs.gst_all_1.gst-plugins-bad # For intervideo* elements
    pkgs.gst_all_1.gst-plugins-base
    pkgs.gst_all_1.gst-plugins-good
    pkgs.gst_all_1.gst-libav # For avenc_aac
    pkgs.gst_all_1.gst-vaapi

    pkgs.llvmPackages_14.llvm
    pkgs.llvmPackages_14.clang
    pkgs.llvmPackages_14.lldb
    pkgs.llvmPackages_14.lld
    pkgs.clang-tools_14

    # GNUstep
    pkgs.gnustep.base
    pkgs.gnustep.make

    pkgs.glib
    pkgs.glib.dev
    pkgs.gobject-introspection
    pkgs.meson
    pkgs.pkg-config
    pkgs.ninja
    pkgs.libsoup_3
    pkgs.libsoup_3.dev
    pkgs.alsa-lib
    pkgs.alsa-lib.dev

    # vaapi (vainfo)
    pkgs.libva-utils

    pkgs.udev
    pkgs.udev.dev

    # MicroHTTPKit
    pkgs.microhttpkit

    pkgs.xctest

  ];

  shellHook = ''
    echo "Entering the vmp development environment..."
    export CC=clang
    export OBJC=clang
    export CXX=clang++
    export LD=ld.lld
  '';
}
