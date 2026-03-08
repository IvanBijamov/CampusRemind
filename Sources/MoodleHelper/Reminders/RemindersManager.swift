import EventKit
import Foundation

actor RemindersManager {
    let eventStore = EKEventStore()

    func requestAccess() async throws {
        let granted = try await eventStore.requestFullAccessToReminders()
        guard granted else {
            throw RemindersError.accessDenied
        }
    }

    func findOrCreateList(named name: String) throws -> EKCalendar {
        let calendars = eventStore.calendars(for: .reminder)
        if let existing = calendars.first(where: {
            $0.title.caseInsensitiveCompare(name) == .orderedSame
        }) {
            return existing
        }

        let newList = EKCalendar(for: .reminder, eventStore: eventStore)
        newList.title = name

        if let defaultSource = eventStore.defaultCalendarForNewReminders()?.source {
            newList.source = defaultSource
        } else if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            newList.source = localSource
        } else if let firstSource = eventStore.sources.first(where: { $0.sourceType != .birthdays }) {
            newList.source = firstSource
        } else {
            throw RemindersError.noSource
        }

        try eventStore.saveCalendar(newList, commit: true)
        return newList
    }

    func reminderExists(title: String, dueDate: Date?, inList list: EKCalendar) async throws -> Bool {
        let predicate = eventStore.predicateForReminders(in: [list])
        let reminders = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }

        // Match against ALL reminders (including completed) to avoid re-creating checked-off items
        return reminders.contains { reminder in
            guard reminder.title?.caseInsensitiveCompare(title) == .orderedSame else { return false }

            if let dueDate = dueDate {
                guard let reminderDue = reminder.dueDateComponents,
                      let reminderDate = Calendar.current.date(from: reminderDue) else {
                    return false
                }
                let cal = Calendar.current
                return cal.compare(dueDate, to: reminderDate, toGranularity: .minute) == .orderedSame
            } else {
                return reminder.dueDateComponents == nil
            }
        }
    }

    func createReminder(title: String, notes: String?, dueDate: Date?, inList list: EKCalendar) throws {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        reminder.calendar = list

        if let dueDate = dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
        }

        try eventStore.save(reminder, commit: true)
    }
}

enum RemindersError: LocalizedError {
    case accessDenied
    case noSource

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Reminders access denied. Grant access in System Settings > Privacy & Security > Reminders."
        case .noSource:
            return "No available source for creating reminder lists."
        }
    }
}
