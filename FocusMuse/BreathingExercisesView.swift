import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

private enum BreathingExerciseType: String, CaseIterable, Identifiable, Hashable {
    case box
    case longExhale
    case equal
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .box: return "Box Breathing"
        case .longExhale: return "Long Exhale"
        case .equal: return "Equal Breathing"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .box: return "square.dashed"
        case .longExhale: return "lungs.fill"
        case .equal: return "target"
        case .custom: return "slider.horizontal.3"
        }
    }

    var purpose: String {
        switch self {
        case .box: return "Relaxation"
        case .longExhale: return "Sleep"
        case .equal: return "Focus"
        case .custom: return "Custom"
        }
    }

    var patternText: String {
        switch self {
        case .box: return "4-4-4-4"
        case .longExhale: return "4-7-8"
        case .equal: return "5-0-5"
        case .custom: return "3-2-5"
        }
    }

    var defaultPattern: BreathPattern {
        switch self {
        case .box: return BreathPattern(inhale: 4, hold: 4, exhale: 4)
        case .longExhale: return BreathPattern(inhale: 4, hold: 7, exhale: 8)
        case .equal: return BreathPattern(inhale: 5, hold: 0, exhale: 5)
        case .custom: return BreathPattern(inhale: 3, hold: 2, exhale: 5)
        }
    }
}

private struct BreathPattern: Hashable {
    var inhale: Int
    var hold: Int
    var exhale: Int

    var displayText: String {
        "\(inhale)-\(hold)-\(exhale)"
    }

    var cycleSeconds: Int {
        inhale + hold + exhale
    }
}

private struct BreathingSessionConfig: Hashable, Identifiable {
    let exercise: BreathingExerciseType
    let durationMinutes: Int
    let pattern: BreathPattern

    var id: String {
        "\(exercise.rawValue)-\(durationMinutes)-\(pattern.displayText)"
    }
}

private enum SettingsSheet: Identifiable {
    case duration(BreathingExerciseType)
    case custom

    var id: String {
        switch self {
        case let .duration(type): return "duration-\(type.rawValue)"
        case .custom: return "custom"
        }
    }
}

struct BreathingExercisesView: View {
    @State private var settingsSheet: SettingsSheet?
    @State private var pendingDuration = 5

    @AppStorage("breathing_box_duration_minutes") private var boxDuration = 5
    @AppStorage("breathing_long_exhale_duration_minutes") private var longExhaleDuration = 5
    @AppStorage("breathing_equal_duration_minutes") private var equalDuration = 5
    @AppStorage("breathing_custom_duration_minutes") private var customDuration = 5

    @AppStorage("breathing_custom_inhale_seconds") private var customInhale = 3
    @AppStorage("breathing_custom_hold_seconds") private var customHold = 2
    @AppStorage("breathing_custom_exhale_seconds") private var customExhale = 5

    @State private var activeSession: BreathingSessionConfig?

    private var customPattern: BreathPattern {
        BreathPattern(inhale: customInhale, hold: customHold, exhale: customExhale)
    }

    private var isSettingsOpen: Bool {
        settingsSheet != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Breathing Exercises")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.9)

                    Text("Choose a breathing exercise to practise")
                        .font(.title3.weight(.medium))
                        .foregroundColor(.white.opacity(0.7))
                }

