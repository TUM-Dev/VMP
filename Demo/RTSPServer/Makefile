PROGRAM_NAME:=rtsp-server
CC:=clang

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	  F_PATH:=/Library/Frameworks
		LIB_PATH:=/Library/Frameworks/GStreamer.framework/Versions/1.0/lib
		HEADER_PATH:=/Library/Frameworks/GStreamer.framework/Headers
    CCFLAGS:=-g -framework GStreamer -F $(F_PATH) -I $(HEADER_PATH) -L $(LIB_PATH)
else
    CCFLAGS:=-g `pkg-config --cflags --libs gstreamer-1.0`
endif

.PHONY: all clean
all: build

# main and tests
build:
	$(CC) $(CCFLAGS) -o $(PROGRAM_NAME) $(PROGRAM_NAME).c

clean:
	$(RM) $(PROGRAM_NAME)
