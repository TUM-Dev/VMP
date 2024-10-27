{ libmicrohttpd, gnustep, lib, meson, ninja, clang, pkg-config, fetchpatch }:

gnustep.stdenv.mkDerivation rec {
  pname = "microhttpkit";
  version = "0.2.1";

  src = ../Libraries/MicroHTTPKit;

  nativeBuildInputs = [ gnustep.make meson ninja clang pkg-config ];
  buildInputs = [ gnustep.base libmicrohttpd ];

  meta = with lib; {
    description = "A small Objective-C 2.0 framework around libmicrohttpd";
    homepage = "https://github.com/hmelder";
    license = licenses.mit;
    maintainers = with maintainers; [ hmelder ];
    platforms = platforms.unix;
  };
}
