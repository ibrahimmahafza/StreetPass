import Foundation
@preconcurrency import NearbyInteraction
import PassbyCore

/// Works out where a nearby phone is: how far, and which way.
///
/// Bluetooth can tell that another phone is close but not where it is. Direction comes from the
/// Ultra Wideband chip, through Apple's Nearby Interaction. Each phone has a one-off token; the two
/// phones swap tokens over Bluetooth and can then range each other.
@MainActor @Observable
final class NearbyFinder: NSObject {
    /// Radians to the right of where the phone is pointing, or nil when the phone cannot tell.
    private(set) var bearing: Double?
    /// Metres to the other phone, or nil when unknown.
    private(set) var distance: Double?
    /// True while the phone needs to be moved around before it can tell the direction.
    private(set) var needsSweep = false

    /// Called with this phone's current token (to hand out over Bluetooth), or nil when it has none.
    @ObservationIgnored var onToken: ((Data?) -> Void)?
    /// Called whenever a new distance or direction arrives.
    @ObservationIgnored var onFix: (() -> Void)?

    @ObservationIgnored private var session: NISession?
    @ObservationIgnored private var demo: Timer?
    @ObservationIgnored private var lastLogged = Date.distantPast
    @ObservationIgnored private var fixes = 0

    /// Apple's documentation gives the camera-assisted angle in radians but does not say which way is
    /// positive. This assumes positive is to the right, like the direction vector; flip it if the arrow
    /// turns out mirrored on a phone that uses camera assistance.
    private static let cameraAngleSign = 1.0

    /// Whether this phone has the chip at all.
    static var canRange: Bool {
        NISession.deviceCapabilities.supportsPreciseDistanceMeasurement
    }

    /// Gets a session and its token ready, so a phone that reads the token can start ranging at once.
    func prepare() {
        guard session == nil else { return }
        let can = NISession.deviceCapabilities
        guard Self.canRange else {
            if !saidCannot {
                saidCannot = true
                note("ranging", "this device cannot range (no Ultra Wideband)")
            }
            return
        }
        let fresh = NISession()
        fresh.delegate = self
        fresh.delegateQueue = .main
        session = fresh
        let token = fresh.discoveryToken.flatMap { try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true) }
        note("ranging", "ready; token \(token?.count ?? 0) bytes; direction from the chip: \(can.supportsDirectionMeasurement ? "yes" : "no"), with the camera: \(can.supportsCameraAssistance ? "yes" : "no")")
        onToken?(token)
    }

    @ObservationIgnored private var saidCannot = false

    /// Starts ranging with the phone that handed over this token.
    func find(peer tokenData: Data) {
        prepare()
        guard let session,
              let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: tokenData)
        else {
            note("ranging", session == nil ? "cannot range with them: this phone has no session" : "cannot range with them: their token (\(tokenData.count) bytes) is unreadable")
            return
        }
        let configuration = NINearbyPeerConfiguration(peerToken: token)
        // Phones that cannot measure direction with the chip alone can with the camera's help.
        // That asks for camera access, so it is only switched on where it is needed.
        let can = NISession.deviceCapabilities
        if !can.supportsDirectionMeasurement, can.supportsCameraAssistance {
            configuration.isCameraAssistanceEnabled = true
        }
        fixes = 0
        note("ranging", "started ranging\(configuration.isCameraAssistanceEnabled ? " with the camera's help" : "")")
        session.run(configuration)
    }

    /// Ends ranging and gets a new token ready for the next person. A token is only good for one session.
    func stop() {
        demo?.invalidate()
        demo = nil
        if session != nil, fixes > 0 { note("ranging", "stopped after \(fixes) readings") }
        session?.invalidate()
        session = nil
        bearing = nil
        distance = nil
        needsSweep = false
        prepare()
    }

    /// For screenshots only: sweeps a made-up direction and distance so the arrow can be seen
    /// without two phones in the room.
    func demoSweep() {
        demo?.invalidate()
        demo = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                let t = Date().timeIntervalSinceReferenceDate
                self?.bearing = sin(t * 0.9) * 1.2
                self?.distance = 2.4 + sin(t * 0.5)
            }
        }
    }
}

// The session is told to call back on the main queue, so hopping onto the main actor is safe.

extension NearbyFinder: NISessionDelegate {
    nonisolated func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        MainActor.assumeIsolated {
            guard session === self.session, let other = nearbyObjects.first else { return }
            distance = other.distance.map { Double($0) }
            if let direction = other.direction {
                bearing = Bearing.right(x: Double(direction.x), z: Double(direction.z))
            } else if let angle = other.horizontalAngle {
                bearing = Bearing.wrap(Double(angle) * Self.cameraAngleSign)
            } else {
                bearing = nil
            }
            fixes += 1
            // The first reading and then one every couple of seconds, so the log stays readable.
            if fixes == 1 || Date().timeIntervalSince(lastLogged) >= 2 {
                lastLogged = Date()
                let far = distance.map { String(format: "%.2f m", $0) } ?? "distance unknown"
                let way = bearing.map { String(format: "%.0f degrees to the right", $0 * 180 / .pi) } ?? "direction unknown"
                note("ranging", "\(fixes == 1 ? "first reading" : "reading \(fixes)"): \(far), \(way)")
            }
            onFix?()
        }
    }

    nonisolated func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        MainActor.assumeIsolated {
            guard session === self.session else { return }
            note("ranging", "lost them (\(reason == .timeout ? "timed out" : "they stopped"))")
            bearing = nil
            distance = nil
            onFix?()
        }
    }

    nonisolated func sessionWasSuspended(_ session: NISession) {
        MainActor.assumeIsolated { note("ranging", "paused by iOS (app not in front)") }
    }

    nonisolated func sessionSuspensionEnded(_ session: NISession) {
        MainActor.assumeIsolated { note("ranging", "iOS allows ranging again") }
    }

    nonisolated func session(_ session: NISession, didUpdateAlgorithmConvergence convergence: NIAlgorithmConvergence, for object: NINearbyObject?) {
        MainActor.assumeIsolated {
            guard session === self.session else { return }
            let settled: Bool
            if case .converged = convergence.status { settled = true } else { settled = false }
            if needsSweep == settled {
                note("ranging", settled ? "direction has settled" : "direction not settled yet; the phone needs moving around")
            }
            needsSweep = !settled
        }
    }

    nonisolated func session(_ session: NISession, didInvalidateWith error: Error) {
        MainActor.assumeIsolated {
            // Refused permission, or the system took the chip away. Drop the session; a new one is made next time.
            guard session === self.session else { return }
            note("ranging", "session ended: \(error.localizedDescription)")
            self.session = nil
            bearing = nil
            distance = nil
            needsSweep = false
            onToken?(nil)
        }
    }
}
