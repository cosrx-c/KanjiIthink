//
//  ContentView.swift
//  Sumi — kanji, one quiet step at a time.
//
//  Design principle: munkens mat, the monk's meal — serve only what
//  nourishes. Every screen offers one thing to do. Scheduling, pacing,
//  catch-up after a break, error analysis, writing unlocks and reminders
//  all happen behind it, out of sight.
//
//  Everything lives in this file so it syncs cleanly through Swift
//  Playgrounds and GitHub:
//
//    1. Design system      tokens and the few shared controls
//    2. Content model      kanji, words, passages, look-alikes (JSON-backed)
//    3. Language helpers   furigana markup, kana and romaji conversion
//    4. Memory model       FSRS-6 scheduler and the study-day clock
//    5. Store              persistence, progress, statistics, import/export
//    6. Sessions           lesson and review queues, undo
//    7. Screens            Home, Study, Library, Settings, onboarding
//    8. Built-in content   the starter pack as embedded JSON
//
//  The research behind each decision is in docs/RESEARCH.md at the root
//  of the repository (next to this Sumi.swiftpm package).
//

import SwiftUI
import PencilKit
import AVFoundation
import UniformTypeIdentifiers
import UserNotifications
import UIKit

// MARK: - 1. Design system

/// Spacing on a 4-pt grid.
enum Space {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

enum Radius {
    static let chip: CGFloat = 10
    static let control: CGFloat = 14
    static let card: CGFloat = 20
}

enum Metrics {
    /// Comfortable line length for reading (about 35 Japanese characters).
    static let readableWidth: CGFloat = 600
    /// Wider column for grids on iPad and the inner display of iPhone Duo.
    static let gridWidth: CGFloat = 900
    /// Primary actions stay thumb-sized instead of stretching across iPad.
    static let actionWidth: CGFloat = 420
    static let minTap: CGFloat = 44
    static let buttonHeight: CGFloat = 50
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Color {
    /// A color that adapts to light/dark appearance and to Increase Contrast.
    static func dynamic(_ light: UInt32, _ dark: UInt32,
                        highLight: UInt32? = nil, highDark: UInt32? = nil) -> Color {
        Color(uiColor: UIColor { traits in
            let high = traits.accessibilityContrast == .high
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: high ? (highDark ?? dark) : dark)
            }
            return UIColor(hex: high ? (highLight ?? light) : light)
        })
    }
}

/// System colors carry the interface, so it adapts to Dark Mode, Increase
/// Contrast and the platform's materials for free. One accent (藍 indigo)
/// marks the single primary action; the remaining hues only ever mean
/// something (correct, wrong, a hint).
enum Palette {
    static let paper = Color(uiColor: .systemBackground)
    static let surface = Color(uiColor: .secondarySystemBackground)
    static let sunken = Color(uiColor: .tertiarySystemFill)
    static let hairline = Color(uiColor: .separator)
    static let ink = Color.primary
    static let ink2 = Color.secondary
    static let ink3 = Color(uiColor: .tertiaryLabel)
    static let accent = Color.dynamic(0x2D4F9E, 0x93ABEB, highLight: 0x1E3A7A, highDark: 0xB4C6F5)
    static let onAccent = Color.dynamic(0xFFFFFF, 0x0D1530)
    static let shu = Color.dynamic(0xC2412D, 0xF08A74, highLight: 0x9C2E1D, highDark: 0xF6A897)
    static let matcha = Color.dynamic(0x3F7A3A, 0x94C98A, highLight: 0x2C5E28, highDark: 0xB5DDAD)
    static let kohaku = Color.dynamic(0x9A6A0B, 0xE5B65A, highLight: 0x7A5208, highDark: 0xF0CC85)
    static let asagi = Color.dynamic(0x2A7F8F, 0x7CC4D1, highLight: 0x1B6170, highDark: 0xA6DAE3)
    static let murasaki = Color.dynamic(0x6B4E9B, 0xB79BE0, highLight: 0x523780, highDark: 0xCDB8EE)
}

/// Japanese typefaces bundled with iOS. Kanji are always set in Hiragino so
/// they render with Japanese glyph shapes, never Chinese fallbacks — a real
/// problem on devices whose language isn't Japanese (Han unification).
enum JPFace: String, Codable, CaseIterable, Identifiable {
    case gothic, mincho, rounded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gothic: return "Gothic"
        case .mincho: return "Mincho"
        case .rounded: return "Rounded"
        }
    }

    func fontName(bold: Bool) -> String {
        switch self {
        case .gothic: return bold ? "HiraginoSans-W6" : "HiraginoSans-W3"
        case .mincho: return bold ? "HiraMinProN-W6" : "HiraMinProN-W3"
        case .rounded: return "HiraMaruProN-W4"
        }
    }
}

extension Font {
    /// Japanese text that scales with Dynamic Type.
    static func jp(_ size: CGFloat, bold: Bool = false, face: JPFace = .gothic,
                   relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(face.fontName(bold: bold), size: size, relativeTo: style)
    }

    /// Japanese text at an exact size (hero glyphs that are already clamped).
    static func jpFixed(_ size: CGFloat, bold: Bool = false, face: JPFace = .gothic) -> Font {
        .custom(face.fontName(bold: bold), fixedSize: size)
    }
}

extension View {
    /// Centers content in a comfortable reading column on wide screens.
    func readableColumn() -> some View {
        frame(maxWidth: Metrics.readableWidth).frame(maxWidth: .infinity)
    }

    /// Caps an action area at thumb size and centers it.
    func actionColumn() -> some View {
        frame(maxWidth: Metrics.actionWidth).frame(maxWidth: .infinity)
    }
}

/// The app's only button. System bordered styles keep Apple's materials and
/// shapes (including Liquid Glass on newer systems); the primary kind is
/// filled with the accent, the secondary kind is a neutral tint.
struct ActionButton: View {
    enum Kind {
        case primary, secondary
    }

    let title: String
    var kind: Kind = .primary
    let action: () -> Void

    var body: some View {
        switch kind {
        case .primary:
            Button(action: action) {
                label.foregroundStyle(Palette.onAccent)
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.accent)
            .controlSize(.large)
        case .secondary:
            Button(action: action) {
                label
            }
            .buttonStyle(.bordered)
            .tint(Color.primary)
            .controlSize(.large)
        }
    }

    private var label: some View {
        Text(title)
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
    }
}

/// A small caps caption that names a task without competing with it.
struct Caption: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.medium))
            .tracking(1.2)
            .foregroundStyle(Palette.ink3)
    }
}

// MARK: Shared pieces

/// The 田-shaped guide found on Japanese practice paper (練習用紙).
struct PracticeGrid: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: w / 2, y: 0))
                    p.addLine(to: CGPoint(x: w / 2, y: h))
                    p.move(to: CGPoint(x: 0, y: h / 2))
                    p.addLine(to: CGPoint(x: w, y: h / 2))
                }
                .stroke(Palette.hairline, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 1)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A vermilion seal (判子) used to mark a finished session — in Japan a
/// stamp is how something is signed off as done.
struct Hanko: View {
    var glyph = "済"
    var size: CGFloat = 96
    @State private var stamped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().strokeBorder(Palette.shu, lineWidth: size * 0.06)
            Text(glyph)
                .font(.jpFixed(size * 0.5, bold: true, face: .mincho))
                .foregroundStyle(Palette.shu)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(-8))
        .scaleEffect(stamped || reduceMotion ? 1 : 1.5)
        .opacity(stamped ? 1 : 0)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.55)) {
                stamped = true
            }
        }
        .accessibilityHidden(true)
    }
}

/// Horizontal shake used when an answer is wrong.
struct Shake: GeometryEffect {
    var travel: CGFloat = 8
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(animatableData * .pi * 4), y: 0))
    }
}

enum Haptics {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}

/// Wraps child views onto new lines like text. Used for furigana runs,
/// chips and reading lists.
struct FlowLayout: Layout {
    var spacing: CGFloat = 0
    var lineSpacing: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                y += rowHeight + lineSpacing
                x = 0
                rowHeight = 0
            }
            x += size.width
            widest = max(widest, x)
            x += spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(widest, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + lineSpacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Only ever used from the main thread, so the unchecked conformance (which
/// the delegate protocol requires) is safe.
final class Speaker: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    static let shared = Speaker()
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speaks Japanese text. Callers pass kana where possible so the voice
    /// never guesses a kanji reading.
    func say(_ text: String) {
        guard !text.isEmpty else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

struct SpeakButton: View {
    let text: String
    var label = "Play pronunciation"

    var body: some View {
        Button {
            Speaker.shared.say(text)
        } label: {
            Image(systemName: "speaker.wave.2")
                .font(.body.weight(.medium))
                .foregroundStyle(Palette.accent)
                .frame(width: Metrics.minTap, height: Metrics.minTap)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - 2. Content model
//
// Content is plain JSON (see docs/CONTENT_SCHEMA.md) so new levels can be
// added by importing a file — no code changes. Decoding is lenient: optional
// fields can be left out of a pack.

enum JLPTLevel: Int, Codable, CaseIterable, Identifiable, Comparable {
    case n5 = 5, n4 = 4, n3 = 3, n2 = 2, n1 = 1, beyond = 0

    var id: Int { rawValue }

    var label: String { self == .beyond ? "Beyond" : "N\(rawValue)" }

    var name: String {
        switch self {
        case .n5: return "Beginner"
        case .n4: return "Elementary"
        case .n3: return "Intermediate"
        case .n2: return "Upper intermediate"
        case .n1: return "Advanced"
        case .beyond: return "Jōyō and beyond"
        }
    }

    /// Study order: N5 first, "beyond" last.
    var order: Int { self == .beyond ? 6 : 6 - rawValue }

    static func < (lhs: JLPTLevel, rhs: JLPTLevel) -> Bool { lhs.order < rhs.order }
}

/// How the character was formed (六書). Knowing the type changes how you
/// study it: pictures are remembered as images, sound+meaning compounds by
/// their phonetic part.
enum KanjiKind: String, Codable {
    case pictograph, indicative, compound, phonetic, borrowed

    var title: String {
        switch self {
        case .pictograph: return "Picture"
        case .indicative: return "Symbol"
        case .compound: return "Combined idea"
        case .phonetic: return "Sound + meaning"
        case .borrowed: return "Borrowed"
        }
    }

    var japanese: String {
        switch self {
        case .pictograph: return "象形"
        case .indicative: return "指事"
        case .compound: return "会意"
        case .phonetic: return "形声"
        case .borrowed: return "仮借"
        }
    }

    var explanation: String {
        switch self {
        case .pictograph: return "Started life as a drawing of the thing itself."
        case .indicative: return "An abstract sign that points at an idea."
        case .compound: return "Meaningful parts combine into a new idea."
        case .phonetic: return "One part hints at the meaning, another at the on'yomi. About 4 in 5 kanji work this way."
        case .borrowed: return "Borrowed for its sound to write a word that had no kanji of its own."
        }
    }
}

struct Part: Codable, Hashable {
    var glyph: String
    var meaning: String
}

struct Word: Codable, Hashable, Identifiable {
    var word: String
    /// Hiragana. Alternatives are separated by "/" (e.g. "にほん/にっぽん").
    var reading: String
    var meaning: String

    var id: String { word + "|" + reading }
    var readings: [String] { reading.split(separator: "/").map { String($0) } }
    var primaryReading: String { readings.first ?? reading }
}

struct Kanji: Codable, Hashable, Identifiable {
    var glyph: String
    var level: JLPTLevel
    var strokes: Int
    var meanings: [String]
    var on: [String]
    var kun: [String]
    var kind: KanjiKind?
    var parts: [Part]
    var phonetic: String?
    var mnemonic: String
    var words: [Word]
    var sentence: String
    var translation: String
    var usage: String?

    var id: String { glyph }
    var primaryMeaning: String { meanings.first ?? "" }
    var meaningList: String { meanings.joined(separator: ", ") }

    enum CodingKeys: String, CodingKey {
        case glyph, level, strokes, meanings, on, kun, kind, parts, phonetic
        case mnemonic, words, sentence, translation, usage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        glyph = try c.decode(String.self, forKey: .glyph)
        level = (try? c.decode(JLPTLevel.self, forKey: .level)) ?? .beyond
        strokes = (try? c.decode(Int.self, forKey: .strokes)) ?? 0
        meanings = (try? c.decode([String].self, forKey: .meanings)) ?? []
        on = (try? c.decode([String].self, forKey: .on)) ?? []
        kun = (try? c.decode([String].self, forKey: .kun)) ?? []
        kind = try? c.decode(KanjiKind.self, forKey: .kind)
        parts = (try? c.decode([Part].self, forKey: .parts)) ?? []
        phonetic = try? c.decode(String.self, forKey: .phonetic)
        mnemonic = (try? c.decode(String.self, forKey: .mnemonic)) ?? ""
        words = (try? c.decode([Word].self, forKey: .words)) ?? []
        sentence = (try? c.decode(String.self, forKey: .sentence)) ?? ""
        translation = (try? c.decode(String.self, forKey: .translation)) ?? ""
        usage = try? c.decode(String.self, forKey: .usage)
    }
}

struct PassageLine: Codable, Hashable {
    var speaker: String?
    var jp: String
    var en: String
}

struct PassageNote: Codable, Hashable {
    /// The lens the note looks through: Culture, Register, Discourse,
    /// Conversation, Intercultural, Word building…
    var lens: String
    var text: String

    var symbol: String {
        switch lens.lowercased() {
        case "culture": return "globe.asia.australia"
        case "register": return "person.2"
        case "discourse": return "text.alignleft"
        case "conversation": return "bubble.left.and.bubble.right"
        case "intercultural": return "hands.sparkles"
        case "word building": return "square.stack.3d.up"
        default: return "lightbulb"
        }
    }
}

struct Question: Codable, Hashable {
    var prompt: String
    var options: [String]
    var answer: Int
    var explanation: String?
}

struct Passage: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var titleEN: String
    var genre: String
    var topic: String
    var level: JLPTLevel
    var lines: [PassageLine]
    var notes: [PassageNote]?
    var question: Question?
}

struct Confusion: Codable, Hashable, Identifiable {
    var glyphs: [String]
    var tip: String

    var id: String { glyphs.joined() }
}

struct ContentPack: Codable {
    var name: String
    var kanji: [Kanji]
    var passages: [Passage]?
    var confusions: [Confusion]?
}

/// Built-in content plus any imported packs. Later packs override earlier
/// ones glyph by glyph, so a pack can also correct the starter content.
struct ContentLibrary {
    var kanji: [Kanji] = []
    var byGlyph: [String: Kanji] = [:]
    var passages: [Passage] = []
    var confusions: [Confusion] = []

    init(packs: [ContentPack]) {
        var kanjiOrder: [String] = []
        var kanjiTable: [String: Kanji] = [:]
        var passageOrder: [String] = []
        var passageTable: [String: Passage] = [:]
        var confusionOrder: [String] = []
        var confusionTable: [String: Confusion] = [:]
        for pack in packs {
            for k in pack.kanji where !k.glyph.isEmpty {
                if kanjiTable[k.glyph] == nil { kanjiOrder.append(k.glyph) }
                kanjiTable[k.glyph] = k
            }
            for p in pack.passages ?? [] {
                if passageTable[p.id] == nil { passageOrder.append(p.id) }
                passageTable[p.id] = p
            }
            for c in pack.confusions ?? [] {
                if confusionTable[c.id] == nil { confusionOrder.append(c.id) }
                confusionTable[c.id] = c
            }
        }
        byGlyph = kanjiTable
        kanji = kanjiOrder.compactMap { kanjiTable[$0] }
        passages = passageOrder.compactMap { passageTable[$0] }
        confusions = confusionOrder.compactMap { confusionTable[$0] }
    }

    func kanjiList(for level: JLPTLevel?) -> [Kanji] {
        guard let level = level else { return kanji }
        return kanji.filter { $0.level == level }
    }

    func confusions(for glyph: String) -> [Confusion] {
        confusions.filter { $0.glyphs.contains(glyph) }
    }

    var levelsWithContent: [JLPTLevel] {
        JLPTLevel.allCases.filter { level in kanji.contains { $0.level == level } }
    }
}

enum BuiltIn {
    static let pack: ContentPack = {
        do {
            return try JSONDecoder().decode(ContentPack.self, from: Data(builtInContentJSON.utf8))
        } catch {
            assertionFailure("Built-in content failed to decode: \(error)")
            return ContentPack(name: "Core", kanji: [], passages: [], confusions: [])
        }
    }()
}

// MARK: - 3. Language helpers

extension Character {
    var isKanji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value)
    }
}

/// Furigana markup: `{今日|きょう}は{雨|あめ}です。`
struct RubyUnit: Hashable, Identifiable {
    var base: String
    var reading: String?

    var id: String { base + "|" + (reading ?? "") }
    var hasKanji: Bool { base.contains { $0.isKanji } }
}

struct RubyToken: Identifiable {
    var id: Int
    var units: [RubyUnit]
}

enum Ruby {
    static func parse(_ markup: String) -> [RubyUnit] {
        var result: [RubyUnit] = []
        var plain = ""
        var i = markup.startIndex
        while i < markup.endIndex {
            if markup[i] == "{",
               let close = markup[i...].firstIndex(of: "}"),
               let bar = markup[i..<close].firstIndex(of: "|") {
                if !plain.isEmpty {
                    result.append(RubyUnit(base: plain, reading: nil))
                    plain = ""
                }
                let base = String(markup[markup.index(after: i)..<bar])
                let reading = String(markup[markup.index(after: bar)..<close])
                result.append(RubyUnit(base: base, reading: reading))
                i = markup.index(after: close)
            } else {
                plain.append(markup[i])
                i = markup.index(after: i)
            }
        }
        if !plain.isEmpty { result.append(RubyUnit(base: plain, reading: nil)) }
        return result
    }

    /// Text without readings, as it would be printed.
    static func plain(_ markup: String) -> String {
        parse(markup).map(\.base).joined()
    }

    /// Text with every annotated word replaced by its reading — what the
    /// speech voice receives, so it can't misread a kanji.
    static func spoken(_ markup: String) -> String {
        parse(markup).map { $0.reading ?? $0.base }.joined()
    }

    /// Characters that may not start a line, and ones that may not end it
    /// (Japanese line-breaking rules, 禁則処理).
    private static let noLineStart: Set<Character> = [
        "。", "、", "」", "』", "）", "！", "？", "ー", "・", "：", "…",
        "ぁ", "ぃ", "ぅ", "ぇ", "ぉ", "っ", "ゃ", "ゅ", "ょ",
        "ァ", "ィ", "ゥ", "ェ", "ォ", "ッ", "ャ", "ュ", "ョ",
        ")", "!", "?", ".", ","
    ]
    private static let noLineEnd: Set<Character> = ["「", "『", "（", "("]

    /// Groups units into unbreakable tokens: annotated words stay whole,
    /// plain text breaks between characters, and punctuation clings to its
    /// neighbour so a line never starts with 。 or ends with 「.
    static func tokens(_ markup: String) -> [RubyToken] {
        var groups: [[RubyUnit]] = []
        var pendingOpen: [RubyUnit] = []

        func push(_ unit: RubyUnit, attach: Bool) {
            if attach, !groups.isEmpty, pendingOpen.isEmpty {
                groups[groups.count - 1].append(unit)
            } else {
                groups.append(pendingOpen + [unit])
                pendingOpen = []
            }
        }

        for unit in parse(markup) {
            if unit.reading != nil {
                push(unit, attach: false)
                continue
            }
            for ch in unit.base {
                let single = RubyUnit(base: String(ch), reading: nil)
                if noLineEnd.contains(ch) {
                    pendingOpen.append(single)
                } else {
                    push(single, attach: noLineStart.contains(ch))
                }
            }
        }
        if !pendingOpen.isEmpty { groups.append(pendingOpen) }
        return groups.enumerated().map { RubyToken(id: $0.offset, units: $0.element) }
    }
}

enum Kana {
    static func toHiragana(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for u in text.unicodeScalars {
            if (0x30A1...0x30F6).contains(u.value), let h = Unicode.Scalar(u.value - 0x60) {
                scalars.append(h)
            } else {
                scalars.append(u)
            }
        }
        return String(scalars)
    }

    /// Normalises an answer for comparison: hiragana only, no spaces or
    /// okurigana markers.
    static func normalize(_ text: String) -> String {
        var s = toHiragana(text.trimmingCharacters(in: .whitespacesAndNewlines))
        for junk in [" ", "　", ".", "-", "・"] {
            s = s.replacingOccurrences(of: junk, with: "")
        }
        return s
    }

    /// Removes dakuten and handakuten (が → か, ぱ → は).
    static func stripVoicing(_ text: String) -> String {
        let decomposed = text.decomposedStringWithCanonicalMapping
        let kept = decomposed.unicodeScalars.filter { $0.value != 0x3099 && $0.value != 0x309A }
        var view = String.UnicodeScalarView()
        view.append(contentsOf: kept)
        return String(view).precomposedStringWithCanonicalMapping
    }

    private static let oRow: Set<Character> = Set("おこそとのほもよろをごぞどぼぽょ")
    private static let uRow: Set<Character> = Set("うくすつぬふむゆるぐずづぶぷゅ")
    private static let eRow: Set<Character> = Set("えけせてねへめれげぜでべぺ")

    /// Collapses long vowels (とうきょう → ときょ) so near-misses can be spotted.
    static func collapseLongVowels(_ text: String) -> String {
        var out = ""
        for ch in text {
            if let last = out.last {
                if ch == "う" && (oRow.contains(last) || uRow.contains(last)) { continue }
                if ch == "お" && oRow.contains(last) { continue }
                if ch == "い" && eRow.contains(last) { continue }
            }
            out.append(ch)
        }
        return out
    }
}

/// Live romaji → hiragana conversion, so learners without a Japanese
/// keyboard can still produce kana (Hepburn, Kunrei and IME spellings).
enum Romaji {
    private static let table: [String: String] = [
        "a": "あ", "i": "い", "u": "う", "e": "え", "o": "お",
        "ka": "か", "ki": "き", "ku": "く", "ke": "け", "ko": "こ",
        "sa": "さ", "si": "し", "shi": "し", "su": "す", "se": "せ", "so": "そ",
        "ta": "た", "ti": "ち", "chi": "ち", "tu": "つ", "tsu": "つ", "te": "て", "to": "と",
        "na": "な", "ni": "に", "nu": "ぬ", "ne": "ね", "no": "の",
        "ha": "は", "hi": "ひ", "hu": "ふ", "fu": "ふ", "he": "へ", "ho": "ほ",
        "ma": "ま", "mi": "み", "mu": "む", "me": "め", "mo": "も",
        "ya": "や", "yu": "ゆ", "yo": "よ",
        "ra": "ら", "ri": "り", "ru": "る", "re": "れ", "ro": "ろ",
        "wa": "わ", "wo": "を", "wi": "うぃ", "we": "うぇ",
        "ga": "が", "gi": "ぎ", "gu": "ぐ", "ge": "げ", "go": "ご",
        "za": "ざ", "zi": "じ", "ji": "じ", "zu": "ず", "ze": "ぜ", "zo": "ぞ",
        "da": "だ", "di": "ぢ", "du": "づ", "de": "で", "do": "ど",
        "ba": "ば", "bi": "び", "bu": "ぶ", "be": "べ", "bo": "ぼ",
        "pa": "ぱ", "pi": "ぴ", "pu": "ぷ", "pe": "ぺ", "po": "ぽ",
        "kya": "きゃ", "kyu": "きゅ", "kyo": "きょ",
        "sha": "しゃ", "shu": "しゅ", "sho": "しょ", "she": "しぇ",
        "sya": "しゃ", "syu": "しゅ", "syo": "しょ",
        "cha": "ちゃ", "chu": "ちゅ", "cho": "ちょ", "che": "ちぇ",
        "cya": "ちゃ", "cyu": "ちゅ", "cyo": "ちょ",
        "tya": "ちゃ", "tyu": "ちゅ", "tyo": "ちょ",
        "nya": "にゃ", "nyu": "にゅ", "nyo": "にょ",
        "hya": "ひゃ", "hyu": "ひゅ", "hyo": "ひょ",
        "mya": "みゃ", "myu": "みゅ", "myo": "みょ",
        "rya": "りゃ", "ryu": "りゅ", "ryo": "りょ",
        "gya": "ぎゃ", "gyu": "ぎゅ", "gyo": "ぎょ",
        "ja": "じゃ", "ju": "じゅ", "jo": "じょ", "je": "じぇ",
        "jya": "じゃ", "jyu": "じゅ", "jyo": "じょ",
        "zya": "じゃ", "zyu": "じゅ", "zyo": "じょ",
        "dya": "ぢゃ", "dyu": "ぢゅ", "dyo": "ぢょ",
        "bya": "びゃ", "byu": "びゅ", "byo": "びょ",
        "pya": "ぴゃ", "pyu": "ぴゅ", "pyo": "ぴょ",
        "fa": "ふぁ", "fi": "ふぃ", "fe": "ふぇ", "fo": "ふぉ",
        "va": "ゔぁ", "vi": "ゔぃ", "vu": "ゔ", "ve": "ゔぇ", "vo": "ゔぉ",
        "thi": "てぃ", "dhi": "でぃ",
        "xa": "ぁ", "xi": "ぃ", "xu": "ぅ", "xe": "ぇ", "xo": "ぉ",
        "la": "ぁ", "li": "ぃ", "lu": "ぅ", "le": "ぇ", "lo": "ぉ",
        "xya": "ゃ", "xyu": "ゅ", "xyo": "ょ", "lya": "ゃ", "lyu": "ゅ", "lyo": "ょ",
        "xtu": "っ", "ltu": "っ", "xtsu": "っ", "ltsu": "っ", "xwa": "ゎ"
    ]
    private static let vowels: Set<Character> = ["a", "i", "u", "e", "o"]

    private static func isLatin(_ c: Character) -> Bool { c.isASCII && c.isLetter }

    /// - Parameter final: when false (live typing), a trailing incomplete
    ///   syllable such as "k" or "n" is left as typed.
    static func toHiragana(_ input: String, final: Bool = false) -> String {
        let chars = Array(input.lowercased())
        var out = ""
        var i = 0
        while i < chars.count {
            let c = chars[i]
            guard isLatin(c) else {
                out.append(c == "-" ? "ー" : c)
                i += 1
                continue
            }
            let next: Character? = i + 1 < chars.count ? chars[i + 1] : nil

            if c == "n" {
                if next == "'" {
                    out.append("ん"); i += 2; continue
                }
                if next == "n" {
                    let after: Character? = i + 2 < chars.count ? chars[i + 2] : nil
                    if let after = after, vowels.contains(after) || after == "y" {
                        out.append("ん"); i += 1; continue
                    }
                    if after == nil && !final {
                        out.append("nn"); i += 2; continue
                    }
                    out.append("ん"); i += 2; continue
                }
                if let next = next, !vowels.contains(next), next != "y" {
                    out.append("ん"); i += 1; continue
                }
                if next == nil {
                    out.append(final ? "ん" : "n"); i += 1; continue
                }
            }

            if let next = next, next == c, !vowels.contains(c) {
                out.append("っ"); i += 1; continue
            }
            if c == "t", next == "c", i + 2 < chars.count, chars[i + 2] == "h" {
                out.append("っ"); i += 1; continue
            }

            var matched = false
            for length in stride(from: 4, through: 1, by: -1) where i + length <= chars.count {
                let key = String(chars[i..<(i + length)])
                if let kana = table[key] {
                    out.append(kana)
                    i += length
                    matched = true
                    break
                }
            }
            if !matched {
                out.append(c)
                i += 1
            }
        }
        return out
    }
}

/// Splits a kun'yomi like "ひと.つ" into its stem and okurigana.
func splitKun(_ reading: String) -> (stem: String, okurigana: String) {
    let parts = reading.split(separator: ".", maxSplits: 1).map { String($0) }
    return (parts.first ?? reading, parts.count > 1 ? parts[1] : "")
}

// MARK: - 4. Memory model

/// Each kanji is learned as up to three separate memories. Readings are
/// tested inside real words (a kanji alone rarely has one "right" reading),
/// and writing unlocks only once recognition is stable — receptive
/// knowledge comes before productive knowledge.
enum Facet: String, Codable, CaseIterable, Identifiable {
    case meaning, reading, writing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .meaning: return "Meaning"
        case .reading: return "Reading"
        case .writing: return "Writing"
        }
    }

    var symbol: String {
        switch self {
        case .meaning: return "eye"
        case .reading: return "keyboard"
        case .writing: return "pencil.tip"
        }
    }

    var question: String {
        switch self {
        case .meaning: return "What does this kanji mean?"
        case .reading: return "How is this word read?"
        case .writing: return "Write the kanji from memory."
        }
    }
}

enum Phase: String, Codable {
    case learning, review, relearning
}

enum Rating: Int, Codable, CaseIterable, Identifiable {
    case again = 1, hard, good, easy

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .again: return "Again"
        case .hard: return "Hard"
        case .good: return "Good"
        case .easy: return "Easy"
        }
    }

    /// Two-button wording: a plain pass/fail is all FSRS needs, and it
    /// removes a decision from every single card.
    var simpleTitle: String {
        switch self {
        case .again: return "Forgot"
        case .good: return "Remembered"
        default: return title
        }
    }

    var tint: Color {
        switch self {
        case .again: return Palette.shu
        case .hard: return Palette.kohaku
        case .good: return Palette.matcha
        case .easy: return Palette.accent
        }
    }
}

