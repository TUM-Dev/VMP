{ libmicrohttpd, gnustep, lib, fetchFromGitHub, meson, ninja, clang, pkg-config, fetchpatch }:

gnustep.stdenv.mkDerivation rec {
  pname = "microhttpkit";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "hmelder";
    repo = "MicroHTTPKit";
    rev = "main";
    hash = "sha256-FuwRyX7mrSYw+an0WaO7hgOmN05dXpWhTVirKf9Ektc=";
  };

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
