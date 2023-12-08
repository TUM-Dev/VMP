{ clangStdenv, lib, fetchFromGitHub, cmake, fetchpatch }:

clangStdenv.mkDerivation rec {
  pname = "libdispatch";
  version = "5.9.1";

  src = fetchFromGitHub {
    owner = "apple";
    repo = "swift-corelibs-libdispatch";
    rev = "swift-${version}-RELEASE";
    hash = "sha256-TrZLw/3cPoUlMAeSUL78o/tuzczXLKc8sZw7brNFrKA=";
  };

  nativeBuildInputs = [ cmake ];
  cmakeFlags = [ "-DCMAKE_INSTALL_LIBDIR=lib" ];

  meta = with lib; {
    description = "The libdispatch Project, (a.k.a. Grand Central Dispatch), for concurrency on multicore hardware";
    homepage = "http://swift.org/";
    license = licenses.asl20;
    maintainers = with maintainers; [ hmelder ];
    platforms = platforms.unix;
  };
}
