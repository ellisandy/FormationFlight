//
//  FlightViewVersion2e.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/28/23.
//

import SwiftUI
import MapKit

fileprivate enum Constants {
    static let radius: CGFloat = 16
    static let indicatorHeight: CGFloat = 6
    static let indicatorWidth: CGFloat = 60
    static let snapRatio: CGFloat = 0.25
    static let minHeightRatio: CGFloat = 0.30
}

private struct ContentHeightKey: @MainActor PreferenceKey {
    @MainActor static var defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        if let next = nextValue() { value = next }
    }
}

private struct FirstItemHeightKey: @MainActor PreferenceKey {
    @MainActor static var defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        if let next = nextValue() { value = next }
    }
}

struct SlidingSheetView<Content: View>: View {
    @State var isOpen: Bool = false
    @GestureState private var translation: CGFloat = 0
    
    @State private var contentHeight: CGFloat = 0
    @State private var firstItemHeight: CGFloat = 0

    var maxHeightMultiplier: CGFloat
    let sheetContent: Content

    init(maxHeightMultiplier: CGFloat = 0.4, @ViewBuilder sheetContent: () -> Content) {
        self.maxHeightMultiplier = maxHeightMultiplier
        self.sheetContent = sheetContent()
    }

    private func offset() -> CGFloat {
        // When closed, show only the first item (plus indicator area). When open, offset is 0.
        guard contentHeight > 0 else { return 0 }
        let collapsedVisibleHeight = firstItemHeight > 0 ? firstItemHeight + Constants.indicatorHeight + 16 : min(contentHeight * Constants.minHeightRatio, contentHeight) - 20
        let closedOffset = max(contentHeight - collapsedVisibleHeight, 0)
        return isOpen ? 0 : closedOffset
    }

    private var indicator: some View {
        RoundedRectangle(cornerRadius: Constants.radius)
            .fill(Color.secondary)
            .frame(
                width: Constants.indicatorWidth,
                height: Constants.indicatorHeight
        )
    }
    
    private var sheetBackground: some View {
        RoundedRectangle(cornerRadius: Constants.radius, style: .continuous)
            .fill(Color(.systemBackground))
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                indicator
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                // Measure entire content height
                ZStack(alignment: .top) {
                    sheetContent
                        .background(
                            GeometryReader { proxy in
                                Color.clear
                                    .preference(key: ContentHeightKey.self, value: proxy.size.height)
                            }
                        )
                    // Measure the first child height by overlaying an invisible reader aligned to the top; consumers should ensure their first element is laid out at the top of sheetContent
                    Color.clear
                        .frame(height: 0)
                        .background(
                            GeometryReader { _ in
                                Color.clear
                            }
                        )
                }
            }
            .frame(width: geometry.size.width, alignment: .top)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(Constants.radius)
            .frame(height: geometry.size.height, alignment: .bottom)
            .offset(y: max(offset() + self.translation, 0))
            .animation(.interactiveSpring(), value: isOpen)
            .animation(.interactiveSpring(), value: translation)
            .onPreferenceChange(ContentHeightKey.self) { value in
                if let value = value, value > 0 {
                    self.contentHeight = value
                }
            }
            .onPreferenceChange(FirstItemHeightKey.self) { value in
                if let value = value, value > 0 {
                    self.firstItemHeight = value
                }
            }
            .gesture(
                DragGesture()
                    .updating(self.$translation) { value, state, _ in
                        state = value.translation.height
                    }.onEnded { value in
                        let snapDistance = max(contentHeight * Constants.snapRatio, 20)
                        guard abs(value.translation.height) > snapDistance else {
                            return
                        }
                        self.isOpen = value.translation.height < 0
                    })
        }
    }
}

private struct FirstItemMeasurer<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: FirstItemHeightKey.self, value: proxy.size.height)
                }
            )
    }
}

struct TestView: View {
    @State private var bottomSheetShown = true
    
    var body: some View {
        ZStack {
            Color.blue
            VStack {
                Spacer()
                SlidingSheetView() {
                    VStack(spacing: 0) {
                        FirstItemMeasurer { Text("Handle Area") }
                        VStack {
                            ForEach(0..<10) { i in
                                Text("Row \(i)")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(i % 2 == 0 ? Color.green.opacity(0.3) : Color.green.opacity(0.15))
                            }
                        }
                    }
                }
            }

        }.ignoresSafeArea(.all)
    }
}
    
#Preview {
    return TestView()
}
