//
//  Array+Extensions.swift
//  Formation Flight
//
//  Created by Jack Ellis on 11/7/25.
//
import Foundation

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        var chunks: [[Element]] = []
        var start = 0
        while start < count {
            let end = Swift.min(start + size, count)
            chunks.append(Array(self[start..<end]))
            start = end
        }
        return chunks
    }
}
