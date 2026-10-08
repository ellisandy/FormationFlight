//
//  Design.swift
//  Formation Flight
//
//  Centralized design tokens and common view modifiers.
//

import SwiftUI

public enum Design {
    public enum Padding {
        public static let horizontal: CGFloat = 8
    }

    /// Widest the main content column grows (D-07). On iPad, edge-to-edge rows, pills and
    /// time wheels spread across ~1000 pt; this keeps them at a readable, iPhone-like width.
    public static let readableContentWidth: CGFloat = 700
}

public extension View {
    func cardBackground() -> some View {
        self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Centres a scroll view's content (List, Form, ScrollView) in a column no wider than
    /// `Design.readableContentWidth`, while the view itself, and so its scrolling and
    /// background, still fills the screen (D-07). No effect at iPhone widths.
    func readableScrollContent() -> some View {
        modifier(ReadableScrollContent())
    }

    /// Caps a non-scrolling view at `Design.readableContentWidth`, centred (D-07).
    func readableWidth() -> some View {
        self.frame(maxWidth: Design.readableContentWidth)
            .frame(maxWidth: .infinity)
    }
}

private struct ReadableScrollContent: ViewModifier {
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .contentMargins(.horizontal, max(0, (width - Design.readableContentWidth) / 2), for: .scrollContent)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}
