import Foundation

/// A place on the plaza floor.
public struct Spot: Equatable, Sendable {
    public var x: Double
    public var z: Double

    public init(x: Double, z: Double) {
        self.x = x
        self.z = z
    }
}

/// How people share the floor: everyone is a solid circle, nobody overlaps, and walkers go round each other.
public enum Crowd {
    /// The direction (length 1) to walk from one spot towards another, bent to go round the people in the way.
    /// Zero when already there.
    public static func steer(from: Spot, to: Spot, around others: [Spot], radius: Double) -> Spot {
        let dx = to.x - from.x, dz = to.z - from.z
        let distance = hypot(dx, dz)
        guard distance > 1e-9 else { return Spot(x: 0, z: 0) }
        let ahead = Spot(x: dx / distance, z: dz / distance)
        // Left of the way ahead, so that a positive `side` below means "to the left".
        let left = Spot(x: -ahead.z, z: ahead.x)

        let reach = radius * 3.4          // how far ahead someone starts to matter
        let lane = radius * 2.3           // how far to the side they still block the way
        var turn = 0.0
        for other in others {
            let ox = other.x - from.x, oz = other.z - from.z
            let gap = hypot(ox, oz)
            guard gap > 1e-9, gap < reach else { continue }
            let forward = ahead.x * ox + ahead.z * oz
            guard forward > 0 else { continue }
            let side = left.x * ox + left.z * oz
            guard abs(side) < lane else { continue }
            // Turn away from the side they are on. Someone dead ahead is passed on the right, so two
            // people walking straight at each other both keep right and miss.
            let weight = (1 - gap / reach) * (1 - abs(side) / lane)
            turn += (side >= 0 ? -1 : 1) * weight * 2.2
        }
        turn = max(-1.7, min(1.7, turn))
        let x = ahead.x + left.x * turn, z = ahead.z + left.z * turn
        let length = hypot(x, z)
        return Spot(x: x / length, z: z / length)
    }

    /// Pushes apart any two people standing closer than two radii. Fixed people do not move, so the
    /// other gives way entirely; two fixed people are left as they are.
    public static func separate(_ spots: inout [Spot], radius: Double, fixed: [Bool]) {
        let minimum = radius * 2
        for _ in 0..<4 {
            for i in spots.indices {
                for j in spots.indices where j > i {
                    if fixed[i], fixed[j] { continue }
                    var nx = spots[j].x - spots[i].x, nz = spots[j].z - spots[i].z
                    let gap = hypot(nx, nz)
                    guard gap < minimum else { continue }
                    if gap < 1e-9 {
                        // Exactly on top of each other: pick a direction that depends only on who they are.
                        let angle = Double(i) * 2.399 + Double(j) * 0.7
                        nx = cos(angle)
                        nz = sin(angle)
                    } else {
                        nx /= gap
                        nz /= gap
                    }
                    let overlap = minimum - gap
                    if fixed[i] {
                        spots[j].x += nx * overlap
                        spots[j].z += nz * overlap
                    } else if fixed[j] {
                        spots[i].x -= nx * overlap
                        spots[i].z -= nz * overlap
                    } else {
                        spots[i].x -= nx * overlap / 2
                        spots[i].z -= nz * overlap / 2
                        spots[j].x += nx * overlap / 2
                        spots[j].z += nz * overlap / 2
                    }
                }
            }
        }
    }
}
