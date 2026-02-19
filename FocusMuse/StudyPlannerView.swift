import SwiftUI
import Combine

private enum PlannerPriority: String, CaseIterable, Identifiable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .gray
        }
    }

    var icon: String {
        switch self {
        case .high:
            return "exclamationmark.triangle.fill"
        case .medium:
            return "flag.fill"
        case .low:
            return "circle.fill"
        }
    }
}

private enum PlannerTag: String, CaseIterable, Identifiable {
    case exam = "Exam"
    case revision = "Revision"
    case assignment = "Assignment"
    case important = "Important"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .exam:
            return .red
        case .revision:
            return .orange
        case .assignment:
            return .blue
        case .important:
            return .pink
        }
    }
}

private enum TaskSortOption: String, CaseIterable, Identifiable {
    case deadline = "Deadline"
    case priority = "Priority"
    case subject = "Subject"

    var id: String { rawValue }
}

private enum TimelineMode: String, CaseIterable, Identifiable {
    case list = "List View"
    case weekly = "Weekly Timeline"

    var id: String { rawValue }
}

private enum PlannerWeekday: Int, CaseIterable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
}

private struct PlannerSubject: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let progress: Double
    let upcomingDeadline: Date
    let tasksLeft: Int
    let accent: Color
}

private struct PlannerTask: Identifiable {
    let id = UUID()
    var title: String
    var subjectID: UUID
    var priority: PlannerPriority
    var dueDate: Date
    var isComplete: Bool
    var tags: [PlannerTag]
}

private struct StudyBlock: Identifiable {
    let id = UUID()
    let title: String
    let subjectID: UUID
    let start: String
    let end: String
}

private struct PlannerGoal: Identifiable {
    struct Milestone: Identifiable {
        let id = UUID()
        var title: String
        var isDone: Bool
    }

    let id = UUID()
    let title: String
    let targetDate: Date
    var milestones: [Milestone]
}

private struct SessionHistoryItem: Identifiable {
    let id = UUID()
    let date: Date
    let subjectID: UUID
    let durationMinutes: Int
    let productivityScore: Int
    let notes: String
}

