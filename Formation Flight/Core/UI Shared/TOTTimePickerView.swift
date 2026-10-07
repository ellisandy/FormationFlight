// TOTTimePickerView.swift
// Reusable picker for date + hour/minute/second components
import SwiftUI

struct TOTTimePickerView: View {
    /// Values offered by each wheel. Exposed so tests can check they line up
    /// with the `Date` model (`Date.hour` is 0...23, minute/second 0...59).
    static let hourRange = 0..<24
    static let minuteRange = 0..<60
    static let secondRange = 0..<60

    @Binding var date: Date
    @Binding var hour: Int
    @Binding var minute: Int
    @Binding var second: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DatePicker("Date", selection: $date, displayedComponents: [.date])
                .datePickerStyle(.compact)

            HStack {
                // Hour wheel 00-23, matching Date.hour
                Picker("Hour", selection: $hour) {
                    ForEach(Self.hourRange, id: \.self) { h in
                        Text(String(format: "%02d", h)).tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                // Minute wheel 0-59
                Picker("Minute", selection: $minute) {
                    ForEach(Self.minuteRange, id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                // Second wheel 0-59
                Picker("Second", selection: $second) {
                    ForEach(Self.secondRange, id: \.self) { s in
                        Text(String(format: "%02d", s)).tag(s)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
            .frame(height: 140)
            .scaleEffect(0.8)
            .clipped()
            .accessibilityElement(children: .contain)
        }
    }
}

// MARK: - Date component bindings

/// Hour/minute/second projections of a `Binding<Date>` for driving `TOTTimePickerView`.
///
/// These route through the shared `Date.updatingHour/Minute/Second(to:)` helpers so every
/// TOT editor clamps to 0...23 / 0...59 and never rolls the date over into the next day.
extension Binding where Value == Date {
    var hourComponent: Binding<Int> {
        Binding<Int>(
            get: { self.wrappedValue.hour },
            set: { self.wrappedValue = self.wrappedValue.updatingHour(to: $0) }
        )
    }

    var minuteComponent: Binding<Int> {
        Binding<Int>(
            get: { self.wrappedValue.minute },
            set: { self.wrappedValue = self.wrappedValue.updatingMinute(to: $0) }
        )
    }

    var secondComponent: Binding<Int> {
        Binding<Int>(
            get: { self.wrappedValue.second },
            set: { self.wrappedValue = self.wrappedValue.updatingSecond(to: $0) }
        )
    }
}

#Preview {
    StatefulPreviewWrapper((Date(), 12, 34, 56)) { binding in
        let dateBinding = Binding(get: { binding.wrappedValue.0 }, set: { binding.wrappedValue.0 = $0 })
        let hBinding = Binding(get: { binding.wrappedValue.1 }, set: { binding.wrappedValue.1 = $0 })
        let mBinding = Binding(get: { binding.wrappedValue.2 }, set: { binding.wrappedValue.2 = $0 })
        let sBinding = Binding(get: { binding.wrappedValue.3 }, set: { binding.wrappedValue.3 = $0 })
        TOTTimePickerView(date: dateBinding, hour: hBinding, minute: mBinding, second: sBinding)
            .padding()
    }
}
