# Webcam

A tiny floating, always-on-top webcam window for macOS — a vertical rectangle
with rounded corners showing your camera in real time.

## Build

```sh
./build.sh
```

(One Objective-C file, `webcam.m`. No Go/CGO needed — plain Cocoa + AVFoundation
is the fastest path on macOS.)

## Run

```sh
open Webcam.app
```

First launch: macOS asks for camera permission → allow it
(System Settings → Privacy & Security → Camera).

## Usage

- Drag the window edge to resize; drag the top bar to move it.
- `ESC` or `q` quits. `Cmd+Q` also works.
- Custom size: `./Webcam.app/Contents/MacOS/Webcam -w 340 -h 620`