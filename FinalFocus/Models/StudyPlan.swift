import Foundation

struct StudyTask: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var course: String
    var minutes: Int
    var reward: String
    var isComplete = false
}

struct StudyPlan: Codable, Hashable {
    var finalName: String
    var targetDate: Date
    var tasks: [StudyTask]

    static let starter = StudyPlan(
        finalName: "Next Final",
        targetDate: Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now,
        tasks: [
            StudyTask(title: "Open notes and mark weak topics", course: "Prep", minutes: 10, reward: "Tea or coffee break"),
            StudyTask(title: "Solve one practice set", course: "Core", minutes: 25, reward: "10 minutes guilt-free scrolling"),
            StudyTask(title: "Make a one-page memory sheet", course: "Recall", minutes: 25, reward: "One episode segment")
        ]
    )
}

struct Reward: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var cost: Int
    var symbol: String

    static let defaults: [Reward] = [
        Reward(title: "Coffee upgrade", cost: 2, symbol: "cup.and.saucer.fill"),
        Reward(title: "Short walk", cost: 1, symbol: "figure.walk"),
        Reward(title: "Snack", cost: 2, symbol: "fork.knife"),
        Reward(title: "Movie night", cost: 6, symbol: "play.tv.fill")
    ]
}
