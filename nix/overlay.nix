self: super: {
  libdispatch = super.callPackage ./libdispatch.nix { };
  microhttpkit = super.callPackage ./microhttpkit.nix { };
  calendarkit = super.callPackage ./calendarkit.nix { };
  xctest = super.callPackage ./xctest.nix { };
  vmpserverd = super.callPackage ./vmpserverd.nix {
    libdispatch = self.libdispatch;
    microhttpkit = self.microhttpkit;
    calendarkit = self.calendarkit;
  };
}

