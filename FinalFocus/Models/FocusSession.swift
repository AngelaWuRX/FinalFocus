import Foundation

enum FocusPhase: String, Codable {
    case idle
    case preparing
    case focusing
    case breakTime
    case complete
    case failed
}

struct FocusSession: Codable, Hashable {
    var phase: FocusPhase = .idle
    var task: StudyTask?
    var startedAt: Date?
    var duration: TimeInterval = 25 * 60
    var prepDuration: TimeInterval = 90
    var breakDuration: TimeInterval = 5 * 60
    var completedSessions = 0

    var activeEndDate: Date? {
        guard let startedAt else { return nil }
        switch phase {
        case .preparing:
            return startedAt.addingTimeInterval(prepDuration)
        case .focusing:
            return startedAt.addingTimeInterval(duration)
        case .breakTime:
            return startedAt.addingTimeInterval(breakDuration)
        case .idle, .complete, .failed:
            return nil
        }
    }
}
