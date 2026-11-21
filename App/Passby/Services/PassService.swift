import CoreBluetooth
import PassbyCore

/// Notices other phones running Passby and swaps profiles with them over Bluetooth.
///
/// Each phone does both jobs: it advertises a service whose one characteristic holds its own
/// profile, and it scans for that service on other phones, connects, reads the profile and hangs up.
@MainActor
final class PassService: NSObject {
    enum Status: Equatable {
        case off, starting, on, bluetoothOff, denied, unsupported
    }

    static let serviceID = CBUUID(string: "7E5B0F4A-3C1D-4E2A-9B6F-50A55B1E0001")
    static let profileID = CBUUID(string: "7E5B0F4A-3C1D-4E2A-9B6F-50A55B1E0002")

    private(set) var status = Status.off {
        didSet { if status != oldValue { onStatus?(status) } }
    }

    var onProfile: ((Profile) -> Void)?
    var onStatus: ((Status) -> Void)?

    private var central: CBCentralManager?
    private var peripheral: CBPeripheralManager?
    private var payload = Data()
    /// Phones we are talking to right now. Core Bluetooth drops a peripheral nobody holds on to.
    private var talking: [UUID: CBPeripheral] = [:]
    private var lastSeen: [UUID: Date] = [:]
    private var rescan: Timer?

    private static let revisitAfter: TimeInterval = 60
    private static let giveUpAfter: TimeInterval = 10

    func start(profile: Profile) {
        payload = profile.wireData()
        guard central == nil else { return }
        status = .starting
        central = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionRestoreIdentifierKey: "passby.central"])
        peripheral = CBPeripheralManager(delegate: self, queue: .main, options: [CBPeripheralManagerOptionRestoreIdentifierKey: "passby.peripheral"])
        // A scan reports each phone once. Restarting it lets someone who walks past again be seen again.
        rescan = Timer.scheduledTimer(withTimeInterval: 45, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.scan() }
        }
    }

    func update(profile: Profile) {
        payload = profile.wireData()
    }

    func stop() {
        rescan?.invalidate()
        rescan = nil
        if let central {
            if central.state == .poweredOn { central.stopScan() }
            talking.values.forEach { central.cancelPeripheralConnection($0) }
        }
        if let peripheral, peripheral.state == .poweredOn {
            peripheral.stopAdvertising()
            peripheral.removeAllServices()
        }
        talking = [:]
        central = nil
        peripheral = nil
        status = .off
    }

    private func scan() {
        guard let central, central.state == .poweredOn else { return }
        central.stopScan()
        central.scanForPeripherals(withServices: [Self.serviceID])
    }

    private func hangUp(_ device: CBPeripheral) {
        talking[device.identifier] = nil
        central?.cancelPeripheralConnection(device)
    }

    private func advertise() {
        guard let peripheral, peripheral.state == .poweredOn else { return }
        peripheral.removeAllServices()
        let profile = CBMutableCharacteristic(type: Self.profileID, properties: [.read], value: nil, permissions: [.readable])
        let service = CBMutableService(type: Self.serviceID, primary: true)
        service.characteristics = [profile]
        peripheral.add(service)
    }
}

// Both managers call back on the main queue, so hopping onto the main actor is safe.

extension PassService: CBCentralManagerDelegate, CBPeripheralDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            switch central.state {
            case .poweredOn:
                status = .on
                scan()
            case .poweredOff:
                status = .bluetoothOff
            case .unauthorized:
                status = .denied
            case .unsupported:
                status = .unsupported
            default:
                status = .starting
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        MainActor.assumeIsolated {
            for device in dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? [] {
                central.cancelPeripheralConnection(device)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover device: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        MainActor.assumeIsolated {
            let id = device.identifier
            guard talking[id] == nil else { return }
            if let seen = lastSeen[id], Date().timeIntervalSince(seen) < Self.revisitAfter { return }
            lastSeen[id] = Date()
            talking[id] = device
            device.delegate = self
            central.connect(device)
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.giveUpAfter) { [weak self] in
                guard let self, self.talking[id] === device else { return }
                self.hangUp(device)
                self.lastSeen[id] = nil     // it never answered, so try again next time it shows up
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect device: CBPeripheral) {
        device.discoverServices([Self.serviceID])
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect device: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated { talking[device.identifier] = nil }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral device: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated { talking[device.identifier] = nil }
    }

    nonisolated func peripheral(_ device: CBPeripheral, didDiscoverServices error: Error?) {
        MainActor.assumeIsolated {
            guard let service = device.services?.first(where: { $0.uuid == Self.serviceID }) else { return hangUp(device) }
            device.discoverCharacteristics([Self.profileID], for: service)
        }
    }

    nonisolated func peripheral(_ device: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        MainActor.assumeIsolated {
            guard let profile = service.characteristics?.first(where: { $0.uuid == Self.profileID }) else { return hangUp(device) }
            device.readValue(for: profile)
        }
    }

    nonisolated func peripheral(_ device: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        MainActor.assumeIsolated {
            // Anything that is not a Passby profile decodes to nil and is dropped.
            if characteristic.uuid == Self.profileID, let data = characteristic.value, let profile = Profile(wireData: data) {
                onProfile?(profile)
            }
            hangUp(device)
        }
    }
}

extension PassService: CBPeripheralManagerDelegate {
    nonisolated func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        MainActor.assumeIsolated { advertise() }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String: Any]) {}

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        guard error == nil else { return }
        peripheral.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [Self.serviceID], CBAdvertisementDataLocalNameKey: "Passby"])
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        MainActor.assumeIsolated {
            guard request.characteristic.uuid == Self.profileID else {
                return peripheral.respond(to: request, withResult: .attributeNotFound)
            }
            guard request.offset <= payload.count else {
                return peripheral.respond(to: request, withResult: .invalidOffset)
            }
            request.value = payload.subdata(in: request.offset..<payload.count)
            peripheral.respond(to: request, withResult: .success)
        }
    }
}
