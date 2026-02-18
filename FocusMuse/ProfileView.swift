import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("profile_name") private var profileName: String = "sadhukhanbidhan"
    @AppStorage("today_study_progress_seconds") private var todayStudyProgressSeconds: Int = 0
    @AppStorage("today_study_progress_day_key") private var todayStudyProgressDayKey: String = ""
    @State private var showNameEditor = false
    @State private var draftName = ""

    @Query(sort: [SortDescriptor(\DailyStudyRecord.date)]) private var records: [DailyStudyRecord]
    private let calendar = Calendar.current

    private var currentWeekInterval: DateInterval {
        let todayStart = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
        let end = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        return DateInterval(start: start, end: end)
    }

    private var previousWeekInterval: DateInterval {
        guard let start = calendar.date(byAdding: .day, value: -7, to: currentWeekInterval.start),
              let end = calendar.date(byAdding: .day, value: -7, to: currentWeekInterval.end) else {
            return currentWeekInterval
        }
        return DateInterval(start: start, end: end)
    }

    private var weeklyFocusSeconds: Int {
        effectiveTotalStudySeconds(in: currentWeekInterval)
    }

    private var previousWeeklyFocusSeconds: Int {
        effectiveTotalStudySeconds(in: previousWeekInterval)
    }

    private var averageDailyFocusSeconds: Int {
        weeklyFocusSeconds / 7
    }

    private var previousAverageDailyFocusSeconds: Int {
        previousWeeklyFocusSeconds / 7
    }

    private var weekLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        let start = formatter.string(from: currentWeekInterval.start)
        guard let lastDay = calendar.date(byAdding: .day, value: -1, to: currentWeekInterval.end) else {
            return start
        }
        let end = formatter.string(from: lastDay)
        return "\(start)–\(end)"
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
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3.weight(.semibold))
                            .foregroundColor(.white)
                                .padding(.vertical, 6)
                        }

                        Text("My page")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "ellipsis")
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.red.opacity(0.9))
                            .rotationEffect(.degrees(90))
                    }

                    ZStack(alignment: .top) {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 210)

                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 0.95, green: 0.32, blue: 0.32), Color(red: 0.70, green: 0.05, blue: 0.08)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Image(systemName: "person.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.white.opacity(0.75))
                            }
                            .frame(width: 130, height: 130)
                            .offset(y: -62)

                            VStack(spacing: 10) {
                                Text(profileName)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)

                                Button {
                                    draftName = profileName
                                    showNameEditor = true
                                } label: {
                                    Text("Edit")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 22)
                                        .padding(.vertical, 10)
                                        .background(Color.red.opacity(0.8))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 22)
                            .offset(y: -50)
                        }
                    }
                    .padding(.top, 56)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Weekly report")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)

                        Text(weekLabel)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white.opacity(0.7))

                        HStack(alignment: .top, spacing: 18) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Total focus\nduration")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.white.opacity(0.92))

                                Text("Previous week \(formatDuration(previousWeeklyFocusSeconds))")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.white.opacity(0.65))

                                Text(formatDuration(weeklyFocusSeconds))
                                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)

                                deltaRow(current: weeklyFocusSeconds, previous: previousWeeklyFocusSeconds)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 1)
                                .frame(maxHeight: .infinity)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Average daily focus")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.white.opacity(0.92))

                                Text("Previous week \(formatDuration(previousAverageDailyFocusSeconds))")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.white.opacity(0.65))

                                Text(formatDuration(averageDailyFocusSeconds))
                                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)

                                deltaRow(current: averageDailyFocusSeconds, previous: previousAverageDailyFocusSeconds)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 220)
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                }
                .padding(20)
                .padding(.bottom, 100)
            }
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .sheet(isPresented: $showNameEditor) {
            NavigationStack {
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

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Profile Name")
                            .font(.headline)
                            .foregroundColor(.white)

                        TextField("Enter name", text: $draftName)
                            #if os(iOS)
                            .textInputAutocapitalization(.words)
                            #endif
                            .autocorrectionDisabled()
                            .padding(12)
                            .foregroundColor(Color.white)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(20)
                }
                .navigationTitle("Edit Name")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showNameEditor = false
                        }
                        .foregroundColor(Color.white)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                profileName = trimmed
                            }
                            showNameEditor = false
                        }
                        .foregroundColor(Color.red)
                    }
                }
            }
        }
    }

    private func totalStudySeconds(in interval: DateInterval) -> Int {
        records.reduce(0) { partial, record in
            if interval.contains(record.date) {
                return partial + max(record.studySeconds, 0)
            }
            return partial
        }
    }

    private func effectiveTotalStudySeconds(in interval: DateInterval) -> Int {
        let base = totalStudySeconds(in: interval)
        let today = calendar.startOfDay(for: Date())
        guard interval.contains(today),
              todayStudyProgressDayKey == dayKey(for: today) else {
            return base
        }

        let persistedToday = records.reduce(0) { partial, record in
            if calendar.isDate(record.date, inSameDayAs: today) {
                return partial + max(record.studySeconds, 0)
            }
            return partial
        }

        let delta = max(todayStudyProgressSeconds - persistedToday, 0)
        return base + delta
    }

    private func dayKey(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d:%02d", hrs, mins, secs)
    }

    private func deltaText(current: Int, previous: Int) -> String {
        let diff = abs(current - previous)
        return formatDuration(diff)
    }

    @ViewBuilder
    private func deltaRow(current: Int, previous: Int) -> some View {
        let isUp = current >= previous
        HStack(spacing: 4) {
            Image(systemName: isUp ? "arrow.up" : "arrow.down")
                .font(.caption.weight(.bold))
            Text(deltaText(current: current, previous: previous))
                .font(.caption.weight(.medium))
        }
        .foregroundColor(isUp ? Color.green : Color.red)
    }
}
