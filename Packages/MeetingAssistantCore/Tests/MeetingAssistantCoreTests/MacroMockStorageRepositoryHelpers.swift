@testable import MeetingAssistantCoreDomain

func makeMacroMockTranscriptionStorageRepository() -> MeetingAssistantCoreDomain.MacroMockTranscriptionStorageRepository {
    let storageRepository = MeetingAssistantCoreDomain.MacroMockTranscriptionStorageRepository()
    storageRepository.saveModelPerformanceAttemptHandler = { _ in }
    return storageRepository
}
