import SwiftUI
import Combine
import AVFoundation
import SwiftData

struct LandingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\DailyStudyRecord.date)]) private var records: [DailyStudyRecord]
    enum FocusState {
        case idle
        case running
        case paused
    }

    enum SessionPhase {
        case study
        case `break`
    }

    enum Mood: String, CaseIterable {
        case piano = "Piano"
        case violin = "Violin"
        case guitar = "Guitar"
        case none = "None"
    }

    @AppStorage("daily_goal_duration_seconds") private var goalDuration: Int = 2 * 60 * 60
    @State private var goalProgressSeconds: Int = 0
    @State private var selectedMood: Mood = .none

    @State private var studyMinutes: Int = 25
    @State private var studySeconds: Int = 0
    @State private var breakMinutes: Int = 5
    @State private var breakSeconds: Int = 0

    @State private var focusState: FocusState = .idle
    @State private var currentPhase: SessionPhase = .study
    @State private var remainingPhaseSeconds: Int? = nil
    @State private var statusPrompt: String = ""

    @State private var moodPlayer: AVAudioPlayer?
    @State private var alarmPlayer: AVAudioPlayer?
    @State private var alarmStopWorkItem: DispatchWorkItem?
    @State private var pendingStudySeconds: Int = 0
    @State private var pendingBreakSeconds: Int = 0
    @State private var pendingSessionsCount: Int = 0
    @State private var showBreakStartPrompt = false
    @State private var showBreakEndedPrompt = false
    @State private var awaitingBreakChoice = false
    @State private var awaitingBreakEndAcknowledge = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var studyDurationSeconds: Int {
        max((studyMinutes * 60) + studySeconds, 1)
    }

    private var breakDurationSeconds: Int {
        max((breakMinutes * 60) + breakSeconds, 1)
    }

    private var ringProgress: Double {
        guard goalDuration > 0 else { return 0 }
        return min(Double(goalProgressSeconds) / Double(goalDuration), 1.0)
    }

    private var remainingGoalSeconds: Int {
        max(goalDuration - goalProgressSeconds, 0)
    }

    private var phaseTitle: String {
        switch currentPhase {
        case .study:
            return "Study"
        case .break:
            return "Break"
        }
    }

    private var phaseRemainingLabel: String {
        formatDuration(remainingPhaseSeconds ?? 0)
    }

    private var focusButtonTitle: String {
        switch focusState {
        case .idle:
            return "Start Focus"
        case .running:
            return "Pause Focus"
        case .paused:
            return "Resume Focus"
        }
    }

    private var currentStreakDays: Int {
        let goal = max(goalDuration, 1)
        let byDay = studySecondsByDay()
        var streak = 0
        var cursor = Calendar.current.startOfDay(for: Date())

        while true {
            let seconds = byDay[cursor, default: 0]
            if seconds >= goal {
                streak += 1
                guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = previous
            } else {
                break
            }
        }
        return streak
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color(red: 0.1, green: 0.0, blue: 0.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        NavigationLink {
                            ProfileView()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "person.circle.fill")
                                Text("My Profile")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.75))
                            .clipShape(Capsule())
                        }
                        Spacer()

                        NavigationLink {
                            ProgressView()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.red)
                                Text("\(currentStreakDays)")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }

                    VStack(spacing: 14) {
                        NavigationLink {
                            SetGoalView(goalDuration: $goalDuration)
                        } label: {
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 20))

                                Circle()
                                    .trim(from: 0, to: ringProgress)
                                    .stroke(
                                        Color.red,
                                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                                    .animation(.easeInOut(duration: 0.25), value: ringProgress)

                                VStack(spacing: 6) {
                                    Text("\(Int(ringProgress * 100))%")
                                        .font(.system(size: 30, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Goal Complete")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.white.opacity(0.9))
                                    Text("Tap to Set Goal")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .frame(width: 220, height: 220)
                        }
                        .frame(maxWidth: .infinity)

                        Text("Remaining Goal Time: \(formatDuration(remainingGoalSeconds))")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Set Mood")
                            .font(.title3.bold())
                            .foregroundColor(.white)

                        HStack(spacing: 10) {
                            ForEach(Mood.allCases, id: \.self) { mood in
                                Button(mood.rawValue) {
                                    selectedMood = mood
                                }
                                .font(.subheadline.weight(selectedMood == mood ? .bold : .regular))
                                .foregroundColor(selectedMood == mood ? .black : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(selectedMood == mood ? Color.white : Color.red)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pomodoro Settings")
                            .font(.title3.bold())
                            .foregroundColor(.white)

                        HStack(spacing: 12) {
                            TimePickerCard(
                                title: "Study Time",
                                minuteSelection: $studyMinutes,
                                secondSelection: $studySeconds
                            )
                            TimePickerCard(
                                title: "Break Time",
                                minuteSelection: $breakMinutes,
                                secondSelection: $breakSeconds
                            )
                        }
                        .frame(height: 120)
                    }

                    Button(action: toggleFocus) {
                        Text(focusButtonTitle)
                            .font(.headline.bold())
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    if focusState != .idle {
                        Button(action: stopFocusCycle) {
                            Text("Stop Focus")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.red.opacity(0.85))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    if focusState != .idle {
                        Text("\(phaseTitle) Time Left: \(phaseRemainingLabel)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                    }

                    if !statusPrompt.isEmpty {
                        Text(statusPrompt)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(20)
            }

            if showBreakStartPrompt {
                promptOverlay(
                    title: "Congratulations! Take a short break!",
                    primaryTitle: "Okay",
                    secondaryTitle: "Skip Break",
                    primaryAction: {
                        stopAlarmAudio()
                        awaitingBreakChoice = false
                        showBreakStartPrompt = false
                    },
                    secondaryAction: {
                        stopAlarmAudio()
                        showBreakStartPrompt = false
                        skipBreakAndResumeStudy()
                    }
                )
            }

            if showBreakEndedPrompt {
                promptOverlay(
                    title: "Break ended! Back to Focus.",
                    primaryTitle: "Okay",
                    secondaryTitle: nil,
                    primaryAction: {
                        stopAlarmAudio()
                        awaitingBreakEndAcknowledge = false
                        showBreakEndedPrompt = false
                        pendingSessionsCount += 1
                        playMoodLoopIfNeeded()
                    },
                    secondaryAction: {}
                )
            }
        }
        .onReceive(ticker) { _ in
            tick()
        }
        .onAppear {
            configureAudioSession()
        }
        .onChange(of: selectedMood) {
            updateMoodAudioForCurrentState()
        }
        .onDisappear {
            flushPendingDurations()
            stopAllAudio()
        }
        #if os(iOS)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    private func toggleFocus() {
        switch focusState {
        case .idle:
            guard remainingGoalSeconds > 0 else {
                statusPrompt = "Study goal already completed. Set a new goal to continue."
                return
            }
            awaitingBreakChoice = false
            awaitingBreakEndAcknowledge = false
            showBreakStartPrompt = false
            showBreakEndedPrompt = false
            stopAlarmAudio()
            currentPhase = .study
            remainingPhaseSeconds = studyDurationSeconds
            pendingSessionsCount += 1
            statusPrompt = ""
            focusState = .running
            playMoodLoopIfNeeded()
        case .running:
            focusState = .paused
            pauseMoodAudioIfNeeded()
            flushPendingDurations()
        case .paused:
            focusState = .running
            playMoodLoopIfNeeded()
        }
    }

    private func stopFocusCycle() {
        flushPendingDurations()
        focusState = .idle
        currentPhase = .study
        remainingPhaseSeconds = nil
        statusPrompt = ""
        awaitingBreakChoice = false
        awaitingBreakEndAcknowledge = false
        showBreakStartPrompt = false
        showBreakEndedPrompt = false
        stopAllAudio()
    }

    private func tick() {
        guard focusState == .running else { return }
        guard !awaitingBreakChoice, !awaitingBreakEndAcknowledge else { return }
        guard let seconds = remainingPhaseSeconds else { return }

        if seconds > 0 {
            remainingPhaseSeconds = seconds - 1
            if currentPhase == .study, goalProgressSeconds < goalDuration {
                goalProgressSeconds += 1
                pendingStudySeconds += 1
            } else if currentPhase == .break {
            pendingBreakSeconds += 1
            }
        }

        if goalProgressSeconds >= goalDuration {
            flushPendingDurations()
            focusState = .idle
            currentPhase = .study
            remainingPhaseSeconds = nil
            statusPrompt = "Study goal completed. Great work!"
            stopAllAudio()
            return
        }

        if (remainingPhaseSeconds ?? 0) <= 0 {
            handlePhaseCompleted()
        }
    }

    private func handlePhaseCompleted() {
        switch currentPhase {
        case .study:
            flushPendingDurations()
            startAlarmLoop()
            statusPrompt = "Congratulations! Take a short break!"
            currentPhase = .break
            remainingPhaseSeconds = breakDurationSeconds
            awaitingBreakChoice = true
            showBreakStartPrompt = true
            stopMoodAudio()
        case .break:
            startAlarmLoop()
            statusPrompt = "Break ended! Back to Focus."
            currentPhase = .study
            remainingPhaseSeconds = studyDurationSeconds
            awaitingBreakEndAcknowledge = true
            showBreakEndedPrompt = true
            stopMoodAudio()
        }
    }

    private func skipBreakAndResumeStudy() {
        flushPendingDurations()
        awaitingBreakChoice = false
        currentPhase = .study
        remainingPhaseSeconds = studyDurationSeconds
        pendingSessionsCount += 1
        statusPrompt = "Break skipped. Back to Focus."
        playMoodLoopIfNeeded()
    }

    private func updateMoodAudioForCurrentState() {
        guard focusState == .running, currentPhase == .study else { return }
        playMoodLoopIfNeeded()
    }

    private func configureAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error.localizedDescription)")
        }
        #endif
    }

    private func playMoodLoopIfNeeded() {
        guard focusState == .running, currentPhase == .study else { return }
        guard let fileName = moodFileName(for: selectedMood) else {
            stopMoodAudio()
            return
        }
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "wav") else { return }

        do {
            if moodPlayer?.url == url, moodPlayer?.isPlaying == true {
                return
            }
            moodPlayer?.stop()
            moodPlayer = try AVAudioPlayer(contentsOf: url)
            moodPlayer?.numberOfLoops = -1
            moodPlayer?.prepareToPlay()
            moodPlayer?.play()
        } catch {
            print("Audio error: \(error.localizedDescription)")
        }
    }

    private func pauseMoodAudioIfNeeded() {
        guard currentPhase == .study else { return }
        moodPlayer?.pause()
    }

    private func stopMoodAudio() {
        moodPlayer?.stop()
        moodPlayer?.currentTime = 0
    }

    private func startAlarmLoop() {
        alarmStopWorkItem?.cancel()
        alarmPlayer?.stop()
        let alarmURL = Bundle.main.url(forResource: "Alarm", withExtension: "wav")
            ?? Bundle.main.url(forResource: "alarm", withExtension: "wav")
        guard let url = alarmURL else { return }

        do {
            alarmPlayer = try AVAudioPlayer(contentsOf: url)
            alarmPlayer?.numberOfLoops = -1
            alarmPlayer?.prepareToPlay()
            alarmPlayer?.play()
        } catch {
            print("Alarm error: \(error.localizedDescription)")
        }
    }

    private func stopAlarmAudio() {
        alarmStopWorkItem?.cancel()
        alarmStopWorkItem = nil
        alarmPlayer?.stop()
        alarmPlayer?.currentTime = 0
    }

    private func stopAllAudio() {
        stopAlarmAudio()
        stopMoodAudio()
    }

    @ViewBuilder
    private func promptOverlay(
        title: String,
        primaryTitle: String,
        secondaryTitle: String?,
        primaryAction: @escaping () -> Void,
        secondaryAction: @escaping () -> Void
    ) -> some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.black.opacity(0.85))
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    if let secondaryTitle {
                        Button(secondaryTitle, action: secondaryAction)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.black.opacity(0.82))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.white.opacity(0.72))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button(primaryTitle, action: primaryAction)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.red.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: 360)
            .background(Color.white.opacity(0.88))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.95), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 24)
        }
    }

    private func flushPendingDurations() {
        guard pendingStudySeconds > 0 || pendingBreakSeconds > 0 || pendingSessionsCount > 0 else { return }
        let dayStart = Calendar.current.startOfDay(for: Date())
        let predicate = #Predicate<DailyStudyRecord> { $0.date == dayStart }
        var descriptor = FetchDescriptor<DailyStudyRecord>(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            if let existing = try modelContext.fetch(descriptor).first {
                existing.studySeconds += pendingStudySeconds
                existing.breakSeconds += pendingBreakSeconds
                existing.sessionsCount += pendingSessionsCount
            } else {
                modelContext.insert(
                    DailyStudyRecord(
                        date: dayStart,
                        studySeconds: pendingStudySeconds,
                        breakSeconds: pendingBreakSeconds,
                        sessionsCount: pendingSessionsCount
                    )
                )
            }
            try modelContext.save()
            pendingStudySeconds = 0
            pendingBreakSeconds = 0
            pendingSessionsCount = 0
        } catch {
            print("Save study record error: \(error.localizedDescription)")
        }
    }

    private func studySecondsByDay() -> [Date: Int] {
        var result: [Date: Int] = [:]
        for record in records {
            let day = Calendar.current.startOfDay(for: record.date)
            result[day, default: 0] += max(record.studySeconds, 0)
        }
        return result
    }

    private func moodFileName(for mood: Mood) -> String? {
        switch mood {
        case .piano:
            return "Piano"
        case .violin:
            return "Violin"
        case .guitar:
            return "Guitar"
        case .none:
            return nil
        }
    }

    private func formatDuration(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        return String(format: "%02dh %02dm %02ds", hours, minutes, seconds)
    }
}

private struct TimePickerCard: View {
    let title: String
    @Binding var minuteSelection: Int
    @Binding var secondSelection: Int

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.white)

            HStack(spacing: 0) {
                Picker("Minutes", selection: $minuteSelection) {
                    ForEach(0..<60, id: \.self) { value in
                        Text("\(value)m")
                            .foregroundStyle(.white)
                            .tag(value)
                    }
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #else
                .pickerStyle(.wheel)
                #endif

                Picker("Seconds", selection: $secondSelection) {
                    ForEach(0..<60, id: \.self) { value in
                        Text("\(value)s")
                            .foregroundStyle(.white)
                            .tag(value)
                    }
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #else
                .pickerStyle(.wheel)
                #endif
            }
            .frame(height: 84)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