struct Card: Codable, Hashable, Identifiable {
    var glyph: String
    var facet: Facet
    var phase: Phase = .learning
    var step: Int = 0
    var stability: Double = 0
    var difficulty: Double = 0
    var due: Date
    var lastReview: Date?
    var reps: Int = 0
    var lapses: Int = 0
    var leech: Bool = false

    var id: String { Card.key(glyph, facet) }

    static func key(_ glyph: String, _ facet: Facet) -> String { glyph + "#" + facet.rawValue }
}

/// FSRS-6 (Free Spaced Repetition Scheduler), the model Anki adopted in 2023.
/// It predicts the probability you can still recall a card and schedules the
/// next review for when that probability falls to your target retention.
/// Parameters are the published FSRS-6 defaults (trained on ~10k users).
struct FSRS {
    var w: [Double] = FSRS.defaultWeights
    var desiredRetention: Double = 0.9
    var maximumInterval: Double = 3650

    static let defaultWeights: [Double] = [
        0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722, 0.1666,
        0.796, 1.4835, 0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425, 0.0912, 0.0658, 0.1542
    ]

    var decay: Double { -w[20] }
    var factor: Double { pow(0.9, 1 / decay) - 1 }

    /// Probability of recall after `elapsedDays` with stability `s`.
    func retrievability(elapsedDays t: Double, stability s: Double) -> Double {
        guard s > 0 else { return 0 }
        return pow(1 + factor * max(t, 0) / s, decay)
    }

    /// Days until recall probability drops to the desired retention.
    func interval(for s: Double) -> Double {
        let raw = s / factor * (pow(desiredRetention, 1 / decay) - 1)
        return min(max(raw.rounded(), 1), maximumInterval)
    }

    /// Reviews per day relative to 90% retention. Shown in Settings so the
    /// cost of a higher target is visible before it's chosen.
    func workloadMultiplier() -> Double {
        let at90 = pow(0.9, 1 / decay) - 1
        let here = pow(desiredRetention, 1 / decay) - 1
        return at90 / here
    }

    func initialStability(_ r: Rating) -> Double { max(w[r.rawValue - 1], 0.1) }

    func initialDifficulty(_ r: Rating) -> Double {
        clampDifficulty(w[4] - exp(w[5] * Double(r.rawValue - 1)) + 1)
    }

    func nextDifficulty(_ d: Double, _ r: Rating) -> Double {
        let delta = -w[6] * (Double(r.rawValue) - 3)
        let damped = d + delta * (10 - d) / 9
        let target = w[4] - exp(w[5] * 3) + 1
        return clampDifficulty(w[7] * target + (1 - w[7]) * damped)
    }

    func recallStability(_ d: Double, _ s: Double, _ r: Double, _ rating: Rating) -> Double {
        let hardPenalty = rating == .hard ? w[15] : 1
        let easyBonus = rating == .easy ? w[16] : 1
        let growth = exp(w[8]) * (11 - d) * pow(s, -w[9]) * (exp((1 - r) * w[10]) - 1)
        return s * (1 + growth * hardPenalty * easyBonus)
    }

    func forgetStability(_ d: Double, _ s: Double, _ r: Double) -> Double {
        let longTerm = w[11] * pow(d, -w[12]) * (pow(s + 1, w[13]) - 1) * exp((1 - r) * w[14])
        let shortTerm = s / exp(w[17] * w[18])
        return max(min(longTerm, shortTerm), 0.01)
    }

    /// Same-day reviews (in-session repeats) use the short-term formula.
    func shortTermStability(_ s: Double, _ rating: Rating) -> Double {
        var increase = exp(w[17] * (Double(rating.rawValue) - 3 + w[18])) * pow(max(s, 0.01), -w[19])
        if rating.rawValue >= 3 { increase = max(increase, 1) }
        return max(s * increase, 0.01)
    }

    private func clampDifficulty(_ d: Double) -> Double { min(max(d, 1), 10) }
}

/// The study day starts at a configurable hour (4 AM by default, like Anki),
/// so a late-night session still counts as "today" and reviews scheduled
/// for a day all arrive together in the morning.
struct StudyClock {
    var dayStartHour: Int
    var calendar = Calendar.current

    func dayStart(_ date: Date) -> Date {
        let shifted = date.addingTimeInterval(-Double(dayStartHour) * 3600)
        let midnight = calendar.startOfDay(for: shifted)
        return calendar.date(byAdding: .hour, value: dayStartHour, to: midnight) ?? midnight
    }

    func isSameDay(_ a: Date, _ b: Date) -> Bool { dayStart(a) == dayStart(b) }

    func date(byAddingDays days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: dayStart(date)) ?? date.addingTimeInterval(Double(days) * 86_400)
    }

    func key(_ date: Date) -> String {
        let shifted = date.addingTimeInterval(-Double(dayStartHour) * 3600)
        let c = calendar.dateComponents([.year, .month, .day], from: shifted)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func daysBetween(_ a: Date, _ b: Date) -> Int {
        calendar.dateComponents([.day], from: dayStart(a), to: dayStart(b)).day ?? 0
    }
}

struct ReviewScheduler {
    var fsrs: FSRS
    var clock: StudyClock

    /// Learning steps: answer once in the lesson quiz, again after ~4 hours
    /// (an early consolidation check), then FSRS takes over.
    func apply(_ rating: Rating, to card: Card, now: Date, fuzz: Bool = true) -> Card {
        var c = card
        if card.reps == 0 || card.lastReview == nil {
            c.stability = fsrs.initialStability(rating)
            c.difficulty = fsrs.initialDifficulty(rating)
        } else {
            let last = card.lastReview ?? now
            if clock.isSameDay(last, now) {
                c.stability = fsrs.shortTermStability(card.stability, rating)
            } else {
                let elapsed = max(now.timeIntervalSince(last) / 86_400, 0)
                let r = fsrs.retrievability(elapsedDays: elapsed, stability: card.stability)
                c.stability = rating == .again
                    ? fsrs.forgetStability(card.difficulty, card.stability, r)
                    : fsrs.recallStability(card.difficulty, card.stability, r, rating)
            }
            c.difficulty = fsrs.nextDifficulty(card.difficulty, rating)
        }
        c.reps += 1
        c.lastReview = now

        switch card.phase {
        case .learning:
            switch rating {
            case .again:
                c.step = 0
                c.due = now.addingTimeInterval(60)
            case .hard:
                c.due = now.addingTimeInterval(card.step == 0 ? 3600 : 4 * 3600)
            case .good:
                if card.step == 0 {
                    c.step = 1
                    c.due = now.addingTimeInterval(4 * 3600)
                } else {
                    graduate(&c, now: now, fuzz: fuzz)
                }
            case .easy:
                graduate(&c, now: now, fuzz: fuzz)
            }
        case .review:
            if rating == .again {
                c.lapses += 1
                c.phase = .relearning
                c.step = 0
                c.due = now.addingTimeInterval(60)
            } else {
                graduate(&c, now: now, fuzz: fuzz)
            }
        case .relearning:
            if rating == .again {
                c.due = now.addingTimeInterval(60)
            } else {
                graduate(&c, now: now, fuzz: fuzz)
            }
        }
        return c
    }

    private func graduate(_ c: inout Card, now: Date, fuzz: Bool) {
        c.phase = .review
        c.step = 0
        var days = fsrs.interval(for: c.stability)
        // A little jitter keeps cards learned together from staying clumped.
        if fuzz && days >= 3 { days = (days * Double.random(in: 0.95...1.05)).rounded() }
        c.due = clock.date(byAddingDays: Int(days), to: now)
    }

    /// The interval each button would give, shown under the button so the
    /// consequence of every choice is visible before it's made.
    func previewLabel(_ rating: Rating, for card: Card, now: Date) -> String {
        let next = apply(rating, to: card, now: now, fuzz: false)
        if next.phase == .review {
            return Format.days(clock.daysBetween(now, next.due))
        }
        let seconds = next.due.timeIntervalSince(now)
        if seconds < 3600 { return "\(max(1, Int(seconds / 60))) min" }
        return "\(Int((seconds / 3600).rounded())) hr"
    }
}

/// How settled a kanji is in memory, from its weakest core facet.
enum Stage: Int, CaseIterable, Identifiable, Comparable {
    case new, learning, familiar, known, mastered

    var id: Int { rawValue }

    static func < (lhs: Stage, rhs: Stage) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .new: return "New"
        case .learning: return "Learning"
        case .familiar: return "Familiar"
        case .known: return "Known"
        case .mastered: return "Mastered"
        }
    }

    var detail: String {
        switch self {
        case .new: return "Not started yet"
        case .learning: return "Still settling in"
        case .familiar: return "Holds for days"
        case .known: return "Holds for weeks"
        case .mastered: return "Holds for months"
        }
    }

    var tint: Color {
        switch self {
        case .new: return Palette.ink3
        case .learning: return Palette.kohaku
        case .familiar: return Palette.asagi
        case .known: return Palette.accent
        case .mastered: return Palette.murasaki
        }
    }

    static func from(_ cards: [Card]) -> Stage {
        guard !cards.isEmpty else { return .new }
        if cards.contains(where: { $0.phase != .review }) { return .learning }
        let weakest = cards.map(\.stability).min() ?? 0
        switch weakest {
        case ..<1: return .learning
        case ..<21: return .familiar
        case ..<90: return .known
        default: return .mastered
        }
    }
}

enum Format {
    static func days(_ d: Int) -> String {
        if d <= 0 { return "today" }
        if d == 1 { return "1 day" }
        if d < 30 { return "\(d) days" }
        if d < 365 { return "\(Int((Double(d) / 30).rounded())) mo" }
        let years = Double(d) / 365
        return years < 10 ? String(format: "%.1f yr", years) : "\(Int(years)) yr"
    }

    static func minutes(_ seconds: Double) -> String {
        let m = Int((seconds / 60).rounded())
        return m < 1 ? "under a minute" : (m == 1 ? "1 min" : "\(m) min")
    }

    /// Rough time estimate for a queue, phrased for a glance.
    static func estimate(seconds: Double) -> String {
        let m = Int((seconds / 60).rounded())
        return m < 1 ? "Under a minute" : "About \(m) min"
    }

    static func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }

    static func hour(_ h: Int) -> String {
        switch h {
        case 0: return "Midnight"
        case 12: return "Noon"
        case 1..<12: return "\(h) AM"
        default: return "\(h - 12) PM"
        }
    }
}

// MARK: - 5. Store

enum FuriganaMode: String, Codable, CaseIterable, Identifiable {
    case adaptive, always, off

    var id: String { rawValue }

    var title: String {
        switch self {
        case .adaptive: return "New kanji only"
        case .always: return "Always"
        case .off: return "Never"
        }
    }

    var detail: String {
        switch self {
        case .adaptive: return "Readings appear only above kanji you haven't learned yet, and fade as you learn them."
        case .always: return "Readings appear above every kanji."
        case .off: return "No readings. Tap a word to look it up."
        }
    }
}

struct AppSettings: Codable, Equatable {
    var newPerDay = 10
    var batchSize = 5
    var retention = 0.9
    var writing = true
    var autoSpeak = false
    var haptics = true
    var furigana: FuriganaMode = .adaptive
    var face: JPFace = .gothic
    var dayStartHour = 4
    var reminder = false
    var reminderHour = 19
    var reminderMinute = 0
    var askedReminder = false

    init() {}

    enum CodingKeys: String, CodingKey {
        case newPerDay, batchSize, retention, writing, autoSpeak, haptics, furigana, face, dayStartHour
        case reminder, reminderHour, reminderMinute, askedReminder
    }

    /// Missing keys fall back to defaults, so adding a setting in a future
    /// version never wipes someone's saved preferences.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        newPerDay = (try? c.decode(Int.self, forKey: .newPerDay)) ?? d.newPerDay
        batchSize = (try? c.decode(Int.self, forKey: .batchSize)) ?? d.batchSize
        retention = (try? c.decode(Double.self, forKey: .retention)) ?? d.retention
        writing = (try? c.decode(Bool.self, forKey: .writing)) ?? d.writing
        autoSpeak = (try? c.decode(Bool.self, forKey: .autoSpeak)) ?? d.autoSpeak
        haptics = (try? c.decode(Bool.self, forKey: .haptics)) ?? d.haptics
        furigana = (try? c.decode(FuriganaMode.self, forKey: .furigana)) ?? d.furigana
        face = (try? c.decode(JPFace.self, forKey: .face)) ?? d.face
        dayStartHour = (try? c.decode(Int.self, forKey: .dayStartHour)) ?? d.dayStartHour
        reminder = (try? c.decode(Bool.self, forKey: .reminder)) ?? d.reminder
        reminderHour = (try? c.decode(Int.self, forKey: .reminderHour)) ?? d.reminderHour
        reminderMinute = (try? c.decode(Int.self, forKey: .reminderMinute)) ?? d.reminderMinute
        askedReminder = (try? c.decode(Bool.self, forKey: .askedReminder)) ?? d.askedReminder
    }
}

struct DayStat: Codable, Hashable {
    var reviews = 0
    var correct = 0
    var learned = 0
    var seconds: Double = 0
}

/// Why an answer went wrong. Asking turns a mistake into something noticed,
/// evaluated and acted on — the noting → evaluation → adjustment cycle of
/// Language Management Theory — instead of a silent red mark.
enum MissReason: String, Codable, CaseIterable, Identifiable {
    case lookalike, reading, meaning, slip

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lookalike: return "Look-alike"
        case .reading: return "Reading"
        case .meaning: return "Meaning"
        case .slip: return "Slip"
        }
    }

    var longTitle: String {
        switch self {
        case .lookalike: return "Mixed it up with a look-alike"
        case .reading: return "Forgot the reading"
        case .meaning: return "Forgot the meaning"
        case .slip: return "Just a slip"
        }
    }

    var symbol: String {
        switch self {
        case .lookalike: return "square.on.square"
        case .reading: return "speaker.wave.2"
        case .meaning: return "text.book.closed"
        case .slip: return "hand.tap"
        }
    }

    var advice: String {
        switch self {
        case .lookalike: return "Open the kanji and compare its look-alikes side by side. Contrast is what keeps similar shapes apart in memory."
        case .reading: return "Say each word aloud as you review it. Sound and spelling bind together through your own voice."
        case .meaning: return "Rewrite the memory hook in your own words. Cues you create yourself are recalled better than ones you're given."
        case .slip: return "Slips happen when answering fast. Pause for a beat before you commit."
        }
    }
}

struct LogEntry: Codable, Hashable {
    var date: Date
    var card: String
    var rating: Int
    var ms: Int
    var miss: MissReason?
}

struct SaveFile: Codable {
    var version = 1
    var cards: [String: Card] = [:]
    var settings = AppSettings()
    var days: [String: DayStat] = [:]
    var log: [LogEntry] = []
    var notes: [String: String] = [:]
    var priority: [String] = []
    var readPassages: [String] = []
    var onboarded = false
    var packs: [ContentPack] = []

    init() {}

    enum CodingKeys: String, CodingKey {
        case version, cards, settings, days, log, notes, priority, readPassages, onboarded, packs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        cards = (try? c.decode([String: Card].self, forKey: .cards)) ?? [:]
        settings = (try? c.decode(AppSettings.self, forKey: .settings)) ?? AppSettings()
        days = (try? c.decode([String: DayStat].self, forKey: .days)) ?? [:]
        log = (try? c.decode([LogEntry].self, forKey: .log)) ?? []
        notes = (try? c.decode([String: String].self, forKey: .notes)) ?? [:]
        priority = (try? c.decode([String].self, forKey: .priority)) ?? []
        readPassages = (try? c.decode([String].self, forKey: .readPassages)) ?? []
        onboarded = (try? c.decode(Bool.self, forKey: .onboarded)) ?? false
        packs = (try? c.decode([ContentPack].self, forKey: .packs)) ?? []
    }
}

