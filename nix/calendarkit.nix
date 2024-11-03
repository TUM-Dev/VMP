{ libical, gnustep, lib, meson, ninja, clang, pkg-config, fetchpatch }:

gnustep.stdenv.mkDerivation rec {
  pname = "calendarkit";
  version = "0.2.0";

  src = ../Libraries/CalendarKit;

  nativeBuildInputs = [ gnustep.make meson ninja clang pkg-config ];
  buildInputs = [ gnustep.base libical ];

  meta = with lib; {
    description = "A small Objective-C wrapper around libical";
    homepage = "https://github.com/hmelder";
    license = licenses.mit;
    maintainers = with maintainers; [ hmelder ];
    platforms = platforms.unix;
  };
}
