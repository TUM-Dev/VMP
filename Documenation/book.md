---
title: "The Virtual Streaming Processor (VMP)"
author: [Hugo Melder]
date: "4th January 2024"
lang: en
book: true
toc: true

fontsize: 12pt
mainfont: EB Garamond
sansfont: Inter
monofont: "IBM Plex Mono"
...

# Chapter 1. Introduction

The importance of livestreaming university lectures and other related events has
surged due to multiple factors. First, there is the growing number of students
which builds pressure on building more and notably larger lecture halls. This is
not economically feasible in the long run. Additionally, growing portfolio, and
interdiciplnary courses also increases the likelyhood of overlapping lectures.
This was accelerated in part of the pandemic, which necessitated a way to attend
a lecture remotely.

Building a reliable system for streaming, processing, and
distributing multiple lectures at the same time is not trivial.

A good system should not introduce any complexity for the lecturer. This means
the system should transparently capture the presentation, camera, and audio
feeds, instead of requiring the lecturer to self-stream using software like OBS.

This requires some form of edge computing device in each lecture hall,
equipped with video and audio capturing capabilities, as well as the power to
blend and encode multiple feeds in real time. The resulting stream is then published
via RTSP, or as a raw network stream.

In theory, compositing—the combination of multiple video and/or audio feeds—can
also be transferred to a data center. However, this necessitates
hardware-accelerated video processing, typically performed using GPUs. Since
edge devices also need to encode the streams to minimize bandwidth, which in
turn requires hardware acceleration, there is usually capacity for additional
blending as well.

With these requirements, one often ends up relying on expensive television
equipment, which is not scalable across numerous lecture halls and seminar
rooms.

The VMP project aims to utilize commodity hardware to fulfill the aforementioned
requirements at a fraction of the cost of comparable commercial equipment.

## Chapter 2. Architecture 

### Chapter 2.1 Terminology

In this section, we define key terms to ensure consistency throughout this document:

#### GNUstep
GNUstep is an open-source cross-platform reimplementation of the Apple Cocoa
frameworks, including a modern Objective-C runtime, implementing a superset of
Objective-C 2.0, and Foundation Kit, which the effective standard library.

#### GStreamer
GStreamer is an open-source multimedia framework. It employs a pipeline-based
model, allowing the construction of various components (such as audio and video
playback, recording, streaming, and editing) into a comprehensive multimedia
workflow.

#### HDCP (High-bandwidth Digital Content Protection)
HDCP is a technology protect the capturing of protected content, namely movies
on a hardware level.

#### NixOS
A Linux distribution based on the functional nix package manager, which
allows for declarative configuration, package-level isolation, and reproducible builds.

#### Objective-C
Objective-C is an object-oriented programming language that adds Smalltalk-style
messaging to the C programming language. Technologies such as Key-Value-Observing (KVO),
and a rich standard library (namely Foundation) makes it a good choice for multimedia
applications.

#### Property List
Property list files are files that store serialized objects. We are using the XML
variant of property lists to store the configuration data of the VMP daemon, as well
as GStreamer pipeline profiles.

#### RTSP (Real Time Streaming Protocol)
RTSP is used to negotiate and control media sessions between endpoints, allowing
clients to request real-time video and audio feeds.

#### Video 4 Linux (V4L2)
Video 4 Linux (V4L2) is a Linux kernel video capture and output API which streamlines
interaction with various different capture cards.

#### Video Acceleration API (VA-API)
VA-API provides a standardized interface for accessing hardware-accelerated
video processing capabilities. It supports encoding, decoding, processing, and
filtering operations, making it hardware and vendor-agnostic.

### Chapter 2.2 Multimedia Pipelines

### Chapter 2.3 Channels

## Chapter 3. Deployment

## Chapter 4. Development