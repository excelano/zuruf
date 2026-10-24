// Ripples.swift
// AppCore
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

// Rings that spread from the talk button while it records, like ripples from
// a pebble, so recording shows around the finger holding it. Spread is how far
// a ring grows, as a multiple of the button's size.
struct Ripples: View {
    private static let period = 1.8
    private static let count = 3

    let spread: Double

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<Self.count, id: \.self) { index in
                    let progress = (time / Self.period + Double(index) / Double(Self.count))
                        .truncatingRemainder(dividingBy: 1)
                    Circle()
                        .stroke(Color.blue, lineWidth: 3)
                        .scaleEffect(1 + progress * spread)
                        .opacity(1 - progress)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
