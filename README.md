# Vino

Vino is a native macOS **live music wallpaper**. It sits at desktop-window level (behind Finder icons), watches the system Now Playing session, and renders the current track as an animated vinyl scene.

The first MVP is intentionally focused on **Yandex Music for macOS** while keeping the media layer generic enough for other apps that publish to macOS Now Playing.

## Current MVP

- Native Swift + SwiftUI/AppKit, no Electron.
- One borderless wallpaper window per display.
- Wallpaper stays behind desktop icons and ignores mouse events.
- Warm photographic listening room with walnut table, amber glass lamp and vintage turntable.
- Current artwork on the upright sleeve and continuously rotating vinyl label; previous artwork on the sleeve stack.
- Artwork decoded only when it changes; missing artwork on an intermediate poll retains the same song's image.
- Independent 33 rpm animation clock, paused with playback, with no reset at track boundaries.
- Bounded Now Playing queries with timeout and automatic polling recovery, including large artwork payloads.
- Reads current track metadata and real artwork through a bundled read-only bridge hosted by Apple-signed `/usr/bin/perl`; JXA remains a metadata fallback.
- Menu bar controls to enable/disable the wallpaper and refresh metadata.
- No Yandex login, password, token, or unofficial Yandex API is required.

## Run it

Requirements: macOS 13+ and Xcode Command Line Tools.

```bash
git clone https://github.com/ibrodevs/vino-mac-app.git
cd vino-mac-app
git switch feat/live-wallpaper-mvp
./Scripts/run.sh
```

Or build only:

```bash
./Scripts/build-app.sh
open dist/Vino.app
```

Then open the **Yandex Music desktop app**, start a track, and return to the desktop. Vino polls the system session once per second and should update automatically.

## How track artwork is read

The bundled Objective-C media reader requests the active system session through MediaRemote, including the actual artwork bytes. A tiny Perl loader runs it inside Apple's system interpreter; Vino does not search catalogs or guess artwork from song names. No player credentials or internet request is required.

`Scripts/build-media-reader.sh` builds the bridge locally with clang. Both the development launcher and packaged app use it. `JXANowPlayingReader.swift` manages the bounded child process and falls back to JXA metadata when the bridge is missing. JXA's MRNowPlayingRequest path does not provide artwork on this Mac, which is why the bridge is necessary. The transport approach is informed by [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter); attribution is in Resources/MediaReader/NOTICE.md and included in the app.

MediaRemote is private API, isolated behind the reader. A player still needs to publish cover art to its system media session.

## Project layout

```text
Sources/Vino/
  VinoApp.swift             app + menu bar entry point
  AppModel.swift            app lifecycle/state
  WallpaperController.swift desktop-level windows
  WallpaperView.swift       live vinyl wallpaper UI
  NowPlayingService.swift   observable media state
  JXANowPlayingReader.swift macOS system Now Playing reader
  NowPlayingTrack.swift     track model
  MenuBarView.swift         controls/settings
Resources/
  Info.plist
Scripts/
  build-app.sh
  run.sh
```

## Next milestones

1. Verify Yandex Music metadata + artwork on the target Mac.
2. Add play/pause/next/previous system media commands.
3. Extend live artwork checks to additional music players.
4. Derive scene lighting from album-art colors.
5. Add themes, launch-at-login, and power-aware rendering.

## Listening-room scene

The wallpaper follows the supplied room screenshot. The cream and espresso placeholder sleeve uses the supporting DESIGN.md palette. No imitation menu bar or Dock is drawn. The room is bundled locally and works offline; see Resources/SCENE.md for the asset prompt.

Vino is a visual companion, not an audio player. Enable playlist/track repeat in Yandex Music for endless audio playback. The vinyl animation continues independently of song duration while macOS reports playback. Actual artwork depends on the music app publishing it through Now Playing.

## Validation

Run `./Scripts/check.sh` for perspective alignment, large-artwork transport, timeout recovery and a rendered room preview at `dist/preview.png`. Run `./Scripts/build-app.sh` to package the app and its local scene asset.

Run `./Scripts/check.sh --live` with a track open in the music player to verify actual artwork end to end and write `dist/live-preview.png`. Default checks also verify track changes, delayed covers and retention during incomplete metadata updates.
