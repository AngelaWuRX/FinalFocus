import Foundation

struct PlanAgentResponse: Codable {
    var plan: StudyPlan
    var note: String
}

enum PreparednessLevel: String, CaseIterable, Identifiable, Codable {
    case lost
    case shaky
    case okay

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lost: return "I am lost"
        case .shaky: return "I am shaky"
        case .okay: return "I know some"
        }
    }
}

enum PlanMode: String, CaseIterable, Identifiable, Codable {
    case normal
    case hard
    case ultimate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .normal: return "Normal"
        case .hard: return "Hard"
        case .ultimate: return "Ultimate"
        }
    }

    var blockScale: Double {
        switch self {
        case .normal: return 1.0
        case .hard: return 1.25
        case .ultimate: return 1.6
        }
    }
}

struct PlanAgentRequest: Codable {
    var goal: String
    var existingFinal: String
    var examDate: Date
    var hoursPerDay: Int
    var preparedness: PreparednessLevel
    var mode: PlanMode
}

struct PlanAgentClient {
    var endpoint: URL? {
        URL(string: "http://127.0.0.1:8787/plan")
    }

    func generatePlan(goal: String, existingPlan: StudyPlan, examDate: Date, hoursPerDay: Int, preparedness: PreparednessLevel, mode: PlanMode) async throws -> PlanAgentResponse {
        guard let endpoint else {
            return localFallback(goal: goal, examDate: examDate, hoursPerDay: hoursPerDay, preparedness: preparedness, mode: mode)
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 4

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(PlanAgentRequest(
            goal: goal,
            existingFinal: existingPlan.finalName,
            examDate: examDate,
            hoursPerDay: hoursPerDay,
            preparedness: preparedness,
            mode: mode
        ))

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PlanAgentResponse.self, from: data)
    }

    func localFallback(goal: String, examDate: Date, hoursPerDay: Int, preparedness: PreparednessLevel, mode: PlanMode) -> PlanAgentResponse {
        let daysLeft = max(1, Calendar.current.dateComponents([.day], from: .now, to: examDate).day ?? 1)
        let dailyBlocks = max(2, min(mode == .ultimate ? 6 : 8, hoursPerDay * 2))
        let totalBlocks = max(6, min(36, dailyBlocks * min(daysLeft, 5)))
        let rescueShare: Double = preparedness == .lost ? 0.45 : preparedness == .shaky ? 0.30 : 0.18
        let rescueBlocks = max(2, Int(Double(totalBlocks) * rescueShare))
        let practiceBlocks = max(2, Int(Double(totalBlocks) * 0.35))
        let recallBlocks = max(2, totalBlocks - rescueBlocks - practiceBlocks - 3)
        let triageMinutes = scaledMinutes(25, mode: mode)
        let rescueMinutes = scaledMinutes(35, mode: mode)
        let recallMinutes = scaledMinutes(25, mode: mode)
        let practiceMinutes = scaledMinutes(45, mode: mode)

        var tasks: [StudyTask] = [
            StudyTask(title: "Emergency triage: collect syllabus, old exams, homework, formula sheet", course: goal, minutes: triageMinutes, reward: "One coin"),
            StudyTask(title: "Rank every topic high-yield, medium, or skip", course: goal, minutes: triageMinutes, reward: "Five minute reset"),
            StudyTask(title: "Build a survival sheet from solved examples, not rereading", course: goal, minutes: triageMinutes, reward: "Snack")
        ]

        for index in 1...rescueBlocks {
            tasks.append(StudyTask(title: "Rescue learn weak topic \(index): watch/read one example, then redo it closed-book", course: goal, minutes: rescueMinutes, reward: "One coin"))
        }

        for index in 1...recallBlocks {
            tasks.append(StudyTask(title: "Active recall loop \(index): blank page, check, correct, repeat", course: goal, minutes: recallMinutes, reward: "Short walk"))
        }

        for index in 1...practiceBlocks {
            tasks.append(StudyTask(title: "Timed practice set \(index): grade mistakes and write fixes", course: goal, minutes: practiceMinutes, reward: "Phone break"))
        }

        tasks.append(StudyTask(title: "Final pass: memorize survival sheet and sleep plan", course: goal, minutes: triageMinutes, reward: "Premium reward"))

        let plan = StudyPlan(
            finalName: goal,
            targetDate: examDate,
            tasks: tasks
        )
        return PlanAgentResponse(plan: plan, note: "\(mode.label) cram plan: \(daysLeft) day(s), \(hoursPerDay) hour(s)/day, \(totalBlocks) work blocks. Blocks are longer in harder modes, so use Ultimate only when you are ready to lock in.")
    }

    private func scaledMinutes(_ base: Int, mode: PlanMode) -> Int {
        let raw = Double(base) * mode.blockScale
        return Int((raw / 5).rounded() * 5)
    }
}
