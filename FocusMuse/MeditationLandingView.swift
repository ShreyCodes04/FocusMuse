import SwiftUI
import AVFoundation
import Combine
#if os(iOS)
import UIKit
#endif

private struct MeditationSession: Identifiable, Hashable {
    let id: UUID
    let title: String
    let description: String
    let duration: Int
    let category: String
    let difficulty: String
    let audioFileName: String
    let backgroundSoundFileName: String?
}

private struct MeditationHistory: Identifiable, Codable {
    let id: UUID
    let sessionTitle: String
    let duration: Int
    let durationSeconds: Int?
    let dateCompleted: Date
    let reflectionMood: String
    let intentionText: String
}

private final class MeditationHistoryStore: ObservableObject {
    @Published var history: [MeditationHistory] = []
    private let storageKey = "meditation_history_json"

    init() {
        load()
    }

    func saveSession(sessionTitle: String, completedSeconds: Int, reflectionMood: String, intentionText: String) {
        let minutes = Double(max(completedSeconds, 0)) / 60.0
        let entry = MeditationHistory(
            id: UUID(),
            sessionTitle: sessionTitle,
            duration: Int(round(minutes)),
            durationSeconds: max(completedSeconds, 0),
            dateCompleted: Date(),
            reflectionMood: reflectionMood,
            intentionText: intentionText
        )
        history.insert(entry, at: 0)
        persist()
    }

    func calculateTodayMinutes(calendar: Calendar = .current) -> Double {
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return 0 }
        let totalSeconds = history
            .filter { $0.dateCompleted >= today && $0.dateCompleted < tomorrow }
            .reduce(0) { $0 + seconds(for: $1) }
        return Double(totalSeconds) / 60.0
    }

    func calculateWeeklySessions(calendar: Calendar = .current) -> Int {
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 7, to: start) else { return 0 }
        return history.filter { $0.dateCompleted >= start && $0.dateCompleted < end }.count
    }

    func calculateStreak(calendar: Calendar = .current) -> Int {
        let uniqueDays = Set(history.map { calendar.startOfDay(for: $0.dateCompleted) })
        var streak = 0
        var cursor = calendar.startOfDay(for: Date())

        while uniqueDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return streak
    }

    func calculateLongestStreak(calendar: Calendar = .current) -> Int {
        let uniqueDays = Array(Set(history.map { calendar.startOfDay(for: $0.dateCompleted) })).sorted()
        guard !uniqueDays.isEmpty else { return 0 }

        var longest = 1
        var current = 1

        for index in 1..<uniqueDays.count {
            let previous = uniqueDays[index - 1]
            let currentDay = uniqueDays[index]
            if calendar.date(byAdding: .day, value: 1, to: previous) == currentDay {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }

        return longest
    }

    func totalMinutes() -> Double {
        let totalSeconds = history.reduce(0) { $0 + seconds(for: $1) }
        return Double(totalSeconds) / 60.0
    }

    private func seconds(for entry: MeditationHistory) -> Int {
        entry.durationSeconds ?? (entry.duration * 60)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            history = []
            return
        }

        do {
            history = try JSONDecoder().decode([MeditationHistory].self, from: data)
        } catch {
            history = []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(history)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // No-op for local-only fallback.
        }
    }
}

private final class MeditationAudioManager: ObservableObject {
    private var ambientPlayer: AVAudioPlayer?

    func startSession(ambientFile: String?) {
        stopAll()

        if let ambientFile {
            guard let player = makePlayer(named: ambientFile) else { return }
            player.numberOfLoops = -1
            player.volume = 0.35
            player.play()
            ambientPlayer = player
        }
    }

    func pauseAll() {
        ambientPlayer?.pause()
    }

    func resumeAll() {
        ambientPlayer?.play()
    }

    func stopAmbient() {
        ambientPlayer?.stop()
        ambientPlayer = nil
    }

    func stopAll() {
        ambientPlayer?.stop()
        ambientPlayer = nil
    }

