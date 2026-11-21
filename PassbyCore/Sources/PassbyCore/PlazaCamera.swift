import Foundation

/// The plaza's camera as plain geometry: it sits above the origin, looks towards negative z and
/// tilts down at the floor. The simulation uses it to place people by where they appear on screen,
/// and the 3D view builds its real camera from the same numbers so the two always agree.
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

    public init(aspect: Double, height: Double = 27, pitch: Double = 40 * .pi / 180, fieldOfView: Double = 38 * .pi / 180) {
        self.aspect = aspect
        self.height = height
        self.pitch = pitch
        self.fieldOfView = fieldOfView
    }

    private var tanV: Double { tan(fieldOfView / 2) }
    private var tanH: Double { tanV * aspect }

    /// The point on the floor under a screen position, or nil where the screen shows sky.
    public func ground(u: Double, v: Double) -> (x: Double, z: Double)? {
        let nx = (2 * u - 1) * tanH
        let ny = (2 * v - 1) * tanV
        // forward (0, -sin, -cos) + right (1, 0, 0) * nx + up (0, cos, -sin) * ny
        let dx = nx
        let dy = -sin(pitch) + cos(pitch) * ny
        let dz = -cos(pitch) - sin(pitch) * ny
        guard dy < -1e-9 else { return nil }
        let t = height / -dy
        return (t * dx, t * dz)
    }

    /// Where a point in the world appears on screen, or nil if it is behind the camera.
    public func screen(x: Double, y: Double, z: Double) -> (u: Double, v: Double)? {
        let wy = y - height
        let depth = -sin(pitch) * wy - cos(pitch) * z
        guard depth > 1e-9 else { return nil }
        let right = x
        let up = cos(pitch) * wy - sin(pitch) * z
        return ((right / (depth * tanH) + 1) / 2, (up / (depth * tanV) + 1) / 2)
    }
}
