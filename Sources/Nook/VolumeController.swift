import AudioToolbox
import CoreAudio
import Foundation

/// Reads and writes the system output volume through CoreAudio and reports
/// changes, including ones made elsewhere (Control Center, other apps).
final class VolumeController {
    var onChange: ((_ volume: Float, _ muted: Bool) -> Void)?

    private var deviceID = AudioDeviceID(kAudioObjectUnknown)
    private var deviceListener: AudioObjectPropertyListenerBlock?
    private var valueListener: AudioObjectPropertyListenerBlock?

    private var volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    private var muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    private var defaultDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    init() {
        attach(to: Self.defaultOutputDevice())

        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self else { return }
            self.attach(to: Self.defaultOutputDevice())
        }
        deviceListener = listener
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &defaultDeviceAddress, .main, listener)
    }

    // MARK: - Volume

    /// False for outputs macOS can't control (e.g. many HDMI/DisplayPort monitors).
    var canSetVolume: Bool {
        guard AudioObjectHasProperty(deviceID, &volumeAddress) else { return false }
        var settable: DarwinBoolean = false
        AudioObjectIsPropertySettable(deviceID, &volumeAddress, &settable)
        return settable.boolValue
    }

    var volume: Float {
        get {
            var value: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            AudioObjectGetPropertyData(deviceID, &volumeAddress, 0, nil, &size, &value)
            return value
        }
        set {
            var value = Float32(min(max(newValue, 0), 1))
            AudioObjectSetPropertyData(
                deviceID, &volumeAddress, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
        }
    }

    var isMuted: Bool {
        get {
            guard AudioObjectHasProperty(deviceID, &muteAddress) else { return false }
            var value: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            AudioObjectGetPropertyData(deviceID, &muteAddress, 0, nil, &size, &value)
            return value != 0
        }
        set {
            guard AudioObjectHasProperty(deviceID, &muteAddress) else { return }
            var value: UInt32 = newValue ? 1 : 0
            AudioObjectSetPropertyData(
                deviceID, &muteAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
        }
    }

    // MARK: - Device tracking

    private func attach(to newDevice: AudioDeviceID) {
        if let valueListener, deviceID != kAudioObjectUnknown {
            AudioObjectRemovePropertyListenerBlock(deviceID, &volumeAddress, .main, valueListener)
            AudioObjectRemovePropertyListenerBlock(deviceID, &muteAddress, .main, valueListener)
        }
        deviceID = newDevice
        guard newDevice != kAudioObjectUnknown else { return }

        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self else { return }
            self.onChange?(self.volume, self.isMuted)
        }
        valueListener = listener
        AudioObjectAddPropertyListenerBlock(newDevice, &volumeAddress, .main, listener)
        AudioObjectAddPropertyListenerBlock(newDevice, &muteAddress, .main, listener)
    }

    private static func defaultOutputDevice() -> AudioDeviceID {
        var id = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id)
        return id
    }
}
