@testable import MeetingAssistantCore
@testable import MeetingAssistantCoreAudio
@testable import MeetingAssistantCoreInfrastructure
import XCTest

@MainActor
final class AudioRecorderOutputInterruptionTests: XCTestCase {
    func testPauseModePrefersPauseSessionWhenSupported() {
        let session = MediaPlaybackResumeSession(target: .music)

        let plan = AudioRecorder.makeOutputInterruptionPlan(
            mode: .pauseMedia,
            mediaPauseOutcome: .paused(session),
            duckingLevelPercent: 30,
        )

        XCTAssertEqual(plan, .pause(session))
    }

    func testPauseModeFallsBackToDuckingWhenPauseUnsupported() {
        let plan = AudioRecorder.makeOutputInterruptionPlan(
            mode: .pauseMedia,
            mediaPauseOutcome: .unsupported,
            duckingLevelPercent: 25,
        )

        XCTAssertEqual(plan, .duck(25))
    }

    func testPauseModeFallsBackToNoInterruptionWhenDuckingDisabled() {
        let plan = AudioRecorder.makeOutputInterruptionPlan(
            mode: .pauseMedia,
            mediaPauseOutcome: .failed,
            duckingLevelPercent: 100,
        )

        XCTAssertEqual(plan, .none)
    }

    func testDuckModeUsesConfiguredDuckingLevel() {
        let plan = AudioRecorder.makeOutputInterruptionPlan(
            mode: .duckAudio,
            mediaPauseOutcome: .noActivePlayback,
            duckingLevelPercent: 40,
        )

        XCTAssertEqual(plan, .duck(40))
    }

    func testNoneModeLeavesOutputUntouched() {
        let plan = AudioRecorder.makeOutputInterruptionPlan(
            mode: .none,
            mediaPauseOutcome: .paused(.init(target: .spotify)),
            duckingLevelPercent: 0,
        )

        XCTAssertEqual(plan, .none)
    }
}
