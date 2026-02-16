import SwiftUI

struct SetGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var goalDuration: Int

    @State private var hourSelection: Int
    @State private var minuteSelection: Int
    @State private var secondSelection: Int

    init(goalDuration: Binding<Int>) {
        _goalDuration = goalDuration
        let total = max(goalDuration.wrappedValue, 1)
        _hourSelection = State(initialValue: total / 3600)
        _minuteSelection = State(initialValue: (total % 3600) / 60)
        _secondSelection = State(initialValue: total % 60)
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

            VStack(spacing: 18) {
                Text("Set Study Goal")
                    .font(.title.bold())
                    .foregroundColor(.white)

                HStack(spacing: 0) {
                    Picker("Hours", selection: $hourSelection) {
                        ForEach(0..<24, id: \.self) { value in
                            Text("\(value)h")
                                .foregroundStyle(.white)
                                .tag(value)
                        }
                    }
                    #if os(macOS)
                    .pickerStyle(.menu)
                    #else
                    .pickerStyle(.wheel)
                    #endif

                    Picker("Minutes", selection: $minuteSelection) {
                        ForEach(0..<60, id: \.self) { value in
                            Text("\(value)m")
                                .foregroundStyle(.white)
                                .tag(value)
                        }
                    }
                    #if os(macOS)
                    .pickerStyle(.menu)
                    #else
                    .pickerStyle(.wheel)
                    #endif

                    Picker("Seconds", selection: $secondSelection) {
                        ForEach(0..<60, id: \.self) { value in
                            Text("\(value)s")
                                .foregroundStyle(.white)
                                .tag(value)
                        }
                    }
                    #if os(macOS)
                    .pickerStyle(.menu)
                    #else
                    .pickerStyle(.wheel)
                    #endif
                }
                .frame(height: 180)
                .padding(.horizontal, 8)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Button("Save Goal") {
                    goalDuration = max((hourSelection * 3600) + (minuteSelection * 60) + secondSelection, 1)
                    dismiss()
                }
                .font(.headline.bold())
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(20)
        }
        .navigationTitle("Set Goal")
        .navigationBarTitleDisplayMode(.inline)
    }
}
