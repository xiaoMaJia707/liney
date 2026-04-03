//
//  IslandPixelAnimation.swift
//  Liney
//
//  Author: everettjf
//

import Combine
import SwiftUI

// MARK: - Animation Style Enum

enum IslandPixelAnimationStyle: String, Codable, CaseIterable, Hashable {
    case none
    case sequential
    case sparkle
    case pixelDino
    case pixelDuck
    case pixelCrab
    case pixelFish
    case pixelCat
    case pixelDog
    case random

    var displayName: String {
        switch self {
        case .none: return "None"
        case .sequential: return "Sequential"
        case .sparkle: return "Sparkle"
        case .pixelDino: return "Pixel Dino"
        case .pixelDuck: return "Pixel Duck"
        case .pixelCrab: return "Pixel Crab"
        case .pixelFish: return "Pixel Fish"
        case .pixelCat: return "Pixel Cat"
        case .pixelDog: return "Pixel Dog"
        case .random: return "Random"
        }
    }

    var iconName: String {
        switch self {
        case .none: return "circle.dashed"
        case .sequential: return "chart.bar.fill"
        case .sparkle: return "sparkles"
        case .pixelDino: return "fossil.shell.fill"
        case .pixelDuck: return "duck.fill"
        case .pixelCrab: return "fish.fill"
        case .pixelFish: return "fish.fill"
        case .pixelCat: return "cat.fill"
        case .pixelDog: return "dog.fill"
        case .random: return "shuffle"
        }
    }

    /// All concrete (non-meta) styles that produce animation.
    static var concreteStyles: [IslandPixelAnimationStyle] {
        allCases.filter { $0 != .none && $0 != .random }
    }

    /// Pick a concrete style (resolving `.random`).
    var resolved: IslandPixelAnimationStyle {
        if self == .random {
            return Self.concreteStyles.randomElement()!
        }
        return self
    }
}

// MARK: - Shared palette

private let pixelColors: [Color] = [
    .red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink,
    .mint, .indigo, .teal,
]

// MARK: - Sequential Bar

struct IslandSequentialBar: View {
    private let count = 5
    @State private var activeIndex: Int = 0
    @State private var colors: [Color] = (0..<5).map { _ in pixelColors.randomElement()! }

    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(colors[i])
                    .frame(width: 3, height: 3)
                    .opacity(i == activeIndex ? 1 : 0.2)
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                activeIndex = (activeIndex + 1) % count
                colors[activeIndex] = pixelColors.randomElement()!
            }
        }
    }
}

// MARK: - Random Sparkle

struct IslandRandomSparkle: View {
    private let count = 4
    @State private var colors: [Color] = (0..<4).map { _ in pixelColors.randomElement()! }
    @State private var opacities: [Double] = (0..<4).map { _ in Double.random(in: 0.3...1) }

    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(colors[i])
                    .frame(width: 3, height: 3)
                    .opacity(opacities[i])
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                let target = Int.random(in: 1...count)
                for _ in 0..<target {
                    let idx = Int.random(in: 0..<count)
                    colors[idx] = pixelColors.randomElement()!
                    opacities[idx] = Double.random(in: 0.3...1)
                }
            }
        }
    }
}

// MARK: - Pixel Creature

/// A tiny pixel-art creature that alternates between two frames and cycles colors.
struct IslandPixelCreature: View {
    let frames: [[[Bool]]]
    let palette: [Color]

    @State private var frameIndex: Int = 0
    @State private var colorIndex: Int = 0

    private let timer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()

    private let pixelSize: CGFloat = 2

    var body: some View {
        let grid = frames[frameIndex]
        VStack(spacing: 0) {
            ForEach(0..<grid.count, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<grid[row].count, id: \.self) { col in
                        Rectangle()
                            .fill(grid[row][col] ? palette[colorIndex] : .clear)
                            .frame(width: pixelSize, height: pixelSize)
                    }
                }
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                frameIndex = (frameIndex + 1) % frames.count
                colorIndex = (colorIndex + 1) % palette.count
            }
        }
    }
}

// MARK: - Creature Definitions

private enum PixelCreatures {
    /// Parse "#" / "." strings into a Bool grid.
    static func parse(_ rows: [String]) -> [[Bool]] {
        rows.map { row in Array(row).map { $0 == "#" } }
    }

    // -- Dino (T-Rex, 7x7) --
    static let dinoFrame1 = parse([
        "..##...",
        "..###..",
        "..####.",
        ".######",
        "..####.",
        "..##...",
        "..#.#..",
    ])
    static let dinoFrame2 = parse([
        "..##...",
        "..###..",
        "..####.",
        ".######",
        "..####.",
        "..##...",
        ".#...#.",
    ])
    static let dinoPalette: [Color] = [.green, .mint, .teal, .cyan, .green, .yellow]

