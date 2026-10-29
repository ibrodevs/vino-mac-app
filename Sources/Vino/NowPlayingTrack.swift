import Foundation

struct NowPlayingTrack: Equatable {
    var title: String
    var artist: String
    var album: String
    var artworkData: Data?
    var duration: TimeInterval
    var elapsed: TimeInterval
    var playbackRate: Double
    var updatedAt: Date

    var isPlaying: Bool {
        playbackRate > 0.001
    }

    var hasTrack: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func elapsedTime(at date: Date) -> TimeInterval {
        let liveElapsed = elapsed + (isPlaying ? max(0, date.timeIntervalSince(updatedAt)) * playbackRate : 0)
        guard duration > 0 else { return max(0, liveElapsed) }
        return min(max(0, liveElapsed), duration)
    }

    static let idle = NowPlayingTrack(
        title: "",
        artist: "",
        album: "",
        artworkData: nil,
        duration: 0,
        elapsed: 0,
        playbackRate: 0,
        updatedAt: .now
    )
}
