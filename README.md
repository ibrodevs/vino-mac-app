# Vino

Vino is a native macOS **live music wallpaper**. It sits at desktop-window level (behind Finder icons), watches the system Now Playing session, and renders the current track as an animated vinyl scene.

The first MVP is intentionally focused on **Yandex Music for macOS** while keeping the media layer generic enough for other apps that publish to macOS Now Playing.

## Current MVP

- Native Swift + SwiftUI/AppKit, no Electron.
- One borderless wallpaper window per display.
- Wallpaper stays behind desktop icons and ignores mouse events.
- Dynamic vinyl scene with spinning record, tonearm, blurred artwork, track title/artist/album, and progress.
- Runtime MediaRemote bridge for system Now Playing metadata.
- Menu bar controls to enable/disable the wallpaper and refresh metadata.
- No Yandex login, password, token, or unofficial Yandex API is required.

## Run it

Requirements: macOS 13+ and Xcode Command Line Tools.

```bash
git clone https://github.com/ibrodevs/vino-mac-app.git
cd vino-mac-app
./Scripts/run.sh
```

Or build only:

```bash
./Scripts/build-app.sh
open dist/Vino.app
```

Then open the **Yandex Music desktop app**, start a track, and return to the desktop. Vino should update from the system Now Playing session.

## Important compatibility note

The system-wide Now Playing reader currently uses Apple's private `MediaRemote` framework loaded dynamically at runtime. We do not link private headers and the app remains buildable with normal Swift tooling, but Apple can change or restrict this framework on any macOS release.

If the menu reports `Now Playing is unavailable`, the wallpaper itself is still working; the next milestone is to add a version-specific helper/fallback for affected macOS builds. That should be tested on the exact Mac/macOS version that will run Vino.

This approach is preferable for the MVP because it does not require Yandex account credentials and can work with any player that publishes a macOS Now Playing session.

## Project layout

```text
Sources/Vino/
  VinoApp.swift             app + menu bar entry point
  AppModel.swift            app lifecycle/state
  WallpaperController.swift desktop-level windows
  WallpaperView.swift       live vinyl wallpaper UI
  NowPlayingService.swift   observable media state
  MediaRemoteBridge.swift   macOS system Now Playing bridge
  NowPlayingTrack.swift     track model
  MenuBarView.swift         controls/settings
Resources/
  Info.plist
Scripts/
  build-app.sh
  run.sh
```

## Next milestones

1. Verify Yandex Music metadata on the target Mac.
2. Add play/pause/next/previous system media commands.
3. Add an optimized compatibility helper for macOS versions where direct MediaRemote reads are restricted.
4. Derive scene lighting from album-art colors.
5. Add themes, launch-at-login, and power-aware rendering.