                ForEach(BreathingExerciseType.allCases) { exercise in
                    breathingCard(for: exercise)
                }
            }
            .padding(20)
            .padding(.bottom, 120)
        }
        .scrollDisabled(isSettingsOpen)
        .background(
            LinearGradient(
                colors: [Color.black, Color(red: 0.2, green: 0.01, blue: 0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Breathing Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $settingsSheet) { item in
            switch item {
            case let .duration(type):
                DurationSettingsSheet(
                    title: "\(type.title) Settings",
                    selectedMinutes: $pendingDuration,
                    onCancel: {
                        settingsSheet = nil
                    },
                    onSave: {
                        applyDuration(pendingDuration, for: type)
                        performHaptic()
                        settingsSheet = nil
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)

            case .custom:
                CustomBreathingSettingsSheet(
                    inhale: $customInhale,
                    hold: $customHold,
                    exhale: $customExhale,
                    targetMinutes: $customDuration,
                    onCancel: {
                        settingsSheet = nil
                    },
                    onSave: {
                        performHaptic()
                        settingsSheet = nil
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .navigationDestination(item: $activeSession) { session in
            BreathingSessionView(config: session)
        }
    }

    private func breathingCard(for exercise: BreathingExerciseType) -> some View {
        Button {
            activeSession = BreathingSessionConfig(
                exercise: exercise,
                durationMinutes: duration(for: exercise),
                pattern: pattern(for: exercise)
            )
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.red.opacity(0.2))
                            Image(systemName: exercise.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 42, height: 42)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.title)
                                .font(.title3.weight(.bold))
                                .foregroundColor(.white)
                                .minimumScaleFactor(0.8)

                            Text(patternTitle(for: exercise))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white.opacity(0.82))
                        }
                    }

                    Spacer(minLength: 8)

                    Button {
                        openSettings(for: exercise)
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white.opacity(0.92))
                            .padding(10)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 16) {
                    infoPill(title: "Purpose", value: exercise.purpose)
                    infoPill(title: "Duration", value: "\(duration(for: exercise)) mins")
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black.opacity(0.34))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.24), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.red.opacity(0.22), radius: 16, x: 0, y: 10)
            .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(BreathingCardPressStyle())
    }

    private func infoPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.66))
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
    }

    private func patternTitle(for exercise: BreathingExerciseType) -> String {
        switch exercise {
        case .custom:
            return customPattern.displayText
        default:
            return exercise.patternText
        }
    }

    private func pattern(for exercise: BreathingExerciseType) -> BreathPattern {
        switch exercise {
        case .custom:
            return customPattern
        default:
            return exercise.defaultPattern
        }
    }

    private func duration(for exercise: BreathingExerciseType) -> Int {
        switch exercise {
        case .box:
            return boxDuration
        case .longExhale:
            return longExhaleDuration
        case .equal:
            return equalDuration
        case .custom:
            return customDuration
        }
    }

    private func applyDuration(_ minutes: Int, for exercise: BreathingExerciseType) {
        switch exercise {
        case .box:
            boxDuration = minutes
        case .longExhale:
            longExhaleDuration = minutes
        case .equal:
            equalDuration = minutes
        case .custom:
            customDuration = minutes
        }
    }

    private func openSettings(for exercise: BreathingExerciseType) {
        switch exercise {
        case .custom:
            settingsSheet = .custom
        default:
            pendingDuration = duration(for: exercise)
            settingsSheet = .duration(exercise)
        }
    }

    private func performHaptic() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
}

private struct DurationSettingsSheet: View {
    let title: String
    @Binding var selectedMinutes: Int
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundColor(.white)

            Text("Target Time (mins)")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.78))

            Picker("Target Time", selection: $selectedMinutes.animation(.spring(response: 0.28, dampingFraction: 0.82))) {
                ForEach(1..<61, id: \.self) { value in
                    Text("\(value) mins")
                        .foregroundStyle(.white)
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .colorScheme(.dark)

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(SheetActionStyle(isPrimary: false))
                Button("Save", action: onSave)
                    .buttonStyle(SheetActionStyle(isPrimary: true))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.95), Color(red: 0.2, green: 0.01, blue: 0.03).opacity(0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(.ultraThinMaterial.opacity(0.16))
        )
    }
}

private struct CustomBreathingSettingsSheet: View {
    @Binding var inhale: Int
    @Binding var hold: Int
    @Binding var exhale: Int
    @Binding var targetMinutes: Int
    let onCancel: () -> Void
    let onSave: () -> Void

    @State private var showingTargetPicker = false
    @State private var pendingTargetMinutes = 5

    private var cycleSeconds: Int {
        inhale + hold + exhale
    }

