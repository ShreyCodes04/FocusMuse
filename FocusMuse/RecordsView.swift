import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct RecordsView: View {
    struct BadgeItem: Identifiable {
        let id = UUID()
        let message: String
        let iconName: String
        let achieved: Bool
    }

    private struct DayAggregate {
        var studySeconds: Int
        var breakSeconds: Int
    }

    @Query(sort: [SortDescriptor(\DailyStudyRecord.date)]) private var records: [DailyStudyRecord]

    @AppStorage("daily_goal_duration_seconds") private var dailyGoalSeconds: Int = 2 * 60 * 60
    @AppStorage("today_study_progress_seconds") private var todayStudyProgressSeconds: Int = 0
    @AppStorage("today_study_progress_day_key") private var todayStudyProgressDayKey: String = ""
    private let calendar = Calendar.current

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    private var weekDates: [Date] {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: weekStart)
        }
    }

    private var recordsByDay: [Date: DayAggregate] {
        var map: [Date: DayAggregate] = [:]
        for record in records {
            let dayStart = calendar.startOfDay(for: record.date)
            if let existing = map[dayStart] {
                map[dayStart] = DayAggregate(
                    studySeconds: existing.studySeconds + record.studySeconds,
                    breakSeconds: existing.breakSeconds + record.breakSeconds
                )
            } else {
                map[dayStart] = DayAggregate(
                    studySeconds: record.studySeconds,
                    breakSeconds: record.breakSeconds
                )
            }
        }
        return map
    }

    private var selectedProgress: Double {
        progress(for: selectedDate)
    }

    private var selectedStudySeconds: Int {
        effectiveStudySeconds(for: selectedDate)
    }

    private var selectedBreakSeconds: Int {
        recordsByDay[calendar.startOfDay(for: selectedDate)]?.breakSeconds ?? 0
    }

    private var selectedDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM"
        return formatter.string(from: selectedDate)
    }

    private var badges: [BadgeItem] {
        let streak = currentStreakDays
        let focusSeconds = totalFocusedSeconds
        return [
            BadgeItem(
                message: "1 week streak",
                iconName: "medal1",
                achieved: streak >= 7
            ),
            BadgeItem(
                message: "1 month streak",
                iconName: "medal2",
                achieved: streak >= 30
            ),
            BadgeItem(
                message: "6 months streak",
                iconName: "medal3",
                achieved: streak >= 180
            ),
            BadgeItem(
                message: "Focussed for 1 hour",
                iconName: "trophy1",
                achieved: focusSeconds >= 1 * 3600
            ),
            BadgeItem(
                message: "Focussed for 10 hours",
                iconName: "trophy2",
                achieved: focusSeconds >= 10 * 3600
            ),
            BadgeItem(
                message: "Focussed for 24 hours",
                iconName: "trophy3",
                achieved: focusSeconds >= 24 * 3600
            )
        ]
    }

    private var totalFocusedSeconds: Int {
        recordsByDay.values.reduce(0) { $0 + max($1.studySeconds, 0) }
    }

    private var currentStreakDays: Int {
        let goal = max(dailyGoalSeconds, 1)
        let byDay = recordsByDay.mapValues { max($0.studySeconds, 0) }
        var streak = 0
        var cursor = today

        while true {
            let seconds = effectiveStudySeconds(for: cursor, recordsByDaySeconds: byDay)
            if seconds >= goal {
                streak += 1
                guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
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
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("Daily Activity")
                            .font(.title2.bold())
                            .foregroundColor(.white)

                        Spacer()

                        NavigationLink {
                            DailyActivityCalendarView(dailyGoalSeconds: dailyGoalSeconds)
                        } label: {
                            Image(systemName: "calendar")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    weeklyRingRow

                    selectedDayDetail

                    badgesSection
                }
                .padding(16)
                .padding(.bottom, 90)
            }
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    private var weeklyRingRow: some View {
        HStack(spacing: 8) {
            ForEach(weekDates, id: \.self) { date in
                let dayStart = calendar.startOfDay(for: date)
                let future = dayStart > today
                let progress = progress(for: dayStart)
                let selected = calendar.isDate(dayStart, inSameDayAs: selectedDate)

                Button {
                    if !future {
                        selectedDate = dayStart
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(dayLetter(for: dayStart))
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white.opacity(0.9))

                        ZStack {
                            Circle()
                                .stroke(
                                    selected ? Color.white : Color.white.opacity(0.22),
                                    lineWidth: selected ? 6 : 5
                                )

                            if !future {
                                Circle()
                                    .trim(from: 0, to: min(progress, 1.0))
                                    .stroke(Color.red, style: StrokeStyle(lineWidth: selected ? 6 : 5, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                            }
                        }
                        .frame(width: 38, height: 38)

                        Text("\(calendar.component(.day, from: dayStart))")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white.opacity(0.95))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .disabled(future)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var selectedDayDetail: some View {
        VStack(spacing: 12) {
            Text(selectedDateLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 14)

                Circle()
                    .trim(from: 0, to: min(selectedProgress, 1.0))
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(min(selectedProgress, 1.0) * 100))%")
                    .font(.title3.bold())
                    .foregroundColor(.white)
            }
            .frame(width: 170, height: 170)

            VStack(alignment: .leading, spacing: 8) {
                Text("Total hours focussed: \(formatDuration(selectedStudySeconds))")
                Text("Total break taken: \(formatDuration(selectedBreakSeconds))")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white.opacity(0.95))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Badges")
                .font(.title3.bold())
                .foregroundColor(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(badges) { badge in
                        BadgeFlipCard(badge: badge)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func progress(for date: Date) -> Double {
        let dayStart = calendar.startOfDay(for: date)
        guard dayStart <= today else { return 0 }
        let seconds = effectiveStudySeconds(for: dayStart)
        let goal = max(dailyGoalSeconds, 1)
        return min(max(Double(seconds) / Double(goal), 0.0), 1.0)
    }

    private func effectiveStudySeconds(for date: Date) -> Int {
        let base = recordsByDay.mapValues { max($0.studySeconds, 0) }
        return effectiveStudySeconds(for: date, recordsByDaySeconds: base)
    }

    private func effectiveStudySeconds(for date: Date, recordsByDaySeconds: [Date: Int]) -> Int {
        let dayStart = calendar.startOfDay(for: date)
        let persisted = recordsByDaySeconds[dayStart] ?? 0
        guard calendar.isDate(dayStart, inSameDayAs: today),
              todayStudyProgressDayKey == dayKey(for: today) else {
            return persisted
        }
        return max(persisted, todayStudyProgressSeconds)
    }

    private func dayKey(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private func dayLetter(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }

    private func formatDuration(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        return String(format: "%02dh %02dm", hours, minutes)
    }
}

private struct BadgeFlipCard: View {
    let badge: RecordsView.BadgeItem
    @State private var isFlipped = false

    var body: some View {
        ZStack {
            front
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            back
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(width: 170, height: 205)
        .onTapGesture {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                isFlipped.toggle()
            }
        }
    }

    private var front: some View {
        VStack(spacing: 12) {
            BadgeArtView(iconName: badge.iconName, achieved: badge.achieved)
                .frame(width: 110, height: 110)

            Text("Tap to flip")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.red.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.red.opacity(0.45), lineWidth: 1)
        )
    }

    private var back: some View {
        VStack(spacing: 10) {
            BadgeArtView(iconName: badge.iconName, achieved: badge.achieved)
                .frame(width: 54, height: 54)

            Text(badge.message)
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.red.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.red.opacity(0.45), lineWidth: 1)
        )
    }
}

private struct BadgeArtView: View {
    let iconName: String
    let achieved: Bool

    var body: some View {
        Group {
            if let image = platformImage(named: iconName) {
                #if os(iOS)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                #elseif os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                #endif
            } else {
                Image(systemName: achieved ? "medal.fill" : "questionmark.circle")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.white.opacity(0.9))
                    .padding(14)
            }
        }
    }

    #if os(iOS)
    private func platformImage(named name: String) -> UIImage? {
        for ext in ["png", "jpeg", "jpg"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                return image
            }
        }
        return UIImage(named: name)
    }
    #elseif os(macOS)
    private func platformImage(named name: String) -> NSImage? {
        for ext in ["png", "jpeg", "jpg"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return NSImage(named: name)
    }
    #endif
}