    // -- Duck (6x6) --
    static let duckFrame1 = parse([
        ".##...",
        "####..",
        ".####.",
        "..###.",
        "..##..",
        "..#.#.",
    ])
    static let duckFrame2 = parse([
        ".##...",
        "####..",
        ".####.",
        "..###.",
        "..##..",
        ".#..#.",
    ])
    static let duckPalette: [Color] = [.yellow, .orange, .yellow, .mint, .yellow, .pink]

    // -- Crab (7x5) --
    static let crabFrame1 = parse([
        "#.###.#",
        ".#####.",
        ".#####.",
        "..###..",
        ".#.#.#.",
    ])
    static let crabFrame2 = parse([
        ".#.#.#.",
        "#.###.#",
        ".#####.",
        "..###..",
        "#..#..#",
    ])
    static let crabPalette: [Color] = [.red, .orange, .red, .pink, .orange, .red]

    // -- Fish (7x5) --
    static let fishFrame1 = parse([
        "..###..",
        ".#####.",
        "#.#####",
        ".#####.",
        "..###..",
    ])
    static let fishFrame2 = parse([
        "...###.",
        "..#####",
        "#.#####",
        "..#####",
        "...###.",
    ])
    static let fishPalette: [Color] = [.blue, .cyan, .teal, .blue, .indigo, .cyan]

    // -- Cat (5x6) --
    static let catFrame1 = parse([
        "#...#",
        "##.##",
        ".###.",
        ".###.",
        "..#..",
        ".#.#.",
    ])
    static let catFrame2 = parse([
        "#...#",
        "##.##",
        ".###.",
        ".###.",
        "..#..",
        "#...#",
    ])
    static let catPalette: [Color] = [.orange, .yellow, .orange, .pink, .orange, .purple]

    // -- Dog (6x6) --
    static let dogFrame1 = parse([
        "##....",
        ".###..",
        ".####.",
        "..###.",
        "..##..",
        "..#.#.",
    ])
    static let dogFrame2 = parse([
        "##....",
        ".###..",
        ".####.",
        "..###.",
        "..##..",
        ".#..#.",
    ])
    static let dogPalette: [Color] = [.brown, .orange, .brown, .yellow, .brown, .red]
}

// MARK: - Creature Factory

private struct IslandDino: View {
    var body: some View {
        IslandPixelCreature(
            frames: [PixelCreatures.dinoFrame1, PixelCreatures.dinoFrame2],
            palette: PixelCreatures.dinoPalette
        )
    }
}

private struct IslandDuck: View {
    var body: some View {
        IslandPixelCreature(
            frames: [PixelCreatures.duckFrame1, PixelCreatures.duckFrame2],
            palette: PixelCreatures.duckPalette
        )
    }
}

private struct IslandCrab: View {
    var body: some View {
        IslandPixelCreature(
            frames: [PixelCreatures.crabFrame1, PixelCreatures.crabFrame2],
            palette: PixelCreatures.crabPalette
        )
    }
}

private struct IslandFish: View {
    var body: some View {
        IslandPixelCreature(
            frames: [PixelCreatures.fishFrame1, PixelCreatures.fishFrame2],
            palette: PixelCreatures.fishPalette
        )
    }
}

private struct IslandCat: View {
    var body: some View {
        IslandPixelCreature(
            frames: [PixelCreatures.catFrame1, PixelCreatures.catFrame2],
            palette: PixelCreatures.catPalette
        )
    }
}

private struct IslandDog: View {
    var body: some View {
        IslandPixelCreature(
            frames: [PixelCreatures.dogFrame1, PixelCreatures.dogFrame2],
            palette: PixelCreatures.dogPalette
        )
    }
}

// MARK: - Unified Wrapper

/// Shows the pixel animation for a given style. Resolves `.random` once on appear.
struct IslandPixelAnimationView: View {
    let style: IslandPixelAnimationStyle
    @State private var resolved: IslandPixelAnimationStyle = .sparkle

    var body: some View {
        Group {
            switch resolved {
            case .none:
                EmptyView()
            case .sequential:
                IslandSequentialBar()
            case .sparkle:
                IslandRandomSparkle()
            case .pixelDino:
                IslandDino()
            case .pixelDuck:
                IslandDuck()
            case .pixelCrab:
                IslandCrab()
            case .pixelFish:
                IslandFish()
            case .pixelCat:
                IslandCat()
            case .pixelDog:
                IslandDog()
            case .random:
                IslandRandomSparkle()
            }
        }
        .onAppear {
            resolved = style.resolved
        }
        .onChange(of: style) { _, newStyle in
            resolved = newStyle.resolved
        }
    }
}

// MARK: - Settings Preview Card

/// A mini Dynamic-Island-style preview used in Settings.
struct IslandPixelAnimationPreview: View {
    let style: IslandPixelAnimationStyle

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "macwindow.on.rectangle")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))

            Text("LINEY")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            if style != .none {
                IslandPixelAnimationView(style: style)
                    .frame(width: 20, height: 14)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.08), lineWidth: 0.5)
        )
    }
}
