import SwiftUI
import SwiftData

struct RecordsView: View {
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
