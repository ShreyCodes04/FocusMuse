import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct TodoView: View {
    struct Task: Identifiable, Codable, Equatable {
        let id: UUID
        var title: String
        var isCompleted: Bool
        var createdAt: Date

        init(id: UUID = UUID(), title: String, isCompleted: Bool = false, createdAt: Date = Date()) {
            self.id = id
            self.title = title
            self.isCompleted = isCompleted
            self.createdAt = createdAt
        }
    }

    let onBack: () -> Void

    @AppStorage("todo_tasks_v2") private var tasksData = Data()

    @State private var inputText = ""
    @State private var tasks: [Task] = []

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
                    HStack(spacing: 10) {
                        Button {
                            onBack()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)

                        Text("To-Do List")
                            .font(.title2.bold())
                            .foregroundColor(.white)

                        Spacer()
                    }

                    HStack(spacing: 10) {
                        taskInput

                        Button {
                            addTask()
                        } label: {
                            Image(systemName: "plus")
                                .font(.headline.weight(.bold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.red.opacity(0.85))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(spacing: 8) {
                        ForEach(tasks) { task in
                            HStack(spacing: 10) {
                                Button {
                                    toggleTask(task)
                                } label: {
                                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundColor(.white.opacity(0.95))
                                }
                                .buttonStyle(.plain)

                                Text(task.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.white)
                                    .strikethrough(task.isCompleted, color: .white.opacity(0.9))
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Button {
                                    deleteTask(task)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.85))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(12)
                            .background(task.isCompleted ? Color.red.opacity(0.5) : Color.red.opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 90)
            }
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .onAppear {
            loadTasks()
        }
    }

    @ViewBuilder
    private var taskInput: some View {
        #if canImport(UIKit)
        KeyboardOnlyTaskField(
            text: $inputText,
            placeholder: "Type Your Task here",
            onSubmit: addTask
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        #else
        TextField("Type Your Task here", text: $inputText)
            .autocorrectionDisabled()
            .submitLabel(SubmitLabel.done)
            .onSubmit { addTask() }
            .foregroundStyle(Color.white)
            .tint(Color.white)
            .overlay(alignment: Alignment.leading) {
                if inputText.isEmpty {
                    Text("Type Your Task here")
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.leading, 1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        #endif
    }

    private func addTask() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tasks.append(Task(title: trimmed))
        tasks.sort { $0.createdAt < $1.createdAt }
        inputText = ""
        saveTasks()
    }

    private func deleteTask(_ task: Task) {
        tasks.removeAll { $0.id == task.id }
        saveTasks()
    }

    private func toggleTask(_ task: Task) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isCompleted.toggle()
        saveTasks()
    }

    private func saveTasks() {
        do {
            tasksData = try JSONEncoder().encode(tasks)
        } catch {
            print("Todo encode error: \(error.localizedDescription)")
        }
    }

    private func loadTasks() {
        guard !tasksData.isEmpty else {
            tasks = []
            return
        }
        do {
            tasks = try JSONDecoder().decode([Task].self, from: tasksData)
        } catch {
            tasks = []
            print("Todo decode error: \(error.localizedDescription)")
        }
    }
}

#if canImport(UIKit)
private struct KeyboardOnlyTaskField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let field = KeyboardOnlyTextField()
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)
        field.textColor = .white
        field.tintColor = .white
        field.textContentType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.returnKeyType = .done
        field.inputAssistantItem.leadingBarButtonGroups = []
        field.inputAssistantItem.trailingBarButtonGroups = []
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.75)]
        )
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        let onSubmit: () -> Void

        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            _text = text
            self.onSubmit = onSubmit
        }

        @objc func textDidChange(_ sender: UITextField) {
            text = sender.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            onSubmit()
            return false
        }
    }
}

private final class KeyboardOnlyTextField: UITextField {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        false
    }

    override func buildMenu(with builder: any UIMenuBuilder) {
        builder.remove(menu: .lookup)
        builder.remove(menu: .find)
        builder.remove(menu: .replace)
        builder.remove(menu: .share)
        builder.remove(menu: .textStyle)
        builder.remove(menu: .autoFill)
    }
}
#endif