struct ForecastDay: Identifiable {
    var id: Int { offset }
    var offset: Int
    var label: String
    var count: Int
}

struct HeatCell: Identifiable {
    var id: Int
    var count: Int
    var isFuture: Bool
}

enum ImportedFile {
    case pack(ContentPack)
    case backup(SaveFile)
}

final class Store: ObservableObject {
    @Published var data: SaveFile {
        didSet { scheduleSave() }
    }
    @Published private(set) var library: ContentLibrary

    static let leechThreshold = 6
    static let backlogThreshold = 100
    static let catchUpBatch = 50

    private let fileURL: URL
    private var pendingSave: DispatchWorkItem?

    init() {
        let directory = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                      appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let url = directory.appendingPathComponent("sumi-progress.json")
        var loaded = SaveFile()
        if let raw = try? Data(contentsOf: url) {
            if let decoded = try? JSONDecoder().decode(SaveFile.self, from: raw) {
                loaded = decoded
            } else {
                // Never overwrite progress we couldn't read: keep a copy aside.
                let stamp = Int(Date().timeIntervalSince1970)
                try? raw.write(to: directory.appendingPathComponent("sumi-progress-unreadable-\(stamp).json"))
            }
        }
        fileURL = url
        data = loaded
        library = ContentLibrary(packs: [BuiltIn.pack] + loaded.packs)
    }

    // MARK: Persistence

    private func scheduleSave() {
        pendingSave?.cancel()
        let snapshot = data
        let url = fileURL
        let work = DispatchWorkItem {
            if let raw = try? JSONEncoder().encode(snapshot) {
                try? raw.write(to: url, options: .atomic)
            }
        }
        pendingSave = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func saveNow() {
        pendingSave?.cancel()
        if let raw = try? JSONEncoder().encode(data) {
            try? raw.write(to: fileURL, options: .atomic)
        }
    }

    // MARK: Derived state

    var settings: AppSettings { data.settings }
    var clock: StudyClock { StudyClock(dayStartHour: data.settings.dayStartHour) }
    var fsrs: FSRS { FSRS(desiredRetention: data.settings.retention) }
    var scheduler: ReviewScheduler { ReviewScheduler(fsrs: fsrs, clock: clock) }
    var todayKey: String { clock.key(Date()) }
    var today: DayStat { data.days[todayKey] ?? DayStat() }

    func card(_ glyph: String, _ facet: Facet) -> Card? { data.cards[Card.key(glyph, facet)] }

    func stage(of glyph: String) -> Stage {
        Stage.from([Facet.meaning, .reading].compactMap { card(glyph, $0) })
    }

    func isStarted(_ glyph: String) -> Bool { card(glyph, .meaning) != nil }

    /// "Known enough to read without help" — drives adaptive furigana.
    func isKnown(_ glyph: String) -> Bool { stage(of: glyph) >= .familiar }

    func dueCards(at now: Date = Date()) -> [Card] {
        data.cards.values.filter { card in
            card.due <= now
                && library.byGlyph[card.glyph] != nil
                && (card.facet != .writing || data.settings.writing)
        }
    }

    var dueCount: Int { dueCards().count }

    var isBacklogged: Bool { dueCount > Store.backlogThreshold }

    var nextDue: Date? {
        let now = Date()
        return data.cards.values
            .filter { $0.due > now && ($0.facet != .writing || data.settings.writing) }
            .map(\.due)
            .min()
    }

    var lessonsLeftToday: Int { max(0, data.settings.newPerDay - today.learned) }

    /// Unstarted kanji in study order: anything the learner asked for first,
    /// then by level, with each kanji's parts taught before the kanji that
    /// contain them (休 after 木, 男 after 田).
    var lessonQueue: [Kanji] {
        let pending = library.kanji.filter { !isStarted($0.glyph) }
        let pendingSet = Set(pending.map(\.glyph))
        let first = data.priority.filter { pendingSet.contains($0) }.compactMap { library.byGlyph[$0] }
        let firstSet = Set(first.map(\.glyph))
        let rest = pending.enumerated()
            .filter { !firstSet.contains($0.element.glyph) }
            .sorted { a, b in
                a.element.level == b.element.level ? a.offset < b.offset : a.element.level < b.element.level
            }
            .map { $0.element }
        return first + Store.partsFirst(rest)
    }

    static func partsFirst(_ list: [Kanji]) -> [Kanji] {
        var index: [String: Kanji] = [:]
        for k in list where index[k.glyph] == nil { index[k.glyph] = k }
        var placed = Set<String>()
        var result: [Kanji] = []
        func place(_ k: Kanji, depth: Int) {
            guard !placed.contains(k.glyph) else { return }
            if depth < 4 {
                for part in k.parts where part.glyph != k.glyph {
                    if let dependency = index[part.glyph] { place(dependency, depth: depth + 1) }
                }
            }
            if !placed.contains(k.glyph) {
                placed.insert(k.glyph)
                result.append(k)
            }
        }
        for k in list { place(k, depth: 0) }
        return result
    }

    var leeches: [Kanji] {
        let glyphs = Set(data.cards.values.filter(\.leech).map(\.glyph))
        return library.kanji.filter { glyphs.contains($0.glyph) }
    }

    func note(for glyph: String) -> String { data.notes[glyph] ?? "" }

    // MARK: Recording answers

    @discardableResult
    func record(_ rating: Rating, glyph: String, facet: Facet, ms: Int, miss: MissReason?, now: Date = Date()) -> Card {
        let key = Card.key(glyph, facet)
        let existing = data.cards[key]
        let base = existing ?? Card(glyph: glyph, facet: facet, due: now)
        var updated = scheduler.apply(rating, to: base, now: now)
        if rating == .again && updated.lapses >= Store.leechThreshold { updated.leech = true }
        if rating != .again && updated.leech && updated.phase == .review && updated.stability >= 21 { updated.leech = false }

        var d = data
        d.cards[key] = updated
        let dayKey = clock.key(now)
        var stat = d.days[dayKey] ?? DayStat()
        stat.reviews += 1
        if rating != .again { stat.correct += 1 }
        stat.seconds += min(Double(ms) / 1000, 60)
        if existing == nil && facet == .meaning { stat.learned += 1 }
        d.days[dayKey] = stat
        d.log.append(LogEntry(date: now, card: key, rating: rating.rawValue, ms: ms, miss: miss))
        if d.log.count > 6000 { d.log.removeFirst(d.log.count - 6000) }
        d.priority.removeAll { $0 == glyph }

        // Production unlocks once recognition holds for a few days.
        let writingKey = Card.key(glyph, .writing)
        if facet == .meaning, updated.phase == .review, updated.stability >= 3, d.cards[writingKey] == nil {
            d.cards[writingKey] = Card(glyph: glyph, facet: .writing, due: clock.date(byAddingDays: 1, to: now))
        }
        data = d
        return updated
    }

    /// Lets someone skip what they already know. Items get a generous
    /// starting memory and are spread over the next few weeks, so anything
    /// that isn't really known surfaces quickly and returns to normal study.
    func markKnown(_ glyphs: [String]) {
        let now = Date()
        var d = data
        for glyph in glyphs {
            guard let kanji = library.byGlyph[glyph] else { continue }
            for facet in [Facet.meaning, .reading] {
                if facet == .reading && kanji.words.isEmpty { continue }
                var c = Card(glyph: glyph, facet: facet, due: now)
                c.phase = .review
                c.stability = 30
                c.difficulty = 3
                c.reps = 1
                c.lastReview = now
                c.due = clock.date(byAddingDays: Int.random(in: 3...28), to: now)
                d.cards[c.id] = c
            }
            d.priority.removeAll { $0 == glyph }
        }
        data = d
    }

    func resetProgress(for glyph: String) {
        var d = data
        for facet in Facet.allCases { d.cards[Card.key(glyph, facet)] = nil }
        data = d
    }

    func prioritize(_ glyph: String) {
        var d = data
        d.priority.removeAll { $0 == glyph }
        d.priority.insert(glyph, at: 0)
        data = d
    }

    func setNote(_ text: String, for glyph: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        data.notes[glyph] = trimmed.isEmpty ? nil : trimmed
    }

    func markRead(_ passageID: String) {
        guard !data.readPassages.contains(passageID) else { return }
        data.readPassages.append(passageID)
    }

    func resetAllProgress() {
        var fresh = SaveFile()
        fresh.settings = data.settings
        fresh.packs = data.packs
        fresh.onboarded = true
        data = fresh
    }

    // MARK: Building sessions

    func reviewItems(limit: Int?) -> [StudyItem] {
        let now = Date()
        var due = dueCards(at: now)
        let model = fsrs
        func risk(_ c: Card) -> Double {
            guard let last = c.lastReview else { return 0 }
            return model.retrievability(elapsedDays: now.timeIntervalSince(last) / 86_400, stability: c.stability)
        }
        if let limit = limit, due.count > limit {
            // Catch-up: the cards you're most likely to have forgotten first.
            due.sort { risk($0) < risk($1) }
            due = Array(due.prefix(limit))
        }
        due.shuffle()
        return due.map { makeItem($0.glyph, $0.facet, reps: $0.reps) }
    }

    func lessonItems(for kanji: [Kanji]) -> [StudyItem] {
        var items: [StudyItem] = []
        for k in kanji {
            items.append(makeItem(k.glyph, .meaning, reps: 0))
            if !k.words.isEmpty { items.append(makeItem(k.glyph, .reading, reps: 0)) }
        }
        return items.shuffled()
    }

    /// Practice outside the schedule — answers here never change intervals.
    func practiceItems(for glyphs: [String]) -> [StudyItem] {
        var items: [StudyItem] = []
        for glyph in glyphs {
            guard let k = library.byGlyph[glyph] else { continue }
            items.append(makeItem(glyph, .meaning, reps: Int.random(in: 0...9)))
            if !k.words.isEmpty { items.append(makeItem(glyph, .reading, reps: Int.random(in: 0...9))) }
            if data.settings.writing { items.append(makeItem(glyph, .writing, reps: 0)) }
        }
        return items.shuffled()
    }

    /// Readings rotate through a kanji's words from one review to the next,
    /// so the reading is tied to vocabulary, not to one memorized pair.
    private func makeItem(_ glyph: String, _ facet: Facet, reps: Int) -> StudyItem {
        let count = library.byGlyph[glyph]?.words.count ?? 0
        return StudyItem(glyph: glyph, facet: facet, wordIndex: count > 0 ? reps % count : 0)
    }

    // MARK: Statistics

    func stageCounts(level: JLPTLevel? = nil) -> [Stage: Int] {
        var counts: [Stage: Int] = [:]
        for k in library.kanjiList(for: level) {
            counts[stage(of: k.glyph), default: 0] += 1
        }
        return counts
    }

    func accuracy(days: Int) -> Double? {
        let now = Date()
        var reviews = 0
        var correct = 0
        for offset in 0..<days {
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: now) ?? now
            if let stat = data.days[clock.key(date)] {
                reviews += stat.reviews
                correct += stat.correct
            }
        }
        return reviews == 0 ? nil : Double(correct) / Double(reviews)
    }

