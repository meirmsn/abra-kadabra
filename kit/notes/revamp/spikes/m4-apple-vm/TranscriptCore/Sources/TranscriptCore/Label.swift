// Joins word timestamps (from the aligner) with speaker turns (from diarization): each word goes
// to the speaker whose turn overlaps it most, or the nearest turn when none overlaps.
public struct Word: Equatable {
    public let text: String
    public let start: Double
    public let end: Double
    public init(_ text: String, _ start: Double, _ end: Double) {
        self.text = text; self.start = start; self.end = end
    }
}

public struct SpeakerTurn: Equatable {
    public let speaker: String
    public let start: Double
    public let end: Double
    public init(_ speaker: String, _ start: Double, _ end: Double) {
        self.speaker = speaker; self.start = start; self.end = end
    }
}

public struct LabelledWord: Equatable {
    public let text: String
    public let speaker: String
}

public func label(words: [Word], turns: [SpeakerTurn]) -> [LabelledWord] {
    guard !turns.isEmpty else { return words.map { LabelledWord(text: $0.text, speaker: "?") } }
    return words.map { w in
        func overlap(_ t: SpeakerTurn) -> Double { max(0, min(w.end, t.end) - max(w.start, t.start)) }
        func distance(_ t: SpeakerTurn) -> Double { max(0, max(t.start - w.end, w.start - t.end)) }
        let best = turns.max { a, b in
            let (oa, ob) = (overlap(a), overlap(b))
            if oa != ob { return oa < ob }
            return distance(a) > distance(b)
        }!
        return LabelledWord(text: w.text, speaker: best.speaker)
    }
}

/// One line per run of consecutive words by the same speaker: "S1: hello there".
public func render(_ words: [LabelledWord]) -> String {
    var lines: [String] = []
    var current: (speaker: String, words: [String])?
    for w in words {
        if current?.speaker == w.speaker {
            current!.words.append(w.text)
        } else {
            if let c = current { lines.append("\(c.speaker): \(c.words.joined(separator: " "))") }
            current = (w.speaker, [w.text])
        }
    }
    if let c = current { lines.append("\(c.speaker): \(c.words.joined(separator: " "))") }
    return lines.joined(separator: "\n")
}
