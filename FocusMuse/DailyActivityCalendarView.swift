import SwiftUI
import SwiftData

struct DailyActivityCalendarView: View {
    @Query(sort: [SortDescriptor(\DailyStudyRecord.date, order: .reverse)]) private var records: [DailyStudyRecord]

    let dailyGoalSeconds: Int
    private let calendar = Calendar.current

    private var months: [Date] {
        ActivitySummaryBuilder.monthStarts(from: records, calendar: calendar)
    }

    private var gridItems: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
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
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(months, id: \.self) { month in
                        let summary = ActivitySummaryBuilder.summary(
                            for: month,
                            records: records,
                            dailyGoalSeconds: dailyGoalSeconds,
                            calendar: calendar
                        )
                        monthSection(summary: summary)
                    }
                }
                .padding(16)
                .padding(.bottom, 90)
            }
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func monthSection(summary: ActivityMonthSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(ActivitySummaryBuilder.monthLabel(summary.monthStart))
                .font(.headline.bold())
                .foregroundColor(.white)

            Text("Target reached \(summary.targetReachedDays)/\(summary.displayedDays) days")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.92))

            Text("\(summary.totalHours) hours")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.92))

            LazyVGrid(columns: gridItems, spacing: 12) {
                ForEach(0..<(summary.firstWeekday - 1), id: \.self) { _ in
                    Color.clear
                        .frame(height: 56)
                }

                ForEach(1...summary.displayedDays, id: \.self) { day in
                    ActivityDayRing(day: day, progress: summary.progressByDay[day - 1])
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
