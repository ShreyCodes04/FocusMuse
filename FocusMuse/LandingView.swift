import SwiftUI
import Combine
import AVFoundation
import SwiftData

struct LandingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
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
    @AppStorage("today_study_progress_seconds") private var todayStudyProgressSeconds: Int = 0
    @AppStorage("today_study_progress_day_key") private var todayStudyProgressDayKey: String = ""
    @AppStorage("today_break_progress_seconds") private var todayBreakProgressSeconds: Int = 0
    @AppStorage("today_break_progress_day_key") private var todayBreakProgressDayKey: String = ""
    @AppStorage("pomodoro_sessions_total_count") private var pomodoroSessionsTotalCount: Int = 0
    @AppStorage("focus_live_total_seconds") private var focusLiveTotalSeconds: Int = 0
    @AppStorage("break_live_total_seconds") private var breakLiveTotalSeconds: Int = 0
    @State private var goalProgressSeconds: Int = 0
    @AppStorage("selected_mood_raw") private var selectedMoodRaw: String = Mood.none.rawValue
    @AppStorage("focus_state_raw") private var focusStateRaw: String = "idle"
    @AppStorage("session_phase_raw") private var sessionPhaseRaw: String = "study"
    @AppStorage("remaining_phase_seconds") private var remainingPhaseSecondsStored: Int = 0
    @AppStorage("focus_status_prompt") private var focusStatusPromptStored: String = ""
    @State private var selectedMood: Mood = .none

    @AppStorage("study_minutes") private var studyMinutes: Int = 25
    @AppStorage("study_seconds") private var studySeconds: Int = 0
    @AppStorage("break_minutes") private var breakMinutes: Int = 5
    @AppStorage("break_seconds") private var breakSeconds: Int = 0

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
    @State private var showGoalReachedPrompt = false
    @State private var showGoalCelebration = false
    @State private var navigateToSetGoalFromPrompt = false
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

    private var todayDayKey: String {
        dayKey(for: Date())
    }

    private var ringActionText: String {
        goalProgressSeconds >= goalDuration ? "Tap to Increase Goal" : "Tap to Set Goal"
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

    private var currentPhaseDurationSeconds: Int {
        switch currentPhase {
        case .study:
            return studyDurationSeconds
        case .break:
            return breakDurationSeconds
        }
    }

    private var phaseProgress: Double {
        let total = max(currentPhaseDurationSeconds, 1)
        let remaining = max(remainingPhaseSeconds ?? total, 0)
        return min(max(1.0 - (Double(remaining) / Double(total)), 0), 1)
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
                                    Text(ringActionText)
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
                        HStack(spacing: 12) {
                            HourglassSandClockView(
                                isRunning: focusState == .running && currentPhase == .study
                            )
                            .frame(width: 56, height: 78)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentPhase == .study ? "Remaining Study Time" : "Remaining Break Time")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.black.opacity(0.72))

                                Text(phaseRemainingLabel)
                                    .font(.title3.bold())
                                    .foregroundColor(.black.opacity(0.88))
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.yellow.opacity(0.96))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
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

            if showGoalCelebration {
                GoalCelebrationOverlayView()
                    .transition(.opacity)
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
                        registerSessionExecution()
                        playMoodLoopIfNeeded()
                    },
                    secondaryAction: {}
                )
            }

            if showGoalReachedPrompt {
                promptOverlay(
                    title: "Congratulations you've met your Daily Goal! Want to increase your Goal?",
                    primaryTitle: "Yes",
                    secondaryTitle: "No",
                    primaryAction: {
                        showGoalReachedPrompt = false
                        navigateToSetGoalFromPrompt = true
                    },
                    secondaryAction: {
                        showGoalReachedPrompt = false
                    }
                )
            }
        }
        .onReceive(ticker) { _ in
            tick()
        }
        .onAppear {
            configureAudioSession()
            resetDailySnapshotIfNeeded()
            selectedMood = Mood(rawValue: selectedMoodRaw) ?? .none
            syncLiveTotalsFromRecords()
            refreshTodayProgress()
            refreshTodayBreakProgress()
            restoreFocusSessionState()
        }
        .onChange(of: selectedMood) {
            selectedMoodRaw = selectedMood.rawValue
            updateMoodAudioForCurrentState()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                flushPendingDurations()
                stopAllAudio()
                persistFocusSessionState()
            } else if newPhase == .active {
                resetDailySnapshotIfNeeded()
                syncLiveTotalsFromRecords()
                refreshTodayProgress()
                refreshTodayBreakProgress()
            }
        }
        .onChange(of: goalDuration) { _, _ in
            refreshTodayProgress()
        }
        .onDisappear {
            flushPendingDurations()
            stopAllAudio()
        }
        #if os(iOS)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationDestination(isPresented: $navigateToSetGoalFromPrompt) {
            SetGoalView(goalDuration: $goalDuration)
        }
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
            registerSessionExecution()
            statusPrompt = ""
            focusState = .running
            playMoodLoopIfNeeded()
            persistFocusSessionState()
        case .running:
            focusState = .paused
            pauseMoodAudioIfNeeded()
            flushPendingDurations()
            persistFocusSessionState()
        case .paused:
            focusState = .running
            playMoodLoopIfNeeded()
            persistFocusSessionState()
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
        clearPersistedFocusSessionState()
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
                focusLiveTotalSeconds += 1
                persistTodayProgressSnapshot()
            } else if currentPhase == .break {
                pendingBreakSeconds += 1
                breakLiveTotalSeconds += 1
                persistTodayBreakSnapshot()
            }

            if pendingStudySeconds + pendingBreakSeconds >= 15 {
                flushPendingDurations()
            }
        }

        if goalProgressSeconds >= goalDuration {
            completeDailyGoalFlow()
            return
        }

        if (remainingPhaseSeconds ?? 0) <= 0 {
            handlePhaseCompleted()
        }
        persistFocusSessionState()
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
        registerSessionExecution()
        statusPrompt = "Break skipped. Back to Focus."
        playMoodLoopIfNeeded()
        persistFocusSessionState()
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
        let today = Calendar.current.startOfDay(for: Date())
        let todayAccumulated = result[today, default: 0] + pendingStudySeconds
        result[today] = max(todayAccumulated, goalProgressSeconds)
        return result
    }

    private func refreshTodayProgress() {
        resetDailySnapshotIfNeeded()
        let today = Calendar.current.startOfDay(for: Date())
        let todayTotal = records
            .filter { Calendar.current.startOfDay(for: $0.date) == today }
            .reduce(0) { $0 + max($1.studySeconds, 0) }
        let liveTotal = todayTotal + pendingStudySeconds
        let snapshot = todayStudyProgressDayKey == todayDayKey ? todayStudyProgressSeconds : 0
        goalProgressSeconds = min(max(liveTotal, snapshot), goalDuration)
        persistTodayProgressSnapshot()
    }

    private func refreshTodayBreakProgress() {
        resetDailySnapshotIfNeeded()
        let today = Calendar.current.startOfDay(for: Date())
        let todayTotalBreak = records
            .filter { Calendar.current.startOfDay(for: $0.date) == today }
            .reduce(0) { $0 + max($1.breakSeconds, 0) }
        let liveTotalBreak = todayTotalBreak + pendingBreakSeconds
        let snapshot = todayBreakProgressDayKey == todayDayKey ? todayBreakProgressSeconds : 0
        todayBreakProgressSeconds = max(liveTotalBreak, snapshot)
        todayBreakProgressDayKey = todayDayKey
    }

    private func syncLiveTotalsFromRecords() {
        let persistedFocus = records.reduce(0) { $0 + max($1.studySeconds, 0) }
        let persistedBreak = records.reduce(0) { $0 + max($1.breakSeconds, 0) }
        focusLiveTotalSeconds = max(focusLiveTotalSeconds, persistedFocus)
        breakLiveTotalSeconds = max(breakLiveTotalSeconds, persistedBreak)
    }

    private func completeDailyGoalFlow() {
        flushPendingDurations()
        persistTodayProgressSnapshot()
        focusState = .idle
        currentPhase = .study
        remainingPhaseSeconds = nil
        awaitingBreakChoice = false
        awaitingBreakEndAcknowledge = false
        showBreakStartPrompt = false
        showBreakEndedPrompt = false
        statusPrompt = "Study goal completed. Great work!"
        stopAllAudio()
        showGoalCelebration = true
        showGoalReachedPrompt = true
        clearPersistedFocusSessionState()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                showGoalCelebration = false
            }
        }
    }

    private func persistFocusSessionState() {
        focusStateRaw = focusStateStorageValue(for: focusState)
        sessionPhaseRaw = sessionPhaseStorageValue(for: currentPhase)
        remainingPhaseSecondsStored = max(remainingPhaseSeconds ?? 0, 0)
        focusStatusPromptStored = statusPrompt
    }

    private func restoreFocusSessionState() {
        currentPhase = sessionPhase(from: sessionPhaseRaw)
        let storedState = focusState(from: focusStateRaw)
        let storedRemaining = max(remainingPhaseSecondsStored, 0)

        guard storedState != .idle, storedRemaining > 0 else {
            clearPersistedFocusSessionState()
            return
        }

        focusState = .paused
        remainingPhaseSeconds = storedRemaining
        statusPrompt = focusStatusPromptStored.isEmpty
            ? "Session restored. Tap Resume Focus to continue."
            : focusStatusPromptStored
        showBreakStartPrompt = false
        showBreakEndedPrompt = false
        awaitingBreakChoice = false
        awaitingBreakEndAcknowledge = false
    }

    private func clearPersistedFocusSessionState() {
        focusStateRaw = "idle"
        sessionPhaseRaw = "study"
        remainingPhaseSecondsStored = 0
        focusStatusPromptStored = ""
    }

    private func focusStateStorageValue(for state: FocusState) -> String {
        switch state {
        case .idle:
            return "idle"
        case .running:
            return "running"
        case .paused:
            return "paused"
        }
    }

    private func focusState(from raw: String) -> FocusState {
        switch raw {
        case "running":
            return .running
        case "paused":
            return .paused
        default:
            return .idle
        }
    }

    private func sessionPhaseStorageValue(for phase: SessionPhase) -> String {
        switch phase {
        case .study:
            return "study"
        case .break:
            return "break"
        }
    }

    private func sessionPhase(from raw: String) -> SessionPhase {
        raw == "break" ? .break : .study
    }

    private func registerSessionExecution() {
        pendingSessionsCount += 1
        pomodoroSessionsTotalCount += 1
    }

    private func persistTodayProgressSnapshot() {
        resetDailySnapshotIfNeeded()
        let key = todayDayKey
        todayStudyProgressDayKey = key
        todayStudyProgressSeconds = max(todayStudyProgressSeconds, goalProgressSeconds)
    }

    private func persistTodayBreakSnapshot() {
        resetDailySnapshotIfNeeded()
        todayBreakProgressDayKey = todayDayKey
        todayBreakProgressSeconds = max(todayBreakProgressSeconds, todayBreakProgressSeconds + 1)
    }

    private func resetDailySnapshotIfNeeded() {
        if todayStudyProgressDayKey != todayDayKey {
            todayStudyProgressDayKey = todayDayKey
            todayStudyProgressSeconds = 0
        }
        if todayBreakProgressDayKey != todayDayKey {
            todayBreakProgressDayKey = todayDayKey
            todayBreakProgressSeconds = 0
        }
    }

    private func dayKey(for date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
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

private struct GoalCelebrationOverlayView: View {
    private struct Particle: Identifiable {
        let id: Int
        let angle: Double
        let distance: CGFloat
        let size: CGFloat
        let delay: Double
        let color: Color
    }

    private let particles: [Particle] = (0..<34).map { index in
        let baseAngle = Double(index) * (360.0 / 34.0)
        return Particle(
            id: index,
            angle: baseAngle + Double.random(in: -8...8),
            distance: CGFloat.random(in: 90...190),
            size: CGFloat.random(in: 5...10),
            delay: Double.random(in: 0...0.15),
            color: [Color.red, Color.white, Color.orange, Color.yellow][index % 4]
        )
    }

    @State private var animate = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .offset(x: animate ? xOffset(for: particle) : 0, y: animate ? yOffset(for: particle) : 0)
                        .opacity(animate ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.05).delay(particle.delay),
                            value: animate
                        )
                }
            }
            .frame(width: 250, height: 250)
        }
        .allowsHitTesting(false)
        .onAppear {
            animate = false
            DispatchQueue.main.async {
                animate = true
            }
        }
    }

    private func xOffset(for particle: Particle) -> CGFloat {
        let radians = particle.angle * .pi / 180
        return cos(radians) * particle.distance
    }

    private func yOffset(for particle: Particle) -> CGFloat {
        let radians = particle.angle * .pi / 180
        return sin(radians) * particle.distance
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

private struct HourglassSandClockView: View {
    let isRunning: Bool
    @State private var elapsedAccumulated: TimeInterval = 0
    @State private var runStart: Date? = nil

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isRunning)) { context in
            let params = animationParameters(at: context.date)

            Canvas { canvas, size in
                drawHourglass(
                    in: size,
                    fillProgress: params.fillProgress,
                    flowProgress: params.flowProgress,
                    isFlipping: params.isFlipping,
                    canvas: &canvas
                )
            }
            .rotationEffect(.degrees(params.rotationDegrees))
        }
        .onAppear {
            if isRunning {
                runStart = Date()
            }
        }
        .onChange(of: isRunning) { _, running in
            if running {
                runStart = Date()
            } else if let start = runStart {
                elapsedAccumulated += Date().timeIntervalSince(start)
                runStart = nil
            }
        }
    }

    private func drawHourglass(
        in size: CGSize,
        fillProgress: Double,
        flowProgress: Double,
        isFlipping: Bool,
        canvas: inout GraphicsContext
    ) {
        let width = size.width
        let height = size.height
        let centerX = width / 2.0
        let left = width * 0.2
        let right = width * 0.8
        let topY = height * 0.12
        let bottomY = height * 0.88
        let midY = height * 0.5
        let neckHalfWidth = width * 0.075
        let capRadius = width * 0.07

        let framePath = Path { path in
            path.move(to: CGPoint(x: left + capRadius, y: topY))
            path.addQuadCurve(
                to: CGPoint(x: right - capRadius, y: topY),
                control: CGPoint(x: centerX, y: topY - capRadius * 0.9)
            )
            path.addQuadCurve(
                to: CGPoint(x: centerX + neckHalfWidth, y: midY),
                control: CGPoint(x: right + capRadius * 0.55, y: topY + ((midY - topY) * 0.33))
            )
            path.addQuadCurve(
                to: CGPoint(x: right - capRadius, y: bottomY),
                control: CGPoint(x: right + capRadius * 0.55, y: bottomY - ((bottomY - midY) * 0.33))
            )
            path.addQuadCurve(
                to: CGPoint(x: left + capRadius, y: bottomY),
                control: CGPoint(x: centerX, y: bottomY + capRadius * 0.9)
            )
            path.addQuadCurve(
                to: CGPoint(x: centerX - neckHalfWidth, y: midY),
                control: CGPoint(x: left - capRadius * 0.55, y: bottomY - ((bottomY - midY) * 0.33))
            )
            path.addQuadCurve(
                to: CGPoint(x: left + capRadius, y: topY),
                control: CGPoint(x: left - capRadius * 0.55, y: topY + ((midY - topY) * 0.33))
            )
            path.closeSubpath()
        }

        canvas.fill(
            framePath,
            with: .linearGradient(
                Gradient(colors: [Color.white.opacity(0.14), Color.white.opacity(0.04)]),
                startPoint: CGPoint(x: centerX, y: topY - 6),
                endPoint: CGPoint(x: centerX, y: bottomY + 6)
            )
        )
        canvas.stroke(framePath, with: .color(.white.opacity(0.92)), lineWidth: 2)
        canvas.stroke(framePath, with: .color(.white.opacity(0.22)), lineWidth: 4)

        let glassShine = Path { path in
            path.move(to: CGPoint(x: left + capRadius * 1.2, y: topY + 7))
            path.addQuadCurve(
                to: CGPoint(x: centerX - neckHalfWidth * 1.2, y: midY - 5),
                control: CGPoint(x: left + capRadius * 0.1, y: topY + ((midY - topY) * 0.35))
            )
            path.move(to: CGPoint(x: left + capRadius * 1.3, y: bottomY - 8))
            path.addQuadCurve(
                to: CGPoint(x: centerX - neckHalfWidth * 1.2, y: midY + 5),
                control: CGPoint(x: left + capRadius * 0.1, y: bottomY - ((bottomY - midY) * 0.35))
            )
        }
        canvas.stroke(glassShine, with: .color(.white.opacity(0.28)), lineWidth: 1.6)

        let topBulbPath = Path { path in
            path.move(to: CGPoint(x: left + capRadius, y: topY))
            path.addQuadCurve(
                to: CGPoint(x: right - capRadius, y: topY),
                control: CGPoint(x: centerX, y: topY - capRadius * 0.9)
            )
            path.addQuadCurve(
                to: CGPoint(x: centerX + neckHalfWidth, y: midY),
                control: CGPoint(x: right + capRadius * 0.55, y: topY + ((midY - topY) * 0.33))
            )
            path.addLine(to: CGPoint(x: centerX - neckHalfWidth, y: midY))
            path.addQuadCurve(
                to: CGPoint(x: left + capRadius, y: topY),
                control: CGPoint(x: left - capRadius * 0.55, y: topY + ((midY - topY) * 0.33))
            )
            path.closeSubpath()
        }

        let bottomBulbPath = Path { path in
            path.move(to: CGPoint(x: centerX - neckHalfWidth, y: midY))
            path.addQuadCurve(
                to: CGPoint(x: left + capRadius, y: bottomY),
                control: CGPoint(x: left - capRadius * 0.55, y: bottomY - ((bottomY - midY) * 0.33))
            )
            path.addQuadCurve(
                to: CGPoint(x: right - capRadius, y: bottomY),
                control: CGPoint(x: centerX, y: bottomY + capRadius * 0.9)
            )
            path.addQuadCurve(
                to: CGPoint(x: centerX + neckHalfWidth, y: midY),
                control: CGPoint(x: right + capRadius * 0.55, y: bottomY - ((bottomY - midY) * 0.33))
            )
            path.closeSubpath()
        }

        let topStartY = topY + 2
        let easedFill = easeInOut(fillProgress)
        let topSandY = topStartY + CGFloat(easedFill) * (midY - topStartY - 3)
        var topLayer = canvas
        topLayer.clip(to: topBulbPath)
        topLayer.fill(
            Path(CGRect(
                x: left - 20,
                y: topSandY,
                width: (right - left) + 40,
                height: (midY - topSandY) + 8
            )),
            with: .linearGradient(
                Gradient(colors: [Color.red.opacity(0.95), Color.red.opacity(0.82)]),
                startPoint: CGPoint(x: centerX, y: topSandY),
                endPoint: CGPoint(x: centerX, y: midY + 6)
            )
        )

        // Lower bulb fills strictly from the bottom base upward.
        let bottomSandY = bottomY - CGFloat(easedFill) * (bottomY - midY - 3)
        var bottomLayer = canvas
        bottomLayer.clip(to: bottomBulbPath)
        bottomLayer.fill(
            Path(CGRect(
                x: left - 20,
                y: bottomSandY,
                width: (right - left) + 40,
                height: (bottomY - bottomSandY) + 10
            )),
            with: .linearGradient(
                Gradient(colors: [Color.red.opacity(0.78), Color.red.opacity(0.95)]),
                startPoint: CGPoint(x: centerX, y: bottomSandY),
                endPoint: CGPoint(x: centerX, y: bottomY + 8)
            )
        )

        if !isFlipping {
            let streamBottomY = max(bottomSandY - 1, midY + 6)
            let streamPulse = CGFloat(1.0 + (0.16 * sin(flowProgress * .pi * 2)))
            let streamWidth = 2.2 * streamPulse
            let streamRect = CGRect(
                x: centerX - (streamWidth / 2),
                y: midY + 1.5,
                width: streamWidth,
                height: max(streamBottomY - (midY + 1.5), 2)
            )
            canvas.fill(Path(roundedRect: streamRect, cornerRadius: streamWidth / 2), with: .color(.red))

            for grain in 0..<3 {
                let phase = (flowProgress + (Double(grain) * 0.28)).truncatingRemainder(dividingBy: 1.0)
                let particleY = midY + CGFloat(phase) * max(streamBottomY - midY, 4)
                let xJitter = CGFloat(sin((phase + Double(grain)) * .pi * 2)) * 1.2
                let size = 2.6 + CGFloat(grain) * 0.6
                let particleRect = CGRect(
                    x: (centerX - (size / 2)) + xJitter,
                    y: particleY,
                    width: size,
                    height: size
                )
                canvas.fill(Path(ellipseIn: particleRect), with: .color(.red.opacity(0.96)))
            }
        }
    }

    private func animationParameters(at now: Date) -> (fillProgress: Double, flowProgress: Double, rotationDegrees: Double, isFlipping: Bool) {
        let fillDuration: TimeInterval = 6.2
        let flipDuration: TimeInterval = 0.55
        let totalCycle = fillDuration + flipDuration

        let elapsed = currentElapsed(at: now)
        let cycleIndex = Int(floor(elapsed / totalCycle))
        let phase = elapsed - (Double(cycleIndex) * totalCycle)
        let isOddCycle = cycleIndex % 2 == 1

        if phase < fillDuration {
            let rawFill = max(min(phase / fillDuration, 1), 0)
            let fill = isOddCycle ? (1.0 - rawFill) : rawFill
            let flowDuration: TimeInterval = 0.85
            let flow = phase.truncatingRemainder(dividingBy: flowDuration) / flowDuration
            return (fill, flow, Double(cycleIndex) * 180.0, false)
        }

        let flip = max(min((phase - fillDuration) / flipDuration, 1), 0)
        let fillAtFlip = isOddCycle ? 0.0 : 1.0
        return (fillAtFlip, 1.0, (Double(cycleIndex) + flip) * 180.0, true)
    }

    private func currentElapsed(at now: Date) -> TimeInterval {
        if isRunning, let runStart {
            return elapsedAccumulated + now.timeIntervalSince(runStart)
        }
        return elapsedAccumulated
    }

    private func easeInOut(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        return t < 0.5 ? (4 * t * t * t) : (1 - pow(-2 * t + 2, 3) / 2)
    }
}
