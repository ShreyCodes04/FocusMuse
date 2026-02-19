import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

private struct MoodEntry: Identifiable, Codable {
    let id: UUID
    let mood: String
    let emotions: [String]
    let causes: [String]
    let note: String
    let date: Date
}

private final class MoodEntryStore: ObservableObject {
    @Published var entries: [MoodEntry] = []
    private let storageKey = "mindfulness_mood_entries"

    init() {
        loadEntries()
    }

    func saveMoodEntry(mood: String, emotions: [String], causes: [String], note: String) {
        let entry = MoodEntry(
            id: UUID(),
            mood: mood,
            emotions: emotions,
            causes: causes,
            note: note,
            date: Date()
        )
        entries.insert(entry, at: 0)
        persistEntries()
        UserDefaults.standard.set(mood, forKey: "latest_mood_checkin")
    }

    func getTodayEntries(calendar: Calendar = .current) -> [MoodEntry] {
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }
        return entries.filter { $0.date >= today && $0.date < tomorrow }
    }

    func getThisWeekEntries(calendar: Calendar = .current) -> [MoodEntry] {
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 7, to: start) else { return [] }
        return entries.filter { $0.date >= start && $0.date < end }
    }

    func moodIcon(for mood: String) -> String {
        switch mood {
        case "Awesome": return "sun.max.fill"
        case "Good": return "face.smiling.fill"
        case "Fine": return "face.dashed.fill"
        case "Low": return "cloud.fill"
        case "Stressed": return "exclamationmark.triangle.fill"
        default: return "face.smiling"
        }
    }

    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            entries = []
            return
        }

        do {
            entries = try JSONDecoder().decode([MoodEntry].self, from: data)
        } catch {
            entries = []
        }
    }

    private func persistEntries() {
        do {
            let data = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // No-op for local persistence fallback.
        }
    }
}

struct MindfulnessLandingView: View {
    @StateObject private var moodStore = MoodEntryStore()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.2, green: 0.01, blue: 0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mindfulness")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Pause, reflect, and reset with structured emotional check-ins.")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    NavigationLink {
                        MoodCheckInFlowView(store: moodStore)
                    } label: {
                        MindfulnessLandingCard(
                            icon: "heart.text.square.fill",
                            title: "Mood Check-In",
                            subtitle: "Track how you feel and understand your patterns."
                        )
                    }
                    .buttonStyle(MindfulnessPressStyle())

                    NavigationLink {
                        BreathingExercisesView()
                    } label: {
                        MindfulnessLandingCard(
                            icon: "wind",
                            title: "Breathing Exercises",
                            subtitle: "Guided breathing sessions are coming soon."
                        )
                    }
                    .buttonStyle(MindfulnessPressStyle())

                    NavigationLink {
                        MeditationLandingView()
                    } label: {
                        MindfulnessLandingCard(
                            icon: "figure.mind.and.body",
                            title: "Meditation",
                            subtitle: "Mindful meditations are coming soon."
                        )
                    }
                    .buttonStyle(MindfulnessPressStyle())
                }
                .padding(20)
                .padding(.bottom, 110)
            }
        }
        .navigationTitle("Mindfulness")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MindfulnessLandingCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.13))
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white.opacity(0.65))
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
                        colors: [Color.white.opacity(0.24), Color.white.opacity(0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: Color.red.opacity(0.22), radius: 18, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 6)
    }
}

private struct MoodCheckInFlowView: View {
    @ObservedObject var store: MoodEntryStore

    @State private var currentStep: Int = 1
    @State private var selectedMood: String?
    @State private var selectedEmotions: Set<String> = []
    @State private var selectedCauses: Set<String> = []
    @State private var additionalReason: String = ""
    @State private var showConfetti = false

    private let moods = ["Awesome", "Good", "Fine", "Low", "Stressed"]
    private let emotions = [
        "Sad", "Angry", "Tired", "Motivated", "Anxious", "Calm", "Excited", "Overwhelmed", "Focused", "Lazy",
        "Confident", "Frustrated", "Hopeful", "Lonely", "Happy", "Irritated", "Peaceful", "Burnt Out", "Inspired", "Nervous",
        "Restless", "Grateful", "Drained", "Curious", "Discouraged"
    ]
    private let causes = [
        "Health", "Food", "Money", "Work", "Studies", "Family", "Friends", "Sleep", "Exams", "Productivity",
        "Relationship", "Weather", "Social Media", "Goals", "Fitness"
    ]

