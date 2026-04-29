import SwiftUI

struct LockedCountdownView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = model.remainingSeconds(now: context.date)

            ZStack {
                Color.black
                    .ignoresSafeArea()

                Text(timeString(for: remaining))
                    .font(.system(size: 76, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.68)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .onChange(of: remaining) { _, _ in
                        model.tick(now: context.date)
                    }
            }
            .statusBarHidden()
        }
    }

    private func timeString(for remaining: Int) -> String {
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingAbandon = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color.black, Color(red: 0.04, green: 0.16, blue: 0.13), Color(red: 0.09, green: 0.09, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        timerPanel
                        nextTasks
                    }
                    .padding(20)
                }
            }
            .navigationTitle("FinalFocus")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CoinBadge(count: model.rewardCoins)
                }
            }
            .sheet(isPresented: $showingAbandon) {
                AbandonSheet()
                    .presentationDetents([.medium])
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.plan.finalName)
                .font(.system(size: 38, weight: .black, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
            Text(model.agentNote)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var timerPanel: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = model.remainingSeconds(now: context.date)
            VStack(spacing: 18) {
                phaseLabel
                TimerRing(remaining: remaining, total: activeTotal)
                    .frame(height: 260)
                    .onChange(of: remaining) { _, _ in
                        model.tick(now: context.date)
                    }

                controls
            }
            .padding(18)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.10)))
        }
    }

    private var phaseLabel: some View {
        HStack {
            Label(labelText, systemImage: labelIcon)
                .font(.headline)
            Spacer()
            Text("\(model.session.completedSessions) blocks")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            switch model.session.phase {
            case .idle, .complete, .failed:
                Button {
                    if let task = model.plan.tasks.first(where: { !$0.isComplete }) ?? model.plan.tasks.first {
                        model.startTask(task)
                    }
                } label: {
                    Label("Start focus now", systemImage: "bolt.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
            case .preparing:
                Button {
                    model.startFocus(minutes: model.session.task?.minutes)
                } label: {
                    Label("Begin focus now", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
            case .focusing:
                Button {
                    showingAbandon = true
                } label: {
                    Label("Abandon", systemImage: "lock.open.trianglebadge.exclamationmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            case .breakTime:
                Button {
                    model.endBreak()
                } label: {
                    Label("End break", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var nextTasks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Next blocks")
                .font(.title3.bold())
            ForEach(model.plan.tasks.prefix(4)) { task in
                TaskRow(task: task) {
                    model.startTask(task)
                }
            }
        }
    }

    private var activeTotal: Int {
        switch model.session.phase {
        case .preparing: return Int(model.session.prepDuration)
        case .focusing: return Int(model.session.duration)
        case .breakTime: return Int(model.session.breakDuration)
        case .idle, .complete, .failed: return 25 * 60
        }
    }

    private var labelText: String {
        switch model.session.phase {
        case .idle: return "Ready to start"
        case .preparing: return "Starting"
        case .focusing: return model.session.task?.title ?? "Deep focus"
        case .breakTime: return "Protected break"
        case .complete: return "Coin earned"
        case .failed: return "Countdown failed"
        }
    }

    private var labelIcon: String {
        switch model.session.phase {
        case .idle: return "sparkles"
        case .preparing: return "figure.mind.and.body"
        case .focusing: return "lock.fill"
        case .breakTime: return "cup.and.saucer.fill"
        case .complete: return "checkmark.seal.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
}

struct PlanView: View {
    @EnvironmentObject private var model: AppModel
    @State private var goal = ""
    @State private var examDate = Calendar.current.date(byAdding: .day, value: 5, to: .now) ?? .now
    @State private var hoursPerDay = 4
    @State private var preparedness: PreparednessLevel = .lost
    @State private var mode: PlanMode = .hard
    @State private var reminderDate = Calendar.current.date(byAdding: .hour, value: 2, to: .now) ?? .now

    var body: some View {
        NavigationStack {
            Form {
                Section("Agent planner") {
                    TextField("Example: Organic Chemistry final in 6 days", text: $goal, axis: .vertical)
                    DatePicker("Exam date", selection: $examDate, displayedComponents: [.date, .hourAndMinute])
                    Stepper("Study time: \(hoursPerDay) hr/day", value: $hoursPerDay, in: 1...12)
                    Picker("Preparedness", selection: $preparedness) {
                        ForEach(PreparednessLevel.allCases) { level in
                            Text(level.label).tag(level)
                        }
                    }
                    Picker("Mode", selection: $mode) {
                        ForEach(PlanMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    Button {
                        Task { await model.askAgent(goal: goal, examDate: examDate, hoursPerDay: hoursPerDay, preparedness: preparedness, mode: mode) }
                    } label: {
                        Label(model.isAgentBusy ? "Planning..." : "Generate rescue plan", systemImage: "wand.and.stars")
                    }
                    .disabled(model.isAgentBusy || goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Text(model.agentNote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Reminder") {
                    DatePicker("Next study time", selection: $reminderDate, displayedComponents: [.date, .hourAndMinute])
                    Button {
                        if let task = model.plan.tasks.first(where: { !$0.isComplete }) ?? model.plan.tasks.first {
                            Task { await model.createReminder(for: task, date: reminderDate) }
                        }
                    } label: {
                        Label("Add next block to Reminders", systemImage: "calendar.badge.plus")
                    }
                }

                Section("Study blocks") {
                    ForEach(model.plan.tasks) { task in
                        HStack(spacing: 12) {
                            Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.isComplete ? .mint : .secondary)
                            VStack(alignment: .leading) {
                                Text(task.title)
                                Text("\(task.course) - \(task.minutes) min - \(task.reward)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Study Plan")
        }
    }
}

struct RewardsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        CoinBadge(count: model.rewardCoins)
                        Text("Earn 1 coin for each completed focus block.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Reward shop") {
                    ForEach(model.rewards) { reward in
                        Button {
                            model.buy(reward)
                        } label: {
                            HStack {
                                Image(systemName: reward.symbol)
                                    .frame(width: 30)
                                Text(reward.title)
                                Spacer()
                                Text("\(reward.cost)")
                                    .font(.headline)
                            }
                        }
                        .disabled(model.rewardCoins < reward.cost)
                    }
                }

                Section("Claimed") {
                    if model.earnedRewards.isEmpty {
                        Text("No rewards claimed yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.earnedRewards) { reward in
                            Label(reward.title, systemImage: reward.symbol)
                        }
                    }
                }
            }
            .navigationTitle("Rewards")
        }
    }
}

struct AbandonSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    @State private var pledge = ""
    @State private var friction = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Make quitting slower")
                .font(.title2.bold())
            Text("To abandon, write the next smallest step and drag the lock all the way. This gives your attention time to recover.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("Next smallest step", text: $reason, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            TextField("Type: I will restart", text: $pledge)
                .textFieldStyle(.roundedBorder)
            Slider(value: $friction, in: 0...1)
                .tint(.red)
            Button(role: .destructive) {
                model.abandon(reason: reason)
                dismiss()
            } label: {
                Label("Confirm abandon", systemImage: "xmark.octagon.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(friction < 0.98 || pledge != "I will restart")
            Spacer()
        }
        .padding(20)
    }
}

struct TaskRow: View {
    var task: StudyTask
    var start: () -> Void

    var body: some View {
        Button(action: start) {
            HStack(spacing: 12) {
                Image(systemName: task.isComplete ? "checkmark.seal.fill" : "book.closed.fill")
                    .foregroundStyle(task.isComplete ? .mint : .white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("\(task.minutes) min - \(task.reward)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(.mint)
                    .font(.title2)
            }
            .padding(14)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct TimerRing: View {
    var remaining: Int
    var total: Int

    private var progress: Double {
        guard total > 0 else { return 0 }
        return 1 - (Double(remaining) / Double(total))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.08), lineWidth: 22)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(AngularGradient(colors: [.mint, .cyan, .yellow, .mint], center: .center), style: StrokeStyle(lineWidth: 22, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.snappy, value: progress)
            VStack(spacing: 6) {
                Text(timeString)
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .monospacedDigit()
                Text(remaining == 0 ? "done" : "remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
    }

    private var timeString: String {
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct CoinBadge: View {
    var count: Int

    var body: some View {
        Label("\(count)", systemImage: "bitcoinsign.circle.fill")
            .font(.headline)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.yellow.opacity(0.18), in: Capsule())
            .foregroundStyle(.yellow)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding()
            .background(configuration.isPressed ? .mint.opacity(0.72) : .mint, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.black)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding()
            .background(configuration.isPressed ? .white.opacity(0.10) : .white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.14)))
    }
}
