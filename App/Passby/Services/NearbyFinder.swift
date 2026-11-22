import AVFoundation
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
    /// What the phone still needs before it can tell the direction, or nil when it needs nothing.
    /// iPhone 14 and later work the direction out with the camera, and that only settles once the
    /// phone has been moved about, so the person has to be told to do it.
    private(set) var need: Bearing.Need?

    /// Called with this phone's current token (to hand out over Bluetooth), or nil when it has none.
    @ObservationIgnored var onToken: ((Data?) -> Void)?
    /// Called whenever a new distance or direction arrives.
    @ObservationIgnored var onFix: (() -> Void)?

    @ObservationIgnored private var session: NISession?
    /// The settings for the person being ranged with, kept so ranging can be started again after iOS pauses it.
    @ObservationIgnored private var peer: NINearbyPeerConfiguration?
    @ObservationIgnored private var paused = false
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
        peer = configuration
        paused = false
        need = Self.startingNeed(for: configuration)
        note("ranging", "started ranging\(configuration.isCameraAssistanceEnabled ? " with the camera's help; camera access: \(Self.cameraAccess)" : "")")
        session.run(configuration)
    }

    /// With the camera's help there is no direction until the phone has been moved about, so that is
    /// asked for from the start, before iOS says anything. Without camera access there will be none at all.
    private static func startingNeed(for configuration: NINearbyPeerConfiguration) -> Bearing.Need? {
        guard configuration.isCameraAssistanceEnabled else { return nil }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted: return .camera
        default: return .moving
        }
    }

    private static var cameraAccess: String {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return "allowed"
        case .notDetermined: return "not asked yet"
        case .denied: return "refused"
        case .restricted: return "restricted"
        @unknown default: return "unknown"
        }
    }

    /// Picks ranging back up with the same person after iOS paused it. A paused session does not
    /// restart by itself. Does nothing if ranging was never paused.
    func resume() {
        guard paused, let session, let peer else { return }
        paused = false
        need = Self.startingNeed(for: peer)
        note("ranging", "starting ranging again\(peer.isCameraAssistanceEnabled ? "; camera access: \(Self.cameraAccess)" : "")")
        session.run(peer)
    }

    /// Ends ranging and gets a new token ready for the next person. A token is only good for one session.
    func stop() {
        demo?.invalidate()
        demo = nil
        if session != nil, fixes > 0 { note("ranging", "stopped after \(fixes) readings") }
        session?.invalidate()
        session = nil
        peer = nil
        paused = false
        bearing = nil
        distance = nil
        need = nil
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

    /// For screenshots only: a distance but no direction yet, as on a phone that has not been moved about.
    func demoWaitingForSweep() {
        demo?.invalidate()
        bearing = nil
        distance = 2.4
        need = .sideToSide
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
        MainActor.assumeIsolated {
            guard session === self.session else { return }
            note("ranging", "paused by iOS (app not in front)")
            paused = true
            bearing = nil
            distance = nil
            need = nil
            onFix?()
        }
    }

    nonisolated func sessionSuspensionEnded(_ session: NISession) {
        MainActor.assumeIsolated {
            guard session === self.session else { return }
            note("ranging", "iOS allows ranging again")
            resume()
        }
    }

    nonisolated func session(_ session: NISession, didUpdateAlgorithmConvergence convergence: NIAlgorithmConvergence, for object: NINearbyObject?) {
        MainActor.assumeIsolated {
            guard session === self.session else { return }
            let next: Bearing.Need?
            switch convergence.status {
            case .converged:
                next = nil
            case let .notConverged(reasons):
                // iOS says what is missing; ask for the one that matters most. With nothing named, any movement.
                let wanted: [Bearing.Need] = reasons.compactMap { reason in
                    switch reason {
                    case .insufficientLighting: return .light
                    case .insufficientHorizontalSweep: return .sideToSide
                    case .insufficientVerticalSweep: return .upAndDown
                    case .insufficientMovement: return .moving
                    case .insufficientSignalStrength: return .closer
                    default: return nil
                    }
                }
                next = Bearing.Need.first(of: wanted) ?? .moving
            case .unknown:
                next = need
            @unknown default:
                next = need
            }
            // Without camera access nothing iOS asks for would help, so that stays the thing to fix.
            let shown = need == .camera && next != nil ? .camera : next
            if shown != need {
                note("ranging", shown.map { "direction not settled yet: \($0.asking.lowercased())" } ?? "direction has settled")
            }
            need = shown
        }
    }

    nonisolated func session(_ session: NISession, didInvalidateWith error: Error) {
        MainActor.assumeIsolated {
            // Refused permission, or the system took the chip away. Drop the session; a new one is made next time.
            guard session === self.session else { return }
            note("ranging", "session ended: \(error.localizedDescription)")
            self.session = nil
            peer = nil
            paused = false
            bearing = nil
            distance = nil
            need = nil
            onToken?(nil)
        }
    }
}
