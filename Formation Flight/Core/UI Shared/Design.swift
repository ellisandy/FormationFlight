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
}

public extension View {
    func cardBackground() -> some View {
        self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
