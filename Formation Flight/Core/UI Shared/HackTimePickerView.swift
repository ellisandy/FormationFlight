// HackTimePickerView.swift
// Reusable picker for minutes/seconds duration
import SwiftUI

struct HackTimePickerView: View {
    // Bind to total seconds for the hack duration
    @Binding var hackDurationSeconds: TimeInterval?
    
    /// Largest duration the wheels can display: 180 minutes and 59 seconds.
    private static let maxPickerSeconds = 180 * 60 + 59

    /// Whole seconds safe to split into wheel positions.
    ///
    /// B-34: `Int(Double)` traps on `nan`/`±infinity`, so non-finite input reads as 0 and
    /// finite input is clamped to the range the wheels can actually show.
    private static func wholeSeconds(_ duration: TimeInterval?) -> Int {
        guard let duration, duration.isFinite else { return 0 }
        return Int(min(max(duration, 0), Double(maxPickerSeconds)))
    }

    var body: some View {
        // Provide a non-optional proxy with a default of 0 when nil
        let total = Self.wholeSeconds(hackDurationSeconds)
        let minutes = total / 60
        let seconds = total % 60

        HStack {
            // Minutes wheel 0-180
            Picker("Min", selection: Binding(
                get: { minutes },
                set: { newMin in
                    let clamped = max(0, min(180, newMin))
                    let newDuration = TimeInterval(clamped * 60 + seconds)
                    hackDurationSeconds = newDuration
                }
            )) {
                ForEach(0..<181, id: \.self) { m in
                    Text("\(m)m").tag(m)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            
            // Seconds wheel 0-59
            Picker("Sec", selection: Binding(
                get: { seconds },
                set: { newSec in
                    let clamped = max(0, min(59, newSec))
                    let newDuration = TimeInterval(minutes * 60 + clamped)
                    hackDurationSeconds = newDuration
                }
            )) {
                ForEach(0..<60, id: \.self) { s in
                    Text(String(format: "%02ds", s)).tag(s)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    StatefulPreviewWrapper(90.0 as Double?) { (binding: Binding<Double?>) in
        HackTimePickerView(hackDurationSeconds: binding)
            .padding()
    }
}

// Helper for previewing bindings
struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    private let content: (Binding<Value>) -> Content
    
    init(_ initialValue: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: initialValue)
        self.content = content
    }
    
    var body: some View {
        content($value)
    }
}