    private func makePlayer(named fileName: String) -> AVAudioPlayer? {
        let (base, ext) = split(fileName: fileName)
        guard let url = Bundle.main.url(forResource: base, withExtension: ext) else {
            return nil
        }
        return try? AVAudioPlayer(contentsOf: url)
    }

    private func split(fileName: String) -> (String, String) {
        if let dot = fileName.lastIndex(of: ".") {
            let name = String(fileName[..<dot])
            let ext = String(fileName[fileName.index(after: dot)...])
            return (name, ext)
        }
        return (fileName, "mp3")
    }
}

private struct MeditationPlayerConfig: Hashable, Identifiable {
    let session: MeditationSession
    let ambient: String

    var id: UUID { session.id }
}

struct MeditationLandingView: View {
    @StateObject private var historyStore = MeditationHistoryStore()
    @StateObject private var audioManager = MeditationAudioManager()

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedCategory = "All"
    @State private var selectedSession: MeditationSession?
    @State private var bookmarks: Set<UUID> = []

    private let categories = ["All", "Focus", "Sleep", "Anxiety Relief", "Relaxation", "Motivation", "Study Prep"]
    private let sounds = ["None", "Rain", "Ocean", "Forest", "Night"]

    private let sessions: [MeditationSession] = [
        .init(id: UUID(uuidString: "A9CC4A37-0458-43FB-A1A1-EF57D76EF0BA")!, title: "Daily Calm", description: "A gentle reset to slow your breath and clear your mind.", duration: 10, category: "Relaxation", difficulty: "Beginner", audioFileName: "Piano.wav", backgroundSoundFileName: "Waves.mp3"),
        .init(id: UUID(uuidString: "8642A97D-C4D0-49CD-BB20-B2127917E2A4")!, title: "Night Drift", description: "Wind down with a soft body scan and quiet guidance.", duration: 12, category: "Sleep", difficulty: "Beginner", audioFileName: "Violin.wav", backgroundSoundFileName: "Night.mp3"),
        .init(id: UUID(uuidString: "7AC26D85-B9AF-4F88-8F8C-57D35B4D488B")!, title: "Study Anchor", description: "Center attention and build deep focus before studying.", duration: 8, category: "Study Prep", difficulty: "Intermediate", audioFileName: "Guitar.wav", backgroundSoundFileName: "Rain.mp3"),
        .init(id: UUID(uuidString: "D0714925-E17E-4B11-8A58-B20966E56F43")!, title: "Quiet Confidence", description: "Shift anxious energy into grounded confidence.", duration: 9, category: "Anxiety Relief", difficulty: "Intermediate", audioFileName: "Piano.wav", backgroundSoundFileName: "Forest.mp3"),
        .init(id: UUID(uuidString: "4C0DC11D-C517-4EE3-8214-93689F10B44B")!, title: "Morning Focus", description: "Start with clarity, intention, and steady breath.", duration: 7, category: "Focus", difficulty: "Beginner", audioFileName: "Violin.wav", backgroundSoundFileName: "Forest.mp3"),
        .init(id: UUID(uuidString: "7B4141DA-F89C-40EA-85E7-5D49716C85F9")!, title: "Momentum", description: "Short motivational session to build forward energy.", duration: 6, category: "Motivation", difficulty: "Beginner", audioFileName: "Guitar.wav", backgroundSoundFileName: "Waves.mp3")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                featuredCard
                suggestedSection
                categoryRow
                sessionGrid
                dashboard
            }
            .padding(20)
            .padding(.bottom, 110)
        }
        .background(
            LinearGradient(
                colors: [Color.black, Color(red: 0.2, green: 0.01, blue: 0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Meditation")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedSession) { session in
            MeditationDetailView(
                session: session,
                allSounds: sounds,
                onStartSession: { ambient in
                    MeditationPlayerView(
                        config: MeditationPlayerConfig(
                            session: session,
                            ambient: ambient
                        ),
                        historyStore: historyStore,
                        audioManager: audioManager
                    )
                }
            )
        }
        .onAppear {
            loadBookmarks()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Meditation")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("Find calm and clarity")
                .font(.title3.weight(.medium))
                .foregroundColor(.white.opacity(0.72))

            HStack(spacing: 10) {
                statChip(title: "Today's Minutes", value: formatMinutes(historyStore.calculateTodayMinutes()))
                statChip(title: "Current Streak", value: "\(historyStore.calculateStreak())")
                statChip(title: "Total Sessions", value: "\(historyStore.history.count)")
            }
        }
    }

    private func statChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.68))
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var featuredCard: some View {
        Button {
            if let daily = sessions.first(where: { $0.title == "Daily Calm" }) {
                selectedSession = daily
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.red.opacity(0.28), Color.black.opacity(0.45), Color.red.opacity(0.16)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(.ultraThinMaterial.opacity(0.12))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Daily Calm")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("10 mins")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white.opacity(0.82))
                    Text("A guided reset for breath, body, and calm focus.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.75))

                    HStack {
                        Spacer()
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 52))
                            .foregroundColor(.white)
                            .shadow(color: .red.opacity(0.4), radius: 16, x: 0, y: 8)
                        Spacer()
                    }
                }
                .padding(22)
            }
            .frame(height: 220)
            .shadow(color: .red.opacity(0.22), radius: 24, x: 0, y: 12)
        }
        .buttonStyle(MeditationPressStyle())
    }

    private var suggestedSection: some View {
        let suggestedCategory = suggestionCategory
        let suggestions = sessions.filter { $0.category == suggestedCategory }

        return VStack(alignment: .leading, spacing: 10) {
            Text("Suggested for You")
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)

            Text("Based on local activity: \(suggestedCategory)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.72))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(suggestions.isEmpty ? Array(sessions.prefix(2)) : suggestions) { session in
                        Button {
                            selectedSession = session
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(session.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.white)
                                Text(session.category)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            selectedCategory = category
                        }
                    } label: {
                        Text(category)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(selectedCategory == category ? .black : .white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(selectedCategory == category ? Color.red : Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .shadow(color: selectedCategory == category ? .red.opacity(0.24) : .clear, radius: 12, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var filteredSessions: [MeditationSession] {
        if selectedCategory == "All" {
            return sessions
        }
        return sessions.filter { $0.category == selectedCategory }
    }

    private var sessionGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(filteredSessions) { session in
                Button {
                    selectedSession = session
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(session.title)
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.white)
                                .minimumScaleFactor(0.8)
                            Spacer(minLength: 8)
                            Button {
                                toggleBookmark(session.id)
                            } label: {
                                Image(systemName: bookmarks.contains(session.id) ? "bookmark.fill" : "bookmark")
                                    .foregroundColor(bookmarks.contains(session.id) ? .red : .white.opacity(0.75))
                            }
                            .buttonStyle(.plain)
                        }

                        Text("\(session.duration) mins")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white.opacity(0.84))

                        HStack(spacing: 8) {
                            pill(text: session.difficulty)
                            pill(text: session.category)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
                    .background {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.black.opacity(0.35))
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    }
                }
                .buttonStyle(MeditationPressStyle())
            }
        }
    }

    private func pill(text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
    }

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress Dashboard")
                .font(.title3.weight(.bold))
                .foregroundColor(.white)

            HStack(spacing: 10) {
                statChip(title: "Total Minutes", value: formatMinutes(historyStore.totalMinutes()))
                statChip(title: "Longest Streak", value: "\(historyStore.calculateLongestStreak())")
                statChip(title: "Sessions This Week", value: "\(historyStore.calculateWeeklySessions())")
            }

            weekDots
        }
        .padding(16)
        .background(Color.black.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        }
    }

    private var weekDots: some View {
        let symbols = ["S", "M", "T", "W", "T", "F", "S"]
        let active = weekActiveDays()

        return HStack(spacing: 12) {
            ForEach(0..<7, id: \.self) { index in
                VStack(spacing: 6) {
                    Text(symbols[index])
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white.opacity(0.75))
                    Circle()
                        .fill(active.contains(index) ? Color.red : Color.gray.opacity(0.5))
                        .frame(width: 10, height: 10)
                        .shadow(color: active.contains(index) ? .red.opacity(0.35) : .clear, radius: 8, x: 0, y: 4)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func weekActiveDays(calendar: Calendar = .current) -> Set<Int> {
        let weekEntries = historyStore.history.filter {
            guard let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start,
                  let end = calendar.date(byAdding: .day, value: 7, to: start) else { return false }
            return $0.dateCompleted >= start && $0.dateCompleted < end
        }

        return Set(weekEntries.map { calendar.component(.weekday, from: $0.dateCompleted) - 1 })
    }

    private var suggestionCategory: String {
        if UserDefaults.standard.string(forKey: "latest_mood_checkin") == "Stressed" {
            return "Anxiety Relief"
        }

        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 21 {
            return "Sleep"
        }

        if UserDefaults.standard.integer(forKey: "today_study_progress_seconds") > 0 {
            return "Focus"
        }

        return "Relaxation"
    }

    private func toggleBookmark(_ id: UUID) {
        if bookmarks.contains(id) {
            bookmarks.remove(id)
        } else {
            bookmarks.insert(id)
        }
        saveBookmarks()
    }

    private func loadBookmarks() {
        guard let data = UserDefaults.standard.data(forKey: "meditation_bookmarks") else { return }
        if let ids = try? JSONDecoder().decode([UUID].self, from: data) {
            bookmarks = Set(ids)
        }
    }

    private func saveBookmarks() {
        if let data = try? JSONEncoder().encode(Array(bookmarks)) {
            UserDefaults.standard.set(data, forKey: "meditation_bookmarks")
        }
    }

    private func formatMinutes(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(rounded))
        }
        return String(format: "%.1f", rounded)
    }

    private func ambientFileName(for sound: String) -> String {
        switch sound {
        case "Rain":
            return "Rain.mp3"
        case "Ocean":
            return "Waves.mp3"
        case "Forest":
            return "Forest.mp3"
        case "Night":
            return "Night.mp3"
        default:
            return "Rain.mp3"
        }
    }
}

