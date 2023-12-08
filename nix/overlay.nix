self: super: {
  libdispatch = super.callPackage ./libdispatch.nix { };
  microhttpkit = super.callPackage ./microhttpkit.nix { };
}

