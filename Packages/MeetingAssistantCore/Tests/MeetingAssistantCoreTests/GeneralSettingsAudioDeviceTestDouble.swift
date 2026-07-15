import Combine
@testable import MeetingAssistantCore

@MainActor
final class GeneralSettingsAudioDeviceTestDouble: GeneralSettingsAudioDeviceManaging {
    private let subject = CurrentValueSubject<[AudioInputDevice], Never>([])

    var availableInputDevices: [AudioInputDevice] {
        subject.value
    }

    var availableInputDevicesPublisher: AnyPublisher<[AudioInputDevice], Never> {
        subject.eraseToAnyPublisher()
    }

    func refreshDevices() {}
}
