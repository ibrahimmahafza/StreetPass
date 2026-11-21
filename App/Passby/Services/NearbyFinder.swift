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
        guard session == nil, Self.canRange else { return }
        let fresh = NISession()
        fresh.delegate = self
        fresh.delegateQueue = .main
        session = fresh
        onToken?(fresh.discoveryToken.flatMap { try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true) })
    }

    /// Starts ranging with the phone that handed over this token.
    func find(peer tokenData: Data) {
        prepare()
        guard let session,
              let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: tokenData)
        else { return }
        let configuration = NINearbyPeerConfiguration(peerToken: token)
        // Phones that cannot measure direction with the chip alone can with the camera's help.
        // That asks for camera access, so it is only switched on where it is needed.
        let can = NISession.deviceCapabilities
        if !can.supportsDirectionMeasurement, can.supportsCameraAssistance {
            configuration.isCameraAssistanceEnabled = true
        }
        session.run(configuration)
    }

    /// Ends ranging and gets a new token ready for the next person. A token is only good for one session.
    func stop() {
        demo?.invalidate()
        demo = nil
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
            onFix?()
        }
    }

    nonisolated func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        MainActor.assumeIsolated {
            guard session === self.session else { return }
            bearing = nil
            distance = nil
            onFix?()
        }
    }

    nonisolated func session(_ session: NISession, didUpdateAlgorithmConvergence convergence: NIAlgorithmConvergence, for object: NINearbyObject?) {
        MainActor.assumeIsolated {
            guard session === self.session else { return }
            if case .converged = convergence.status {
                needsSweep = false
            } else {
                needsSweep = true
            }
        }
    }

    nonisolated func session(_ session: NISession, didInvalidateWith error: Error) {
        MainActor.assumeIsolated {
            // Refused permission, or the system took the chip away. Drop the session; a new one is made next time.
            guard session === self.session else { return }
            self.session = nil
            bearing = nil
            distance = nil
            needsSweep = false
            onToken?(nil)
        }
    }
}