struct StudyPlannerView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var subjects: [PlannerSubject] = []
    @State private var tasks: [PlannerTask] = []
    @State private var sortOption: TaskSortOption = .deadline
    @State private var selectedFilterTag: PlannerTag? = nil
    @State private var showingAddTaskSheet = false

    @State private var timelineMode: TimelineMode = .list
    @State private var weeklyBlocks: [PlannerWeekday: [StudyBlock]] = [:]

    @State private var activeFocusSubject: PlannerSubject?
    @State private var availableHoursPerDay: Double = 3
    @State private var difficultyBias: Double = 0.55

    @State private var goals: [PlannerGoal] = []
    @State private var remindersDeadline = true
    @State private var remindersAdaptive = true
    @State private var remindersSummary = false

    @State private var history: [SessionHistoryItem] = []
    @State private var expandedHistoryIDs: Set<UUID> = []

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.21, green: 0.01, blue: 0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection

                    if horizontalSizeClass == .regular {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(spacing: 16) {
                                subjectDashboardSection
                                smartPlanSection
                                remindersSection
                                tagFilterSection
                            }
                            .frame(maxWidth: 430)

                            VStack(spacing: 16) {
                                taskManagerSection
                                timelineSection
                                analyticsSection
                                goalsSection
                                historySection
                                personalizationSection
                            }
                        }
                    } else {
                        subjectDashboardSection
                        tagFilterSection
                        taskManagerSection
                        smartPlanSection
                        timelineSection
                        analyticsSection
                        goalsSection
                        remindersSection
                        historySection
                        personalizationSection
                    }
                }
                .padding(20)
                .padding(.bottom, 120)
            }
        }
        .navigationTitle("Study Planner")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddTaskSheet) {
            AddTaskSheet(subjects: subjects) { draft in
                tasks.append(draft)
            }
            .presentationDetents([.medium, .large])
        }
        .fullScreenCover(item: $activeFocusSubject) { subject in
            FocusSessionView(subject: subject)
        }
        .onAppear {
            guard subjects.isEmpty else { return }
            seedData()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Study Planner")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Structured planning, intelligent scheduling, and deep focus in one premium workspace.")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subjectDashboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "rectangle.stack.fill", title: "Subject Dashboard")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(subjects) { subject in
                        subjectCard(subject)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func subjectCard(_ subject: PlannerSubject) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(subject.accent.opacity(0.2))
                    Image(systemName: subject.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 42, height: 42)

                Spacer()

                ProgressRing(progress: subject.progress, tint: subject.accent)
                    .frame(width: 42, height: 42)
            }

            Text(subject.name)
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)

            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .foregroundColor(.red.opacity(0.9))
                Text("Due \(subject.upcomingDeadline, style: .date)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.72))
            }

            Text("\(subject.tasksLeft) tasks left")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.85))

            Button {
                activeFocusSubject = subject
            } label: {
                Label("Start Focus Session", systemImage: "timer")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(subject.accent.opacity(0.85))
                    .clipShape(Capsule())
            }
            .buttonStyle(PlannerPressStyle(scale: 0.96))
        }
        .padding(16)
        .frame(width: 250, alignment: .leading)
        .modifier(PlannerGlassCard(accent: subject.accent))
        .scaleEffect(activeFocusSubject?.id == subject.id ? 0.98 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: activeFocusSubject?.id)
    }

    private var tagFilterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "line.3.horizontal.decrease.circle.fill", title: "Custom Tags & Filters")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    filterChip(title: "All", color: .white, isSelected: selectedFilterTag == nil) {
                        selectedFilterTag = nil
                    }

                    ForEach(PlannerTag.allCases) { tag in
                        filterChip(title: tag.rawValue, color: tag.color, isSelected: selectedFilterTag == tag) {
                            selectedFilterTag = selectedFilterTag == tag ? nil : tag
                        }
                    }
                }
            }
        }
        .modifier(PlannerGlassCard(accent: .red.opacity(0.8)))
    }

    private func filterChip(title: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? color : Color.white.opacity(0.08))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var taskManagerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle(icon: "checklist", title: "Smart Task Manager")
                Spacer()

                Menu {
                    Picker("Sort", selection: $sortOption) {
                        ForEach(TaskSortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    Label(sortOption.rawValue, systemImage: "arrow.up.arrow.down.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
            }

            ZStack(alignment: .bottomTrailing) {
                List {
                    ForEach(sortedTasks) { task in
                        taskRow(task)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteTask(task.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    postponeTask(task.id)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                    }
                }
                .listStyle(.plain)
                .frame(minHeight: 300, maxHeight: 360)
                .scrollContentBackground(.hidden)

                Button {
                    showingAddTaskSheet = true
                } label: {
                    Label("Add Task", systemImage: "plus")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .shadow(color: .red.opacity(0.45), radius: 12, x: 0, y: 8)
                }
                .buttonStyle(PlannerPressStyle(scale: 0.96))
                .padding(14)
            }
        }
        .modifier(PlannerGlassCard(accent: .red))
    }

    private func taskRow(_ task: PlannerTask) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                toggleTask(task.id)
            } label: {
                Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(task.isComplete ? .green : .white.opacity(0.6))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(task.isComplete ? .white.opacity(0.5) : .white)
                    .strikethrough(task.isComplete, color: .white.opacity(0.5))

                HStack(spacing: 8) {
                    priorityBadge(task.priority)

                    Text(subjectName(for: task.subjectID))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.68))

                    Text(task.dueDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.74))
                }

                HStack(spacing: 6) {
                    ForEach(task.tags, id: \.self) { tag in
                        Text(tag.rawValue)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(tag.color.opacity(0.75))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: task.isComplete)
    }

    private func priorityBadge(_ priority: PlannerPriority) -> some View {
        HStack(spacing: 5) {
            Image(systemName: priority.icon)
                .font(.caption2)
            Text(priority.rawValue)
                .font(.caption2.weight(.bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(priority.color.opacity(0.88))
        .clipShape(Capsule())
    }

    private var smartPlanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "sparkles", title: "Smart Plan")

            Text("Analyzes deadlines, difficulty, and available time to generate high-impact sessions.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.72))

            VStack(spacing: 10) {
                plannerSlider(title: "Available Study Time", valueText: "\(Int(availableHoursPerDay)) hrs/day", value: $availableHoursPerDay, range: 1...8)
                plannerSlider(title: "Difficulty Bias", valueText: "\(Int(difficultyBias * 100))%", value: $difficultyBias, range: 0.2...1.0)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(generatedBlocks) { block in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(block.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)

                            Text("\(block.start) - \(block.end)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.74))

                            Text("\(subjectName(for: block.subjectID)) · Focus suggestion")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.65))
                        }
                        .padding(12)
                        .frame(width: 180, alignment: .leading)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
        .modifier(PlannerGlassCard(accent: .red.opacity(0.9)))
    }

    private func plannerSlider(title: String, valueText: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.78))
                Spacer()
                Text(valueText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
            }
            Slider(value: value, in: range)
                .tint(.red)
        }
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle(icon: "calendar", title: "Study Timeline")
                Spacer()
                Picker("Timeline Mode", selection: $timelineMode) {
                    ForEach(TimelineMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 290)
            }

            if timelineMode == .list {
                VStack(spacing: 8) {
                    ForEach(flattenedBlocks.prefix(6)) { block in
                        HStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(subjectAccent(for: block.subjectID))
                                .frame(width: 6)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(block.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.white)
                                Text("\(block.start) - \(block.end)")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.72))
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(PlannerWeekday.allCases) { day in
                            timelineDayColumn(day)
                        }
                    }
                }
            }
        }
        .modifier(PlannerGlassCard(accent: .red.opacity(0.8)))
    }

    private func timelineDayColumn(_ day: PlannerWeekday) -> some View {
        let isToday = calendar.component(.weekday, from: Date()) == day.rawValue
        let dayBlocks = weeklyBlocks[day, default: []]

        return VStack(alignment: .leading, spacing: 8) {
            Text(day.shortName)
                .font(.caption.weight(.bold))
                .foregroundColor(isToday ? .red : .white.opacity(0.82))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(isToday ? Color.white : Color.clear)
                .clipShape(Capsule())

            ForEach(dayBlocks) { block in
                timelineBlockCard(block)
                    .draggable(block.id.uuidString)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: 150, alignment: .top)
        .frame(minHeight: 220, alignment: .top)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .dropDestination(for: String.self) { items, _ in
            moveBlock(items, to: day)
        }
    }

    private func timelineBlockCard(_ block: StudyBlock) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(block.title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
            Text("\(block.start)-\(block.end)")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.72))
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(subjectAccent(for: block.subjectID).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "chart.xyaxis.line", title: "Progress Analytics")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(subjects) { subject in
                        VStack(spacing: 8) {
                            ProgressRing(progress: subject.progress, tint: subject.accent)
                                .frame(width: 62, height: 62)
                            Text(subject.name)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Weekly Study Hours")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.78))

                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(Array(weeklyHours.enumerated()), id: \.offset) { index, value in
                        VStack(spacing: 5) {
                            Capsule()
                                .fill(index == 4 ? Color.red : Color.white.opacity(0.25))
                                .frame(width: 18, height: CGFloat(20 + (value * 8)))
                            Text(shortWeekdays[index])
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.72))
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                statPill(title: "Streak", value: "12 days", icon: "flame.fill")
                statPill(title: "Completion", value: "87%", icon: "checkmark.seal.fill")
            }
        }
        .modifier(PlannerGlassCard(accent: .red.opacity(0.85)))
    }

    private func statPill(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.red)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "target", title: "Goals & Milestones")

            ForEach(Array(goals.indices), id: \.self) { index in
                VStack(alignment: .leading, spacing: 10) {
                    Text(goals[index].title)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)

                    Text("Target: \(goals[index].targetDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.72))

                    SwiftUI.ProgressView(value: goalProgress(for: goals[index]))
                        .tint(.red)

                    ForEach(Array(goals[index].milestones.indices), id: \.self) { milestoneIndex in
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                goals[index].milestones[milestoneIndex].isDone.toggle()
                            }
                        } label: {
                            HStack {
                                Image(systemName: goals[index].milestones[milestoneIndex].isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(goals[index].milestones[milestoneIndex].isDone ? .green : .white.opacity(0.65))
                                Text(goals[index].milestones[milestoneIndex].title)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(goals[index].milestones[milestoneIndex].isDone ? 0.55 : 0.95))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .modifier(PlannerGlassCard(accent: .red.opacity(0.8)))
    }

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "bell.badge.fill", title: "Smart Reminders")

            reminderToggleRow(title: "Deadline alerts", subtitle: "Get notified before due dates", isOn: $remindersDeadline)
            reminderToggleRow(title: "Adaptive reminders", subtitle: "Rebalance prompts for missed sessions", isOn: $remindersAdaptive)
            reminderToggleRow(title: "Daily study summary", subtitle: "Evening wrap-up insights", isOn: $remindersSummary)
        }
        .modifier(PlannerGlassCard(accent: .red.opacity(0.9)))
    }

    private func reminderToggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.68))
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.red)
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "clock.arrow.circlepath", title: "Study Session History")

            ForEach(history) { item in
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedHistoryIDs.contains(item.id) },
                        set: { expanded in
                            if expanded {
                                expandedHistoryIDs.insert(item.id)
                            } else {
                                expandedHistoryIDs.remove(item.id)
                            }
                        }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Duration: \(item.durationMinutes) min")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.78))
                        Text("Productivity: \(item.productivityScore)%")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.78))
                        Text(item.notes)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.68))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    HStack {
                        Text(item.date, style: .date)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Text(subjectName(for: item.subjectID))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.72))
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .modifier(PlannerGlassCard(accent: .red.opacity(0.85)))
    }

    private var personalizationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(icon: "brain.head.profile", title: "AI Insights")

            Text("Adaptive difficulty suggests Physics problem-solving before 6 PM for 18% higher completion likelihood.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))

            Text("Focus prediction: tomorrow's optimal deep-work window is 7:30 PM - 9:00 PM.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .modifier(PlannerGlassCard(accent: .red.opacity(0.82)))
    }

    private func sectionTitle(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.red)
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
        }
    }

    private var shortWeekdays: [String] {
        ["M", "T", "W", "T", "F", "S", "S"]
    }

    private var weeklyHours: [Double] {
        [2.1, 3.2, 2.8, 4.0, 3.4, 2.7, 2.4]
    }

    private var generatedBlocks: [StudyBlock] {
        let focusLength = Int((availableHoursPerDay * 60) / 3)
        return [
            StudyBlock(title: "Concept Sprint", subjectID: subjects[safe: 0]?.id ?? UUID(), start: "06:30 PM", end: "\(formattedEndTime(startHour: 18, startMinute: 30, minutes: focusLength))"),
            StudyBlock(title: "Problem Drill", subjectID: subjects[safe: 1]?.id ?? UUID(), start: "08:00 PM", end: "\(formattedEndTime(startHour: 20, startMinute: 0, minutes: focusLength))"),
            StudyBlock(title: "Active Recall", subjectID: subjects[safe: 2]?.id ?? UUID(), start: "09:15 PM", end: "\(formattedEndTime(startHour: 21, startMinute: 15, minutes: focusLength))")
        ]
    }

    private var flattenedBlocks: [StudyBlock] {
        PlannerWeekday.allCases.flatMap { weeklyBlocks[$0, default: []] }
    }

    private var sortedTasks: [PlannerTask] {
        var result = tasks

        if let selectedFilterTag {
            result = result.filter { $0.tags.contains(selectedFilterTag) }
        }

        switch sortOption {
        case .deadline:
            result.sort { $0.dueDate < $1.dueDate }
        case .priority:
            let order: [PlannerPriority: Int] = [.high: 0, .medium: 1, .low: 2]
            result.sort { order[$0.priority, default: 3] < order[$1.priority, default: 3] }
        case .subject:
            result.sort { subjectName(for: $0.subjectID) < subjectName(for: $1.subjectID) }
        }

        return result
    }

    private func subjectName(for subjectID: UUID) -> String {
        subjects.first(where: { $0.id == subjectID })?.name ?? "General"
    }

    private func subjectAccent(for subjectID: UUID) -> Color {
        subjects.first(where: { $0.id == subjectID })?.accent ?? .red
    }

    private func toggleTask(_ id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            tasks[index].isComplete.toggle()
        }
    }

    private func deleteTask(_ id: UUID) {
        tasks.removeAll { $0.id == id }
    }

    private func postponeTask(_ id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].dueDate = calendar.date(byAdding: .day, value: 1, to: tasks[index].dueDate) ?? tasks[index].dueDate
    }

    private func goalProgress(for goal: PlannerGoal) -> Double {
        guard !goal.milestones.isEmpty else { return 0 }
        let done = goal.milestones.filter { $0.isDone }.count
        return Double(done) / Double(goal.milestones.count)
    }

    private func moveBlock(_ blockIDs: [String], to day: PlannerWeekday) -> Bool {
        guard let firstID = blockIDs.first, let uuid = UUID(uuidString: firstID) else { return false }

        var movedBlock: StudyBlock?
        for key in PlannerWeekday.allCases {
            if let index = weeklyBlocks[key, default: []].firstIndex(where: { $0.id == uuid }) {
                movedBlock = weeklyBlocks[key, default: []].remove(at: index)
                break
            }
        }

        guard let movedBlock else { return false }
        weeklyBlocks[day, default: []].append(movedBlock)
        return true
    }

    private func formattedEndTime(startHour: Int, startMinute: Int, minutes: Int) -> String {
        var components = DateComponents()
        components.hour = startHour
        components.minute = startMinute
        let start = calendar.date(from: components) ?? Date()
        let end = calendar.date(byAdding: .minute, value: minutes, to: start) ?? start
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: end)
    }

    private func seedData() {
        let seededSubjects = [
            PlannerSubject(name: "Mathematics", icon: "function", progress: 0.74, upcomingDeadline: calendar.date(byAdding: .day, value: 2, to: Date()) ?? Date(), tasksLeft: 4, accent: .red),
            PlannerSubject(name: "Physics", icon: "atom", progress: 0.58, upcomingDeadline: calendar.date(byAdding: .day, value: 4, to: Date()) ?? Date(), tasksLeft: 6, accent: .orange),
            PlannerSubject(name: "Chemistry", icon: "flask.fill", progress: 0.81, upcomingDeadline: calendar.date(byAdding: .day, value: 3, to: Date()) ?? Date(), tasksLeft: 2, accent: .pink),
            PlannerSubject(name: "History", icon: "book.closed.fill", progress: 0.43, upcomingDeadline: calendar.date(byAdding: .day, value: 5, to: Date()) ?? Date(), tasksLeft: 5, accent: .blue)
        ]
        subjects = seededSubjects

        tasks = [
            PlannerTask(title: "Derivatives practice set", subjectID: seededSubjects[0].id, priority: .high, dueDate: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date(), isComplete: false, tags: [.exam, .important]),
            PlannerTask(title: "Optics summary sheet", subjectID: seededSubjects[1].id, priority: .medium, dueDate: calendar.date(byAdding: .day, value: 2, to: Date()) ?? Date(), isComplete: false, tags: [.revision]),
            PlannerTask(title: "Organic reactions map", subjectID: seededSubjects[2].id, priority: .high, dueDate: calendar.date(byAdding: .day, value: 3, to: Date()) ?? Date(), isComplete: true, tags: [.assignment]),
            PlannerTask(title: "Industrial revolution timeline", subjectID: seededSubjects[3].id, priority: .low, dueDate: calendar.date(byAdding: .day, value: 4, to: Date()) ?? Date(), isComplete: false, tags: [.revision])
        ]

        weeklyBlocks = [
            .monday: [StudyBlock(title: "Math Drill", subjectID: seededSubjects[0].id, start: "06:00 PM", end: "06:45 PM")],
            .tuesday: [StudyBlock(title: "Physics Problems", subjectID: seededSubjects[1].id, start: "07:15 PM", end: "08:00 PM")],
            .wednesday: [StudyBlock(title: "Chem Review", subjectID: seededSubjects[2].id, start: "06:45 PM", end: "07:30 PM")],
            .thursday: [StudyBlock(title: "History Notes", subjectID: seededSubjects[3].id, start: "08:00 PM", end: "08:40 PM")],
            .friday: [StudyBlock(title: "Mock Quiz", subjectID: seededSubjects[0].id, start: "07:30 PM", end: "08:15 PM")],
            .saturday: [],
            .sunday: []
        ]

        goals = [
            PlannerGoal(
                title: "Finals Completion",
                targetDate: calendar.date(byAdding: .day, value: 24, to: Date()) ?? Date(),
                milestones: [
                    .init(title: "Finish Math Module 5", isDone: true),
                    .init(title: "Complete Physics Mock Test", isDone: false),
                    .init(title: "Revise Organic Chemistry", isDone: false)
                ]
            )
        ]

        history = [
            SessionHistoryItem(date: calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date(), subjectID: seededSubjects[0].id, durationMinutes: 50, productivityScore: 92, notes: "Strong concentration during problem-solving."),
            SessionHistoryItem(date: calendar.date(byAdding: .day, value: -2, to: Date()) ?? Date(), subjectID: seededSubjects[1].id, durationMinutes: 40, productivityScore: 84, notes: "Needed more time on conceptual questions."),
            SessionHistoryItem(date: calendar.date(byAdding: .day, value: -3, to: Date()) ?? Date(), subjectID: seededSubjects[3].id, durationMinutes: 35, productivityScore: 78, notes: "Session interrupted twice; adaptive reminders recommended.")
        ]
    }
}