private struct MeditationDetailView<Destination: View>: View {
    let session: MeditationSession
    let allSounds: [String]
    let onStartSession: (String) -> Destination

    @State private var selectedSound = "None"
    @State private var showSoundSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(session.title)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("\(session.duration) mins · \(session.category) · \(session.difficulty)")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.78))

                Text(session.description)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.82))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Background Sound")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)

                    Button {
                        showSoundSheet = true
                    } label: {
                        HStack {
                            Text(selectedSound)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.09))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                }

                NavigationLink {
                    onStartSession(selectedSound)
                } label: {
                    Text("Start Meditation")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(20)
            .padding(.bottom, 80)
        }
        .background(
            LinearGradient(
                colors: [Color.black, Color(red: 0.2, green: 0.01, blue: 0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSoundSheet) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Select Ambient Sound")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)

                ForEach(allSounds, id: \.self) { sound in
                    Button {
                        selectedSound = sound
                    } label: {
                        HStack {
                            Text(sound)
                                .foregroundColor(.white)
                            Spacer()
                            if sound == selectedSound {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
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
            .presentationDetents([.medium, .large])
        }
    }
}

private struct MeditationPlayerView: View {
    let config: MeditationPlayerConfig
    @ObservedObject var historyStore: MeditationHistoryStore
    @ObservedObject var audioManager: MeditationAudioManager

    @Environment(\.dismiss) private var dismiss

    @State private var remainingSeconds: Int = 0
    @State private var isPaused = false
    @State private var heartScale: CGFloat = 0.88
    @State private var completed = false
    @State private var selectedMood = "Calm"
    @State private var pulseTick = 0
    @State private var completedMinutes: Double = 0
    @State private var completedSeconds: Int = 0

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let reflectionMoods = ["Calm", "Relaxed", "Focused", "Sleepy", "Neutral"]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.2, green: 0.01, blue: 0.03)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if completed {
                completionView
            } else {
                playerView
            }
        }
        .onAppear {
            remainingSeconds = max(config.session.duration * 60, 1)
            audioManager.startSession(ambientFile: ambientFileName(for: config.ambient))
            heartScale = 0.88
        }
        .onReceive(ticker) { _ in
            guard !isPaused, !completed else { return }
            guard remainingSeconds > 0 else { return }
            remainingSeconds -= 1
            pulseTick += 1
            if pulseTick % 2 == 0 {
                withAnimation(.easeInOut(duration: 1.8)) {
                    heartScale = heartScale < 1 ? 1.12 : 0.88
                }
            }
            if remainingSeconds == 0 {
                finishSession()
            }
        }
        .onDisappear {
            audioManager.stopAll()
        }
    }

    private var playerView: some View {
        VStack(spacing: 24) {
            Text(config.session.title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            ZStack {
                Image(systemName: "heart.fill")
                    .font(.system(size: 170))
                    .foregroundColor(Color.red.opacity(0.28))
                    .blur(radius: 16)
                    .scaleEffect(heartScale)

                Image(systemName: "heart.fill")
                    .font(.system(size: 160))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Color.red.opacity(0.95)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(heartScale)
                    .shadow(color: Color.red.opacity(0.35), radius: 26, x: 0, y: 12)
            }

            Text(timeLabel)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()

            HStack(spacing: 12) {
                Button(isPaused ? "Resume" : "Pause") {
                    isPaused.toggle()
                    if isPaused {
                        audioManager.pauseAll()
                    } else {
                        audioManager.resumeAll()
                    }
                }
                .buttonStyle(MeditationActionStyle(primary: true))

                Button("End") {
                    finishSession()
                }
                .buttonStyle(MeditationActionStyle(primary: false))
            }
        }
        .padding(24)
    }

    private var completionView: some View {
        VStack(spacing: 16) {
            Text("Session Complete")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Duration completed: \(completedMinutesLabel) mins")
                .font(.headline)
                .foregroundColor(.white.opacity(0.78))

            Text("How do you feel now?")
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)

            HStack(spacing: 8) {
                ForEach(reflectionMoods, id: \.self) { mood in
                    Button {
                        selectedMood = mood
                    } label: {
                        Text(mood)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(selectedMood == mood ? .black : .white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(selectedMood == mood ? Color.red : Color.white.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            Button("Save") {
                historyStore.saveSession(
                    sessionTitle: config.session.title,
                    completedSeconds: completedSeconds,
                    reflectionMood: selectedMood,
                    intentionText: ""
                )
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                dismiss()
            }
            .buttonStyle(MeditationActionStyle(primary: true))
        }
        .padding(24)
    }

    private var timeLabel: String {
        let m = max(remainingSeconds, 0) / 60
        let s = max(remainingSeconds, 0) % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func finishSession() {
        let totalSeconds = max(config.session.duration * 60, 1)
        let elapsedSeconds = max(totalSeconds - remainingSeconds, 0)
        completedSeconds = elapsedSeconds
        completedMinutes = Double(elapsedSeconds) / 60.0
        audioManager.stopAll()
        withAnimation(.easeInOut(duration: 0.25)) {
            completed = true
        }
    }

    private var completedMinutesLabel: String {
        let roundedToTenth = (completedMinutes * 10).rounded() / 10
        if roundedToTenth.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(roundedToTenth))
        }
        return String(format: "%.1f", roundedToTenth)
    }

    private func ambientFileName(for sound: String) -> String? {
        switch sound {
        case "Rain":
            return "Rain.mp3"
        case "Ocean":
            return "Waves.mp3"
        case "Forest":
            return "Forest.mp3"
        case "Night":
            return "Night.mp3"
        default:
            return nil
        }
    }
}

private struct MeditationActionStyle: ButtonStyle {
    let primary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundColor(.white)
            .frame(minWidth: 120)
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .background(primary ? Color.red : Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct MeditationPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.02 : 0)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: configuration.isPressed)
    }
}
