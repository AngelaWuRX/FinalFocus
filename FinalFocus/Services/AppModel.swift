import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var plan: StudyPlan = .starter
    @Published var session = FocusSession()
    @Published var rewardCoins = 0
    @Published var earnedRewards: [Reward] = []
    @Published var rewards = Reward.defaults
    @Published var agentNote = "Tell the planning agent what final you are studying for."
    @Published var isAgentBusy = false

    private let reminderCoordinator = ReminderCoordinator()
    private let planAgent = PlanAgentClient()
    private let defaults = UserDefaults.standard
    private let planKey = "FinalFocus.plan"
    private let sessionKey = "FinalFocus.session"
    private let coinsKey = "FinalFocus.coins"
    private let earnedKey = "FinalFocus.earnedRewards"

    func bootstrap() async {
        load()
        failLoadedActiveCountdownIfNeeded()
        await reminderCoordinator.requestNotificationPermission()
    }

    func startTask(_ task: StudyTask) {
        session.task = task
        startFocus(minutes: task.minutes)
    }

    func startFocus(minutes: Int? = nil) {
        session.phase = .focusing
        session.startedAt = .now
        if let minutes {
            session.duration = TimeInterval(minutes * 60)
        }
        save()
        Task {
            await reminderCoordinator.scheduleLocalNotification(
                title: "Block complete",
                body: "Claim your reward coin and take a real break.",
                secondsFromNow: session.duration
            )
        }
    }

    func startBreak() {
        session.phase = .breakTime
        session.startedAt = .now
        save()
        Task {
            await reminderCoordinator.scheduleLocalNotification(
                title: "Break finished",
                body: "Come back before the next session gets harder to start.",
                secondsFromNow: session.breakDuration
            )
        }
    }

    func endBreak() {
        session.phase = .idle
        session.startedAt = nil
        save()
    }

    func completeFocus() {
        guard let task = session.task else { return }
        rewardCoins += 1
        session.completedSessions += 1
        plan.tasks = plan.tasks.map { current in
            var updated = current
            if current.id == task.id {
                updated.isComplete = true
            }
            return updated
        }
        session.phase = .complete
        session.startedAt = nil
        save()
    }

    func abandon(reason: String) {
        agentNote = reason.isEmpty ? "Session abandoned. Restart with a smaller first step." : "Session abandoned: \(reason)"
        session = FocusSession(completedSessions: session.completedSessions)
        save()
    }

    func failActiveCountdown(reason: String) {
        guard session.phase == .preparing || session.phase == .focusing else { return }
        let taskTitle = session.task?.title ?? "focus block"
        session.phase = .failed
        session.startedAt = nil
        agentNote = "\(taskTitle) failed: \(reason)"
        save()
    }

    func buy(_ reward: Reward) {
        guard rewardCoins >= reward.cost else { return }
        rewardCoins -= reward.cost
        earnedRewards.append(reward)
        save()
    }

    func createReminder(for task: StudyTask, date: Date) async {
        await reminderCoordinator.createStudyReminder(title: task.title, notes: task.course, date: date)
    }

    func askAgent(goal: String, examDate: Date, hoursPerDay: Int, preparedness: PreparednessLevel, mode: PlanMode) async {
        let trimmed = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isAgentBusy = true
        defer { isAgentBusy = false }

        do {
            let response = try await planAgent.generatePlan(goal: trimmed, existingPlan: plan, examDate: examDate, hoursPerDay: hoursPerDay, preparedness: preparedness, mode: mode)
            plan = response.plan
            agentNote = response.note
            save()
        } catch {
            let response = planAgent.localFallback(goal: trimmed, examDate: examDate, hoursPerDay: hoursPerDay, preparedness: preparedness, mode: mode)
            plan = response.plan
            agentNote = response.note
            save()
        }
    }

    func remainingSeconds(now: Date = .now) -> Int {
        guard let end = session.activeEndDate else { return 0 }
        return max(0, Int(end.timeIntervalSince(now).rounded(.up)))
    }

    func tick(now: Date = .now) {
        guard session.phase == .preparing || session.phase == .focusing || session.phase == .breakTime else { return }
        if remainingSeconds(now: now) == 0 {
            switch session.phase {
            case .preparing:
                failActiveCountdown(reason: "old preparation timer is no longer supported")
            case .focusing:
                completeFocus()
            case .breakTime:
                session.phase = .idle
                session.startedAt = nil
                save()
            case .idle, .complete, .failed:
                break
            }
        }
    }

    private func failLoadedActiveCountdownIfNeeded() {
        guard session.phase == .preparing || session.phase == .focusing else { return }
        failActiveCountdown(reason: "the app was closed during the countdown")
    }

    private func load() {
        if let data = defaults.data(forKey: planKey), let decoded = try? JSONDecoder().decode(StudyPlan.self, from: data) {
            plan = decoded
        }
        if let data = defaults.data(forKey: sessionKey), let decoded = try? JSONDecoder().decode(FocusSession.self, from: data) {
            session = decoded
        }
        if let data = defaults.data(forKey: earnedKey), let decoded = try? JSONDecoder().decode([Reward].self, from: data) {
            earnedRewards = decoded
        }
        rewardCoins = defaults.integer(forKey: coinsKey)
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(plan), forKey: planKey)
        defaults.set(try? JSONEncoder().encode(session), forKey: sessionKey)
        defaults.set(try? JSONEncoder().encode(earnedRewards), forKey: earnedKey)
        defaults.set(rewardCoins, forKey: coinsKey)
    }
}