    private var patternText: String {
        "\(inhale)-\(hold)-\(exhale)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Set Breathing Pattern")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                Spacer(minLength: 8)
                Text(patternText)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.red)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Time Per Cycle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.78))
                Text("Time per cycle: \(cycleSeconds) seconds")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Breathing Pattern")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.78))

                HStack(spacing: 8) {
                    customPicker(title: "Inhale", range: 1...10, selection: $inhale)
                    customPicker(title: "Hold", range: 0...10, selection: $hold)
                    customPicker(title: "Exhale", range: 1...10, selection: $exhale)
                }
            }

            Button {
                pendingTargetMinutes = targetMinutes
                showingTargetPicker = true
            } label: {
                HStack {
                    Text("Breathing Target Time")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(targetMinutes) mins")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(SheetActionStyle(isPrimary: false))
                Button("Save", action: onSave)
                    .buttonStyle(SheetActionStyle(isPrimary: true))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.95), Color(red: 0.2, green: 0.01, blue: 0.03).opacity(0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(.ultraThinMaterial.opacity(0.16))
        )
        .sheet(isPresented: $showingTargetPicker) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Breathing Target Time")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)

                Picker("Minutes", selection: $pendingTargetMinutes.animation(.spring(response: 0.28, dampingFraction: 0.82))) {
                    ForEach(1..<61, id: \.self) { value in
                        Text("\(value) mins")
                            .foregroundStyle(.white)
                            .tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .colorScheme(.dark)

                HStack(spacing: 12) {
                    Button("Cancel") {
                        showingTargetPicker = false
                    }
                    .buttonStyle(SheetActionStyle(isPrimary: false))

                    Button("Save") {
                        targetMinutes = pendingTargetMinutes
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                        showingTargetPicker = false
                    }
                    .buttonStyle(SheetActionStyle(isPrimary: true))
                }
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.95), Color(red: 0.2, green: 0.01, blue: 0.03).opacity(0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .overlay(.ultraThinMaterial.opacity(0.16))
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private func customPicker(title: String, range: ClosedRange<Int>, selection: Binding<Int>) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.8))
            Picker(title, selection: selection.animation(.spring(response: 0.28, dampingFraction: 0.82))) {
                ForEach(range, id: \.self) { value in
                    Text("\(value)s")
                        .foregroundStyle(.white)
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity, maxHeight: 140)
            .clipped()
            .colorScheme(.dark)
        }
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct BreathingSessionView: View {
    let config: BreathingSessionConfig

    @State private var phaseIndex = 0
    @State private var secondsInCurrentPhase = 0
    @State private var remainingSeconds = 0
    @State private var circleScale: CGFloat = 0.74

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private struct SessionPhase {
        let title: String
        let duration: Int
        let targetScale: CGFloat
    }

    private var phases: [SessionPhase] {
        if config.exercise == .box {
            return [
                SessionPhase(title: "Inhale", duration: config.pattern.inhale, targetScale: 1.28),
                SessionPhase(title: "Hold", duration: config.pattern.hold, targetScale: 1.28),
                SessionPhase(title: "Exhale", duration: config.pattern.exhale, targetScale: 0.74),
                SessionPhase(title: "Hold", duration: config.pattern.hold, targetScale: 0.74)
            ].filter { $0.duration > 0 }
        }

        return [
            SessionPhase(title: "Inhale", duration: config.pattern.inhale, targetScale: 1.28),
            SessionPhase(title: "Hold", duration: config.pattern.hold, targetScale: 1.28),
            SessionPhase(title: "Exhale", duration: config.pattern.exhale, targetScale: 0.74)
        ].filter { $0.duration > 0 }
    }

    private var currentPhase: SessionPhase {
        phases[phaseIndex]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.2, green: 0.01, blue: 0.03)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 26) {
                Text(config.exercise.title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.8)

                Text(timeLabel)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()

                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 240, height: 240)
                        .blur(radius: 20)
                        .scaleEffect(circleScale)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.35), Color.red.opacity(0.92)],
                                center: .center,
                                startRadius: 30,
                                endRadius: 128
                            )
                        )
                        .frame(width: 210, height: 210)
                        .scaleEffect(circleScale)
                        .shadow(color: Color.red.opacity(0.45), radius: 24, x: 0, y: 8)
                }
                .animation(.easeInOut(duration: Double(max(currentPhase.duration, 1))), value: circleScale)

                Text(currentPhase.title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.18), value: currentPhase.title)

                Text("Pattern: \(patternLabel)")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.72))
            }
            .padding(24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            remainingSeconds = max(config.durationMinutes * 60, 1)
            phaseIndex = 0
            secondsInCurrentPhase = 0
            circleScale = 0.74
            DispatchQueue.main.async {
                circleScale = currentPhase.targetScale
            }
        }
        .onReceive(ticker) { _ in
            tick()
        }
    }

    private var timeLabel: String {
        let minutes = max(remainingSeconds, 0) / 60
        let seconds = max(remainingSeconds, 0) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var patternLabel: String {
        if config.exercise == .box {
            return "4-4-4-4"
        }
        return config.pattern.displayText
    }

    private func tick() {
        guard remainingSeconds > 0 else { return }

        remainingSeconds -= 1
        secondsInCurrentPhase += 1

        if secondsInCurrentPhase >= currentPhase.duration {
            secondsInCurrentPhase = 0
            phaseIndex = (phaseIndex + 1) % phases.count
            withAnimation(.easeInOut(duration: Double(max(currentPhase.duration, 1)))) {
                circleScale = currentPhase.targetScale
            }
        }
    }
}

private struct BreathingCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .brightness(configuration.isPressed ? -0.02 : 0)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

private struct SheetActionStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isPrimary ? Color.red : Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
