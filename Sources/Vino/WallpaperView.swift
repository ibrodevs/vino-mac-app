import AppKit
import SwiftUI

struct WallpaperView: View {
    @ObservedObject var nowPlaying: NowPlayingService

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                background

                HStack(spacing: max(40, proxy.size.width * 0.055)) {
                    VinylStage(track: nowPlaying.track)
                        .frame(
                            width: min(proxy.size.width * 0.48, 700),
                            height: min(proxy.size.height * 0.76, 700)
                        )

                    TrackPanel(track: nowPlaying.track, connectionState: nowPlaying.connectionState)
                        .frame(maxWidth: 520, alignment: .leading)
                }
                .padding(.horizontal, max(52, proxy.size.width * 0.07))
                .padding(.vertical, 60)
            }
        }
        .ignoresSafeArea()
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.055, green: 0.05, blue: 0.07),
                    Color(red: 0.015, green: 0.016, blue: 0.022)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color.white.opacity(0.08), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 900
            )

            if let data = nowPlaying.track.artworkData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 110)
                    .opacity(0.16)
                    .scaleEffect(1.15)
            }
        }
        .clipped()
    }
}

private struct VinylStage: View {
    let track: NowPlayingTrack

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.08, style: .continuous)
                    .fill(.white.opacity(0.035))
                    .overlay {
                        RoundedRectangle(cornerRadius: side * 0.08, style: .continuous)
                            .stroke(.white.opacity(0.09), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.5), radius: 40, y: 24)

                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    let elapsed = track.elapsedTime(at: timeline.date)
                    let angle = Angle.degrees(elapsed * 198.0) // 33 rpm ≈ 198°/s

                    ZStack {
                        VinylDisc(track: track)
                            .rotationEffect(angle)
                            .frame(width: side * 0.69, height: side * 0.69)
                            .offset(x: -side * 0.08)

                        Tonearm(isPlaying: track.isPlaying)
                            .frame(width: side * 0.34, height: side * 0.72)
                            .offset(x: side * 0.28, y: -side * 0.02)
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct VinylDisc: View {
    let track: NowPlayingTrack

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .fill(Color(red: 0.022, green: 0.024, blue: 0.03))
                    .shadow(color: .black.opacity(0.75), radius: side * 0.07, y: side * 0.035)

                ForEach(0..<18, id: \.self) { index in
                    Circle()
                        .stroke(.white.opacity(index.isMultiple(of: 3) ? 0.055 : 0.025), lineWidth: 0.7)
                        .padding(side * (0.025 + CGFloat(index) * 0.011))
                }

                Circle()
                    .fill(.white.opacity(0.04))
                    .frame(width: side * 0.48, height: side * 0.48)

                artwork(side: side)

                Circle()
                    .fill(.black)
                    .frame(width: side * 0.028, height: side * 0.028)
                    .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 1))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func artwork(side: CGFloat) -> some View {
        if let data = track.artworkData, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: side * 0.39, height: side * 0.39)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.14), .white.opacity(0.035)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: side * 0.39, height: side * 0.39)
                .overlay {
                    Image(systemName: "waveform")
                        .font(.system(size: side * 0.095, weight: .light))
                        .foregroundStyle(.white.opacity(0.62))
                }
        }
    }
}

private struct Tonearm: View {
    let isPlaying: Bool

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack(alignment: .top) {
                Circle()
                    .fill(.black.opacity(0.78))
                    .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
                    .frame(width: width * 0.42, height: width * 0.42)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.72), .white.opacity(0.22)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width * 0.095, height: height * 0.67)
                    .overlay(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.black.opacity(0.9))
                            .frame(width: width * 0.18, height: height * 0.08)
                            .offset(y: height * 0.035)
                    }
                    .offset(y: width * 0.15)
                    .rotationEffect(.degrees(isPlaying ? 18 : 7), anchor: .top)
                    .animation(.easeInOut(duration: 0.8), value: isPlaying)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

private struct TrackPanel: View {
    let track: NowPlayingTrack
    let connectionState: NowPlayingService.ConnectionState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("VINO  /  NOW PLAYING")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(2.2)
                .foregroundStyle(.white.opacity(0.46))

            if track.hasTrack {
                Text(track.title)
                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)

                Text(track.artist.isEmpty ? "Unknown artist" : track.artist)
                    .font(.system(size: 23, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(1)

                if !track.album.isEmpty {
                    Text(track.album)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                }

                TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
                    ProgressView(
                        value: track.duration > 0 ? track.elapsedTime(at: timeline.date) : 0,
                        total: max(track.duration, 1)
                    )
                    .progressViewStyle(.linear)
                    .tint(.white.opacity(0.8))
                }
                .frame(maxWidth: 380)
            } else {
                Text("Play something\nin Yandex Music")
                    .font(.system(size: 42, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineSpacing(3)

                Text("Vino reads the macOS system Now Playing session through an Apple-signed system process. Start a track in the Yandex Music desktop app and it should appear here automatically.")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineSpacing(5)
                    .frame(maxWidth: 450, alignment: .leading)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(connectionState.isConnected ? Color.green.opacity(0.85) : Color.orange.opacity(0.85))
                    .frame(width: 7, height: 7)
                Text(connectionState.label)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.36))
            }
            .padding(.top, 8)
        }
    }
}
