import AppKit
import SwiftUI

/// All live surfaces share the photograph's coordinate system, including on
/// ultrawide displays: crop the complete composition, never stretch individual props.
struct WallpaperView: View {
    @ObservedObject var nowPlaying: NowPlayingService

    var body: some View {
        GeometryReader { proxy in
            let scale = max(proxy.size.width / 1586, proxy.size.height / 992)
            ListeningRoom(artwork: nowPlaying.artwork,
                          previousArtwork: nowPlaying.previousArtwork,
                          isPlaying: nowPlaying.track.isPlaying)
                .frame(width: 1586, height: 992)
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipped()
        .ignoresSafeArea()
    }
}

struct ListeningRoom: View {
    let artwork: NSImage?
    let previousArtwork: NSImage?
    let isPlaying: Bool
    private static let roomImage: NSImage = {
        guard let url = Bundle.main.url(forResource: "listening-room", withExtension: "png")
                ?? Bundle.module.url(forResource: "listening-room", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            preconditionFailure("The bundled listening-room photograph is missing")
        }
        return image
    }()

    @State private var accumulatedRotation: TimeInterval = 0
    @State private var rotationStartedAt = Date.now

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(nsImage: Self.roomImage)
                .resizable()
                .frame(width: 1586, height: 992)

            sleeve(artwork, corners: [CGPoint(x: 83, y: 319), CGPoint(x: 440, y: 309),
                                      CGPoint(x: 470, y: 620), CGPoint(x: 104, y: 650)])
            sleeve(previousArtwork ?? artwork,
                   corners: [CGPoint(x: 1144, y: 590), CGPoint(x: 1479, y: 590),
                             CGPoint(x: 1563, y: 703), CGPoint(x: 1195, y: 708)])

            // Rotate in the plane of the record BEFORE foreshortening it.
            // This clock is independent of both the song duration and metadata polls.
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isPlaying)) { timeline in
                let elapsed = accumulatedRotation + (isPlaying ? max(0, timeline.date.timeIntervalSince(rotationStartedAt)) : 0)
                AlbumSurface(image: artwork)
                    .frame(width: 150, height: 150)
                    .clipShape(Circle())
                    .rotationEffect(.degrees((elapsed * 198).truncatingRemainder(dividingBy: 360)))
                    .scaleEffect(x: 1, y: 0.285)
                    .overlay {
                        Capsule()
                            .fill(LinearGradient(colors: [Color(red: 0.9, green: 0.76, blue: 0.52), .brown], startPoint: .leading, endPoint: .trailing))
                            .frame(width: 5, height: 12)
                            .offset(y: -5)
                    }
                    .position(x: 738, y: 568)
            }
            .frame(width: 1586, height: 992)
        }
        .frame(width: 1586, height: 992)
        .onChange(of: isPlaying) { playing in
            let now = Date.now
            if !playing { accumulatedRotation += max(0, now.timeIntervalSince(rotationStartedAt)) }
            rotationStartedAt = now
        }
    }

    private func sleeve(_ image: NSImage?, corners: [CGPoint]) -> some View {
        AlbumSurface(image: image)
            .frame(width: 400, height: 400)
            .overlay(Color(red: 0.36, green: 0.16, blue: 0.045).opacity(0.16).blendMode(.multiply))
            .overlay(Rectangle().stroke(Color(red: 1, green: 0.85, blue: 0.61).opacity(0.25), lineWidth: 1))
            .projectionEffect(SleeveProjection.transform(side: 400, corners: corners))
    }
}

private struct AlbumSurface: View {
    let image: NSImage?

    var body: some View {
        GeometryReader { proxy in
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            } else {
                ZStack {
                    Color(red: 0.965, green: 0.929, blue: 0.89)
                    VStack(spacing: 14) {
                        Image(systemName: "waveform")
                            .font(.system(size: proxy.size.width * 0.16, weight: .ultraLight))
                        Text("vino")
                            .font(.system(size: proxy.size.width * 0.13, weight: .medium, design: .serif))
                            .tracking(-2)
                        Text("SIDE A · 33⅓ RPM")
                            .font(.system(size: proxy.size.width * 0.028, design: .monospaced))
                            .tracking(2)
                    }
                    .foregroundStyle(Color(red: 0.322, green: 0.173, blue: 0.145))
                }
            }
        }
    }
}

/// Homography maps the square artwork to the four corners of a photographed sleeve.
/// Affine skew alone would misalign the bottom corners of the leaning cover.
enum SleeveProjection {
    static func transform(side: CGFloat, corners p: [CGPoint]) -> ProjectionTransform {
        let dx1 = p[1].x - p[2].x, dx2 = p[3].x - p[2].x
        let dy1 = p[1].y - p[2].y, dy2 = p[3].y - p[2].y
        let sx = p[0].x - p[1].x + p[2].x - p[3].x
        let sy = p[0].y - p[1].y + p[2].y - p[3].y
        let denominator = dx1 * dy2 - dx2 * dy1
        let g = (sx * dy2 - dx2 * sy) / denominator
        let h = (dx1 * sy - sx * dy1) / denominator
        var result = ProjectionTransform()
        result.m11 = (p[1].x - p[0].x + g * p[1].x) / side
        result.m12 = (p[1].y - p[0].y + g * p[1].y) / side
        result.m13 = g / side
        result.m21 = (p[3].x - p[0].x + h * p[3].x) / side
        result.m22 = (p[3].y - p[0].y + h * p[3].y) / side
        result.m23 = h / side
        result.m31 = p[0].x
        result.m32 = p[0].y
        return result
    }
}
