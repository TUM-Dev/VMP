#ifndef CALENDARS_H
#define CALENDARS_H

static const char *const EMPTY_CALENDAR =
    "BEGIN:VCALENDAR\r\nPRODID:Test Calendar\r\nVERSION:2.0\r\nEND:VCALENDAR";

static const char *const INCOMPLETE_CALENDAR = "BEGIN:VCALENDAR\r\n";

static const char *const SIMPLE_CALENDAR = "BEGIN:VCALENDAR\r\n\
PRODID:Test Calendar\r\n\
VERSION:2.0\r\n\
BEGIN:VTIMEZONE\r\n\
TZID:W. Europe Standard Time\r\n\
BEGIN:STANDARD\r\n\
DTSTART:16010101T030000\r\n\
TZOFFSETFROM:+0200\r\n\
TZOFFSETTO:+0100\r\n\
RRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=-1SU;BYMONTH=10\r\n\
END:STANDARD\r\n\
BEGIN:DAYLIGHT\r\n\
DTSTART:16010101T020000\r\n\
TZOFFSETFROM:+0100\r\n\
TZOFFSETTO:+0200\r\n\
RRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=-1SU;BYMONTH=3\r\n\
END:DAYLIGHT\r\n\
END:VTIMEZONE\r\n\
BEGIN:VEVENT\r\n\
UID:sdfg9438wpwoskegt47817\r\n\
DTSTART;TZID=W. Europe Standard Time:20241015T173000\r\n\
DTEND;TZID=W. Europe Standard Time:20241015T190000\r\n\
DTSTAMP:20240903T102623\r\n\
LOCATION:FMI_HS1\r\n\
SUMMARY:Enhance your Calm IN0420\r\n\
DESCRIPTION:47817\r\n\
END:VEVENT\r\n\
END:VCALENDAR";

static const char *const SIMPLE_TIME_CALENDAR = "BEGIN:VCALENDAR\r\n\
PRODID:Test Calendar\r\n\
VERSION:2.0\r\n\
BEGIN:VTIMEZONE\r\n\
TZID:W. Europe Standard Time\r\n\
BEGIN:STANDARD\r\n\
DTSTART:16010101T030000\r\n\
TZOFFSETFROM:+0200\r\n\
TZOFFSETTO:+0100\r\n\
RRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=-1SU;BYMONTH=10\r\n\
END:STANDARD\r\n\
BEGIN:DAYLIGHT\r\n\
DTSTART:16010101T020000\r\n\
TZOFFSETFROM:+0100\r\n\
TZOFFSETTO:+0200\r\n\
RRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=-1SU;BYMONTH=3\r\n\
END:DAYLIGHT\r\n\
END:VTIMEZONE\r\n\
BEGIN:VEVENT\r\n\
UID:sdfg9438wpwoskegt47817\r\n\
DTSTART;TZID=W. Europe Standard Time:20241015T173000\r\n\
DTEND;TZID=W. Europe Standard Time:20241015T190000\r\n\
DTSTAMP:20240903T102623\r\n\
LOCATION:FMI_HS1\r\n\
SUMMARY:In daylight\r\n\
DESCRIPTION:47817\r\n\
END:VEVENT\r\n\
BEGIN:VEVENT\r\n\
UID:sdfg9438wpwoskegt47818\r\n\
DTSTART;TZID=W. Europe Standard Time:20241115T173000\r\n\
DTEND;TZID=W. Europe Standard Time:20241115T190000\r\n\
DTSTAMP:20240903T102623\r\n\
LOCATION:FMI_HS1\r\n\
SUMMARY:Not in daylight\r\n\
DESCRIPTION:47817\r\n\
END:VEVENT\r\n\
END:VCALENDAR";

// Last two events are identical
static const char *const SIMPLE_EQUALITY_CALENDAR = "BEGIN:VCALENDAR\r\n\
PRODID:Test Calendar\r\n\
VERSION:2.0\r\n\
BEGIN:VTIMEZONE\r\n\
TZID:W. Europe Standard Time\r\n\
BEGIN:STANDARD\r\n\
DTSTART:16010101T030000\r\n\
TZOFFSETFROM:+0200\r\n\
TZOFFSETTO:+0100\r\n\
RRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=-1SU;BYMONTH=10\r\n\
END:STANDARD\r\n\
BEGIN:DAYLIGHT\r\n\
DTSTART:16010101T020000\r\n\
TZOFFSETFROM:+0100\r\n\
TZOFFSETTO:+0200\r\n\
RRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=-1SU;BYMONTH=3\r\n\
END:DAYLIGHT\r\n\
END:VTIMEZONE\r\n\
BEGIN:VEVENT\r\n\
UID:sdfg9438wpwoskegt47817\r\n\
DTSTART;TZID=W. Europe Standard Time:20241015T173000\r\n\
DTEND;TZID=W. Europe Standard Time:20241015T190000\r\n\
DTSTAMP:20240903T102623\r\n\
LOCATION:FMI_HS1\r\n\
SUMMARY:In daylight\r\n\
DESCRIPTION:47817\r\n\
END:VEVENT\r\n\
BEGIN:VEVENT\r\n\
UID:sdfg9438wpwoskegt47818\r\n\
DTSTART;TZID=W. Europe Standard Time:20241115T173000\r\n\
DTEND;TZID=W. Europe Standard Time:20241115T190000\r\n\
DTSTAMP:20240903T102623\r\n\
LOCATION:FMI_HS1\r\n\
SUMMARY:Not in daylight\r\n\
DESCRIPTION:47817\r\n\
END:VEVENT\r\n\
BEGIN:VEVENT\r\n\
UID:sdfg9438wpwoskegt47818\r\n\
DTSTART;TZID=W. Europe Standard Time:20241115T173000\r\n\
DTEND;TZID=W. Europe Standard Time:20241115T190000\r\n\
DTSTAMP:20240903T102623\r\n\
LOCATION:FMI_HS1\r\n\
SUMMARY:Not in daylight\r\n\
DESCRIPTION:47817\r\n\
END:VEVENT\r\n\
END:VCALENDAR";

#endif // CALENDARS_H
