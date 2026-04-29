import EventKit
import Foundation
import UserNotifications

actor ReminderCoordinator {
    private let eventStore = EKEventStore()

    func requestNotificationPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    func scheduleLocalNotification(title: String, body: String, secondsFromNow: TimeInterval) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, secondsFromNow), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    func createStudyReminder(title: String, notes: String, date: Date) async {
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = (try? await eventStore.requestFullAccessToReminders()) ?? false
        } else {
            granted = (try? await eventStore.requestAccess(to: .reminder)) ?? false
        }

        guard granted, let calendar = eventStore.defaultCalendarForNewReminders() else { return }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = "Study: \(title)"
        reminder.notes = notes
        reminder.calendar = calendar
        reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        try? eventStore.save(reminder, commit: true)
    }
}
