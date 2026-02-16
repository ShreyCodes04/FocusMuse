import SwiftUI
import SwiftData

struct RecordsView: View {
    struct BadgeItem: Identifiable {
        enum Art {
            case streakOne
            case streakTwo
            case focusHours
        }

        let id = UUID()
        let title: String
        let message: String
        let art: Art
    }

    private struct DayAggregate {
        var studySeconds: Int
        var breakSeconds: Int
    }

    @Query(sort: [SortDescriptor(\DailyStudyRecord.date)]) private var records: [DailyStudyRecord]

    private let dailyGoalSeconds: Int = 2 * 60 * 60
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
        recordsByDay[calendar.startOfDay(for: selectedDate)]?.studySeconds ?? 0
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
        [
            BadgeItem(title: "Starter Streak", message: "1 week streak", art: .streakOne),
            BadgeItem(title: "Momentum Streak", message: "2 week streak", art: .streakTwo),
            BadgeItem(title: "Deep Focus", message: "4 hours focused", art: .focusHours)
        ]
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
        let seconds = recordsByDay[dayStart]?.studySeconds ?? 0
        let goal = max(dailyGoalSeconds, 1)
        return min(max(Double(seconds) / Double(goal), 0.0), 1.0)
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
        VStack(spacing: 10) {
            BadgeArtView(art: badge.art)
                .frame(width: 92, height: 92)

            Text(badge.title)
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Tap to flip")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var back: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.title2.weight(.bold))
                .foregroundColor(.red.opacity(0.9))

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
    let art: RecordsView.BadgeItem.Art

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.red.opacity(0.9), Color.white.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            switch art {
            case .streakOne:
                ZStack {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white.opacity(0.95))
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 2)
                        .frame(width: 64, height: 64)
                }
            case .streakTwo:
                ZStack {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white.opacity(0.95))
                    Path { path in
                        path.move(to: CGPoint(x: 18, y: 72))
                        path.addLine(to: CGPoint(x: 34, y: 58))
                        path.addLine(to: CGPoint(x: 52, y: 66))
                        path.addLine(to: CGPoint(x: 72, y: 48))
                    }
                    .stroke(Color.white.opacity(0.45), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                }
            case .focusHours:
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.75), lineWidth: 4)
                        .frame(width: 54, height: 54)
                    Path { path in
                        path.move(to: CGPoint(x: 46, y: 46))
                        path.addLine(to: CGPoint(x: 46, y: 30))
                        path.move(to: CGPoint(x: 46, y: 46))
                        path.addLine(to: CGPoint(x: 58, y: 52))
                    }
                    .stroke(Color.white.opacity(0.95), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
            }
        }
    }
}