private struct PlannerGlassCard: ViewModifier {
    let accent: Color

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black.opacity(0.32))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.25), Color.white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: accent.opacity(0.22), radius: 18, x: 0, y: 12)
            .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 6)
    }
}

private struct PlannerPressStyle: ButtonStyle {
    let scale: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .brightness(configuration.isPressed ? -0.02 : 0)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

private struct ProgressRing: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: 5)
            Circle()
                .trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))%")
                .font(.caption2.weight(.bold))
                .foregroundColor(.white)
        }
    }
}

private struct AddTaskSheet: View {
    let subjects: [PlannerSubject]
    let onAdd: (PlannerTask) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedSubjectID: UUID?
    @State private var selectedPriority: PlannerPriority = .medium
    @State private var dueDate = Date()
    @State private var selectedTag: PlannerTag = .assignment

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Task title", text: $title)
                }

                Section("Details") {
                    Picker("Subject", selection: $selectedSubjectID) {
                        ForEach(subjects) { subject in
                            Text(subject.name).tag(Optional(subject.id))
                        }
                    }

                    Picker("Priority", selection: $selectedPriority) {
                        ForEach(PlannerPriority.allCases) { priority in
                            Text(priority.rawValue).tag(priority)
                        }
                    }

                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date])

                    Picker("Tag", selection: $selectedTag) {
                        ForEach(PlannerTag.allCases) { tag in
                            Text(tag.rawValue).tag(tag)
                        }
                    }
                }
            }
            .navigationTitle("Add Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let fallbackID = subjects.first?.id ?? UUID()
                        let task = PlannerTask(
                            title: title.isEmpty ? "New Study Task" : title,
                            subjectID: selectedSubjectID ?? fallbackID,
                            priority: selectedPriority,
                            dueDate: dueDate,
                            isComplete: false,
                            tags: [selectedTag]
                        )
                        onAdd(task)
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            selectedSubjectID = subjects.first?.id
        }
    }
}

private struct FocusSessionView: View {
    let subject: PlannerSubject

    @Environment(\.dismiss) private var dismiss
    @State private var secondsRemaining = 25 * 60
    @State private var isRunning = true

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.17, green: 0.01, blue: 0.03)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: subject.icon)
                    .font(.system(size: 46))
                    .foregroundColor(.red)

                Text(subject.name)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(timeLabel)
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()

                Text("Distraction Lock Enabled")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.72))

                HStack(spacing: 12) {
                    Button(isRunning ? "Pause" : "Resume") {
                        isRunning.toggle()
                    }
                    .buttonStyle(FocusButtonStyle(primary: true))

                    Button("End") {
                        dismiss()
                    }
                    .buttonStyle(FocusButtonStyle(primary: false))
                }
            }
            .padding(24)
        }
        .onReceive(timer) { _ in
            guard isRunning, secondsRemaining > 0 else { return }
            secondsRemaining -= 1
        }
    }

    private var timeLabel: String {
        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct FocusButtonStyle: ButtonStyle {
    let primary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundColor(primary ? .white : .white.opacity(0.88))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(minWidth: 120)
            .background(primary ? Color.red : Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
