import SwiftUI

/// Samples inside the chosen range, grouped into runs (a new run starts after a sampling pause, e.g. sleep),
/// and thinned to at most `limit` points so an hour of 2-second samples stays cheap to draw.
/// Each point's `id` is its time (or its clock-aligned bucket when thinned), so thinned points don't jump between
/// buckets as new samples arrive. Charts aren't animated: Swift Charts re-lays out every mark per frame (~35% CPU).
struct VisiblePoints {
    typealias Point = (index: Int, run: Int, id: Double)
    let indices: [Point]

    init(times: Ring<Date>, lead: Ring<Float>?, range: TimeInterval, limit: Int = 240) {
        guard let end = times.last else {
            indices = []
            return
        }
        let start = end.addingTimeInterval(-range)
        var all: [Point] = []
        var run = 0
        for i in 0..<times.count where times[i] >= start {
            if let last = all.last, times[i].timeIntervalSince(times[last.index]) > 10 { run += 1 }
            all.append((i, run, times[i].timeIntervalSince1970))
        }
        guard all.count > limit, let lead else {
            indices = all
            return
        }
        // Fixed time buckets (a multiple of the 2 s sample interval), keeping each bucket's peak so spikes stay
        // visible. Buckets are aligned to the clock, so they don't shift between updates.
        let bucket = max(2, (range / Double(limit) / 2).rounded(.up) * 2)
        var thinned: [Point] = []
        for p in all {
            let key = (p.id / bucket).rounded(.down) * bucket
            if let last = thinned.last, last.id == key, last.run == p.run {
                if lead[p.index] > lead[last.index] { thinned[thinned.count - 1] = (p.index, p.run, key) }
            } else {
                thinned.append((p.index, p.run, key))
            }
        }
        indices = thinned
    }

    /// Min, average and max of a series over these points.
    func stats(_ values: Ring<Float>) -> (min: Double, avg: Double, max: Double)? {
        let v = indices.compactMap { $0.index < values.count ? Double(values[$0.index]) : nil }
        guard let lo = v.min(), let hi = v.max() else { return nil }
        return (lo, v.reduce(0, +) / Double(v.count), hi)
    }
}
