// TOTTimePickerView.swift
// Reusable picker for date + hour/minute/second components
import SwiftUI

struct TOTTimePickerView: View {
    @Binding var date: Date
    @Binding var hour: Int
    @Binding var minute: Int
    @Binding var second: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DatePicker("Date", selection: $date, displayedComponents: [.date])
                .datePickerStyle(.compact)
            
            HStack {
                // Hour wheel 1-24 (changed from 0-23)
                Picker("Hour", selection: $hour) {
                    ForEach(1..<25, id: \.self) { h in
                        Text(String(format: "%02d", h)).tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                
                // Minute wheel 0-59
                Picker("Minute", selection: $minute) {
                    ForEach(0..<60, id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                
                // Second wheel 0-59
                Picker("Second", selection: $second) {
                    ForEach(0..<60, id: \.self) { s in
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
