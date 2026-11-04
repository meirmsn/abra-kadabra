// Gives each timed item the label of the span that overlaps it most, or of the nearest span when
// none overlaps: the kind of join an engine makes between two models' timed outputs.
public struct Item: Equatable {
    public let text: String
    public let start: Double
    public let end: Double
    public init(_ text: String, _ start: Double, _ end: Double) {
        self.text = text; self.start = start; self.end = end
    }
}

public struct Span: Equatable {
    public let label: String
    public let start: Double
    public let end: Double
    public init(_ label: String, _ start: Double, _ end: Double) {
        self.label = label; self.start = start; self.end = end
    }
}

public struct LabelledItem: Equatable {
    public let text: String
    public let label: String
}

public func label(items: [Item], spans: [Span]) -> [LabelledItem] {
    guard !spans.isEmpty else { return items.map { LabelledItem(text: $0.text, label: "?") } }
    return items.map { w in
        func overlap(_ t: Span) -> Double { max(0, min(w.end, t.end) - max(w.start, t.start)) }
        func distance(_ t: Span) -> Double { max(0, max(t.start - w.end, w.start - t.end)) }
        let best = spans.max { a, b in
            let (oa, ob) = (overlap(a), overlap(b))
            if oa != ob { return oa < ob }
            return distance(a) > distance(b)
        }!
        return LabelledItem(text: w.text, label: best.label)
    }
}

/// One line per run of consecutive items with the same label: "A: hello there".
public func render(_ items: [LabelledItem]) -> String {
    var lines: [String] = []
    var current: (label: String, items: [String])?
    for w in items {
        if current?.label == w.label {
            current!.items.append(w.text)
        } else {
            if let c = current { lines.append("\(c.label): \(c.items.joined(separator: " "))") }
            current = (w.label, [w.text])
        }
    }
    if let c = current { lines.append("\(c.label): \(c.items.joined(separator: " "))") }
    return lines.joined(separator: "\n")
}
