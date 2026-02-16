import SwiftUI
import SwiftData

struct ProgressView: View {
    struct ProductivityPoint: Identifiable {
        let id = UUID()
        let dayLabel: String
        let minutes: Int
    }

    struct TodoStoredTask: Codable {
        let id: UUID
        let title: String
        let isCompleted: Bool
        let createdAt: Date
    }

    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\DailyStudyRecord.date)]) private var records: [DailyStudyRecord]
    @AppStorage("todo_tasks_v2") private var tasksData = Data()
    @AppStorage("daily_goal_duration_seconds") private var goalDuration: Int = 2 * 60 * 60

    private let recentProductivity: [ProductivityPoint] = [
        ProductivityPoint(dayLabel: "Mon", minutes: 557),
        ProductivityPoint(dayLabel: "Tue", minutes: 45),
        ProductivityPoint(dayLabel: "Wed", minutes: 522),
        ProductivityPoint(dayLabel: "Thu", minutes: 425),
        ProductivityPoint(dayLabel: "Fri", minutes: 301),
        ProductivityPoint(dayLabel: "Sat", minutes: 465),
        ProductivityPoint(dayLabel: "Sun", minutes: 378)
    ]

    private var focusSecondsTotal: Int {
        records.reduce(0) { $0 + max($1.studySeconds, 0) }
    }

    private var breakSecondsTotal: Int {
        records.reduce(0) { $0 + max($1.breakSeconds, 0) }
    }

    private var sessionsTotal: Int {
        records.reduce(0) { $0 + max($1.sessionsCount, 0) }
    }

    private var tasksCompletedTotal: Int {
        decodeTodoTasks().filter(\.isCompleted).count
    }

    private var streakDays: Int {
        let goal = max(goalDuration, 1)
        var byDay: [Date: Int] = [:]
        for record in records {
            let day = Calendar.current.startOfDay(for: record.date)
            byDay[day, default: 0] += max(record.studySeconds, 0)
        }

        var streak = 0
        var cursor = Calendar.current.startOfDay(for: Date())
        while byDay[cursor, default: 0] >= goal {
            streak += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
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
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)

                        Text("Insights")
                            .font(.title2.bold())
                            .foregroundColor(.white)

                        Spacer()
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            insightCard(
                                title: "Focus Time",
                                value: formatHoursMinutes(focusSecondsTotal),
                                subtitle: "Accumulated study time",
                                icon: "bolt.fill",
                                colors: [Color.orange, Color.yellow]
                            )
                            insightCard(
                                title: "Tasks Completed",
                                value: "\(tasksCompletedTotal)",
                                subtitle: "From To-do list",
                                icon: "checklist",
                                colors: [Color.green.opacity(0.9), Color.green]
                            )
                            insightCard(
                                title: "Sessions",
                                value: "\(sessionsTotal)",
                                subtitle: "Study runs executed",
                                icon: "timer",
                                colors: [Color.blue, Color.cyan]
                            )
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            insightCard(
                                title: "Streak",
                                value: "\(streakDays) days",
                                subtitle: "Continuous goal days",
                                icon: "flame.fill",
                                colors: [Color.red, Color.orange]
                            )
                            insightCard(
                                title: "Break Time",
                                value: formatHoursMinutes(breakSecondsTotal),
                                subtitle: "Accumulated total break",
                                icon: "cup.and.saucer.fill",
                                colors: [Color.red.opacity(0.9), Color.orange.opacity(0.85)]
                            )
                        }
                    }

                    recentProductivitySection
                        .padding(.top, 10)
                }
                .padding(16)
                .padding(.bottom, 90)
            }
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    @ViewBuilder
    private func insightCard(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        colors: [Color]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.95))
                Spacer()
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white.opacity(0.9))
            }

            Text(value)
                .font(.title2.bold())
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 0)

            Text(subtitle)
                .font(.caption2.weight(.medium))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(2)
        }
        .padding(12)
        .frame(width: 185, height: 142)
        .background(
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func decodeTodoTasks() -> [TodoStoredTask] {
        guard !tasksData.isEmpty else { return [] }
        do {
            return try JSONDecoder().decode([TodoStoredTask].self, from: tasksData)
        } catch {
            return []
        }
    }

    private func formatHoursMinutes(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    private var recentProductivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Productivity")
                .font(.title3.bold())
                .foregroundColor(.white)
                .padding(.top, 4)

            ProductivityGraph(points: recentProductivity)
                .frame(height: 260)
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

private struct ProductivityGraph: View {
    let points: [ProgressView.ProductivityPoint]

    private var minY: Double {
        Double(points.map(\.minutes).min() ?? 0)
    }

    private var maxY: Double {
        Double(points.map(\.minutes).max() ?? 1)
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let topPadding: CGFloat = 30
            let bottomPadding: CGFloat = 34
            let horizontalInset: CGFloat = 18
            let graphHeight = height - topPadding - bottomPadding
            let usableWidth = max(width - (horizontalInset * 2), 1)
            let stepX = points.count > 1 ? usableWidth / CGFloat(points.count - 1) : usableWidth

            let plotted: [CGPoint] = points.enumerated().map { index, item in
                let normalized = normalize(Double(item.minutes))
                let y = topPadding + graphHeight * (1 - normalized)
                let x = horizontalInset + CGFloat(index) * stepX
                return CGPoint(x: x, y: y)
            }

            ZStack(alignment: .topLeading) {
                Path { path in
                    guard let first = plotted.first else { return }
                    path.move(to: CGPoint(x: first.x, y: height - bottomPadding))
                    path.addLine(to: first)
                    for idx in 1..<plotted.count {
                        let previous = plotted[idx - 1]
                        let current = plotted[idx]
                        let mid = CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2)
                        path.addQuadCurve(to: mid, control: CGPoint(x: (mid.x + previous.x) / 2, y: previous.y))
                        path.addQuadCurve(to: current, control: CGPoint(x: (mid.x + current.x) / 2, y: current.y))
                    }
                    path.addLine(to: CGPoint(x: plotted.last?.x ?? 0, y: height - bottomPadding))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [Color.red.opacity(0.52), Color.red.opacity(0.08), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Path { path in
                    guard let first = plotted.first else { return }
                    path.move(to: first)
                    for idx in 1..<plotted.count {
                        let previous = plotted[idx - 1]
                        let current = plotted[idx]
                        let mid = CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2)
                        path.addQuadCurve(to: mid, control: CGPoint(x: (mid.x + previous.x) / 2, y: previous.y))
                        path.addQuadCurve(to: current, control: CGPoint(x: (mid.x + current.x) / 2, y: current.y))
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [Color.red.opacity(0.95), Color.red.opacity(0.72)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )

                ForEach(Array(points.enumerated()), id: \.element.id) { index, item in
                    let point = plotted[index]
                    VStack(spacing: 3) {
                        Text(formatMinutes(item.minutes))
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white.opacity(0.9))
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                    }
                    .position(x: point.x, y: max(10, point.y - 13))
                }

                ForEach(Array(points.enumerated()), id: \.element.id) { index, item in
                    let point = plotted[index]
                    Text(item.dayLabel)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.white.opacity(0.72))
                        .position(x: point.x, y: height - 10)
                }
            }
        }
    }

    private func normalize(_ value: Double) -> Double {
        let range = max(maxY - minY, 1)
        return (value - minY) / range
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m)m" }
        return "\(h)h \(m)m"
    }
}
