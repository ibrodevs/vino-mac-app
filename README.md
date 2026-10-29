# Vino

Vino is a native macOS **live music wallpaper**. It sits at desktop-window level (behind Finder icons), watches the system Now Playing session, and renders the current track as an animated vinyl scene.

The first MVP is intentionally focused on **Yandex Music for macOS** while keeping the media layer generic enough for other apps that publish to macOS Now Playing.

## Current MVP

- Native Swift + SwiftUI/AppKit, no Electron.
- One borderless wallpaper window per display.
- Wallpaper stays behind desktop icons and ignores mouse events.
- Dynamic vinyl scene with spinning record, tonearm, blurred artwork, track title/artist/album, and progress.
- Polls the macOS system Now Playing session through Apple-signed `/usr/bin/osascript` + JXA.
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

## Why the reader uses `osascript`

Apple tightened direct third-party access to the private MediaRemote framework starting with macOS 15.4. Vino therefore executes a very small JXA query inside Apple's own `/usr/bin/osascript` process and reads `MRNowPlayingRequest` from there. This keeps the app credential-free and works on newer macOS versions where calling MediaRemote directly from Vino may return an empty result.

MediaRemote is still private API and Apple can change it. The implementation is isolated in `JXANowPlayingReader.swift` so we can replace the transport without touching the wallpaper UI.

Artwork availability depends on what the active player publishes into the system session. The first hardware test should verify what the current Yandex Music macOS build exposes.

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
3. Add a fallback artwork provider if Yandex does not publish artwork bytes.
4. Derive scene lighting from album-art colors.
5. Add themes, launch-at-login, and power-aware rendering.
