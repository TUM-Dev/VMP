{ libmicrohttpd, gnustep, lib, fetchFromGitHub, meson, ninja, clang, pkg-config, fetchpatch }:

gnustep.stdenv.mkDerivation rec {
  pname = "microhttpkit";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "hmelder";
    repo = "MicroHTTPKit";
    rev = "v0.2.0-rc";
    hash = "sha256-Y2OcGydAoS72D9EFLn8pAELU9vDcf+BgqbRzK4J9J9A=";
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
