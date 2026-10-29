import Foundation
import SwiftUI

func XCTAssertEqual<T: Equatable>(_ actual: T, _ expected: T) { precondition(actual == expected) }
func XCTAssertEqual(_ actual: CGFloat, _ expected: CGFloat, accuracy: CGFloat) { precondition(abs(actual - expected) <= accuracy) }
func XCTUnwrap<T>(_ value: T?) throws -> T { guard let value else { throw NSError(domain: "VinoChecks", code: 1) }; return value }
func XCTAssertNil<T>(_ value: T?) { precondition(value == nil) }

private final class LiveResult: @unchecked Sendable {
    var snapshot: JXANowPlayingReader.Snapshot?
}

@main struct VinoChecks {
    @MainActor static func main() throws {
        let checks = VinoChecks()
        checks.testArtworkCornersMatchPhotographedSleeve()
        checks.testLargeArtworkDoesNotBlockPolling()
        checks.testHungQueryTimesOutAndNextPollRecovers()
        try checks.testArtworkUpdatesWithTrack()
        try checks.testRenderListeningRoom()
        if CommandLine.arguments.contains("--live") { try checks.testLiveArtwork() }
        print("PASS: perspective corners, 300 KB artwork, timeout recovery, scene render")
    }
    func testArtworkCornersMatchPhotographedSleeve() {
        let corners = [CGPoint(x: 83, y: 319), CGPoint(x: 440, y: 309),
                       CGPoint(x: 470, y: 620), CGPoint(x: 104, y: 650)]
        let matrix = SleeveProjection.transform(side: 400, corners: corners)
        for (point, expected) in zip([CGPoint.zero, CGPoint(x: 400, y: 0),
                                      CGPoint(x: 400, y: 400), CGPoint(x: 0, y: 400)], corners) {
            let divisor = matrix.m13 * point.x + matrix.m23 * point.y + matrix.m33
            XCTAssertEqual((matrix.m11 * point.x + matrix.m21 * point.y + matrix.m31) / divisor, expected.x, accuracy: 0.001)
            XCTAssertEqual((matrix.m12 * point.x + matrix.m22 * point.y + matrix.m32) / divisor, expected.y, accuracy: 0.001)
        }
    }

    func testLargeArtworkDoesNotBlockPolling() {
        let received = DispatchSemaphore(value: 0)
        let script = #"JSON.stringify({title:'Fixture',artist:'Artist',album:'Album',duration:120,elapsed:1,playbackRate:1,artworkBase64:'A'.repeat(300000),sourceApp:'Test'})"#
        let reader = JXANowPlayingReader(script: script) { snapshot in
            XCTAssertEqual(snapshot?.artworkBase64?.count, 300000)
            received.signal()
        }
        reader.refresh()
        precondition(received.wait(timeout: .now() + 6) == .success)
    }

    func testHungQueryTimesOutAndNextPollRecovers() {
        let received = DispatchSemaphore(value: 0)
        let reader = JXANowPlayingReader(script: "delay(10); '{}'", timeout: 0.2) { snapshot in
            XCTAssertNil(snapshot)
            received.signal()
        }
        reader.refresh()
        reader.refresh()
        precondition(received.wait(timeout: .now() + 4) == .success)
        precondition(received.wait(timeout: .now() + 4) == .success)
    }

    @MainActor func testArtworkUpdatesWithTrack() throws {
        let service = NowPlayingService()
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        bitmap.setColor(.red, atX: 0, y: 0)
        let first = try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).base64EncodedString()
        bitmap.setColor(.blue, atX: 0, y: 0)
        let second = try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).base64EncodedString()
        func snapshot(_ title: String, _ image: String?) -> JXANowPlayingReader.Snapshot {
            .init(title: title, artist: "Artist", album: "Album", duration: 120,
                  elapsed: 10, playbackRate: 1, artworkBase64: image, sourceApp: "Test")
        }
        service.apply(snapshot("First", first))
        let firstImage = try XCTUnwrap(service.artwork)
        service.apply(snapshot("First", nil))
        precondition(service.artwork === firstImage, "An intermediate poll must retain artwork")
        service.apply(snapshot("Second", nil))
        precondition(service.artwork == nil, "Never display a previous track as the current cover")
        precondition(service.previousArtwork === firstImage)
        service.apply(snapshot("Second", second))
        precondition(service.track.artworkData == Data(base64Encoded: second))
        precondition(service.artwork != nil)
        service.apply(snapshot("Second", "invalid image"))
        precondition(service.track.artworkData == Data(base64Encoded: second))
        print("PASS: artwork changes with song, delayed images, missing/invalid artwork")
    }

    @MainActor func testLiveArtwork() throws {
        let finished = DispatchSemaphore(value: 0)
        // Callback and semaphore run off the main queue, as in the production reader.
        let result = LiveResult()
        let reader = JXANowPlayingReader { snapshot in
            result.snapshot = snapshot
            finished.signal()
        }
        reader.refresh()
        precondition(finished.wait(timeout: .now() + 6) == .success)
        let snapshot = try XCTUnwrap(result.snapshot)
        let data = try XCTUnwrap(snapshot.artworkBase64.flatMap { Data(base64Encoded: $0) })
        let service = NowPlayingService()
        service.apply(snapshot)
        let artwork = try XCTUnwrap(service.artwork)
        let renderer = ImageRenderer(content: ListeningRoom(artwork: artwork, previousArtwork: nil, isPlaying: false))
        renderer.proposedSize = ProposedViewSize(width: 1586, height: 992)
        let image = try XCTUnwrap(renderer.nsImage)
        let png = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(image.tiffRepresentation))?.representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: "dist/live-preview.png"))
        print("PASS: live system artwork from \(snapshot.sourceApp): \(snapshot.title) (\(data.count) bytes)")
    }

    @MainActor func testRenderListeningRoom() throws {
        // Distinct test covers reveal projection, cropping and record-label alignment.
        let cover = NSImage(size: NSSize(width: 500, height: 500), flipped: false) { rect in
            NSColor(calibratedRed: 0.32, green: 0.43, blue: 0.46, alpha: 1).setFill()
            rect.fill()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont(name: "Georgia", size: 78)!,
                .foregroundColor: NSColor(calibratedRed: 1, green: 0.97, blue: 0.9, alpha: 1)
            ]
            ("Blue\nSessions" as NSString).draw(at: NSPoint(x: 45, y: 260), withAttributes: attributes)
            NSColor(calibratedRed: 0.82, green: 0.55, blue: 0.32, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 245, y: 50, width: 190, height: 190)).fill()
            return true
        }
        let renderer = ImageRenderer(content: ListeningRoom(artwork: cover, previousArtwork: nil, isPlaying: false))
        renderer.proposedSize = ProposedViewSize(width: 1586, height: 992)
        let image = try XCTUnwrap(renderer.nsImage)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(image.tiffRepresentation)))
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let destination = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("dist/preview.png")
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try png.write(to: destination)
        XCTAssertEqual(image.size.width, 1586)
        XCTAssertEqual(image.size.height, 992)
    }
}
