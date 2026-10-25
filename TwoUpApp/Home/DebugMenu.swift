#if DEBUG
import SwiftUI
import TwoUpCore

/// DEBUG builds only. Five taps on the "TWO-UP" pill open it.
struct DebugMenu: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var picked = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Override today's date") {
                    DatePicker("Date and time", selection: $picked)
                    Button("Apply") { apply(picked) }
                    Button("Use real date") { env.clock.setDebugDate(nil); dismiss() }
                }
                Section("Jump to") {
                    jump("24 April, 23:59:50", month: 4, day: 24, hour: 23, minute: 59, second: 50)
                    jump("25 April, 09:00", month: 4, day: 25, hour: 9)
                    jump("26 April, 09:00", month: 4, day: 26, hour: 9)
                    jump("31 December, 23:59:50", month: 12, day: 31, hour: 23, minute: 59, second: 50)
                }
            }
            .navigationTitle("Debug date")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func jump(_ title: String, month: Int, day: Int, hour: Int = 0, minute: Int = 0, second: Int = 0) -> some View {
        Button(title) {
            let year = env.clock.calendar.component(.year, from: Date())
            let c = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
            if let date = env.clock.calendar.date(from: c) { apply(date) }
        }
    }

    private func apply(_ date: Date) {
        env.clock.setDebugDate(date)
        dismiss()
    }
}
#endif
