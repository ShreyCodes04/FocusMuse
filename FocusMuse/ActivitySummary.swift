import Foundation
import SwiftUI

struct ActivityMonthSummary {
    let monthStart: Date
    let displayedDays: Int
    let daysInMonth: Int
    let leadingEmptySlots: Int
    let progressByDay: [Double]
    let targetReachedDays: Int
    let totalHours: Int
}

enum ActivitySummaryBuilder {
    static func monthStarts(from _: [DailyStudyRecord], calendar: Calendar = .current) -> [Date] {
        let current = startOfMonth(for: Date(), calendar: calendar)
        var months: [Date] = []
        for offset in 0..<12 {
            if let month = calendar.date(byAdding: .month, value: -offset, to: current) {
                months.append(month)
            }
        }
        return months
    }

    static func summary(
        for monthStart: Date,
        records: [DailyStudyRecord],
        dailyGoalSeconds: Int,
        todayOverrideSeconds: Int? = nil,
        todayOverrideDay: Int? = nil,
        calendar: Calendar = .current
    ) -> ActivityMonthSummary {
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingEmptySlots = (firstWeekday - calendar.firstWeekday + 7) % 7
        let now = Date()
        let isCurrentMonth = calendar.isDate(monthStart, equalTo: now, toGranularity: .month)
        let displayedDays = isCurrentMonth ? calendar.component(.day, from: now) : daysInMonth

        var secondsByDay: [Int: Int] = [:]
        let monthComponents = calendar.dateComponents([.year, .month], from: monthStart)

        for record in records {
            let recordComponents = calendar.dateComponents([.year, .month, .day], from: record.date)
            guard recordComponents.year == monthComponents.year,
                  recordComponents.month == monthComponents.month,
                  let day = recordComponents.day else {
                continue
            }
            secondsByDay[day, default: 0] += max(record.studySeconds, 0)
        }

        if isCurrentMonth, let todayOverrideSeconds, let todayOverrideDay {
            secondsByDay[todayOverrideDay] = max(secondsByDay[todayOverrideDay, default: 0], todayOverrideSeconds)
        }

        let goal = max(dailyGoalSeconds, 1)
        let progresses: [Double] = (1...displayedDays).map { day in
            let seconds = secondsByDay[day, default: 0]
            return min(max(Double(seconds) / Double(goal), 0.0), 1.0)
        }

        let totalSeconds = secondsByDay.values.reduce(0, +)

        return ActivityMonthSummary(
            monthStart: monthStart,
            displayedDays: displayedDays,
            daysInMonth: daysInMonth,
            leadingEmptySlots: leadingEmptySlots,
            progressByDay: progresses,
            targetReachedDays: progresses.filter { $0 >= 1.0 }.count,
            totalHours: Int((Double(totalSeconds) / 3600.0).rounded())
        )
    }

    static func monthLabel(_ date: Date) -> String {
        monthFormatter.string(from: date)
    }

    static func startOfMonth(for date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()
}

struct ActivityDayRing: View {
    let day: Int
    let progress: Double

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 5)

                Circle()
                    .trim(from: 0, to: min(progress, 1.0))
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 34, height: 34)

            Text("\(day)")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
    }
}
