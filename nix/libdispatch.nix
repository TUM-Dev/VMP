{ clangStdenv, lib, fetchFromGitHub, cmake, fetchpatch, writeText }:

clangStdenv.mkDerivation rec {
  pname = "libdispatch";
  version = "5.10.1";

  src = fetchFromGitHub {
    owner = "apple";
    repo = "swift-corelibs-libdispatch";
    rev = "swift-${version}-RELEASE";
    hash = "sha256-pta3wJj2LJ/lsYAWQpw0wSGLDMO41mN8Zbl78LUCaQo";
  };

  nativeBuildInputs = [ cmake ];
  cmakeFlags = [ "-DCMAKE_INSTALL_LIBDIR=lib" ];
    
  # Remove this once libdispatch includes a pkgconfig file
  pkgconfig = writeText "libdispatch.pc" ''
    prefix=@out@
    exec_prefix=@out@
    libdir=@out@/lib
    includedir=@out@/include

    Name: libdispatch
    Description: The libdispatch Project (Grand Central Dispatch) for concurrency on multicore hardware
    Version: ${version}
    Libs: -L@out@/lib -ldispatch
    Cflags: -I@out@/include
  '';

  postInstall = ''
    mkdir -p $out/lib/pkgconfig
    sed "s|@out@|$out|g" ${pkgconfig} > $out/lib/pkgconfig/libdispatch.pc
  '';

  meta = with lib; {
    description = "The libdispatch Project, (a.k.a. Grand Central Dispatch), for concurrency on multicore hardware";
    homepage = "http://swift.org/";
    license = licenses.asl20;
    maintainers = with maintainers; [ hmelder ];
    platforms = platforms.unix;
  };
}