    func reviews(days: Int) -> Int {
        let now = Date()
        return (0..<days).reduce(0) { total, offset in
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: now) ?? now
            return total + (data.days[clock.key(date)]?.reviews ?? 0)
        }
    }

    func forecast(days: Int = 7) -> [ForecastDay] {
        let now = Date()
        let start = clock.dayStart(now)
        let cards = data.cards.values.filter { $0.facet != .writing || data.settings.writing }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return (0..<days).map { offset in
            let dayStart = clock.date(byAddingDays: offset, to: start)
            let dayEnd = clock.date(byAddingDays: offset + 1, to: start)
            let count = cards.filter { card in
                offset == 0 ? card.due < dayEnd : (card.due >= dayStart && card.due < dayEnd)
            }.count
            let label = offset == 0 ? "Today" : formatter.string(from: dayStart)
            return ForecastDay(offset: offset, label: label, count: count)
        }
    }

    /// Weeks as columns, Monday-first rows.
    func heatmap(weeks: Int) -> [[HeatCell]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date().addingTimeInterval(-Double(data.settings.dayStartHour) * 3600))
        let weekday = (calendar.component(.weekday, from: today) + 5) % 7
        let thisWeek = calendar.date(byAdding: .day, value: -weekday, to: today) ?? today
        var columns: [[HeatCell]] = []
        for w in 0..<weeks {
            let weekStart = calendar.date(byAdding: .day, value: -7 * (weeks - 1 - w), to: thisWeek) ?? thisWeek
            var column: [HeatCell] = []
            for d in 0..<7 {
                let date = calendar.date(byAdding: .day, value: d, to: weekStart) ?? weekStart
                let future = date > today
                let key = String(format: "%04d-%02d-%02d",
                                 calendar.component(.year, from: date),
                                 calendar.component(.month, from: date),
                                 calendar.component(.day, from: date))
                column.append(HeatCell(id: w * 7 + d, count: future ? 0 : (data.days[key]?.reviews ?? 0), isFuture: future))
            }
            columns.append(column)
        }
        return columns
    }

    /// Monday-to-Sunday flags for the current week.
    var weekRhythm: [Bool] {
        heatmap(weeks: 1).first?.map { $0.count > 0 } ?? Array(repeating: false, count: 7)
    }

    var missTally: [(reason: MissReason, count: Int)] {
        var counts: [MissReason: Int] = [:]
        for entry in data.log.suffix(1500) {
            if let miss = entry.miss { counts[miss, default: 0] += 1 }
        }
        return MissReason.allCases
            .map { (reason: $0, count: counts[$0] ?? 0) }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
    }

    func coverage(of passage: Passage) -> Double {
        let glyphs = passage.lines.flatMap { Ruby.plain($0.jp).filter { $0.isKanji } }
        guard !glyphs.isEmpty else { return 1 }
        let known = glyphs.filter { isKnown(String($0)) }.count
        return Double(known) / Double(glyphs.count)
    }

    /// The unread passage closest to "almost all familiar" — comprehensible
    /// input with a little left to stretch for.
    var suggestedPassage: Passage? {
        let unread = library.passages.filter { !data.readPassages.contains($0.id) }
        return unread.max { coverage(of: $0) < coverage(of: $1) }
    }

    // MARK: Import and export

    func exportData() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(data)) ?? Data()
    }

    func inspect(_ raw: Data) throws -> ImportedFile {
        if let pack = try? JSONDecoder().decode(ContentPack.self, from: raw), !pack.kanji.isEmpty || !(pack.passages ?? []).isEmpty {
            return .pack(pack)
        }
        let backup = try JSONDecoder().decode(SaveFile.self, from: raw)
        return .backup(backup)
    }

    func install(_ pack: ContentPack) {
        var d = data
        d.packs.removeAll { $0.name == pack.name }
        d.packs.append(pack)
        data = d
        rebuildLibrary()
    }

    func removePack(named name: String) {
        data.packs.removeAll { $0.name == name }
        rebuildLibrary()
    }

    func restore(_ backup: SaveFile) {
        var restored = backup
        restored.onboarded = true
        data = restored
        rebuildLibrary()
    }

    private func rebuildLibrary() {
        library = ContentLibrary(packs: [BuiltIn.pack] + data.packs)
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - 6. Sessions

struct StudyItem: Identifiable, Hashable {
    let id = UUID()
    let glyph: String
    let facet: Facet
    let wordIndex: Int
}

enum SessionMode {
    case review, lesson, practice
}

struct SessionLaunch: Identifiable, Hashable {
    let id = UUID()
    var mode: SessionMode
    var items: [StudyItem]
    var lessonGlyphs: [String] = []
}

struct SessionResult {
    var answered = 0
    var firstTry = 0
    var missed: [String] = []
    var started = Date()
}

final class SessionModel: ObservableObject {
    let mode: SessionMode
    @Published private(set) var queue: [StudyItem]
    @Published private(set) var completed = 0
    @Published private(set) var total: Int
    @Published private(set) var result = SessionResult()
    @Published private(set) var canUndo = false
    @Published private(set) var isWrappingUp = false

    private var failed = Set<String>()
    private var history: [Snapshot] = []

    private struct Snapshot {
        var save: SaveFile
        var queue: [StudyItem]
        var completed: Int
        var total: Int
        var result: SessionResult
        var failed: Set<String>
    }

    init(mode: SessionMode, items: [StudyItem]) {
        self.mode = mode
        self.queue = SessionModel.interleave(items)
        self.total = items.count
    }

    var current: StudyItem? { queue.first }
    var isFinished: Bool { queue.isEmpty }
    var remaining: Int { queue.count }
    var progress: Double { total == 0 ? 1 : Double(completed) / Double(total) }

    private static func key(_ item: StudyItem) -> String { item.glyph + "#" + item.facet.rawValue }

    /// Records an answer. A miss goes back into the queue a few cards later,
    /// so it's retrieved again while the correction is fresh.
    func commit(_ rating: Rating, ms: Int, miss: MissReason?, store: Store) {
        guard let item = queue.first else { return }
        history.append(Snapshot(save: store.data, queue: queue, completed: completed,
                                total: total, result: result, failed: failed))
        if history.count > 30 { history.removeFirst() }
        if mode != .practice {
            store.record(rating, glyph: item.glyph, facet: item.facet, ms: ms, miss: miss)
        }
        var next = queue
        next.removeFirst()
        var r = result
        r.answered += 1
        let key = SessionModel.key(item)
        if rating == .again {
            failed.insert(key)
            if !r.missed.contains(item.glyph) { r.missed.append(item.glyph) }
            let position = min(next.count, Int.random(in: 3...6))
            next.insert(StudyItem(glyph: item.glyph, facet: item.facet, wordIndex: item.wordIndex), at: position)
        } else {
            if !failed.contains(key) { r.firstTry += 1 }
            completed += 1
        }
        result = r
        queue = next
        canUndo = true
    }

    func undo(store: Store) {
        guard let last = history.popLast() else { return }
        if mode != .practice { store.data = last.save }
        queue = last.queue
        completed = last.completed
        total = last.total
        result = last.result
        failed = last.failed
        canUndo = !history.isEmpty
    }

    /// Ends the session gracefully: unseen cards wait for next time, but
    /// anything missed must still be answered correctly once.
    func wrapUp() {
        let keep = queue.filter { failed.contains(SessionModel.key($0)) }
        queue = keep
        total = completed + keep.count
        isWrappingUp = true
    }

    func remove(glyph: String) {
        let before = queue.count
        queue.removeAll { $0.glyph == glyph }
        total = max(total - (before - queue.count), completed)
    }

    func skipCurrent() {
        guard !queue.isEmpty else { return }
        queue.removeFirst()
        total = max(completed + queue.count, completed)
    }

    /// Mixes facets so the same kanji never appears twice in a row
    /// (interleaving beats blocked practice for discrimination).
    static func interleave(_ items: [StudyItem]) -> [StudyItem] {
        var pool = items
        var out: [StudyItem] = []
        while !pool.isEmpty {
            let previous = out.last?.glyph
            if let index = pool.firstIndex(where: { $0.glyph != previous }) {
                out.append(pool.remove(at: index))
            } else {
                out.append(pool.removeFirst())
            }
        }
        return out
    }
}

// MARK: Writing surface

/// A square writing surface over 田-grid paper. After an answer is revealed
/// the model shape fades in beneath your strokes for direct comparison.
struct WritingPad: View {
    let clearToken: Int
    @Binding var hasInk: Bool
    var guide: String?
    var guideOpacity: Double = 0.2
    var face: JPFace = .gothic

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(Palette.surface)
                PracticeGrid()
                if let guide = guide {
                    Text(guide)
                        .font(.jpFixed(geo.size.width * 0.78, face: face))
                        .foregroundStyle(Palette.accent.opacity(guideOpacity))
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
                InkCanvas(clearToken: clearToken, hasInk: $hasInk)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .animation(.easeOut(duration: 0.3), value: guide)
        .accessibilityElement()
        .accessibilityLabel("Writing area")
        .accessibilityHint("Draw the kanji with your finger or Apple Pencil")
    }
}

struct InkCanvas: UIViewRepresentable {
    let clearToken: Int
    @Binding var hasInk: Bool

    func makeCoordinator() -> Coordinator { Coordinator(hasInk: $hasInk) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .label, width: 9)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = false
        canvas.delegate = context.coordinator
        context.coordinator.lastClear = clearToken
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        if context.coordinator.lastClear != clearToken {
            context.coordinator.lastClear = clearToken
            canvas.drawing = PKDrawing()
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var hasInk: Binding<Bool>
        var lastClear = 0

        init(hasInk: Binding<Bool>) {
            self.hasInk = hasInk
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let inked = !canvasView.drawing.strokes.isEmpty
            let binding = hasInk
            DispatchQueue.main.async {
                if binding.wrappedValue != inked { binding.wrappedValue = inked }
            }
        }
    }
}

// MARK: Text helpers

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

extension Character {
    /// Kana, kanji, CJK punctuation and full-width forms.
    var isJapanese: Bool {
        guard let v = unicodeScalars.first?.value else { return false }
        return (0x3000...0x30FF).contains(v) || (0x31F0...0x31FF).contains(v)
            || (0x3400...0x4DBF).contains(v) || (0x4E00...0x9FFF).contains(v)
            || (0xFF00...0xFFEF).contains(v) || (0x2E80...0x2FDF).contains(v)
    }
}

/// Point size of each text style at the default Dynamic Type setting.
func pointSize(for style: Font.TextStyle) -> CGFloat {
    switch style {
    case .largeTitle: return 34
    case .title: return 28
    case .title2: return 22
    case .title3: return 20
    case .callout: return 16
    case .subheadline: return 15
    case .footnote: return 13
    case .caption: return 12
    case .caption2: return 11
    default: return 17
    }
}

/// English text with embedded Japanese. Japanese runs switch to Hiragino so
/// kanji inside an English sentence still get Japanese glyph shapes.
func MixedText(_ string: String, style: Font.TextStyle = .body, bold: Bool = false) -> Text {
    let size = pointSize(for: style)
    var result = Text("")
    var run = ""
    var runIsJapanese = false

    func flush() {
        guard !run.isEmpty else { return }
        let font: Font = runIsJapanese
            ? .jp(size, bold: bold, relativeTo: style)
            : .system(style, weight: bold ? .semibold : .regular)
        result = result + Text(run).font(font)
        run = ""
    }

    for ch in string {
        let japanese = ch.isJapanese
        if japanese != runIsJapanese && !run.isEmpty { flush() }
        runIsJapanese = japanese
        run.append(ch)
    }
    flush()
    return result
}

/// A Japanese word with one kanji picked out — typographic input
/// enhancement, so attention lands on the character being learned.
func jpText(_ string: String, highlight: String? = nil, size: CGFloat,
            face: JPFace = .gothic, fixed: Bool = true) -> Text {
    var result = Text("")
    for ch in string {
        let s = String(ch)
        let isTarget = highlight == s
        let font: Font = fixed
            ? .jpFixed(size, bold: isTarget, face: face)
            : .jp(size, bold: isTarget, face: face)
        result = result + Text(s).font(font).foregroundColor(isTarget ? Palette.accent : Palette.ink)
    }
    return result
}

/// Japanese text with furigana. Readings sit at half the base size (the
/// JIS convention), lines are loosely spaced (~1.9× with ruby) and line
/// breaks follow kinsoku rules.
struct RubyText: View {
    @EnvironmentObject var store: Store
    let markup: String
    var size: CGFloat = 20
    var highlight: String? = nil
    var mode: FuriganaMode? = nil
    var onTap: ((RubyUnit) -> Void)? = nil
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        let base = size * min(max(scale, 0.85), 1.8)
        FlowLayout(spacing: 0, lineSpacing: base * 0.3) {
            ForEach(Ruby.tokens(markup)) { token in
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(Array(token.units.enumerated()), id: \.offset) { _, unit in
                        unitView(unit, base: base)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Ruby.plain(markup))
    }

    @ViewBuilder
    private func unitView(_ unit: RubyUnit, base: CGFloat) -> some View {
        let column = VStack(spacing: base * 0.05) {
            Text(showsReading(unit) ? (unit.reading ?? " ") : " ")
                .font(.jpFixed(base * 0.5))
                .foregroundStyle(Palette.ink2)
                .lineLimit(1)
                .fixedSize()
            jpText(unit.base, highlight: highlight, size: base)
                .lineLimit(1)
                .fixedSize()
        }
        if let onTap = onTap, unit.hasKanji {
            column
                .contentShape(Rectangle())
                .onTapGesture { onTap(unit) }
        } else {
            column
        }
    }

    private func showsReading(_ unit: RubyUnit) -> Bool {
        guard unit.reading != nil, unit.hasKanji else { return false }
        switch mode ?? store.data.settings.furigana {
        case .always: return true
        case .off: return false
        case .adaptive: return unit.base.contains { $0.isKanji && !store.isKnown(String($0)) }
        }
    }
}


// MARK: - 7. Screens

enum Route: Hashable {
    case study(SessionLaunch)
    case library
    case kanji(String)
    case passage(String)
}

final class Router: ObservableObject {
    @Published var path: [Route] = []
}

/// What the home screen offers right now. Decided entirely by the store:
/// reviews first (they protect what's learned), then new kanji within the
/// daily pace, otherwise rest.
enum HomeState {
    case review(count: Int)
    case learn(batch: [Kanji])
    case rest(next: Date?, canLearnMore: Bool, passage: Passage?)
}

extension Store {
    var homeState: HomeState {
        let due = dueCount
        if due > 0 { return .review(count: due) }
        let queue = lessonQueue
        let left = min(lessonsLeftToday, queue.count)
        if left > 0 {
            return .learn(batch: Array(queue.prefix(min(data.settings.batchSize, left))))
        }
        return .rest(next: nextDue, canLearnMore: !queue.isEmpty, passage: suggestedPassage)
    }

    func reviewLaunch() -> SessionLaunch? {
        let items = reviewItems(limit: isBacklogged ? Store.catchUpBatch : nil)
        return items.isEmpty ? nil : SessionLaunch(mode: .review, items: items)
    }

    func lessonLaunch(extra: Bool) -> SessionLaunch? {
        let size = data.settings.batchSize
        let count = extra ? size : min(size, lessonsLeftToday)
        let batch = Array(lessonQueue.prefix(max(count, 1)))
        guard !batch.isEmpty else { return nil }
        return SessionLaunch(mode: .lesson, items: lessonItems(for: batch), lessonGlyphs: batch.map(\.glyph))
    }

    func practiceLaunch(_ glyphs: [String]) -> SessionLaunch? {
        let items = practiceItems(for: glyphs)
        return items.isEmpty ? nil : SessionLaunch(mode: .practice, items: items)
    }

    /// One line about how well a kanji is held in memory.
    func memoryLine(for glyph: String) -> String? {
        guard let c = self.card(glyph, .meaning) ?? self.card(glyph, .reading), let last = c.lastReview else { return nil }
        let now = Date()
        let recall = fsrs.retrievability(elapsedDays: now.timeIntervalSince(last) / 86_400, stability: c.stability)
        let next = c.due <= now ? "Due now" : "Next review \(c.due.formatted(.relative(presentation: .named)))"
        return "\(next) · \(Format.percent(recall)) recall"
    }
}

/// "on・on　kun(okurigana)" — one quiet line of readings.
func readingLine(_ kanji: Kanji) -> String {
    let kun = kanji.kun.map { reading -> String in
        let split = splitKun(reading.replacingOccurrences(of: "-", with: ""))
        return split.okurigana.isEmpty ? split.stem : "\(split.stem)(\(split.okurigana))"
    }
    return [kanji.on.joined(separator: "・"), kun.joined(separator: "・")]
        .filter { !$0.isEmpty }
        .joined(separator: "　")
}

/// The app's root. It owns its store and router, so `WindowGroup {
/// ContentView() }` is all an App needs.
struct ContentView: View {
    @StateObject private var store = Store()
    @StateObject private var router = Router()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings = false

    private var needsOnboarding: Binding<Bool> {
        Binding(get: { !store.data.onboarded }, set: { if !$0 { store.data.onboarded = true } })
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            HomeView(showSettings: $showSettings)
                .navigationDestination(for: Route.self) { route in
                    destination(route)
                }
        }
        .tint(Palette.accent)
        .environmentObject(store)
        .environmentObject(router)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(store)
                .environmentObject(router)
        }
        .fullScreenCover(isPresented: needsOnboarding) {
            OnboardingView().environmentObject(store)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Reminders.sync(store)
            } else if phase == .background {
                store.saveNow()
                Reminders.schedule(store)
            }
        }
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .study(let launch):
            StudyView(launch: launch)
        case .library:
            LibraryView()
        case .kanji(let glyph):
            KanjiView(glyph: glyph)
        case .passage(let id):
            PassageView(passageID: id)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// MARK: Home

/// One number or one glyph, one action. Nothing else competes for attention.
struct HomeView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @Binding var showSettings: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 104

    private var hero: CGFloat { min(heroSize, 160) }

    var body: some View {
        TimelineView(.everyMinute) { _ in
            let state = store.homeState
            VStack(spacing: 0) {
                Spacer(minLength: Space.xl)
                centerpiece(state)
                    .padding(.horizontal, Space.l)
                Spacer(minLength: Space.xl)
                actions(state)
                    .padding(.horizontal, Space.l)
                    .padding(.bottom, Space.l)
                    .actionColumn()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    router.path.append(.library)
                } label: {
                    Label("Library", systemImage: "square.grid.2x2")
                }
                Button {
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
    }

    @ViewBuilder
    private func centerpiece(_ state: HomeState) -> some View {
        switch state {
        case .review(let count):
            VStack(spacing: Space.xs) {
                Text("\(count)")
                    .font(.system(size: hero, weight: .light))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(count == 1 ? "review" : "reviews")
                    .font(.title3)
                    .foregroundStyle(Palette.ink2)
            }
            .accessibilityElement(children: .combine)
        case .learn(let batch):
            VStack(spacing: Space.xs) {
                Text(batch.first?.glyph ?? "")
                    .font(.jpFixed(hero * 1.1, face: store.data.settings.face))
                Text(batch.count == 1 ? "1 new kanji" : "\(batch.count) new kanji")
                    .font(.title3)
                    .foregroundStyle(Palette.ink2)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(batch.count == 1 ? "1 new kanji to learn" : "\(batch.count) new kanji to learn")
        case .rest(let next, _, _):
            VStack(spacing: Space.xs) {
                Text("Done")
                    .font(.system(size: hero * 0.6, weight: .light))
                Group {
                    if let next = next {
                        Text("Next review \(next, format: .relative(presentation: .named))")
                    } else {
                        Text("Nothing left to learn — import more in Settings.")
                    }
                }
                .font(.title3)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private func actions(_ state: HomeState) -> some View {
        switch state {
        case .review:
            ActionButton(title: "Review") {
                if let launch = store.reviewLaunch() { router.path.append(.study(launch)) }
            }
            .keyboardShortcut(.defaultAction)
        case .learn:
            ActionButton(title: "Learn") {
                if let launch = store.lessonLaunch(extra: false) { router.path.append(.study(launch)) }
            }
            .keyboardShortcut(.defaultAction)
        case .rest(_, let canLearnMore, let passage):
            VStack(spacing: Space.s) {
                if let passage = passage {
                    Button {
                        router.path.append(.passage(passage.id))
                    } label: {
                        Text("Read “\(Ruby.plain(passage.title))”")
                            .font(.body)
                    }
                    .buttonStyle(.borderless)
                }
                if canLearnMore {
                    Button {
                        if let launch = store.lessonLaunch(extra: true) { router.path.append(.study(launch)) }
                    } label: {
                        Text("Learn more today")
                            .font(.body)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .frame(minHeight: Metrics.buttonHeight)
        }
    }
}

// MARK: Study

/// A study session: lesson pages (for new kanji), then questions, then a
/// stamp. Pushed onto the navigation stack so Back always leaves — every
/// answer is already saved.
struct StudyView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: SessionModel
    @State private var teaching: Bool
    @State private var page = 0
    let launch: SessionLaunch

    init(launch: SessionLaunch) {
        self.launch = launch
        _model = StateObject(wrappedValue: SessionModel(mode: launch.mode, items: launch.items))
        _teaching = State(initialValue: !launch.lessonGlyphs.isEmpty)
    }

    private var progress: Double {
        if teaching { return Double(page + 1) / Double(max(launch.lessonGlyphs.count, 1)) }
        return model.progress
    }

    private var counter: String {
        if teaching { return "\(page + 1) of \(launch.lessonGlyphs.count)" }
        if model.isFinished { return "" }
        return "\(model.completed) of \(model.total)"
    }

    var body: some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { studyToolbar }
            .safeAreaInset(edge: .top, spacing: 0) {
                if !model.isFinished {
                    ProgressView(value: progress)
                        .tint(Palette.accent)
                        .padding(.horizontal, Space.l)
                        .padding(.vertical, Space.xs)
                        .readableColumn()
                        .accessibilityLabel(counter)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: teaching)
            .animation(.easeInOut(duration: 0.25), value: model.isFinished)
    }

    @ViewBuilder
    private var content: some View {
        if teaching {
            LessonPager(glyphs: launch.lessonGlyphs, page: $page, onFinish: finishTeaching)
        } else if model.isFinished {
            SummaryView(model: model) { dismiss() }
        } else if let item = model.current {
            QuestionView(model: model, item: item)
                .id(item.id)
                .transition(.opacity)
        }
    }

    @ToolbarContentBuilder
    private var studyToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(counter)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Palette.ink2)
        }
        if teaching {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    markKnown()
                } label: {
                    Label("I know this", systemImage: "checkmark.circle")
                }
            }
        } else if !model.isFinished {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.undo(store: store)
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(!model.canUndo)
                .keyboardShortcut("z", modifiers: .command)
            }
        }
    }

    /// Skips a kanji the learner already knows; it's verified later by a
    /// spaced check instead of being taught.
    private func markKnown() {
        guard launch.lessonGlyphs.indices.contains(page) else { return }
        let glyph = launch.lessonGlyphs[page]
        store.markKnown([glyph])
        model.remove(glyph: glyph)
        if store.data.settings.haptics { Haptics.success() }
        if page >= launch.lessonGlyphs.count - 1 {
            finishTeaching()
        } else {
            withAnimation { page += 1 }
        }
    }

    private func finishTeaching() {
        if model.isFinished {
            dismiss()
        } else {
            teaching = false
        }
    }
}

struct LessonPager: View {
    let glyphs: [String]
    @Binding var page: Int
    let onFinish: () -> Void

    private var isLast: Bool { page >= glyphs.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(glyphs.enumerated()), id: \.offset) { offset, glyph in
                    ScrollView {
                        KanjiArticle(glyph: glyph)
                            .padding(.horizontal, Space.l)
                            .padding(.vertical, Space.l)
                            .readableColumn()
                    }
                    .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            ActionButton(title: isLast ? "Begin" : "Next") {
                if isLast {
                    onFinish()
                } else {
                    withAnimation { page += 1 }
                }
            }
            .keyboardShortcut(.defaultAction)
            .padding(.horizontal, Space.l)
            .padding(.vertical, Space.m)
            .actionColumn()
        }
    }
}

/// Everything about one kanji, set as plain typography: the glyph, what it
/// means and how it sounds, a hook, real words and a real sentence. Words
/// and the sentence speak when tapped.
struct KanjiArticle: View {
    @EnvironmentObject var store: Store
    let glyph: String
    var detailed = false
    @State private var editingHook = false
    @State private var hookDraft = ""
    @FocusState var hookFocused: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var glyphSize: CGFloat = 128

    var body: some View {
        if let kanji = store.library.byGlyph[glyph] {
            VStack(alignment: .leading, spacing: Space.xxl) {
                header(kanji)
                hook(kanji)
                if !kanji.words.isEmpty { words(kanji) }
                if !kanji.sentence.isEmpty { sentence(kanji) }
                if detailed { notes(kanji) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func header(_ kanji: Kanji) -> some View {
        VStack(spacing: Space.s) {
            Text(kanji.glyph)
                .font(.jpFixed(min(glyphSize, 190), face: store.data.settings.face))
                .accessibilityLabel("Kanji \(kanji.glyph)")
            Text(kanji.meaningList.capitalizedFirst)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(readingLine(kanji))
                .font(.jp(17, relativeTo: .body))
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func hook(_ kanji: Kanji) -> some View {
        let own = store.note(for: kanji.glyph)
        return VStack(alignment: .leading, spacing: Space.s) {
            if !kanji.parts.isEmpty {
                MixedText(kanji.parts.map { "\($0.glyph) \($0.meaning)" }.joined(separator: " + "), style: .subheadline)
                    .foregroundStyle(Palette.ink2)
            }
            if editingHook {
                TextField("A picture or story that makes it stick for you", text: $hookDraft, axis: .vertical)
                    .lineLimit(2...6)
                    .focused($hookFocused)
                HStack {
                    Button("Cancel") { editingHook = false }
                        .foregroundStyle(Palette.ink2)
                    Spacer()
                    Button("Save") {
                        store.setNote(hookDraft, for: kanji.glyph)
                        editingHook = false
                    }
                    .fontWeight(.semibold)
                }
                .font(.subheadline)
                .frame(minHeight: Metrics.minTap)
            } else {
                MixedText(own.isEmpty ? kanji.mnemonic : own, style: .body)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                Button(own.isEmpty ? "Write your own" : "Edit your own") {
                    hookDraft = own
                    editingHook = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { hookFocused = true }
                }
                .font(.footnote)
                .buttonStyle(.borderless)
            }
        }
    }

    private func words(_ kanji: Kanji) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            ForEach(kanji.words) { word in
                HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                    jpText(word.word, highlight: kanji.glyph, size: 20, face: store.data.settings.face, fixed: false)
                        .fixedSize()
                    Text(word.readings.joined(separator: " / "))
                        .font(.jp(14, relativeTo: .subheadline))
                        .foregroundStyle(Palette.ink2)
                        .fixedSize()
                    Spacer(minLength: Space.s)
                    Text(word.meaning)
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink2)
                        .multilineTextAlignment(.trailing)
                }
                .contentShape(Rectangle())
                .onTapGesture { Speaker.shared.say(word.primaryReading) }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Plays the pronunciation")
            }
        }
    }

    private func sentence(_ kanji: Kanji) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            RubyText(markup: kanji.sentence, size: 19, highlight: kanji.glyph)
                .contentShape(Rectangle())
                .onTapGesture { Speaker.shared.say(Ruby.spoken(kanji.sentence)) }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Plays the sentence")
            Text(kanji.translation)
                .font(.subheadline)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func notes(_ kanji: Kanji) -> some View {
        let confusions = store.library.confusions(for: kanji.glyph)
        let usage = kanji.usage ?? ""
        let memory = store.memoryLine(for: kanji.glyph)
        if !usage.isEmpty || !confusions.isEmpty || memory != nil {
            VStack(alignment: .leading, spacing: Space.m) {
                if !usage.isEmpty {
                    MixedText(usage, style: .subheadline)
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(confusions) { confusion in
                    MixedText(confusion.tip, style: .subheadline)
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let memory = memory {
                    Text(memory)
                        .font(.footnote)
                        .foregroundStyle(Palette.ink3)
                }
            }
        }
    }
}

/// One question. The prompt sits in the middle of the screen; the only
/// controls sit at the bottom, within reach of a thumb.
struct QuestionView: View {
    @EnvironmentObject var store: Store
    @ObservedObject var model: SessionModel
    let item: StudyItem

    @State private var revealed = false
    @State private var typed = ""
    @State private var verdict: Bool? = nil
    @State private var hint: String? = nil
    @State private var usedHint = false
    @State private var inferredMiss: MissReason? = nil
    @State private var shakes: CGFloat = 0
    @State private var shownAt = Date()
    @State private var answerMs = 0
    @State private var clearToken = 0
    @State private var hasInk = false
    @FocusState var fieldFocused: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 128

    private var settings: AppSettings { store.data.settings }
    private var hero: CGFloat { min(heroSize, 200) }
    private var kanji: Kanji? { store.library.byGlyph[item.glyph] }

    private var word: Word? {
        guard let k = kanji, !k.words.isEmpty else { return nil }
        return k.words[item.wordIndex % k.words.count]
    }

    /// The memory hook appears only when it can help: new, relearning or
    /// repeatedly forgotten cards, or right after a miss.
    private var needsSupport: Bool {
        if verdict == false { return true }
        guard let card = store.card(item.glyph, item.facet) else { return true }
        return card.phase != .review || card.leech
    }

    private var isLeech: Bool { store.card(item.glyph, item.facet)?.leech ?? false }

    var body: some View {
        if let k = kanji, item.facet != .reading || word != nil {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    ScrollView {
                        VStack(spacing: Space.xl) {
                            prompt(k)
                            if revealed {
                                answer(k)
                                    .transition(.opacity)
                            }
                        }
                        .padding(.horizontal, Space.l)
                        .padding(.vertical, Space.xl)
                        .frame(maxWidth: .infinity, minHeight: geo.size.height)
                        .readableColumn()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if item.facet == .meaning && !revealed { reveal() }
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
                controls(k)
                    .padding(.horizontal, Space.l)
                    .padding(.vertical, Space.m)
                    .actionColumn()
            }
            .onAppear(perform: appear)
        } else {
            Color.clear.onAppear { model.skipCurrent() }
        }
    }

    // MARK: Prompt and answer

    @ViewBuilder
    private func prompt(_ k: Kanji) -> some View {
        switch item.facet {
        case .meaning:
            VStack(spacing: Space.s) {
                Text(k.glyph)
                    .font(.jpFixed(hero, face: settings.face))
                    .accessibilityLabel("Kanji \(k.glyph)")
                Caption(text: "Meaning")
                    .opacity(revealed ? 0 : 1)
            }
        case .reading:
            if let w = word {
                VStack(spacing: Space.s) {
                    jpText(w.word, highlight: k.glyph, size: min(hero * 0.6, 84), face: settings.face)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                    Text(w.meaning)
                        .font(.body)
                        .foregroundStyle(Palette.ink2)
                        .multilineTextAlignment(.center)
                    Caption(text: "Reading")
                        .opacity(verdict == nil ? 1 : 0)
                }
            }
        case .writing:
            VStack(spacing: Space.m) {
                Text(k.meaningList.capitalizedFirst)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                if let w = k.words.first {
                    MixedText("\(w.word.replacingOccurrences(of: k.glyph, with: "〇"))（\(w.primaryReading)）", style: .body)
                        .foregroundStyle(Palette.ink2)
                }
                WritingPad(clearToken: clearToken, hasInk: $hasInk, guide: revealed ? k.glyph : nil,
                           guideOpacity: 0.3, face: settings.face)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: 320)
                Caption(text: "Write it")
                    .opacity(revealed ? 0 : 1)
            }
        }
    }

    @ViewBuilder
    private func answer(_ k: Kanji) -> some View {
        VStack(spacing: Space.s) {
            switch item.facet {
            case .meaning:
                Text(k.meaningList.capitalizedFirst)
                    .font(.title2.weight(.semibold))
                Text(readingLine(k))
                    .font(.jp(16, relativeTo: .callout))
                    .foregroundStyle(Palette.ink2)
            case .reading:
                if let w = word {
                    readingResult(w)
                }
            case .writing:
                Text(readingLine(k))
                    .font(.jp(16, relativeTo: .callout))
                    .foregroundStyle(Palette.ink2)
            }
            if needsSupport {
                MixedText(hookText(k), style: .callout)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.xs)
            }
            if isLeech {
                ForEach(store.library.confusions(for: k.glyph)) { confusion in
                    MixedText(confusion.tip, style: .footnote)
                        .foregroundStyle(Palette.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private func readingResult(_ w: Word) -> some View {
        VStack(spacing: Space.xxs) {
            Text(w.readings.joined(separator: " / "))
                .font(.jp(30, relativeTo: .title))
                .foregroundStyle(verdict == true ? Palette.matcha : Palette.ink)
            if verdict == false && !typed.isEmpty {
                Text(typed)
                    .font(.jp(17, relativeTo: .body))
                    .strikethrough()
                    .foregroundStyle(Palette.shu)
                    .accessibilityLabel("You typed \(typed)")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { Speaker.shared.say(w.primaryReading) }
    }

    private func hookText(_ k: Kanji) -> String {
        let own = store.note(for: k.glyph)
        return own.isEmpty ? k.mnemonic : own
    }

    // MARK: Controls

    @ViewBuilder
    private func controls(_ k: Kanji) -> some View {
        switch item.facet {
        case .meaning:
            if revealed {
                gradeButtons
            } else {
                ActionButton(title: "Show") { reveal() }
                    .keyboardShortcut(.space, modifiers: [])
            }
        case .reading:
            readingControls(k)
        case .writing:
            if revealed {
                gradeButtons
            } else {
                HStack(spacing: Space.s) {
                    ActionButton(title: "Clear", kind: .secondary) { clearToken += 1 }
                        .disabled(!hasInk)
                    ActionButton(title: "Show") { reveal() }
                        .keyboardShortcut(.space, modifiers: [])
                }
            }
        }
    }

    private var gradeButtons: some View {
        HStack(spacing: Space.s) {
            ActionButton(title: "Forgot", kind: .secondary) { grade(.again) }
                .keyboardShortcut("1", modifiers: [])
            ActionButton(title: "Remembered") { grade(.good) }
                .keyboardShortcut(.defaultAction)
        }
    }

    @ViewBuilder
    private func readingControls(_ k: Kanji) -> some View {
        if verdict == nil {
            VStack(spacing: Space.s) {
                if let hint = hint {
                    MixedText(hint, style: .subheadline)
                        .foregroundStyle(Palette.kohaku)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }
                answerField(k)
            }
        } else if verdict == true {
            ActionButton(title: "Continue") { grade(.good) }
                .keyboardShortcut(.defaultAction)
        } else {
            HStack(spacing: Space.s) {
                ActionButton(title: "I mistyped", kind: .secondary) { grade(.good) }
                ActionButton(title: "Continue") { grade(.again) }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func answerField(_ k: Kanji) -> some View {
        HStack(spacing: Space.xs) {
            TextField("かな or romaji", text: $typed)
                .font(.jp(22, relativeTo: .title3))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($fieldFocused)
                .onSubmit { check(k) }
                .onChange(of: typed) { _, newValue in
                    let converted = Romaji.toHiragana(newValue)
                    if converted != newValue { typed = converted }
                }
                .padding(.leading, Space.xxl)
            Button {
                check(k)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .frame(minWidth: Metrics.minTap, minHeight: Metrics.minTap)
            }
            .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel("Check")
        }
        .padding(.horizontal, Space.xxs)
        .frame(minHeight: Metrics.buttonHeight)
        .background(Palette.surface, in: Capsule())
        .modifier(Shake(animatableData: shakes))
    }

    // MARK: Actions

    private func appear() {
        shownAt = Date()
        if item.facet == .reading {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { fieldFocused = true }
        }
    }

    private func reveal() {
        answerMs = Int(Date().timeIntervalSince(shownAt) * 1000)
        withAnimation(.easeOut(duration: 0.2)) { revealed = true }
        if settings.haptics { Haptics.tap() }
        if settings.autoSpeak, let w = word { Speaker.shared.say(w.primaryReading) }
    }

    private func check(_ k: Kanji) {
        guard verdict == nil, let w = word else { return }
        let answer = Kana.normalize(Romaji.toHiragana(typed, final: true))
        guard !answer.isEmpty else { return }
        typed = answer
        let targets = w.readings.map { Kana.normalize($0) }
        if targets.contains(answer) {
            finish(correct: true, word: w)
            return
        }
        if !usedHint, let message = nearMissHint(answer, targets: targets, kanji: k) {
            usedHint = true
            withAnimation(.easeOut(duration: 0.2)) { hint = message }
            typed = ""
            withAnimation(.default) { shakes += 1 }
            if settings.haptics { Haptics.tap() }
            return
        }
        if inferredMiss == nil { inferredMiss = .reading }
        finish(correct: false, word: w)
    }

    private func finish(correct: Bool, word w: Word) {
        answerMs = Int(Date().timeIntervalSince(shownAt) * 1000)
        fieldFocused = false
        withAnimation(.easeOut(duration: 0.2)) {
            verdict = correct
            revealed = true
        }
        if settings.haptics {
            if correct { Haptics.success() } else { Haptics.error() }
        }
        if settings.autoSpeak { Speaker.shared.say(w.primaryReading) }
    }

    /// One free retry for answers that are almost right, pointing at exactly
    /// what to notice. The kind of slip is recorded silently, so patterns
    /// can shape support without asking the learner anything.
    private func nearMissHint(_ answer: String, targets: [String], kanji k: Kanji) -> String? {
        for target in targets {
            if answer.replacingOccurrences(of: "っ", with: "") == target.replacingOccurrences(of: "っ", with: "") {
                inferredMiss = .slip
                return "Almost — check for a small っ."
            }
            if Kana.collapseLongVowels(answer) == Kana.collapseLongVowels(target) {
                inferredMiss = .slip
                return "Almost — listen for a long vowel."
            }
            if Kana.stripVoicing(answer) == Kana.stripVoicing(target) {
                inferredMiss = .slip
                return "Almost — check the ゛ marks."
            }
        }
        let readings = k.on + k.kun
        let candidates = readings.map { Kana.normalize($0) } + readings.map { Kana.normalize(splitKun($0).stem) }
        if candidates.contains(answer) {
            inferredMiss = .reading
            return "That's a reading of \(k.glyph), but not in this word."
        }
        return nil
    }

    private func grade(_ rating: Rating) {
        let ms = answerMs > 0 ? answerMs : Int(Date().timeIntervalSince(shownAt) * 1000)
        if settings.haptics && item.facet != .reading { Haptics.tap() }
        var miss: MissReason? = nil
        if rating == .again {
            switch item.facet {
            case .meaning: miss = .meaning
            case .reading: miss = inferredMiss ?? .reading
            case .writing: miss = nil
            }
        }
        model.commit(rating, ms: ms, miss: miss, store: store)
    }
}

struct SummaryView: View {
    @EnvironmentObject var store: Store
    @ObservedObject var model: SessionModel
    let onDone: () -> Void
    @State private var offerReminder = false

    private var title: String {
        switch model.mode {
        case .lesson: return "Learned"
        case .review: return "Reviewed"
        case .practice: return "Practiced"
        }
    }

    private var detail: String {
        let accuracy = model.total == 0 ? 1 : Double(model.result.firstTry) / Double(model.total)
        switch model.mode {
        case .lesson:
            return "They'll come back in a few hours, while still fresh."
        case .review:
            return "\(model.total) \(model.total == 1 ? "card" : "cards") · \(Format.percent(accuracy)) on the first try"
        case .practice:
            return "Practice doesn't change your schedule."
        }
    }

    var body: some View {
        VStack(spacing: Space.xl) {
            Spacer()
            Hanko(glyph: model.mode == .lesson ? "学" : "済")
            VStack(spacing: Space.xs) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Space.l)
            Spacer()
            VStack(spacing: Space.s) {
                if offerReminder {
                    ActionButton(title: "Remind me daily", kind: .secondary) {
                        Reminders.enable(store) { _ in }
                        offerReminder = false
                    }
                }
                ActionButton(title: "Done") { finish() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.l)
            .actionColumn()
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            // Ask about reminders once, in context, after a first real session.
            offerReminder = model.mode != .practice && !store.data.settings.askedReminder && !store.data.settings.reminder
        }
    }

    private func finish() {
        if offerReminder { store.data.settings.askedReminder = true }
        onDone()
    }
}

// MARK: Library

struct LibraryView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @State private var shelf: Shelf = .kanji
    @State private var query = ""

    enum Shelf: String, CaseIterable, Identifiable {
        case kanji = "Kanji"
        case texts = "Texts"
        var id: String { rawValue }
    }

    private var searchPrompt: String {
        shelf == .kanji ? "Kanji, meaning or reading" : "Search texts"
    }

    private let columns = [GridItem(.adaptive(minimum: 60, maximum: 88), spacing: Space.xs)]

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Search accepts the kanji, an English meaning, or a reading in kana or
    /// romaji.
    private var kanjiResults: [Kanji] {
        let q = trimmed
        guard !q.isEmpty else { return store.library.kanji }
        let lower = q.lowercased()
        let kana = Kana.normalize(Romaji.toHiragana(lower, final: true))
        let hasKana = !kana.isEmpty && kana.allSatisfy { $0.isJapanese }
        return store.library.kanji.filter { k in
            if k.glyph == q || k.words.contains(where: { $0.word.contains(q) }) { return true }
            if k.meanings.contains(where: { $0.lowercased().contains(lower) }) { return true }
            guard hasKana else { return false }
            if (k.on + k.kun).contains(where: { Kana.normalize($0).hasPrefix(kana) }) { return true }
            return k.words.contains { word in word.readings.contains { Kana.normalize($0).hasPrefix(kana) } }
        }
    }

    private var passageResults: [Passage] {
        let q = trimmed.lowercased()
        guard !q.isEmpty else { return store.library.passages }
        return store.library.passages.filter {
            Ruby.plain($0.title).contains(q) || $0.titleEN.lowercased().contains(q) || $0.topic.lowercased().contains(q)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                Picker("Library", selection: $shelf) {
                    ForEach(Shelf.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: Metrics.actionWidth)
                .frame(maxWidth: .infinity)

                if shelf == .kanji {
                    kanjiSection
                } else {
                    textsSection
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.xxl)
            .frame(maxWidth: Metrics.gridWidth)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Library")
        .searchable(text: $query, prompt: Text(searchPrompt))
    }

    @ViewBuilder
    private var kanjiSection: some View {
        let results = kanjiResults
        if results.isEmpty {
            ContentUnavailableView.search(text: trimmed)
        } else {
            ForEach(store.library.levelsWithContent) { level in
                let inLevel = results.filter { $0.level == level }
                if !inLevel.isEmpty {
                    levelBlock(level, kanji: inLevel)
                }
            }
        }
    }

    private func levelBlock(_ level: JLPTLevel, kanji: [Kanji]) -> some View {
        let all = store.library.kanjiList(for: level)
        let known = all.filter { store.stage(of: $0.glyph) >= .known }.count
        return VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(level.label)
                    .font(.headline)
                Spacer()
                Text("\(known) of \(all.count) known")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Palette.ink2)
            }
            LazyVGrid(columns: columns, spacing: Space.xs) {
                ForEach(kanji) { k in
                    Button {
                        router.path.append(.kanji(k.glyph))
                    } label: {
                        GlyphCell(kanji: k)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var textsSection: some View {
        let results = passageResults
        if results.isEmpty {
            ContentUnavailableView.search(text: trimmed)
        } else {
            VStack(spacing: 0) {
                ForEach(results) { passage in
                    Button {
                        router.path.append(.passage(passage.id))
                    } label: {
                        PassageRow(passage: passage)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
    }
}

/// A kanji in the library. Its ink deepens as it settles in memory — faint
/// when new, full black once known — so progress is visible without a
/// single chart.
struct GlyphCell: View {
    @EnvironmentObject var store: Store
    let kanji: Kanji

    private func inkOpacity(_ stage: Stage) -> Double {
        switch stage {
        case .new: return 0.22
        case .learning: return 0.45
        case .familiar: return 0.7
        case .known, .mastered: return 1
        }
    }

    var body: some View {
        let stage = store.stage(of: kanji.glyph)
        Text(kanji.glyph)
            .font(.jp(30, face: store.data.settings.face, relativeTo: .title))
            .foregroundStyle(Palette.ink.opacity(inkOpacity(stage)))
            .frame(maxWidth: .infinity, minHeight: 60)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(kanji.glyph), \(kanji.primaryMeaning)")
            .accessibilityValue(stage.title)
            .accessibilityAddTraits(.isButton)
    }
}

struct PassageRow: View {
    @EnvironmentObject var store: Store
    let passage: Passage

    var body: some View {
        HStack(alignment: .center, spacing: Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Ruby.plain(passage.title))
                    .font(.jp(20, relativeTo: .title3))
                    .foregroundStyle(Palette.ink)
                Text(passage.titleEN)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
            }
            Spacer()
            Text("\(Format.percent(store.coverage(of: passage))) known")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Palette.ink2)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.ink3)
        }
        .padding(.vertical, Space.m)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct KanjiView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let glyph: String
    @State private var confirmReset = false

    var body: some View {
        ScrollView {
            KanjiArticle(glyph: glyph, detailed: true)
                .padding(.horizontal, Space.l)
                .padding(.vertical, Space.l)
                .readableColumn()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    menuItems
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Reset \(glyph)?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset progress", role: .destructive) { store.resetProgress(for: glyph) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its reviews are cleared and it returns to your lessons.")
        }
    }

    @ViewBuilder
    private var menuItems: some View {
        if store.isStarted(glyph) {
            Button {
                if let launch = store.practiceLaunch([glyph]) { router.path.append(.study(launch)) }
            } label: {
                Label("Practice", systemImage: "arrow.triangle.2.circlepath")
            }
            Button(role: .destructive) {
                confirmReset = true
            } label: {
                Label("Reset progress", systemImage: "arrow.counterclockwise")
            }
        } else {
            Button {
                store.prioritize(glyph)
            } label: {
                Label(store.data.priority.first == glyph ? "Next in line" : "Learn next", systemImage: "plus.circle")
            }
            Button {
                store.markKnown([glyph])
            } label: {
                Label("I already know it", systemImage: "checkmark")
            }
        }
    }
}

// MARK: Reading

struct PassageView: View {
    @EnvironmentObject var store: Store
    let passageID: String
    @State private var showTranslation = false
    @State private var lookup: RubyUnit? = nil
    @State private var choice: Int? = nil

    private var passage: Passage? { store.library.passages.first { $0.id == passageID } }

    var body: some View {
        if let passage = passage {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xxl) {
                    header(passage)
                    lines(passage)
                    if let notes = passage.notes, !notes.isEmpty { notesView(notes) }
                    if let question = passage.question { questionView(question, passage: passage) }
                }
                .padding(.horizontal, Space.l)
                .padding(.vertical, Space.l)
                .readableColumn()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Speaker.shared.say(passage.lines.map { Ruby.spoken($0.jp) }.joined(separator: "\n"))
                    } label: {
                        Label("Listen", systemImage: "speaker.wave.2")
                    }
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { showTranslation.toggle() }
                    } label: {
                        Label(showTranslation ? "Hide translation" : "Show translation", systemImage: "translate")
                    }
                }
            }
            .sheet(item: $lookup) { unit in
                WordSheet(unit: unit)
                    .environmentObject(store)
                    .presentationDetents([.medium])
            }
            .onDisappear {
                if passage.question == nil { store.markRead(passage.id) }
            }
        } else {
            ContentUnavailableView("Text not found", systemImage: "doc.text")
        }
    }

    private func header(_ passage: Passage) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            RubyText(markup: passage.title, size: 28)
            Text("\(passage.titleEN) · \(passage.genre)")
                .font(.subheadline)
                .foregroundStyle(Palette.ink2)
        }
    }

    private func lines(_ passage: Passage) -> some View {
        VStack(alignment: .leading, spacing: Space.l) {
            ForEach(Array(passage.lines.enumerated()), id: \.offset) { _, line in
                VStack(alignment: .leading, spacing: Space.xxs) {
                    if let speaker = line.speaker {
                        Text(Ruby.plain(speaker))
                            .font(.jp(13, bold: true, relativeTo: .caption))
                            .foregroundStyle(Palette.ink2)
                    }
                    RubyText(markup: line.jp, size: 20, onTap: { lookup = $0 })
                    if showTranslation {
                        Text(line.en)
                            .font(.subheadline)
                            .foregroundStyle(Palette.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                    }
                }
            }
        }
    }

    private func notesView(_ notes: [PassageNote]) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            ForEach(notes, id: \.self) { note in
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(note.lens)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.ink2)
                    MixedText(note.text, style: .subheadline)
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func questionView(_ question: Question, passage: Passage) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            MixedText(question.prompt, style: .headline, bold: true)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                Button {
                    guard choice == nil else { return }
                    withAnimation(.easeOut(duration: 0.2)) { choice = index }
                    store.markRead(passage.id)
                    if store.data.settings.haptics {
                        if index == question.answer { Haptics.success() } else { Haptics.error() }
                    }
                } label: {
                    HStack(spacing: Space.s) {
                        MixedText(option, style: .body)
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: Space.xs)
                        if choice != nil && index == question.answer {
                            Image(systemName: "checkmark").foregroundStyle(Palette.matcha)
                        } else if choice == index {
                            Image(systemName: "xmark").foregroundStyle(Palette.shu)
                        }
                    }
                    .padding(.vertical, Space.s)
                    .frame(maxWidth: .infinity, minHeight: Metrics.minTap, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(choice == index ? .isSelected : [])
            }
            if let picked = choice, let explanation = question.explanation {
                MixedText((picked == question.answer ? "Right. " : "Not quite. ") + explanation, style: .subheadline)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
    }
}

/// Lookup for a tapped word: its reading, the kanji in it, and a way to
/// queue an unlearned kanji next — reading feeds straight back into study.
struct WordSheet: View {
    @EnvironmentObject var store: Store
    let unit: RubyUnit

    private var glyphs: [String] {
        var seen: [String] = []
        for ch in unit.base where ch.isKanji {
            let g = String(ch)
            if !seen.contains(g) { seen.append(g) }
        }
        return seen
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(unit.base)
                        .font(.jp(34, bold: true, face: store.data.settings.face, relativeTo: .largeTitle))
                    if let reading = unit.reading {
                        Text(reading)
                            .font(.jp(18, relativeTo: .title3))
                            .foregroundStyle(Palette.ink2)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { Speaker.shared.say(unit.reading ?? unit.base) }
                ForEach(glyphs, id: \.self) { glyph in
                    row(glyph)
                }
            }
            .padding(Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func row(_ glyph: String) -> some View {
        if let kanji = store.library.byGlyph[glyph] {
            let started = store.isStarted(glyph)
            HStack(spacing: Space.m) {
                Text(glyph)
                    .font(.jp(28, face: store.data.settings.face, relativeTo: .title))
                VStack(alignment: .leading, spacing: 2) {
                    Text(kanji.meaningList.capitalizedFirst)
                        .font(.body)
                    Text(store.stage(of: glyph).title)
                        .font(.caption)
                        .foregroundStyle(Palette.ink2)
                }
                Spacer()
                if !started {
                    Button(store.data.priority.contains(glyph) ? "Queued" : "Learn next") {
                        store.prioritize(glyph)
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.data.priority.contains(glyph))
                }
            }
        } else {
            HStack(spacing: Space.m) {
                Text(glyph)
                    .font(.jp(28, relativeTo: .title))
                Text("Not in your library yet")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
            }
        }
    }
}

// MARK: Settings

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var importing = false
    @State private var exporting = false
    @State private var exportDocument: BackupDocument? = nil
    @State private var pendingBackup: SaveFile? = nil
    @State private var confirmReset = false
    @State private var alertMessage: String? = nil
    @State private var showKnownPicker = false

    private var paceOptions: [Int] {
        Array(Set([0, 3, 5, 10, 15, 20, 30, store.data.settings.newPerDay])).sorted()
    }

    private var reminderBinding: Binding<Bool> {
        Binding(get: { store.data.settings.reminder }, set: { on in
            if on {
                Reminders.enable(store) { granted in
                    if !granted { alertMessage = "Allow notifications for Sumi in the Settings app to get reminders." }
                }
            } else {
                Reminders.disable(store)
            }
        })
    }

    private var reminderTime: Binding<Date> {
        Binding(get: {
            Calendar.current.date(bySettingHour: store.data.settings.reminderHour,
                                  minute: store.data.settings.reminderMinute, second: 0, of: Date()) ?? Date()
        }, set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            store.data.settings.reminderHour = parts.hour ?? 19
            store.data.settings.reminderMinute = parts.minute ?? 0
            Reminders.schedule(store)
        })
    }

    private var backupBinding: Binding<Bool> {
        Binding(get: { pendingBackup != nil }, set: { if !$0 { pendingBackup = nil } })
    }

    private var alertBinding: Binding<Bool> {
        Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("New kanji a day", selection: $store.data.settings.newPerDay) {
                        ForEach(paceOptions, id: \.self) { n in
                            Text(n == 0 ? "Paused" : "\(n)").tag(n)
                        }
                    }
                    Toggle("Writing practice", isOn: $store.data.settings.writing)
                    Picker("Furigana", selection: $store.data.settings.furigana) {
                        ForEach(FuriganaMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    Picker("Typeface", selection: $store.data.settings.face) {
                        ForEach(JPFace.allCases) { face in
                            Text(face.title).tag(face)
                        }
                    }
                    Toggle("Speak answers", isOn: $store.data.settings.autoSpeak)
                }

                Section {
                    Toggle("Daily reminder", isOn: reminderBinding)
                    if store.data.settings.reminder {
                        DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                }

                Section {
                    Button("Mark kanji I know") { showKnownPicker = true }
                    Button("Import") { importing = true }
                    Button("Export backup") {
                        exportDocument = BackupDocument(data: store.exportData())
                        exporting = true
                    }
                    .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .json,
                                  defaultFilename: "Sumi backup") { result in
                        if case .failure(let error) = result { alertMessage = error.localizedDescription }
                    }
                    ForEach(store.data.packs, id: \.name) { pack in
                        LabeledContent(pack.name, value: "\(pack.kanji.count) kanji")
                            .swipeActions {
                                Button("Remove", role: .destructive) { store.removePack(named: pack.name) }
                            }
                    }
                }

                Section {
                    NavigationLink("How Sumi works") { AboutView() }
                    NavigationLink("Privacy") { PrivacyView() }
                }

                Section {
                    Button("Reset progress", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("Sumi 1.0")
                        .frame(maxWidth: .infinity)
                        .padding(.top, Space.l)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showKnownPicker) {
                KnownPickerView().environmentObject(store)
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset everything", role: .destructive) { store.resetAllProgress() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Every review and note is erased. This can't be undone.")
            }
            .confirmationDialog("Restore this backup?", isPresented: backupBinding, titleVisibility: .visible) {
                Button("Replace my progress", role: .destructive) {
                    if let backup = pendingBackup { store.restore(backup) }
                    pendingBackup = nil
                }
                Button("Cancel", role: .cancel) { pendingBackup = nil }
            } message: {
                Text("Your current progress on this device will be replaced.")
            }
            .alert(alertMessage ?? "", isPresented: alertBinding) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            alertMessage = error.localizedDescription
        case .success(let url):
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let raw = try Data(contentsOf: url)
                let file = try store.inspect(raw)
                // Let the document picker finish dismissing before presenting.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    switch file {
                    case .pack(let pack):
                        store.install(pack)
                        alertMessage = "Added “\(pack.name)”."
                    case .backup(let backup):
                        pendingBackup = backup
                    }
                }
            } catch {
                alertMessage = "That file isn't a Sumi content pack or backup."
            }
        }
    }
}

/// Lets experienced learners skip what they already know.
struct KnownPickerView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var onConfirm: (() -> Void)? = nil
    @State private var selected: Set<String> = []
    private let columns = [GridItem(.adaptive(minimum: 60, maximum: 88), spacing: Space.xs)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    Text("Tap the kanji you can already read. Each one is checked later in a review.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(store.library.levelsWithContent) { level in
                        let candidates = store.library.kanjiList(for: level).filter { !store.isStarted($0.glyph) }
                        if !candidates.isEmpty {
                            levelGrid(level, candidates)
                        }
                    }
                }
                .padding(.horizontal, Space.l)
                .padding(.vertical, Space.m)
                .frame(maxWidth: Metrics.gridWidth)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Kanji you know")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selected.isEmpty ? "Done" : "Mark \(selected.count)") {
                        if !selected.isEmpty {
                            store.markKnown(Array(selected))
                            onConfirm?()
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func levelGrid(_ level: JLPTLevel, _ candidates: [Kanji]) -> some View {
        let allSelected = candidates.allSatisfy { selected.contains($0.glyph) }
        return VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                Text(level.label)
                    .font(.headline)
                Spacer()
                Button(allSelected ? "Clear" : "Select all") {
                    for k in candidates {
                        if allSelected { selected.remove(k.glyph) } else { selected.insert(k.glyph) }
                    }
                }
                .font(.subheadline)
                .buttonStyle(.borderless)
            }
            LazyVGrid(columns: columns, spacing: Space.xs) {
                ForEach(candidates) { k in
                    let isOn = selected.contains(k.glyph)
                    Button {
                        if isOn { selected.remove(k.glyph) } else { selected.insert(k.glyph) }
                    } label: {
                        Text(k.glyph)
                            .font(.jp(30, face: store.data.settings.face, relativeTo: .title))
                            .foregroundStyle(isOn ? Palette.onAccent : Palette.ink)
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(isOn ? Palette.accent : Color.clear,
                                        in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(k.glyph), \(k.primaryMeaning)")
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }
}

struct AboutView: View {
    private struct Point: Identifiable {
        let title: String
        let text: String
        var id: String { title }
    }

    private let points: [Point] = [
        Point(title: "Reviews arrive just before you'd forget",
              text: "A memory model (FSRS-6) estimates how well you hold each kanji and schedules the next review for when recall drops to about 90%."),
        Point(title: "You always answer first",
              text: "Recalling an answer strengthens memory far more than re-reading it."),
        Point(title: "Readings live in words",
              text: "A kanji alone rarely has one right reading, so readings are practiced inside real words."),
        Point(title: "Recognize, then read, then write",
              text: "Writing unlocks once you recognize a kanji reliably."),
        Point(title: "Real Japanese",
              text: "Every kanji comes with words and a sentence, and short texts show furigana only above kanji you haven't learned."),
        Point(title: "Mistakes are noticed for you",
              text: "Near misses get a hint and a second try. Kanji you keep forgetting automatically get more support.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                ForEach(points) { point in
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text(point.title)
                            .font(.headline)
                        Text(point.text)
                            .font(.subheadline)
                            .foregroundStyle(Palette.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text("JLPT levels are a study guide. The JLPT hasn't published official kanji lists since 2010; Sumi isn't affiliated with the Japan Foundation or JEES.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Space.l)
            .readableColumn()
        }
        .navigationTitle("How Sumi works")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Text("Sumi doesn't collect, track or share any data. There are no accounts, ads or analytics.")
                Text("Your progress is stored only on this device. Files you import stay inside the app, and backups you export go only where you choose.")
                Text("Reminders are scheduled on this device. Speech is generated on-device by iOS.")
                Text("To erase everything, use Reset progress in Settings or delete the app.")
            }
            .font(.body)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Space.l)
            .readableColumn()
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: Onboarding

struct OnboardingView: View {
    @EnvironmentObject var store: Store
    @State private var pace = 10
    @State private var showPicker = false
    @State private var markedKnown = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: Space.xl) {
                Text("墨")
                    .font(.jpFixed(96, face: .mincho))
                    .accessibilityHidden(true)
                VStack(spacing: Space.s) {
                    Text("Kanji, one quiet step at a time.")
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text("A few minutes a day. Sumi decides what to review and when — you just begin.")
                        .font(.body)
                        .foregroundStyle(Palette.ink2)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, Space.xl)
            .readableColumn()
            Spacer()
            VStack(spacing: Space.l) {
                VStack(spacing: Space.xs) {
                    Picker("New kanji a day", selection: $pace) {
                        Text("5").tag(5)
                        Text("10").tag(10)
                        Text("20").tag(20)
                    }
                    .pickerStyle(.segmented)
                    Text("new kanji a day")
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                }
                ActionButton(title: "Begin") { finish() }
                    .keyboardShortcut(.defaultAction)
                Button("I already know some kanji") { showPicker = true }
                    .font(.subheadline)
                    .buttonStyle(.borderless)
                    .frame(minHeight: Metrics.minTap)
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.l)
            .actionColumn()
        }
        .interactiveDismissDisabled()
        .sheet(isPresented: $showPicker, onDismiss: {
            if markedKnown { finish() }
        }) {
            KnownPickerView(onConfirm: { markedKnown = true })
                .environmentObject(store)
        }
    }

    private func finish() {
        store.data.settings.newPerDay = pace
        store.data.onboarded = true
    }
}

// MARK: Reminders

/// Local reminders that say exactly how many reviews are waiting. Nothing
/// leaves the device; the next two weeks are rescheduled each time the app
/// goes to the background, so counts stay accurate.
enum Reminders {
    private static let prefix = "sumi.reminder."
    private static let days = 14

    private static var identifiers: [String] { (0..<days).map { prefix + String($0) } }

    static func enable(_ store: Store, completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                store.data.settings.askedReminder = true
                store.data.settings.reminder = granted
                if granted { schedule(store) }
                completion(granted)
            }
        }
    }

    static func disable(_ store: Store) {
        store.data.settings.reminder = false
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.setBadgeCount(0, withCompletionHandler: nil)
    }

    /// Turns reminders off here if they were turned off in the Settings app.
    static func sync(_ store: Store) {
        guard store.data.settings.reminder else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            DispatchQueue.main.async {
                if allowed {
                    schedule(store)
                } else {
                    disable(store)
                }
            }
        }
    }

    static func schedule(_ store: Store) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        let settings = store.data.settings
        guard settings.reminder else { return }

        let calendar = Calendar.current
        let now = Date()
        let cards = Array(store.data.cards.values).filter { $0.facet != .writing || settings.writing }
        let hasLessons = !store.lessonQueue.isEmpty && settings.newPerDay > 0
        let lessonsLeftToday = store.lessonsLeftToday > 0

        for day in 0..<days {
            guard let base = calendar.date(byAdding: .day, value: day, to: calendar.startOfDay(for: now)),
                  let fire = calendar.date(bySettingHour: settings.reminderHour, minute: settings.reminderMinute,
                                           second: 0, of: base),
                  fire > now else { continue }
            let due = cards.filter { $0.due <= fire }.count
            let content = UNMutableNotificationContent()
            if due > 0 {
                content.body = due == 1 ? "1 kanji is ready to review." : "\(due) kanji reviews are ready."
            } else if hasLessons && (day > 0 || lessonsLeftToday) {
                content.body = "New kanji are ready when you are."
            } else {
                continue
            }
            content.title = "Sumi"
            content.sound = .default
            content.badge = NSNumber(value: due)
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            center.add(UNNotificationRequest(identifier: prefix + String(day), content: content, trigger: trigger),
                       withCompletionHandler: nil)
        }
        center.setBadgeCount(store.dueCount, withCompletionHandler: nil)
    }
}

// MARK: - 8. Built-in content
//
// The starter pack: 59 N5 kanji, 5 N4 kanji, 5 reading passages and the
// look-alike sets. Same schema as importable packs — see
// docs/CONTENT_SCHEMA.md. The editable source is content/core-n5.json.

let builtInContentJSON = #"""
{
  "name": "Core N5 starter",
  "kanji": [
    {"glyph": "一", "level": 5, "strokes": 1, "meanings": ["one"], "on": ["イチ", "イツ"], "kun": ["ひと", "ひと.つ"], "kind": "indicative", "parts": [], "mnemonic": "A single flat stroke — one finger laid on the table.", "words": [{"word": "一つ", "reading": "ひとつ", "meaning": "one (thing)"}, {"word": "一人", "reading": "ひとり", "meaning": "one person; alone"}, {"word": "一月", "reading": "いちがつ", "meaning": "January"}], "sentence": "{一人|ひとり}で{東京|とうきょう}へ{行|い}きました。", "translation": "I went to Tokyo on my own.", "usage": "Japanese has two counting systems: いち、に、さん… from Chinese, and native ひとつ、ふたつ… for counting things up to ten."},
    {"glyph": "二", "level": 5, "strokes": 2, "meanings": ["two"], "on": ["ニ"], "kun": ["ふた", "ふた.つ"], "kind": "indicative", "parts": [], "mnemonic": "Two lines stacked — the longer bottom one is a shelf holding up the top.", "words": [{"word": "二つ", "reading": "ふたつ", "meaning": "two (things)"}, {"word": "二人", "reading": "ふたり", "meaning": "two people"}, {"word": "二月", "reading": "にがつ", "meaning": "February"}], "sentence": "{猫|ねこ}が{二匹|にひき}います。", "translation": "There are two cats.", "usage": "One and two people are irregular: 一人 ひとり, 二人 ふたり. From three on it's number + にん."},
    {"glyph": "三", "level": 5, "strokes": 3, "meanings": ["three"], "on": ["サン"], "kun": ["み", "み.つ", "みっ.つ"], "kind": "indicative", "parts": [], "mnemonic": "Three lines — count them. The middle one is the shortest.", "words": [{"word": "三つ", "reading": "みっつ", "meaning": "three (things)"}, {"word": "三月", "reading": "さんがつ", "meaning": "March"}, {"word": "三人", "reading": "さんにん", "meaning": "three people"}], "sentence": "りんごを{三|みっ}つください。", "translation": "Three apples, please.", "usage": "Months are simply number + 月: 三月 is March, the end of the Japanese school and business year."},
    {"glyph": "四", "level": 5, "strokes": 5, "meanings": ["four"], "on": ["シ"], "kun": ["よ", "よ.つ", "よっ.つ", "よん"], "kind": "borrowed", "parts": [{"glyph": "囗", "meaning": "enclosure"}, {"glyph": "儿", "meaning": "legs"}], "mnemonic": "A room (囗) with legs (儿) inside: four walls, four corners.", "words": [{"word": "四つ", "reading": "よっつ", "meaning": "four (things)"}, {"word": "四月", "reading": "しがつ", "meaning": "April"}, {"word": "四人", "reading": "よにん", "meaning": "four people"}], "sentence": "{四月|しがつ}に{日本|にほん}へ{行|い}きます。", "translation": "I'm going to Japan in April.", "usage": "し sounds like 死 (death), so よん is usually preferred — some buildings even skip room 4."},
    {"glyph": "五", "level": 5, "strokes": 4, "meanings": ["five"], "on": ["ゴ"], "kun": ["いつ", "いつ.つ"], "kind": "borrowed", "parts": [], "mnemonic": "Between a sky line and a ground line, a figure twists like a 5 written in a hurry.", "words": [{"word": "五つ", "reading": "いつつ", "meaning": "five (things)"}, {"word": "五月", "reading": "ごがつ", "meaning": "May"}, {"word": "五日", "reading": "いつか", "meaning": "the 5th (of the month); five days"}], "sentence": "{毎朝|まいあさ}{五時|ごじ}に{起|お}きます。", "translation": "I get up at five every morning.", "usage": "Early May has Golden Week, a cluster of national holidays when much of Japan travels."},
    {"glyph": "六", "level": 5, "strokes": 4, "meanings": ["six"], "on": ["ロク"], "kun": ["む", "む.つ", "むっ.つ"], "kind": "borrowed", "parts": [{"glyph": "亠", "meaning": "lid"}, {"glyph": "八", "meaning": "spread legs"}], "mnemonic": "A lid (亠) over spread legs (八): a little hut where six people huddle.", "words": [{"word": "六つ", "reading": "むっつ", "meaning": "six (things)"}, {"word": "六月", "reading": "ろくがつ", "meaning": "June"}, {"word": "六百", "reading": "ろっぴゃく", "meaning": "six hundred"}], "sentence": "{会議|かいぎ}は{六時|ろくじ}からです。", "translation": "The meeting starts at six.", "usage": "Sounds merge in numbers: ろく + ひゃく becomes ろっぴゃく."},
    {"glyph": "七", "level": 5, "strokes": 2, "meanings": ["seven"], "on": ["シチ"], "kun": ["なな", "なな.つ", "なの"], "kind": "borrowed", "parts": [], "mnemonic": "An upside-down 7 with a line through it, like a European-style seven.", "words": [{"word": "七つ", "reading": "ななつ", "meaning": "seven (things)"}, {"word": "七月", "reading": "しちがつ", "meaning": "July"}, {"word": "七時", "reading": "しちじ", "meaning": "seven o'clock"}], "sentence": "{毎朝|まいあさ}{七時|しちじ}に{家|いえ}を{出|で}ます。", "translation": "I leave home at seven every morning.", "usage": "なな is often used instead of しち, because しち is easy to mishear as いち."},
    {"glyph": "八", "level": 5, "strokes": 2, "meanings": ["eight"], "on": ["ハチ"], "kun": ["や", "や.つ", "やっ.つ", "よう"], "kind": "borrowed", "parts": [], "mnemonic": "Two strokes spreading apart like the foot of a mountain.", "words": [{"word": "八つ", "reading": "やっつ", "meaning": "eight (things)"}, {"word": "八月", "reading": "はちがつ", "meaning": "August"}, {"word": "八百", "reading": "はっぴゃく", "meaning": "eight hundred"}], "sentence": "{八時|はちじ}に{学校|がっこう}へ{行|い}きます。", "translation": "I go to school at eight.", "usage": "八 widens toward the bottom (末広がり, 'spreading toward the end'), so it's considered a lucky number."},
    {"glyph": "九", "level": 5, "strokes": 2, "meanings": ["nine"], "on": ["キュウ", "ク"], "kun": ["ここの", "ここの.つ"], "kind": "borrowed", "parts": [{"glyph": "丿", "meaning": "slanted stroke"}, {"glyph": "乙", "meaning": "hook"}], "mnemonic": "A slanted arm (丿) and a hooked elbow (乙) reaching for the ninth cookie.", "words": [{"word": "九つ", "reading": "ここのつ", "meaning": "nine (things)"}, {"word": "九月", "reading": "くがつ", "meaning": "September"}, {"word": "九時", "reading": "くじ", "meaning": "nine o'clock"}], "sentence": "{九月|くがつ}はまだ{暑|あつ}いです。", "translation": "September is still hot.", "usage": "く sounds like 苦 (suffering), so like 4 it's sometimes avoided. Times always use く: 九時 くじ."},
    {"glyph": "十", "level": 5, "strokes": 2, "meanings": ["ten"], "on": ["ジュウ", "ジッ"], "kun": ["とお", "と"], "parts": [], "mnemonic": "A plus sign: two hands of five fingers crossed together make ten.", "words": [{"word": "十", "reading": "とお", "meaning": "ten (things)"}, {"word": "十月", "reading": "じゅうがつ", "meaning": "October"}, {"word": "十日", "reading": "とおか", "meaning": "the 10th (of the month); ten days"}], "sentence": "{十分|じゅっぷん}{待|ま}ってください。", "translation": "Please wait ten minutes.", "usage": "十分 can be じゅっぷん (ten minutes) or じゅうぶん (enough) — context decides."},
    {"glyph": "百", "level": 5, "strokes": 6, "meanings": ["hundred"], "on": ["ヒャク"], "kun": ["もも"], "kind": "phonetic", "phonetic": "白 (ハク) hints at the sound ヒャク", "parts": [{"glyph": "一", "meaning": "one"}, {"glyph": "白", "meaning": "white"}], "mnemonic": "One (一) over white (白): live to a hundred and everything turns white.", "words": [{"word": "百", "reading": "ひゃく", "meaning": "hundred"}, {"word": "三百", "reading": "さんびゃく", "meaning": "three hundred"}, {"word": "百円", "reading": "ひゃくえん", "meaning": "100 yen"}], "sentence": "このペンは{百円|ひゃくえん}です。", "translation": "This pen is 100 yen.", "usage": "Sounds shift after some numbers: 三百 さんびゃく, 六百 ろっぴゃく, 八百 はっぴゃく."},
    {"glyph": "千", "level": 5, "strokes": 3, "meanings": ["thousand"], "on": ["セン"], "kun": ["ち"], "parts": [{"glyph": "丿", "meaning": "slanted stroke"}, {"glyph": "十", "meaning": "ten"}], "mnemonic": "Ten (十) wearing a slanted cap (丿): ten, multiplied up to a thousand.", "words": [{"word": "千", "reading": "せん", "meaning": "thousand"}, {"word": "三千", "reading": "さんぜん", "meaning": "three thousand"}, {"word": "千円", "reading": "せんえん", "meaning": "1,000 yen"}], "sentence": "{千円|せんえん}{札|さつ}しかありません。", "translation": "I only have a 1,000-yen note.", "usage": "Large numbers are grouped by 万 (10,000), not by thousands: 10,000 is 一万 いちまん."},
    {"glyph": "円", "level": 5, "strokes": 4, "meanings": ["yen", "circle"], "on": ["エン"], "kun": ["まる.い"], "parts": [], "mnemonic": "A shop window frame with a bar across it — the price tag says yen.", "words": [{"word": "円", "reading": "えん", "meaning": "yen; circle"}, {"word": "千円", "reading": "せんえん", "meaning": "1,000 yen"}, {"word": "一万円", "reading": "いちまんえん", "meaning": "10,000 yen"}], "sentence": "このケーキは{五百円|ごひゃくえん}です。", "translation": "This cake is 500 yen.", "usage": "Both ¥ and 円 are read えん. 百円ショップ (100-yen shops) sell almost everything."},
    {"glyph": "日", "level": 5, "strokes": 4, "meanings": ["sun", "day"], "on": ["ニチ", "ジツ"], "kun": ["ひ", "-び", "-か"], "kind": "pictograph", "parts": [], "mnemonic": "The sun, once drawn as a circle with a dot, squared off over time.", "words": [{"word": "日曜日", "reading": "にちようび", "meaning": "Sunday"}, {"word": "毎日", "reading": "まいにち", "meaning": "every day"}, {"word": "今日", "reading": "きょう", "meaning": "today"}], "sentence": "{今日|きょう}は{日曜日|にちようび}です。", "translation": "Today is Sunday.", "usage": "Shop hours often list 日・祝, meaning 'Sundays and holidays'. 今日 is read きょう as a whole word — a special reading."},
    {"glyph": "月", "level": 5, "strokes": 4, "meanings": ["moon", "month"], "on": ["ゲツ", "ガツ"], "kun": ["つき"], "kind": "pictograph", "parts": [], "mnemonic": "A crescent moon with two wisps of cloud drifting across it.", "words": [{"word": "月", "reading": "つき", "meaning": "moon; month"}, {"word": "月曜日", "reading": "げつようび", "meaning": "Monday"}, {"word": "一月", "reading": "いちがつ", "meaning": "January"}], "sentence": "{今夜|こんや}は{月|つき}がきれいですね。", "translation": "The moon is beautiful tonight, isn't it?", "usage": "月がきれいですね is famously — if probably apocryphally — credited to Natsume Sōseki as a subtle way to say 'I love you'."},
    {"glyph": "火", "level": 5, "strokes": 4, "meanings": ["fire"], "on": ["カ"], "kun": ["ひ", "-び", "ほ-"], "kind": "pictograph", "parts": [], "mnemonic": "A campfire: flames leaping up with sparks flying out on both sides.", "words": [{"word": "火", "reading": "ひ", "meaning": "fire"}, {"word": "火曜日", "reading": "かようび", "meaning": "Tuesday"}, {"word": "花火", "reading": "はなび", "meaning": "fireworks"}], "sentence": "{火|ひ}に{気|き}をつけてください。", "translation": "Please be careful with fire.", "usage": "花火 (fireworks, literally 'flower fire') are the highlight of summer festivals."},
    {"glyph": "水", "level": 5, "strokes": 4, "meanings": ["water"], "on": ["スイ"], "kun": ["みず"], "kind": "pictograph", "parts": [], "mnemonic": "A main stream running down the middle with splashes to the left and right.", "words": [{"word": "水", "reading": "みず", "meaning": "water"}, {"word": "水曜日", "reading": "すいようび", "meaning": "Wednesday"}, {"word": "水着", "reading": "みずぎ", "meaning": "swimsuit"}], "sentence": "{水|みず}を{一杯|いっぱい}ください。", "translation": "A glass of water, please.", "usage": "Restaurants bring お水 (water, with the polite お) free of charge."},
    {"glyph": "木", "level": 5, "strokes": 4, "meanings": ["tree", "wood"], "on": ["ボク", "モク"], "kun": ["き", "こ-"], "kind": "pictograph", "parts": [], "mnemonic": "A trunk with branches reaching up and roots spreading below.", "words": [{"word": "木", "reading": "き", "meaning": "tree; wood"}, {"word": "木曜日", "reading": "もくようび", "meaning": "Thursday"}, {"word": "木村", "reading": "きむら", "meaning": "Kimura (surname)"}], "sentence": "{公園|こうえん}に{大|おお}きい{木|き}があります。", "translation": "There's a big tree in the park.", "usage": "木 appears in many surnames: 木村, 鈴木, 佐々木."},
    {"glyph": "金", "level": 5, "strokes": 8, "meanings": ["gold", "money"], "on": ["キン", "コン"], "kun": ["かね", "かな-"], "parts": [{"glyph": "人", "meaning": "roof"}, {"glyph": "王", "meaning": "king"}], "mnemonic": "Under a roof (人), a king (王) guards two glittering nuggets of gold.", "words": [{"word": "お金", "reading": "おかね", "meaning": "money"}, {"word": "金曜日", "reading": "きんようび", "meaning": "Friday"}, {"word": "金", "reading": "きん", "meaning": "gold"}], "sentence": "{金曜日|きんようび}に{友|とも}だちと{会|あ}います。", "translation": "I'm meeting a friend on Friday.", "usage": "In everyday speech money is お金, with the polite prefix お."},
    {"glyph": "土", "level": 5, "strokes": 3, "meanings": ["earth", "soil"], "on": ["ド", "ト"], "kun": ["つち"], "kind": "pictograph", "parts": [], "mnemonic": "A cross planted in a mound — the bottom line is the ground, wider than the top.", "words": [{"word": "土", "reading": "つち", "meaning": "soil; earth"}, {"word": "土曜日", "reading": "どようび", "meaning": "Saturday"}, {"word": "土地", "reading": "とち", "meaning": "land; plot"}], "sentence": "{土曜日|どようび}は{休|やす}みです。", "translation": "Saturday is a day off.", "usage": "Calendars mark the week with one kanji per day: 月 火 水 木 金 土 日 — the moon, five elements and the sun."},
    {"glyph": "年", "level": 5, "strokes": 6, "meanings": ["year"], "on": ["ネン"], "kun": ["とし"], "parts": [], "mnemonic": "A person bent under a sheaf of harvested grain — one harvest, one year.", "words": [{"word": "今年", "reading": "ことし", "meaning": "this year"}, {"word": "来年", "reading": "らいねん", "meaning": "next year"}, {"word": "毎年", "reading": "まいとし/まいねん", "meaning": "every year"}], "sentence": "{来年|らいねん}、{日本|にほん}に{住|す}みたいです。", "translation": "Next year, I want to live in Japan.", "usage": "Japan also counts years by imperial era: 2019 was 令和元年, the first year of Reiwa."},
    {"glyph": "時", "level": 5, "strokes": 10, "meanings": ["time", "hour"], "on": ["ジ"], "kun": ["とき"], "kind": "phonetic", "phonetic": "寺 (ジ) gives the sound ジ", "parts": [{"glyph": "日", "meaning": "sun"}, {"glyph": "寺", "meaning": "temple"}], "mnemonic": "Sun (日) + temple (寺): the temple bell rings by the sun to tell the time.", "words": [{"word": "時間", "reading": "じかん", "meaning": "time; hours"}, {"word": "何時", "reading": "なんじ", "meaning": "what time"}, {"word": "時々", "reading": "ときどき", "meaning": "sometimes"}], "sentence": "{今|いま}、{何時|なんじ}ですか。", "translation": "What time is it now?", "usage": "Watch the irregular hours: 四時 よじ, 七時 しちじ, 九時 くじ."},
    {"glyph": "今", "level": 5, "strokes": 4, "meanings": ["now"], "on": ["コン", "キン"], "kun": ["いま"], "parts": [{"glyph": "人", "meaning": "roof"}], "mnemonic": "Someone ducks under a roof (人) right now — the rain has just started.", "words": [{"word": "今", "reading": "いま", "meaning": "now"}, {"word": "今日", "reading": "きょう", "meaning": "today"}, {"word": "今年", "reading": "ことし", "meaning": "this year"}, {"word": "今晩", "reading": "こんばん", "meaning": "this evening"}], "sentence": "{今日|きょう}は{忙|いそが}しいです。", "translation": "I'm busy today.", "usage": "今日 (きょう) and 今年 (ことし) are whole-word readings — learn them as words, not kanji by kanji."},
    {"glyph": "何", "level": 5, "strokes": 7, "meanings": ["what"], "on": ["カ"], "kun": ["なに", "なん"], "kind": "phonetic", "phonetic": "可 (カ) gives the sound カ", "parts": [{"glyph": "亻", "meaning": "person"}, {"glyph": "可", "meaning": "possible"}], "mnemonic": "A person (亻) sees something that might be possible (可) and asks: what?", "words": [{"word": "何", "reading": "なに", "meaning": "what"}, {"word": "何時", "reading": "なんじ", "meaning": "what time"}, {"word": "何人", "reading": "なんにん", "meaning": "how many people"}], "sentence": "これは{何|なん}ですか。", "translation": "What is this?", "usage": "なに becomes なん before d-, n- and t- sounds and before counters: 何ですか, 何時, 何人."},
    {"glyph": "前", "level": 5, "strokes": 9, "meanings": ["front", "before"], "on": ["ゼン"], "kun": ["まえ"], "parts": [{"glyph": "月", "meaning": "flesh"}, {"glyph": "刂", "meaning": "knife"}], "mnemonic": "Antlers on top, then flesh (月) and a knife (刂): the hunter always walks in front.", "words": [{"word": "前", "reading": "まえ", "meaning": "front; before"}, {"word": "午前", "reading": "ごぜん", "meaning": "a.m.; morning"}, {"word": "名前", "reading": "なまえ", "meaning": "name"}], "sentence": "{駅|えき}の{前|まえ}で{待|ま}っています。", "translation": "I'm waiting in front of the station.", "usage": "駅前 ('in front of the station') is the classic meeting spot in every Japanese town."},
    {"glyph": "後", "level": 5, "strokes": 9, "meanings": ["after", "behind", "later"], "on": ["ゴ", "コウ"], "kun": ["のち", "うし.ろ", "あと", "おく.れる"], "parts": [{"glyph": "彳", "meaning": "step"}, {"glyph": "幺", "meaning": "thread"}, {"glyph": "夂", "meaning": "slow feet"}], "mnemonic": "Stepping (彳) with a thread (幺) tangled round slow feet (夂) — you fall behind.", "words": [{"word": "後ろ", "reading": "うしろ", "meaning": "behind; back"}, {"word": "午後", "reading": "ごご", "meaning": "p.m.; afternoon"}, {"word": "後で", "reading": "あとで", "meaning": "later"}], "sentence": "{仕事|しごと}の{後|あと}で{会|あ}いましょう。", "translation": "Let's meet after work.", "usage": "In speech, times use 午前 (a.m.) and 午後 (p.m.); printed timetables usually use the 24-hour clock."},
    {"glyph": "人", "level": 5, "strokes": 2, "meanings": ["person"], "on": ["ジン", "ニン"], "kun": ["ひと"], "kind": "pictograph", "parts": [], "mnemonic": "Two legs mid-stride: a person seen from the side.", "words": [{"word": "人", "reading": "ひと", "meaning": "person"}, {"word": "日本人", "reading": "にほんじん", "meaning": "Japanese person"}, {"word": "三人", "reading": "さんにん", "meaning": "three people"}], "sentence": "あの{人|ひと}は{先生|せんせい}です。", "translation": "That person is a teacher.", "usage": "Nationality is country + 人 (じん): アメリカ人, 日本人. Counting people is number + 人 (にん)."},
    {"glyph": "子", "level": 5, "strokes": 3, "meanings": ["child"], "on": ["シ", "ス"], "kun": ["こ"], "kind": "pictograph", "parts": [], "mnemonic": "A baby swaddled in a blanket, arms stretched out wide (一).", "words": [{"word": "子ども", "reading": "こども", "meaning": "child"}, {"word": "女の子", "reading": "おんなのこ", "meaning": "girl"}, {"word": "男の子", "reading": "おとこのこ", "meaning": "boy"}], "sentence": "{子|こ}どもが{公園|こうえん}で{遊|あそ}んでいます。", "translation": "Children are playing in the park.", "usage": "子 was a classic ending for women's given names of earlier generations: 花子, 洋子."},
    {"glyph": "女", "level": 5, "strokes": 3, "meanings": ["woman", "female"], "on": ["ジョ", "ニョ"], "kun": ["おんな", "め"], "kind": "pictograph", "parts": [], "mnemonic": "A figure kneeling gracefully with arms crossed.", "words": [{"word": "女の人", "reading": "おんなのひと", "meaning": "woman"}, {"word": "女性", "reading": "じょせい", "meaning": "woman (formal)"}, {"word": "女の子", "reading": "おんなのこ", "meaning": "girl"}], "sentence": "{女|おんな}の{人|ひと}が{歌|うた}っています。", "translation": "A woman is singing.", "usage": "Look for 女 on toilet and bath signs. At hot springs, the curtain marked 女湯 is the women's bath."},
    {"glyph": "男", "level": 5, "strokes": 7, "meanings": ["man", "male"], "on": ["ダン", "ナン"], "kun": ["おとこ"], "kind": "compound", "parts": [{"glyph": "田", "meaning": "rice field"}, {"glyph": "力", "meaning": "power"}], "mnemonic": "Power (力) in the rice field (田): the field worker.", "words": [{"word": "男の人", "reading": "おとこのひと", "meaning": "man"}, {"word": "男性", "reading": "だんせい", "meaning": "man (formal)"}, {"word": "男の子", "reading": "おとこのこ", "meaning": "boy"}], "sentence": "{男|おとこ}の{子|こ}が{走|はし}っています。", "translation": "A boy is running.", "usage": "At hot springs, 男湯 is the men's bath. 男性 and 女性 are the polite forms you'll see on forms and signs."},
    {"glyph": "先", "level": 5, "strokes": 6, "meanings": ["ahead", "previous", "tip"], "on": ["セン"], "kun": ["さき"], "kind": "compound", "parts": [{"glyph": "儿", "meaning": "legs"}], "mnemonic": "A foot stepping out ahead of a pair of legs (儿) — the one who went first.", "words": [{"word": "先生", "reading": "せんせい", "meaning": "teacher"}, {"word": "先週", "reading": "せんしゅう", "meaning": "last week"}, {"word": "先", "reading": "さき", "meaning": "ahead; tip"}], "sentence": "{先週|せんしゅう}、{京都|きょうと}へ{行|い}きました。", "translation": "Last week I went to Kyoto.", "usage": "先生 is also the title for doctors, lawyers and politicians. お先に失礼します ('excuse me for leaving first') is said when leaving work before colleagues."},
    {"glyph": "生", "level": 5, "strokes": 5, "meanings": ["life", "birth", "raw"], "on": ["セイ", "ショウ"], "kun": ["い.きる", "う.まれる", "は.える", "なま"], "kind": "pictograph", "parts": [{"glyph": "土", "meaning": "ground"}], "mnemonic": "A sprout pushing up through the ground (土) — life being born.", "words": [{"word": "学生", "reading": "がくせい", "meaning": "student"}, {"word": "先生", "reading": "せんせい", "meaning": "teacher"}, {"word": "生まれる", "reading": "うまれる", "meaning": "to be born"}, {"word": "生", "reading": "なま", "meaning": "raw; draft"}], "sentence": "{私|わたし}は{大学生|だいがくせい}です。", "translation": "I'm a university student.", "usage": "生 has more readings than almost any other kanji, so learn it word by word: 生ビール (なま, draft beer), 一生 (いっしょう, a lifetime)."},
    {"glyph": "学", "level": 5, "strokes": 8, "meanings": ["study", "learning"], "on": ["ガク"], "kun": ["まな.ぶ"], "parts": [{"glyph": "子", "meaning": "child"}], "mnemonic": "A child (子) under a roof with three sparks of knowledge above — the schoolhouse.", "words": [{"word": "学生", "reading": "がくせい", "meaning": "student"}, {"word": "大学", "reading": "だいがく", "meaning": "university"}, {"word": "学校", "reading": "がっこう", "meaning": "school"}], "sentence": "{日本語|にほんご}を{学|まな}んでいます。", "translation": "I'm studying Japanese.", "usage": "In 学校, がく + こう becomes がっこう: the く shrinks to a small っ. You'll see this sound change everywhere."},
    {"glyph": "名", "level": 5, "strokes": 6, "meanings": ["name", "fame"], "on": ["メイ", "ミョウ"], "kun": ["な"], "kind": "compound", "parts": [{"glyph": "夕", "meaning": "evening"}, {"glyph": "口", "meaning": "mouth"}], "mnemonic": "Evening (夕) + mouth (口): in the dark you call out your name so people know who you are.", "words": [{"word": "名前", "reading": "なまえ", "meaning": "name"}, {"word": "有名", "reading": "ゆうめい", "meaning": "famous"}, {"word": "名刺", "reading": "めいし", "meaning": "business card"}], "sentence": "お{名前|なまえ}は{何|なん}ですか。", "translation": "What's your name?", "usage": "Family names come first in Japanese: in 山田太郎, Yamada is the family name. Business cards (名刺) are offered and received with both hands."},
    {"glyph": "友", "level": 5, "strokes": 4, "meanings": ["friend"], "on": ["ユウ"], "kun": ["とも"], "kind": "compound", "parts": [{"glyph": "ナ", "meaning": "hand"}, {"glyph": "又", "meaning": "hand"}], "mnemonic": "Two hands (ナ and 又) reaching for each other — friends.", "words": [{"word": "友だち", "reading": "ともだち", "meaning": "friend"}, {"word": "友人", "reading": "ゆうじん", "meaning": "friend (formal)"}, {"word": "親友", "reading": "しんゆう", "meaning": "best friend"}], "sentence": "{友|とも}だちと{映画|えいが}を{見|み}ました。", "translation": "I watched a film with a friend.", "usage": "友だち is everyday; 友人 sounds formal and appears in writing and speeches. Same meaning, different register."},
    {"glyph": "上", "level": 5, "strokes": 3, "meanings": ["up", "above"], "on": ["ジョウ"], "kun": ["うえ", "あ.げる", "あ.がる", "のぼ.る"], "kind": "indicative", "parts": [], "mnemonic": "A line rising up from the ground line.", "words": [{"word": "上", "reading": "うえ", "meaning": "above; top"}, {"word": "上手", "reading": "じょうず", "meaning": "skilful"}, {"word": "上がる", "reading": "あがる", "meaning": "to go up"}], "sentence": "{机|つくえ}の{上|うえ}に{本|ほん}があります。", "translation": "There's a book on the desk.", "usage": "Learners hear 日本語が上手ですね a lot. The modest reply is いいえ、まだまだです ('no, I still have a long way to go')."},
    {"glyph": "下", "level": 5, "strokes": 3, "meanings": ["down", "below"], "on": ["カ", "ゲ"], "kun": ["した", "さ.げる", "くだ.さる", "お.りる"], "kind": "indicative", "parts": [], "mnemonic": "A line hanging down from the ceiling line.", "words": [{"word": "下", "reading": "した", "meaning": "below; under"}, {"word": "地下鉄", "reading": "ちかてつ", "meaning": "subway"}, {"word": "下手", "reading": "へた", "meaning": "unskilful"}], "sentence": "{椅子|いす}の{下|した}に{猫|ねこ}がいます。", "translation": "There's a cat under the chair.", "usage": "On railways, 上り trains run toward Tokyo or the main city, and 下り trains run away from it."},
    {"glyph": "中", "level": 5, "strokes": 4, "meanings": ["middle", "inside"], "on": ["チュウ"], "kun": ["なか"], "kind": "indicative", "parts": [{"glyph": "口", "meaning": "box"}], "mnemonic": "A box (口) pierced straight through the middle.", "words": [{"word": "中", "reading": "なか", "meaning": "inside; middle"}, {"word": "中国", "reading": "ちゅうごく", "meaning": "China"}, {"word": "一日中", "reading": "いちにちじゅう", "meaning": "all day long"}], "sentence": "かばんの{中|なか}に{何|なに}がありますか。", "translation": "What's in the bag?", "usage": "Shop signs: 営業中 means 'open', 準備中 means 'getting ready' (closed). Here 中 means 'in the middle of'."},
    {"glyph": "大", "level": 5, "strokes": 3, "meanings": ["big", "large"], "on": ["ダイ", "タイ"], "kun": ["おお.きい"], "kind": "pictograph", "parts": [], "mnemonic": "A person stretching their arms wide: 'it was THIS big!'", "words": [{"word": "大きい", "reading": "おおきい", "meaning": "big"}, {"word": "大学", "reading": "だいがく", "meaning": "university"}, {"word": "大人", "reading": "おとな", "meaning": "adult"}], "sentence": "{大|おお}きい{家|いえ}ですね。", "translation": "What a big house.", "usage": "Menus often offer 大盛り (おおもり), a large serving, next to the regular size."},
    {"glyph": "小", "level": 5, "strokes": 3, "meanings": ["small", "little"], "on": ["ショウ"], "kun": ["ちい.さい", "こ-", "お-"], "parts": [], "mnemonic": "One tiny stroke in the middle with two little drops beside it.", "words": [{"word": "小さい", "reading": "ちいさい", "meaning": "small"}, {"word": "小学校", "reading": "しょうがっこう", "meaning": "elementary school"}, {"word": "小川", "reading": "おがわ", "meaning": "stream; brook"}], "sentence": "{小|ちい}さい{犬|いぬ}が{好|す}きです。", "translation": "I like small dogs.", "usage": "As a prefix, 小 can mean small or slight: 小雨 (こさめ) is a light drizzle."},
    {"glyph": "右", "level": 5, "strokes": 5, "meanings": ["right"], "on": ["ウ", "ユウ"], "kun": ["みぎ"], "parts": [{"glyph": "ナ", "meaning": "hand"}, {"glyph": "口", "meaning": "mouth"}], "mnemonic": "A hand (ナ) bringing food to the mouth (口) — most people eat with their right hand.", "words": [{"word": "右", "reading": "みぎ", "meaning": "right"}, {"word": "右手", "reading": "みぎて", "meaning": "right hand"}, {"word": "右側", "reading": "みぎがわ", "meaning": "right side"}], "sentence": "{次|つぎ}の{角|かど}を{右|みぎ}に{曲|ま}がってください。", "translation": "Please turn right at the next corner.", "usage": "In Tokyo, people stand on the left of escalators; in Osaka, on the right."},
    {"glyph": "左", "level": 5, "strokes": 5, "meanings": ["left"], "on": ["サ"], "kun": ["ひだり"], "parts": [{"glyph": "ナ", "meaning": "hand"}, {"glyph": "工", "meaning": "tool"}], "mnemonic": "A hand (ナ) steadying a tool (工) — the left hand holds while the right one works.", "words": [{"word": "左", "reading": "ひだり", "meaning": "left"}, {"word": "左手", "reading": "ひだりて", "meaning": "left hand"}, {"word": "左側", "reading": "ひだりがわ", "meaning": "left side"}], "sentence": "{左|ひだり}に{銀行|ぎんこう}があります。", "translation": "There's a bank on the left.", "usage": "Cars drive on the left in Japan, so look right first when you cross the road."},
    {"glyph": "山", "level": 5, "strokes": 3, "meanings": ["mountain"], "on": ["サン"], "kun": ["やま"], "kind": "pictograph", "parts": [], "mnemonic": "Three peaks, the middle one the tallest.", "words": [{"word": "山", "reading": "やま", "meaning": "mountain"}, {"word": "富士山", "reading": "ふじさん", "meaning": "Mt. Fuji"}, {"word": "山田", "reading": "やまだ", "meaning": "Yamada (surname)"}], "sentence": "{富士山|ふじさん}に{登|のぼ}りたいです。", "translation": "I want to climb Mt. Fuji.", "usage": "Mountain names use the on'yomi: 富士山 is ふじさん, never 'Fuji-yama'."},
    {"glyph": "川", "level": 5, "strokes": 3, "meanings": ["river"], "on": ["セン"], "kun": ["かわ"], "kind": "pictograph", "parts": [], "mnemonic": "Three streams of water flowing down side by side.", "words": [{"word": "川", "reading": "かわ", "meaning": "river"}, {"word": "小川", "reading": "おがわ", "meaning": "stream; brook"}, {"word": "川口", "reading": "かわぐち", "meaning": "river mouth; Kawaguchi"}], "sentence": "{川|かわ}で{泳|およ}ぎました。", "translation": "I swam in the river.", "usage": "After another word, かわ often softens to がわ: 小川 おがわ, 品川 しながわ."},
    {"glyph": "天", "level": 5, "strokes": 4, "meanings": ["heaven", "sky"], "on": ["テン"], "kun": ["あめ", "あま"], "parts": [{"glyph": "一", "meaning": "line above"}, {"glyph": "大", "meaning": "big person"}], "mnemonic": "A line (一) above a big person (大): what's above your head is the sky.", "words": [{"word": "天気", "reading": "てんき", "meaning": "weather"}, {"word": "天国", "reading": "てんごく", "meaning": "heaven; paradise"}, {"word": "天ぷら", "reading": "てんぷら", "meaning": "tempura"}], "sentence": "{明日|あした}の{天気|てんき}はどうですか。", "translation": "What's the weather like tomorrow?", "usage": "天気予報 (てんきよほう), the weather forecast, is a fixture of morning TV."},
    {"glyph": "気", "level": 5, "strokes": 6, "meanings": ["spirit", "air", "mood"], "on": ["キ", "ケ"], "kun": [], "parts": [{"glyph": "气", "meaning": "steam"}, {"glyph": "メ", "meaning": "cross"}], "mnemonic": "Steam (气) rising with a swirl (メ) inside: energy, spirit, the air around you.", "words": [{"word": "天気", "reading": "てんき", "meaning": "weather"}, {"word": "元気", "reading": "げんき", "meaning": "healthy; energetic"}, {"word": "気持ち", "reading": "きもち", "meaning": "feeling"}], "sentence": "お{元気|げんき}ですか。", "translation": "How have you been?", "usage": "お元気ですか is for someone you haven't seen in a while — it isn't a daily 'how are you'."},
    {"glyph": "雨", "level": 5, "strokes": 8, "meanings": ["rain"], "on": ["ウ"], "kun": ["あめ", "あま-"], "kind": "pictograph", "parts": [], "mnemonic": "Four raindrops falling from a cloud that hangs under the sky line.", "words": [{"word": "雨", "reading": "あめ", "meaning": "rain"}, {"word": "大雨", "reading": "おおあめ", "meaning": "heavy rain"}, {"word": "雨水", "reading": "あまみず", "meaning": "rainwater"}], "sentence": "{雨|あめ}が{降|ふ}っています。", "translation": "It's raining.", "usage": "梅雨 (つゆ), the rainy season, soaks most of Japan in June and July."},
    {"glyph": "本", "level": 5, "strokes": 5, "meanings": ["book", "origin", "main"], "on": ["ホン"], "kun": ["もと"], "kind": "indicative", "parts": [{"glyph": "木", "meaning": "tree"}, {"glyph": "一", "meaning": "line at the root"}], "mnemonic": "A tree (木) with a line marking its root: the origin — and books are the root of knowledge.", "words": [{"word": "本", "reading": "ほん", "meaning": "book"}, {"word": "日本", "reading": "にほん/にっぽん", "meaning": "Japan"}, {"word": "三本", "reading": "さんぼん", "meaning": "three (long, thin things)"}], "sentence": "{毎晩|まいばん}、{本|ほん}を{読|よ}みます。", "translation": "I read every night.", "usage": "本 also counts long, thin things — pens, bottles, trains: 一本 いっぽん, 二本 にほん, 三本 さんぼん."},
    {"glyph": "休", "level": 5, "strokes": 6, "meanings": ["rest", "day off"], "on": ["キュウ"], "kun": ["やす.む"], "kind": "compound", "parts": [{"glyph": "亻", "meaning": "person"}, {"glyph": "木", "meaning": "tree"}], "mnemonic": "A person (亻) leaning against a tree (木): taking a rest.", "words": [{"word": "休む", "reading": "やすむ", "meaning": "to rest; to take time off"}, {"word": "休み", "reading": "やすみ", "meaning": "holiday; break"}, {"word": "夏休み", "reading": "なつやすみ", "meaning": "summer vacation"}], "sentence": "{少|すこ}し{休|やす}みましょう。", "translation": "Let's take a short break.", "usage": "Shop signs: 定休日 is the regular closing day; 本日休業 means 'closed today'."},
    {"glyph": "見", "level": 5, "strokes": 7, "meanings": ["see", "look"], "on": ["ケン"], "kun": ["み.る", "み.える", "み.せる"], "kind": "compound", "parts": [{"glyph": "目", "meaning": "eye"}, {"glyph": "儿", "meaning": "legs"}], "mnemonic": "An eye (目) on legs (儿), walking around to see everything.", "words": [{"word": "見る", "reading": "みる", "meaning": "to see; to watch"}, {"word": "見せる", "reading": "みせる", "meaning": "to show"}, {"word": "花見", "reading": "はなみ", "meaning": "cherry-blossom viewing"}], "sentence": "{窓|まど}から{海|うみ}が{見|み}えます。", "translation": "You can see the sea from the window.", "usage": "In shops, 見せてください ('please show me') is how you ask to look at an item."},
    {"glyph": "行", "level": 5, "strokes": 6, "meanings": ["go", "conduct"], "on": ["コウ", "ギョウ"], "kun": ["い.く", "ゆ.く", "おこな.う"], "kind": "pictograph", "parts": [{"glyph": "彳", "meaning": "step"}], "mnemonic": "A crossroads seen from above: which way will you go?", "words": [{"word": "行く", "reading": "いく", "meaning": "to go"}, {"word": "銀行", "reading": "ぎんこう", "meaning": "bank"}, {"word": "旅行", "reading": "りょこう", "meaning": "trip; travel"}], "sentence": "{明日|あした}、{銀行|ぎんこう}に{行|い}きます。", "translation": "I'm going to the bank tomorrow.", "usage": "On train displays, 東京行 means 'bound for Tokyo'."},
    {"glyph": "来", "level": 5, "strokes": 7, "meanings": ["come", "next"], "on": ["ライ"], "kun": ["く.る", "きた.る"], "kind": "borrowed", "parts": [{"glyph": "木", "meaning": "tree"}], "mnemonic": "A tree (木) with a crossbar: once a drawing of wheat, a crop that came from far away.", "words": [{"word": "来る", "reading": "くる", "meaning": "to come"}, {"word": "来年", "reading": "らいねん", "meaning": "next year"}, {"word": "来週", "reading": "らいしゅう", "meaning": "next week"}], "sentence": "{友|とも}だちが{家|いえ}に{来|き}ました。", "translation": "A friend came over to my place.", "usage": "来る is irregular: 来ます (きます), 来ない (こない), 来て (きて)."},
    {"glyph": "食", "level": 5, "strokes": 9, "meanings": ["eat", "food"], "on": ["ショク"], "kun": ["た.べる", "く.う"], "parts": [{"glyph": "人", "meaning": "lid"}, {"glyph": "良", "meaning": "good"}], "mnemonic": "A lid (人) over something good (良): a covered dish of good food.", "words": [{"word": "食べる", "reading": "たべる", "meaning": "to eat"}, {"word": "食べ物", "reading": "たべもの", "meaning": "food"}, {"word": "食堂", "reading": "しょくどう", "meaning": "cafeteria; dining hall"}], "sentence": "{朝|あさ}ご{飯|はん}を{食|た}べましたか。", "translation": "Did you have breakfast?", "usage": "Say いただきます before eating and ごちそうさまでした afterwards — both are expected at the table."},
    {"glyph": "話", "level": 5, "strokes": 13, "meanings": ["talk", "story"], "on": ["ワ"], "kun": ["はな.す", "はなし"], "parts": [{"glyph": "言", "meaning": "words"}, {"glyph": "舌", "meaning": "tongue"}], "mnemonic": "Words (言) + tongue (舌): talking.", "words": [{"word": "話す", "reading": "はなす", "meaning": "to speak; to talk"}, {"word": "電話", "reading": "でんわ", "meaning": "telephone"}, {"word": "話", "reading": "はなし", "meaning": "talk; story"}], "sentence": "{母|はは}と{電話|でんわ}で{話|はな}しました。", "translation": "I talked with my mother on the phone.", "usage": "Casual calls open with もしもし. In business calls you give your company and name first."},
    {"glyph": "語", "level": 5, "strokes": 14, "meanings": ["language", "word"], "on": ["ゴ"], "kun": ["かた.る"], "kind": "phonetic", "phonetic": "吾 (ゴ) gives the sound ゴ", "parts": [{"glyph": "言", "meaning": "words"}, {"glyph": "吾", "meaning": "I, me"}], "mnemonic": "Words (言) + I (吾): the words I speak — my language.", "words": [{"word": "日本語", "reading": "にほんご", "meaning": "Japanese (language)"}, {"word": "英語", "reading": "えいご", "meaning": "English"}, {"word": "物語", "reading": "ものがたり", "meaning": "tale; story"}], "sentence": "{英語|えいご}と{日本語|にほんご}が{話|はな}せます。", "translation": "I can speak English and Japanese.", "usage": "Country + 語 gives its language: 中国語, 韓国語. English is 英語, from 英 for England."},
    {"glyph": "読", "level": 5, "strokes": 14, "meanings": ["read"], "on": ["ドク", "トク"], "kun": ["よ.む"], "kind": "phonetic", "parts": [{"glyph": "言", "meaning": "words"}, {"glyph": "売", "meaning": "sell"}], "mnemonic": "Words (言) + sell (売): a news-seller reading the headlines aloud.", "words": [{"word": "読む", "reading": "よむ", "meaning": "to read"}, {"word": "読書", "reading": "どくしょ", "meaning": "reading (books)"}, {"word": "読み方", "reading": "よみかた", "meaning": "way of reading"}], "sentence": "{新聞|しんぶん}を{読|よ}みますか。", "translation": "Do you read the newspaper?", "usage": "読み方 is the word to use when you ask how a kanji is read: この漢字の読み方は？"},
    {"glyph": "校", "level": 5, "strokes": 10, "meanings": ["school"], "on": ["コウ"], "kun": [], "kind": "phonetic", "phonetic": "交 (コウ) gives the sound コウ", "parts": [{"glyph": "木", "meaning": "tree"}, {"glyph": "交", "meaning": "mix"}], "mnemonic": "Tree (木) + mix (交): children mixing together under the trees of the schoolyard.", "words": [{"word": "学校", "reading": "がっこう", "meaning": "school"}, {"word": "高校", "reading": "こうこう", "meaning": "high school"}, {"word": "校長", "reading": "こうちょう", "meaning": "principal"}], "sentence": "{学校|がっこう}は{八時半|はちじはん}に{始|はじ}まります。", "translation": "School starts at half past eight.", "usage": "The Japanese school year begins in April, under the cherry blossoms."},
    {"glyph": "車", "level": 5, "strokes": 7, "meanings": ["car", "vehicle"], "on": ["シャ"], "kun": ["くるま"], "kind": "pictograph", "parts": [], "mnemonic": "A cart seen from above: an axle through the middle with a wheel at each end.", "words": [{"word": "車", "reading": "くるま", "meaning": "car"}, {"word": "電車", "reading": "でんしゃ", "meaning": "train"}, {"word": "自転車", "reading": "じてんしゃ", "meaning": "bicycle"}], "sentence": "{車|くるま}で{会社|かいしゃ}に{行|い}きます。", "translation": "I drive to work.", "usage": "車 on its own means a car; trains are 電車, 'electric vehicles'."},
    {"glyph": "電", "level": 5, "strokes": 13, "meanings": ["electricity"], "on": ["デン"], "kun": [], "parts": [{"glyph": "雨", "meaning": "rain"}], "mnemonic": "Under the rain clouds (雨), a lightning bolt with a hooked tail strikes: electricity.", "words": [{"word": "電車", "reading": "でんしゃ", "meaning": "train"}, {"word": "電話", "reading": "でんわ", "meaning": "telephone"}, {"word": "電気", "reading": "でんき", "meaning": "electricity; light"}], "sentence": "{電車|でんしゃ}が{来|き}ました。", "translation": "The train is here.", "usage": "電 means electricity in nearly every word — 'turn off the light' is 電気を消して."},
    {"glyph": "田", "level": 4, "strokes": 5, "meanings": ["rice field"], "on": ["デン"], "kun": ["た"], "kind": "pictograph", "parts": [], "mnemonic": "A rice field divided into four neat plots.", "words": [{"word": "田んぼ", "reading": "たんぼ", "meaning": "rice paddy"}, {"word": "田中", "reading": "たなか", "meaning": "Tanaka (surname)"}, {"word": "山田", "reading": "やまだ", "meaning": "Yamada (surname)"}], "sentence": "{田中|たなか}さんは{田|た}んぼで{働|はたら}いています。", "translation": "Tanaka-san works in the rice paddies.", "usage": "Rice paddies shaped many surnames: 田中 ('in the fields'), 山田 ('mountain field')."},
    {"glyph": "春", "level": 4, "strokes": 9, "meanings": ["spring"], "on": ["シュン"], "kun": ["はる"], "parts": [{"glyph": "日", "meaning": "sun"}], "mnemonic": "Three tiers of new growth and a person stretching under the sun (日): spring.", "words": [{"word": "春", "reading": "はる", "meaning": "spring"}, {"word": "春休み", "reading": "はるやすみ", "meaning": "spring break"}, {"word": "青春", "reading": "せいしゅん", "meaning": "youth"}], "sentence": "{春|はる}になると、{桜|さくら}が{咲|さ}きます。", "translation": "When spring comes, the cherry blossoms bloom.", "usage": "The school and business year starts in April, so spring means fresh starts."},
    {"glyph": "夏", "level": 4, "strokes": 10, "meanings": ["summer"], "on": ["カ", "ゲ"], "kun": ["なつ"], "parts": [{"glyph": "夂", "meaning": "slow feet"}], "mnemonic": "A heavy head on top, slow dragging feet (夂) below: too hot to hurry in summer.", "words": [{"word": "夏", "reading": "なつ", "meaning": "summer"}, {"word": "夏休み", "reading": "なつやすみ", "meaning": "summer vacation"}, {"word": "真夏", "reading": "まなつ", "meaning": "midsummer"}], "sentence": "{夏休|なつやす}みに{海|うみ}へ{行|い}きました。", "translation": "I went to the beach during the summer holidays.", "usage": "Summer is festival (祭り) season: yukata, fireworks and street food."},
    {"glyph": "秋", "level": 4, "strokes": 9, "meanings": ["autumn"], "on": ["シュウ"], "kun": ["あき"], "parts": [{"glyph": "禾", "meaning": "grain"}, {"glyph": "火", "meaning": "fire"}], "mnemonic": "Grain (禾) + fire (火): fields are harvested and the stubble is burned — autumn.", "words": [{"word": "秋", "reading": "あき", "meaning": "autumn"}, {"word": "秋分", "reading": "しゅうぶん", "meaning": "autumn equinox"}, {"word": "秋田", "reading": "あきた", "meaning": "Akita (prefecture)"}], "sentence": "{秋|あき}は{食|た}べ{物|もの}がおいしいです。", "translation": "Food tastes great in autumn.", "usage": "Autumn is called 食欲の秋, 'the season of appetite', for its harvest foods."},
    {"glyph": "冬", "level": 4, "strokes": 5, "meanings": ["winter"], "on": ["トウ"], "kun": ["ふゆ"], "parts": [{"glyph": "夂", "meaning": "slow feet"}], "mnemonic": "Slow feet (夂) shuffling over two flakes of ice: winter.", "words": [{"word": "冬", "reading": "ふゆ", "meaning": "winter"}, {"word": "冬休み", "reading": "ふゆやすみ", "meaning": "winter break"}, {"word": "真冬", "reading": "まふゆ", "meaning": "midwinter"}], "sentence": "{冬|ふゆ}は{雪|ゆき}が{降|ふ}ります。", "translation": "It snows in winter.", "usage": "In winter, families gather around a こたつ — a low heated table covered with a quilt."}
  ],
  "passages": [
    {"id": "station", "title": "{駅|えき}で", "titleEN": "At the station", "genre": "Signs & announcements", "topic": "Getting around", "level": 5, "lines": [{"jp": "{東京|とうきょう}{行|ゆ}き　{九時|くじ}{十分|じゅっぷん}{発|はつ}", "en": "Bound for Tokyo — departs 9:10"}, {"jp": "まもなく、{一番線|いちばんせん}に{電車|でんしゃ}が{参|まい}ります。", "en": "A train will shortly arrive at platform 1."}, {"jp": "{黄色|きいろ}い{線|せん}の{内側|うちがわ}までお{下|さ}がりください。", "en": "Please stand behind the yellow line."}, {"jp": "{電車|でんしゃ}の{中|なか}では、{電話|でんわ}はご{遠慮|えんりょ}ください。", "en": "Please refrain from phone calls on the train."}, {"jp": "{出口|でぐち}は{左|ひだり}です。", "en": "The exit is on the left."}], "notes": [{"lens": "Discourse", "text": "Signs drop verbs and particles: 東京行き 九時十分発 is just two noun phrases. Public signage favors this compact style."}, {"lens": "Register", "text": "Announcements use keigo: 参ります (humble 'comes'), お下がりください, ご遠慮ください ('kindly refrain'). You'll rarely say these yourself, but you'll hear them every day."}, {"lens": "Culture", "text": "Talking on the phone in trains is considered rude in Japan. People switch to マナーモード (silent mode) and text instead."}], "question": {"prompt": "What are passengers asked not to do on the train?", "options": ["Eat snacks", "Talk on the phone", "Stand near the doors"], "answer": 1, "explanation": "電話はご遠慮ください means 'please refrain from phone calls'."}},
    {"id": "seasons", "title": "{日本|にほん}の{四季|しき}", "titleEN": "Japan's four seasons", "genre": "Explanation", "topic": "Nature & culture", "level": 4, "lines": [{"jp": "{日本|にほん}には{春|はる}、{夏|なつ}、{秋|あき}、{冬|ふゆ}の{四|よっ}つの{季節|きせつ}があります。", "en": "Japan has four seasons: spring, summer, autumn and winter."}, {"jp": "{春|はる}は{桜|さくら}の{下|した}で{花見|はなみ}をします。", "en": "In spring, people hold flower-viewing parties under the cherry trees."}, {"jp": "{夏|なつ}は{暑|あつ}くて、{雨|あめ}もたくさん{降|ふ}ります。", "en": "Summer is hot, and it rains a lot too."}, {"jp": "{秋|あき}になると、{山|やま}の{木|き}が{赤|あか}くなります。", "en": "When autumn comes, the trees on the mountains turn red."}, {"jp": "{冬|ふゆ}は{寒|さむ}いですが、{雪|ゆき}の{山|やま}はとてもきれいです。", "en": "Winter is cold, but the snowy mountains are beautiful."}], "notes": [{"lens": "Culture", "text": "Seasonal awareness (季節感) runs through Japanese life: food, greetings and even business letters open with a nod to the season."}, {"lens": "Discourse", "text": "Each sentence opens with a season + は. Repeating the same topic frame is a simple way a Japanese paragraph signals a list."}, {"lens": "Word building", "text": "New words are built from kanji you know: 花 (flower) + 見 (see) = 花見, 'flower viewing'."}], "question": {"prompt": "What happens to the mountain trees in autumn?", "options": ["They blossom", "They turn red", "They are covered in snow"], "answer": 1, "explanation": "山の木が赤くなります: 'the mountain trees turn red'."}},
    {"id": "restaurant", "title": "レストランで", "titleEN": "At a restaurant", "genre": "Dialogue", "topic": "Food & service", "level": 5, "lines": [{"speaker": "{店員|てんいん}", "jp": "いらっしゃいませ。{何名様|なんめいさま}ですか。", "en": "Welcome! How many in your party?"}, {"speaker": "{客|きゃく}", "jp": "{二人|ふたり}です。", "en": "Two."}, {"speaker": "{店員|てんいん}", "jp": "こちらへどうぞ。", "en": "This way, please."}, {"speaker": "{客|きゃく}", "jp": "すみません、お{水|みず}をください。", "en": "Excuse me, could we have some water?"}, {"speaker": "{店員|てんいん}", "jp": "はい、{少々|しょうしょう}お{待|ま}ちください。", "en": "Certainly — one moment, please."}, {"speaker": "{客|きゃく}", "jp": "ごちそうさまでした。", "en": "Thank you for the meal."}], "notes": [{"lens": "Conversation", "text": "いらっしゃいませ is a greeting that expects no reply — a small nod is enough. A question like 何名様ですか opens an adjacency pair: the answer comes right away, usually short (二人です)."}, {"lens": "Register", "text": "Staff speak in keigo (何名様, 少々お待ちください) while customers use plain polite です/ください. The asymmetry is normal in Japanese service encounters."}, {"lens": "Culture", "text": "There's no tipping in Japan. Saying ごちそうさまでした as you leave is the thanks."}], "question": {"prompt": "How many people are in the customer's group?", "options": ["One", "Two", "Three"], "answer": 1, "explanation": "二人です: 'two people'. 二人 is read ふたり."}},
    {"id": "diary", "title": "{日記|にっき}", "titleEN": "A diary entry", "genre": "Diary", "topic": "Daily life", "level": 5, "lines": [{"jp": "{十月|じゅうがつ}{五日|いつか}　{雨|あめ}", "en": "October 5th — rain"}, {"jp": "{今日|きょう}は{学校|がっこう}が{休|やす}みだった。", "en": "There was no school today."}, {"jp": "{朝|あさ}、{友|とも}だちと{電話|でんわ}で{話|はな}した。", "en": "In the morning, I talked to a friend on the phone."}, {"jp": "{午後|ごご}は{本|ほん}を{読|よ}んで、{日本|にほん}の{映画|えいが}を{見|み}た。", "en": "In the afternoon, I read a book and watched a Japanese film."}, {"jp": "{明日|あした}は{山田|やまだ}{先生|せんせい}の{授業|じゅぎょう}だ。{早|はや}く{寝|ね}よう。", "en": "Tomorrow is Professor Yamada's class. I'll get to bed early."}], "notes": [{"lens": "Register", "text": "Diaries use the plain form (だった, 話した, 見た). With no listener to be polite to, です/ます would sound oddly formal."}, {"lens": "Discourse", "text": "Dates are month + day. Days 1–10 use native readings: 五日 is いつか, not ごにち."}, {"lens": "Culture", "text": "Teachers are addressed as surname + 先生 — never by their first name, even outside class."}], "question": {"prompt": "What did the writer do in the afternoon?", "options": ["Went to school", "Read a book and watched a film", "Met a friend"], "answer": 1, "explanation": "午後は本を読んで、日本の映画を見た。"}},
    {"id": "email", "title": "{先生|せんせい}へのメール", "titleEN": "An email to a teacher", "genre": "Email", "topic": "School life", "level": 5, "lines": [{"jp": "{山田|やまだ}{先生|せんせい}", "en": "Professor Yamada,"}, {"jp": "いつもお{世話|せわ}になっております。{一年|いちねん}のキムです。", "en": "Thank you, as always, for your guidance. This is Kim, first year."}, {"jp": "{熱|ねつ}があるので、{明日|あした}は{学校|がっこう}を{休|やす}みます。", "en": "I have a fever, so I'll be absent from school tomorrow."}, {"jp": "{申|もう}し{訳|わけ}ありません。", "en": "I'm very sorry."}, {"jp": "よろしくお{願|ねが}いします。", "en": "Thank you for your understanding."}], "notes": [{"lens": "Register", "text": "Formal emails open with a set phrase (いつもお世話になっております) and close with よろしくお願いします. Leaving them out sounds abrupt rather than efficient."}, {"lens": "Intercultural", "text": "Apologizing for an absence — even with a good reason — maintains the relationship. It isn't an admission of fault."}, {"lens": "Discourse", "text": "The structure is fixed: name → greeting → who you are → reason → apology → closing. Learn the frame once and you can write many emails."}], "question": {"prompt": "Why will Kim miss school tomorrow?", "options": ["A fever", "A part-time job", "The rain"], "answer": 0, "explanation": "熱があるので: 'because I have a fever'."}}
  ],
  "confusions": [
    {"glyphs": ["人", "入"], "tip": "人 (person): the left stroke sits on top. 入 (enter): the right stroke sits on top, like an arrow pointing in."},
    {"glyphs": ["大", "犬", "太", "天"], "tip": "大 is big. A dot at the top right makes 犬 (dog); a dot at the bottom makes 太 (thick); a line on top makes 天 (sky)."},
    {"glyphs": ["日", "目", "白", "田"], "tip": "日 has one inner line, 目 (eye) has two, 白 (white) adds a tick on top, and 田 (field) is split into four."},
    {"glyphs": ["土", "士"], "tip": "土 (earth): the bottom line is longer — the ground is wide. 士 (samurai): the top line is longer."},
    {"glyphs": ["右", "左"], "tip": "Both start with a hand (ナ). 右 has a mouth 口; 左 has a tool 工. Their stroke order differs too: 右 starts with the slanted stroke, 左 with the horizontal one."},
    {"glyphs": ["木", "本", "休", "体"], "tip": "木 is a tree. 本 adds a line at the root. 休 is a person resting against a 木; 体 (body) has 本 instead."},
    {"glyphs": ["十", "千", "干"], "tip": "十 is ten. 千 (thousand) adds a slanted stroke on top; 干 (dry) has a flat line on top instead."},
    {"glyphs": ["見", "貝"], "tip": "見 (see) ends in walking legs 儿; 貝 (shellfish) ends in two short strokes like little feet."},
    {"glyphs": ["話", "語", "読"], "tip": "All three start with 言 (words). The right side tells them apart: 舌 tongue → 話 talk, 吾 → 語 language, 売 → 読 read."},
    {"glyphs": ["学", "字"], "tip": "学 (study) has three short marks on top; 字 (character) has a plain roof 宀."},
    {"glyphs": ["小", "少"], "tip": "小 (small) is three strokes; 少 (few) adds a long sweeping stroke at the bottom."}
  ]
}
"""#
