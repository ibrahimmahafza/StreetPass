import Foundation

/// The plaza's camera as plain geometry: it hangs above the floor, tilts down, and unless it has
/// been turned looks towards negative z. The simulation uses it to place people by where they
/// appear on screen, and the 3D view builds its real camera from the same numbers so the two always agree.
///
/// Screen positions run 0...1: `u` left to right, `v` bottom to top.
public struct PlazaCamera: Equatable, Sendable {
    /// Width divided by height of the view.
    public let aspect: Double
    /// Height above the floor.
    public let height: Double
    /// Radians below horizontal.
    public let pitch: Double
    /// Vertical field of view in radians.
    public let fieldOfView: Double
    /// Where over the floor the camera hangs.
    public let x: Double
    public let z: Double
    /// Radians the camera has swung round the vertical. Positive turns the floor clockwise on screen.
    public let turn: Double

    public init(
        aspect: Double, height: Double = 27, pitch: Double = 40 * .pi / 180, fieldOfView: Double = 38 * .pi / 180,
        x: Double = 0, z: Double = 0, turn: Double = 0
    ) {
        self.aspect = aspect
        self.height = height
        self.pitch = pitch
        self.fieldOfView = fieldOfView
        self.x = x
        self.z = z
        self.turn = turn
    }

    /// The same camera with a narrower view, so everything appears `factor` times larger.
    public func zoomed(by factor: Double) -> PlazaCamera {
        PlazaCamera(
            aspect: aspect, height: height, pitch: pitch,
            fieldOfView: 2 * atan(tan(fieldOfView / 2) / max(factor, 0.01)), x: x, z: z, turn: turn)
    }

    /// The same camera slid across the floor.
    public func moved(x dx: Double, z dz: Double) -> PlazaCamera {
        PlazaCamera(
            aspect: aspect, height: height, pitch: pitch, fieldOfView: fieldOfView, x: x + dx, z: z + dz, turn: turn)
    }

    /// The same camera swung round a point on the floor, still looking at whatever it was looking at there.
    public func turned(by angle: Double, about pivot: (x: Double, z: Double)) -> PlazaCamera {
        let rx = x - pivot.x, rz = z - pivot.z
        return PlazaCamera(
            aspect: aspect, height: height, pitch: pitch, fieldOfView: fieldOfView,
            x: pivot.x + rx * cos(angle) + rz * sin(angle),
            z: pivot.z - rx * sin(angle) + rz * cos(angle),
            turn: turn + angle)
    }

    private var tanV: Double { tan(fieldOfView / 2) }
    private var tanH: Double { tanV * aspect }

    /// The point on the floor under a screen position, or nil where the screen shows sky.
    public func ground(u: Double, v: Double) -> (x: Double, z: Double)? {
        let nx = (2 * u - 1) * tanH
        let ny = (2 * v - 1) * tanV
        // Across the floor the camera's right is (cos turn, -sin turn) and its forward is (-sin turn, -cos turn).
        let ahead = cos(pitch) + sin(pitch) * ny
        let dy = -sin(pitch) + cos(pitch) * ny
        guard dy < -1e-9 else { return nil }
        let t = height / -dy
        return (
            x + t * (nx * cos(turn) - ahead * sin(turn)),
            z + t * (-nx * sin(turn) - ahead * cos(turn))
        )
    }

    /// Where a point in the world appears on screen, or nil if it is behind the camera.
    public func screen(x px: Double, y: Double, z pz: Double) -> (u: Double, v: Double)? {
        let wy = y - height
        let rx = px - x, rz = pz - z
        let right = rx * cos(turn) - rz * sin(turn)
        let ahead = -rx * sin(turn) - rz * cos(turn)
        let depth = -sin(pitch) * wy + cos(pitch) * ahead
        guard depth > 1e-9 else { return nil }
        let up = cos(pitch) * wy + sin(pitch) * ahead
        return ((right / (depth * tanH) + 1) / 2, (up / (depth * tanV) + 1) / 2)
    }
}
