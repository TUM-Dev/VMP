{ gnustep, lib, fetchFromGitHub, meson, ninja, clang, pkg-config, fetchpatch }:

gnustep.stdenv.mkDerivation rec {
  pname = "xctest";
  version = "0.1.1";

  src = fetchFromGitHub {
    owner = "gnustep";
    repo = "tools-xctest";
    rev = "v0.1.1";
    hash = "sha256-aLZGStbMoa2NhL72ZYZXXZFx9IAWZ49n1acPch4r9Rk=";
  };

  nativeBuildInputs = [ gnustep.make meson ninja clang pkg-config ];
  buildInputs = [ gnustep.base ];
}