    var body: some View {
        Group {
            switch currentStep {
            case 1:
                stepOne
            case 2:
                stepTwo
            case 3:
                stepThree
            default:
                MoodSummaryDashboardView(store: store, latestMood: selectedMood ?? "Fine", showConfetti: $showConfetti)
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: currentStep)
        .onChange(of: selectedMood) { _, newMood in
            if newMood == "Awesome" {
                showConfetti = true
            }
        }
    }

    private var stepOne: some View {
        contentShell(title: "How are you feeling?", stepLabel: "Step 1 of 3") {
            VStack(spacing: 12) {
                ForEach(moods, id: \.self) { mood in
                    Button {
                        performHaptic()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                            selectedMood = mood
                        }
                    } label: {
                        Text(moodLabel(for: mood))
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(selectedMood == mood ? Color.red : Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                if selectedMood == mood {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                                }
                            }
                    }
                    .buttonStyle(MindfulnessPressStyle())
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentStep = 2
                    }
                } label: {
                    Text("Next")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selectedMood == nil ? Color.white.opacity(0.14) : Color.yellow)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(selectedMood == nil)
                .animation(.easeInOut(duration: 0.2), value: selectedMood)
            }
        }
        .navigationTitle("Mood Check-In")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var stepTwo: some View {
        contentShell(
            title: "Which emotions best describe how you feel?",
            subtitle: "Selected: \(selectedEmotions.count)",
            stepLabel: "Step 2 of 3"
        ) {
            ScrollView {
                let columns = [GridItem(.adaptive(minimum: 110), spacing: 10)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    ForEach(emotions, id: \.self) { emotion in
                        chip(
                            title: emotion,
                            isSelected: selectedEmotions.contains(emotion)
                        ) {
                            toggleEmotion(emotion)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 330)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentStep = 3
                }
            } label: {
                Text("Next")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selectedEmotions.isEmpty ? Color.white.opacity(0.14) : Color.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(selectedEmotions.isEmpty)
            .animation(.easeInOut(duration: 0.2), value: selectedEmotions.isEmpty)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var stepThree: some View {
        contentShell(title: "What's making you feel this way?", stepLabel: "Step 3 of 3") {
            ScrollView {
                let columns = [GridItem(.adaptive(minimum: 120), spacing: 10)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    ForEach(causes, id: \.self) { cause in
                        chip(title: cause, isSelected: selectedCauses.contains(cause)) {
                            toggleCause(cause)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 220)

            VStack(alignment: .leading, spacing: 8) {
                Text("Any other reasons?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.85))

                TextField("Type your reason here...", text: $additionalReason)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button {
                saveAndMoveToSummary()
            } label: {
                Text("Save")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(MindfulnessPressStyle())
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func contentShell(title: String, subtitle: String? = nil, stepLabel: String, @ViewBuilder content: () -> some View) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.2, green: 0.01, blue: 0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                Text(stepLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.7))

                SwiftUI.ProgressView(value: progressValue(for: stepLabel))
                    .tint(.red)

                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.72))
                }

                content()
            }
            .padding(20)
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(isSelected ? Color.red : Color.white.opacity(0.08))
            .clipShape(Capsule())
            .shadow(color: isSelected ? Color.red.opacity(0.28) : .clear, radius: 10, x: 0, y: 6)
            .contentShape(Rectangle())
            .onTapGesture {
                action()
            }
            .animation(.easeInOut(duration: 0.18), value: isSelected)
    }

    private func moodLabel(for mood: String) -> String {
        switch mood {
        case "Awesome": return "😄 Awesome"
        case "Good": return "🙂 Good"
        case "Fine": return "😐 Fine"
        case "Low": return "😔 Low"
        case "Stressed": return "😣 Stressed"
        default: return mood
        }
    }

    private func progressValue(for stepLabel: String) -> Double {
        switch stepLabel {
        case "Step 1 of 3": return 0.33
        case "Step 2 of 3": return 0.67
        default: return 1.0
        }
    }

    private func saveAndMoveToSummary() {
        store.saveMoodEntry(
            mood: selectedMood ?? "Fine",
            emotions: Array(selectedEmotions).sorted(),
            causes: Array(selectedCauses).sorted(),
            note: additionalReason
        )
        withAnimation(.easeInOut(duration: 0.25)) {
            currentStep = 4
        }
    }

    private func performHaptic() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    private func toggleEmotion(_ emotion: String) {
        performHaptic()
        if selectedEmotions.contains(emotion) {
            selectedEmotions.remove(emotion)
        } else {
            selectedEmotions.insert(emotion)
        }
    }

    private func toggleCause(_ cause: String) {
        performHaptic()
        if selectedCauses.contains(cause) {
            selectedCauses.remove(cause)
        } else {
            selectedCauses.insert(cause)
        }
    }
}

private struct MoodSummaryDashboardView: View {
    @ObservedObject var store: MoodEntryStore
    let latestMood: String
    @Binding var showConfetti: Bool

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.2, green: 0.01, blue: 0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    summaryCard
                    todayCard
                    weekCard
                }
                .padding(20)
                .padding(.bottom, 90)
            }

            if showConfetti && latestMood == "Awesome" {
                MoodConfettiView()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showConfetti = false
                            }
                        }
                    }
            }
        }
        .navigationTitle("Mood Summary")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's Mood")
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)

            HStack(spacing: 12) {
                Image(systemName: store.moodIcon(for: latestMood))
                    .font(.system(size: 36))
                    .foregroundColor(.red)
                Text(latestMood)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .modifier(MindfulnessGlassCard())
    }

    private var todayCard: some View {
        let todayEntries = store.getTodayEntries(calendar: calendar)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Check-ins Today: \(todayEntries.count)")
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(todayEntries) { entry in
                        VStack(spacing: 8) {
                            Image(systemName: store.moodIcon(for: entry.mood))
                                .font(.title3)
                                .foregroundColor(.white)
                            Text(entry.date, style: .time)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.72))
                        }
                        .padding(10)
                        .frame(width: 84)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
        .modifier(MindfulnessGlassCard())
    }

    private var weekCard: some View {
        let weekEntries = store.getThisWeekEntries(calendar: calendar)
        let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

        return VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)

            HStack(spacing: 12) {
                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: 8) {
                        Text(weekdaySymbols[index])
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white.opacity(0.78))

                        if let dayMood = moodForDay(weekdayIndex: index, entries: weekEntries) {
                            Image(systemName: store.moodIcon(for: dayMood))
                                .foregroundColor(.red)
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.55))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Text("Weekly check-ins: \(weekEntries.count)")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white.opacity(0.72))
        }
        .modifier(MindfulnessGlassCard())
    }

    private func moodForDay(weekdayIndex: Int, entries: [MoodEntry]) -> String? {
        for entry in entries {
            let weekday = calendar.component(.weekday, from: entry.date)
            let normalizedIndex = weekday - 1
            if normalizedIndex == weekdayIndex {
                return entry.mood
            }
        }
        return nil
    }
}

private struct MindfulnessPlaceholderView: View {
    let title: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.2, green: 0.01, blue: 0.03)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Coming Soon")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MindfulnessGlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black.opacity(0.35))
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
            .shadow(color: Color.red.opacity(0.24), radius: 16, x: 0, y: 10)
            .shadow(color: Color.black.opacity(0.36), radius: 10, x: 0, y: 6)
    }
}

private struct MindfulnessPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .brightness(configuration.isPressed ? -0.02 : 0)
            .animation(.spring(response: 0.23, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

private struct MoodConfettiView: View {
    private let symbols = ["circle.fill", "seal.fill", "sparkle"]

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    for i in 0..<22 {
                        let x = CGFloat((Double(i) * 37).truncatingRemainder(dividingBy: Double(size.width)))
                        let y = CGFloat(((time * 80) + Double(i * 41)).truncatingRemainder(dividingBy: Double(size.height + 120))) - 60
                        let rect = CGRect(x: x, y: y, width: 8, height: 8)
                        var resolved = context.resolve(Text(Image(systemName: symbols[i % symbols.count])))
                        resolved.shading = .color(i.isMultiple(of: 2) ? .red : .white)
                        context.draw(resolved, in: rect)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
