//
//  ContentView.swift
//  Sumi — kanji, one card at a time.
//
//  Design principle: munkens mat, the monk's meal — serve only what
//  nourishes. Every screen offers one thing to do; scheduling, pacing,
//  catch-up, error analysis, writing unlocks and reminders run out of sight.
//
//  Interaction: study is one full-screen vertical feed with no buttons —
//  tap reveals, swipe up for next, down for back, right for Forgot, left to
//  save, double-tap for Easy, hold for stroke order and sound, pinch to
//  close. Motion uses springs that inherit the finger's velocity; haptics
//  and speech land on the same frame as the visual they belong to. Every
//  gesture also has a keyboard key and a VoiceOver action.
//
//  Look: sumi ink on washi. Cards are sheets of paper with grain, a lit
//  edge and two shadows, stacked in a 2.5D deck that leans with the phone;
//  a slow ink wash drifts behind everything; Liquid Glass is kept for the
//  floating controls. Dark mode is true black.
//
//  Everything lives in this file so it syncs cleanly through Swift
//  Playgrounds and GitHub:
//
//    1. Design system      ink and paper, type, materials, motion, haptics, speech
//    2. Content model      kanji, words, passages, look-alikes (JSON-backed)
//    3. Language helpers   furigana markup, kana and romaji conversion
//    4. Memory model       FSRS-6 scheduler and the study-day clock
//    5. Store              persistence, progress, statistics, import/export
//    6. Sessions           the study queue, combos, undo, context cards
//    7. Screens            Home, the study feed, Library, Settings, onboarding
//    8. Built-in content   the starter pack (with KanjiVG strokes) as JSON
//
//  The research behind each decision is in docs/RESEARCH.md at the root
//  of the repository (next to this Sumi.swiftpm package).
//

import SwiftUI
import CoreHaptics
import CoreMotion
import AVFoundation
import UniformTypeIdentifiers
import UserNotifications
import UIKit

// MARK: - 1. Design system
//
// The look: sumi ink on washi paper. Warm off-white paper by day, true
// black by night. One indigo accent (藍) marks what can be acted on;
// vermilion (朱) only ever means "forgot", matcha only "right". English is
// set in San Francisco — with New York, Apple's serif, for a few display
// lines — and Japanese in Hiragino. Spacing sits on a 4-pt grid and moves
// in steps of 8; corner radii are concentric with the display's.

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
    static let tile: CGFloat = 18
    static let card: CGFloat = 24
    static let sheet: CGFloat = 32
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
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }

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

    /// A see-through color with its own strength in light and dark.
    static func translucent(light: UInt32, lightAlpha: CGFloat, dark: UInt32, darkAlpha: CGFloat) -> Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: dark, alpha: darkAlpha)
            }
            return UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

/// Ink and paper. Text colors are warm greys rather than pure neutrals so
/// they sit in the paper instead of on it; every pair keeps at least 4.5:1
/// contrast for text, and Increase Contrast deepens them further.
enum Palette {
    /// The page: washi by day, true black by night (OLED, and calm).
    static let paper = Color.dynamic(0xF6F3EC, 0x000000, highLight: 0xFFFFFF, highDark: 0x000000)
    /// A sheet lying on the page — cards, tiles, sheets.
    static let card = Color.dynamic(0xFFFEFB, 0x171615, highLight: 0xFFFFFF, highDark: 0x232220)
    /// A quieter surface: wells, fields, the space beneath a pushed card.
    static let surface = Color.dynamic(0xEEEAE1, 0x1D1C1A, highLight: 0xE4DED2, highDark: 0x2B2A27)
    static let sunken = Color.dynamic(0xE8E3D9, 0x0E0E0D, highLight: 0xDCD5C8, highDark: 0x1B1B1A)
    static let hairline = Color.dynamic(0xE1DCD2, 0x2C2B29, highLight: 0xB7B0A3, highDark: 0x4B4946)
    /// The thin edge of a sheet: a shadow line by day, a lit edge by night.
    static let edge = Color.translucent(light: 0x000000, lightAlpha: 0.07, dark: 0xFFFFFF, darkAlpha: 0.09)
    static let ink = Color.dynamic(0x1E1C19, 0xF3F0E9, highLight: 0x000000, highDark: 0xFFFFFF)
    static let ink2 = Color.dynamic(0x67625A, 0xA7A298, highLight: 0x433F38, highDark: 0xD2CDC3)
    static let ink3 = Color.dynamic(0x968F83, 0x716D66, highLight: 0x67625A, highDark: 0x9C978D)
    static let accent = Color.dynamic(0x2D4F9E, 0x93ABEB, highLight: 0x1E3A7A, highDark: 0xB4C6F5)
    static let onAccent = Color.dynamic(0xFFFFFF, 0x0D1530)
    static let shu = Color.dynamic(0xC2412D, 0xF08A74, highLight: 0x9C2E1D, highDark: 0xF6A897)
    static let matcha = Color.dynamic(0x3F7A3A, 0x94C98A, highLight: 0x2C5E28, highDark: 0xB5DDAD)
    static let kohaku = Color.dynamic(0x9A6A0B, 0xE5B65A, highLight: 0x7A5208, highDark: 0xF0CC85)
    static let asagi = Color.dynamic(0x2A7F8F, 0x7CC4D1, highLight: 0x1B6170, highDark: 0xA6DAE3)
    static let murasaki = Color.dynamic(0x6B4E9B, 0xB79BE0, highLight: 0x523780, highDark: 0xCDB8EE)
    static let sakura = Color.dynamic(0xD6336C, 0xF27BA6, highLight: 0xAD1F52, highDark: 0xF7A3C2)
    static let canvas = paper
    /// Light that follows a finger or the pointer across a card.
    static let glow = Color.translucent(light: 0x2D4F9E, lightAlpha: 0.075, dark: 0xFFFFFF, darkAlpha: 0.075)
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

    /// New York, Apple's serif, for the few display lines that set the
    /// tone. It scales with Dynamic Type like any text style.
    static func display(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .serif, weight: weight)
    }

    /// SF Pro Rounded for numbers that are meant to be read at a glance.
    static func figure(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .rounded, weight: weight)
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

    /// Lifts a sheet of paper off the page (see `Elevation`).
    func elevation(_ level: CGFloat = 1) -> some View {
        modifier(Elevation(level: level))
    }
}

/// A small caps caption that names a task without competing with it.
/// Tracking opens up as caps get small, as Apple's own captions do.
struct Caption: View {
    let text: String
    var color: Color = Palette.ink2

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1.1)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

/// Motion in Apple's terms: springs that start from where things are,
/// inherit the finger's velocity, project momentum and resist at the edges.
enum Motion {
    /// Critically damped — for things that simply settle.
    static let settle = Animation.spring(duration: 0.35, bounce: 0)
    /// A touch of overshoot, only after a gesture carried momentum.
    static let flick = Animation.spring(duration: 0.4, bounce: 0.2)
    /// Answers arriving on a reveal.
    static let reveal = Animation.spring(duration: 0.45, bounce: 0.08)

    /// A page turn that continues at the finger's speed. `velocity` is
    /// relative: points per second divided by the distance left to travel.
    static func page(velocity: Double) -> Animation {
        .interpolatingSpring(duration: 0.38, bounce: 0, initialVelocity: velocity)
    }

    /// Apple's rubber-band curve: the further past the edge, the less the
    /// content follows.
    static func rubberband(_ overshoot: CGFloat, dimension: CGFloat, constant: CGFloat = 0.55) -> CGFloat {
        guard dimension > 0 else { return 0 }
        let distance = abs(overshoot)
        let resisted = (distance * dimension * constant) / (dimension + constant * distance)
        return overshoot < 0 ? -resisted : resisted
    }

    /// Where a flick comes to rest (UIScrollView's fast deceleration).
    static func project(_ velocity: CGFloat, decelerationRate: CGFloat = 0.99) -> CGFloat {
        (velocity / 1000) * decelerationRate / (1 - decelerationRate)
    }
}

/// Haptics use the system's documented meanings — selection for "this will
/// commit", impact for things snapping into place, notifications only for
/// real outcomes — plus a few Core Haptics patterns for moments that deserve
/// their own feel: a brush touching paper on every stroke, a heart that
/// pops, two dull knocks for "forgot". All of it can be switched off.
enum Haptics {
    static var enabled = true
    private static var engine: CHHapticEngine?
    private static var player: CHHapticPatternPlayer?
    private static let supportsCustom = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    /// iPad has no Taptic Engine, so Settings hides the switch there.
    static var isSupported: Bool { supportsCustom }

    /// Stops a pattern in progress, such as the stroke taps when a hold ends.
    static func stop() {
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
    }

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func warning() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func tap() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func soft() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func rigid() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7)
    }

    static func medium() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// A value is about to change — the swipe will commit if released now.
    static func tick() {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// A page settling into place — barely there, like a detent.
    static func snap() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.55)
    }

    /// One soft touch at the start of each stroke, in time with the drawing.
    static func strokes(count: Int, interval: TimeInterval) {
        guard count > 0 else { return }
        let events = (0..<count).map { index in
            transient(at: Double(index) * interval, intensity: 0.45, sharpness: 0.2)
        }
        play(events)
    }

    /// The heart: a quick, rising double pop.
    static func heart() {
        play([transient(at: 0, intensity: 0.55, sharpness: 0.45),
              transient(at: 0.09, intensity: 1, sharpness: 0.75)])
    }

    /// Forgot: two low, dull knocks.
    static func forgot() {
        play([transient(at: 0, intensity: 0.75, sharpness: 0.12),
              transient(at: 0.12, intensity: 0.5, sharpness: 0.08)])
    }

    /// Saved: one crisp click.
    static func saved() {
        play([transient(at: 0, intensity: 0.85, sharpness: 0.9)])
    }

    private static func transient(at time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient,
                      parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                                   CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)],
                      relativeTime: time)
    }

    private static func play(_ events: [CHHapticEvent]) {
        guard enabled else { return }
        guard supportsCustom else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        do {
            let engine = try runningEngine()
            let next = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            stop()
            try next.start(atTime: CHHapticTimeImmediate)
            player = next
        } catch {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private static func runningEngine() throws -> CHHapticEngine {
        if let engine = engine {
            try engine.start()
            return engine
        }
        let created = try CHHapticEngine()
        created.playsHapticsOnly = true
        created.isAutoShutdownEnabled = true
        created.resetHandler = {
            try? Haptics.engine?.start()
        }
        try created.start()
        engine = created
        return created
    }
}

/// Japanese speech from the best voice installed — Premium, then Enhanced,
/// then the default — or the voice chosen in Settings. Automatic playback
/// respects the Ring/Silent switch (like video feeds); a deliberate gesture
/// plays even in silent mode (like Dictionary). Callers pass kana so the
/// voice never guesses a kanji reading.
///
/// Only ever used from the main thread, so the unchecked conformance (which
/// the delegate protocol requires) is safe.
final class Speaker: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    static let shared = Speaker()
    /// Identifier of the voice picked in Settings; empty means automatic.
    static var preferredVoiceID = ""
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Installed Japanese voices, best quality first.
    static var japaneseVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "ja-JP" }
            .sorted { lhs, rhs in
                lhs.quality.rawValue == rhs.quality.rawValue
                    ? lhs.name < rhs.name
                    : lhs.quality.rawValue > rhs.quality.rawValue
            }
    }

    static func qualityName(_ quality: AVSpeechSynthesisVoiceQuality) -> String {
        switch quality {
        case .premium: return "Premium"
        case .enhanced: return "Enhanced"
        default: return "Standard"
        }
    }

    private var voice: AVSpeechSynthesisVoice? {
        let voices = Speaker.japaneseVoices
        if !Speaker.preferredVoiceID.isEmpty,
           let chosen = voices.first(where: { $0.identifier == Speaker.preferredVoiceID }) {
            return chosen
        }
        return voices.first ?? AVSpeechSynthesisVoice(language: "ja-JP")
    }

    func say(_ text: String, deliberate: Bool = true) {
        guard !text.isEmpty else { return }
        let session = AVAudioSession.sharedInstance()
        if deliberate {
            try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        } else {
            try? session.setCategory(.ambient, mode: .spokenAudio, options: [.mixWithOthers])
        }
        try? session.setActive(true)
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.preUtteranceDelay = 0
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .word) }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: Materials

extension View {
    /// Liquid Glass on iOS 26; before that, frosted glass — a thin
    /// material with a lit edge and a soft shadow. Only for the floating,
    /// functional layer (chips, pills, controls), never for content.
    @ViewBuilder
    func glassBackground<S: Shape>(_ shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(LiquidGlass.make(tint: tint, interactive: interactive), in: shape)
        } else {
            self.modifier(FrostedGlass(shape: shape, tint: tint))
        }
        #else
        self.modifier(FrostedGlass(shape: shape, tint: tint))
        #endif
    }

    func glassCapsule(tint: Color? = nil) -> some View {
        glassBackground(Capsule(), tint: tint)
    }
}

#if compiler(>=6.2)
@available(iOS 26.0, *)
enum LiquidGlass {
    static func make(tint: Color?, interactive: Bool) -> Glass {
        var glass = Glass.regular
        if let tint = tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return glass
    }
}
#endif

/// Glass before iOS 26. Reduce Transparency makes it solid.
struct FrostedGlass<S: Shape>: ViewModifier {
    let shape: S
    var tint: Color?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let dark = scheme == .dark
        return content
            .background {
                ZStack {
                    if reduceTransparency {
                        shape.fill(Palette.card)
                    } else {
                        shape.fill(.ultraThinMaterial)
                    }
                    if let tint = tint {
                        shape.fill(tint.opacity(0.14))
                    }
                }
            }
            .overlay {
                shape.stroke(LinearGradient(colors: [Color.white.opacity(dark ? 0.22 : 0.75),
                                                     Color.white.opacity(dark ? 0.04 : 0.2)],
                                            startPoint: .top, endPoint: .bottom),
                             lineWidth: 0.75)
                    .allowsHitTesting(false)
            }
            .shadow(color: Color.black.opacity(dark ? 0.35 : 0.07), radius: 14, x: 0, y: 6)
    }
}

/// Two shadows, as real paper has: a tight contact shadow and a wide, soft
/// ambient one. Deeper in dark mode, where shadows need more to read.
struct Elevation: ViewModifier {
    var level: CGFloat = 1
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let dark = scheme == .dark
        let contact: Double = (dark ? 0.5 : 0.05) * Double(level)
        let ambient: Double = (dark ? 0.55 : 0.07) * Double(level)
        return content
            .shadow(color: Color.black.opacity(contact), radius: 1, x: 0, y: 1)
            .shadow(color: Color.black.opacity(ambient), radius: 22 * level, x: 0, y: 10 * level)
    }
}

// MARK: Buttons

/// Buttons answer the moment they're touched: a slight sink and dim, then
/// a spring back on release.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(configuration.isPressed ? Animation.easeOut(duration: 0.08) : Motion.flick,
                       value: configuration.isPressed)
    }
}

/// A quiet capsule on glass for secondary actions; `prominent` fills it
/// with the accent for the one thing that matters on a screen.
struct GlassPillStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        pill(configuration.label)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(configuration.isPressed ? Animation.easeOut(duration: 0.08) : Motion.flick,
                       value: configuration.isPressed)
            .hoverEffect(.highlight)
    }

    @ViewBuilder
    private func pill(_ label: Configuration.Label) -> some View {
        if prominent {
            label
                .font(.headline)
                .foregroundStyle(Palette.onAccent)
                .lineLimit(1)
                .padding(.horizontal, Space.xl)
                .frame(minHeight: Metrics.buttonHeight)
                .background(Palette.accent.gradient, in: Capsule())
                .shadow(color: Palette.accent.opacity(0.3), radius: 12, x: 0, y: 6)
        } else {
            label
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .padding(.horizontal, Space.l)
                .frame(minHeight: Metrics.minTap)
                .glassBackground(Capsule(), interactive: true)
        }
    }
}

/// Settings rows lead with a small colored tile, as in the Settings app.
struct SettingsIcon: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(width: 29, height: 29)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .accessibilityHidden(true)
    }
}

// MARK: Paper and ink

/// A small deterministic random generator (SplitMix64), so textures and
/// ink washes look the same on every launch.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A value in 0..<1.
    mutating func unit() -> Double {
        Double(next() >> 11) / 9_007_199_254_740_992.0
    }
}

/// Washi grain: specks and short fibres, rendered once into a small tile
/// that repeats, so the texture costs nothing to draw.
enum Grain {
    static let forLight: UIImage = make(tone: UIColor.black, strength: 1)
    static let forDark: UIImage = make(tone: UIColor.white, strength: 0.7)

    private static func make(tone: UIColor, strength: CGFloat) -> UIImage {
        let size = CGSize(width: 180, height: 180)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 2
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            var rng = SeededRandom(seed: 0x5EED_CAFE)
            for _ in 0..<1400 {
                let x = CGFloat(rng.unit()) * size.width
                let y = CGFloat(rng.unit()) * size.height
                let side = CGFloat(0.4 + rng.unit() * 0.9)
                let alpha = CGFloat(0.015 + rng.unit() * 0.045) * strength
                tone.withAlphaComponent(alpha).setFill()
                context.fill(CGRect(x: x, y: y, width: side, height: side))
            }
            for _ in 0..<70 {
                let x = CGFloat(rng.unit()) * size.width
                let y = CGFloat(rng.unit()) * size.height
                let angle = CGFloat(rng.unit()) * .pi
                let length = CGFloat(4 + rng.unit() * 10)
                let fibre = UIBezierPath()
                fibre.move(to: CGPoint(x: x, y: y))
                fibre.addQuadCurve(to: CGPoint(x: x + cos(angle) * length, y: y + sin(angle) * length),
                                   controlPoint: CGPoint(x: x + cos(angle + 0.6) * length * 0.5,
                                                         y: y + sin(angle + 0.6) * length * 0.5))
                fibre.lineWidth = 0.35
                tone.withAlphaComponent(CGFloat(0.03 + rng.unit() * 0.04) * strength).setStroke()
                fibre.stroke()
            }
        }
    }
}

/// The grain laid over a surface.
struct PaperGrain: View {
    var strength: Double = 1
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Image(uiImage: scheme == .dark ? Grain.forDark : Grain.forLight)
            .resizable(resizingMode: .tile)
            .opacity(strength)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Ink settling in water: a few soft clouds of indigo and sepia that drift
/// slowly across the paper. A mesh gradient on iOS 18, radial clouds before.
enum InkWash {
    static func points(time: TimeInterval) -> [SIMD2<Float>] {
        let t = Float(time.truncatingRemainder(dividingBy: 3_600))
        let a: Float = sin(t * 0.11) * 0.09
        let b: Float = sin(t * 0.07 + 1.3) * 0.13
        let c: Float = cos(t * 0.09 + 2.1) * 0.11
        let d: Float = sin(t * 0.08 + 4.0) * 0.09
        let e: Float = cos(t * 0.06 + 3.2) * 0.12
        return [
            SIMD2<Float>(0, 0), SIMD2<Float>(0.5 + e * 0.5, 0), SIMD2<Float>(1, 0),
            SIMD2<Float>(0, 0.5 + a), SIMD2<Float>(0.5 + b, 0.5 + c), SIMD2<Float>(1, 0.5 + d),
            SIMD2<Float>(0, 1), SIMD2<Float>(0.5 + e, 1), SIMD2<Float>(1, 1)
        ]
    }

    private static let lightMesh: [Color] = [
        0xF6F3EC, 0xF3EEE5, 0xF6F3EC,
        0xEBEDF3, 0xF1EDE5, 0xF3EADB,
        0xF6F3EC, 0xEDEEF3, 0xF5F1E9
    ].map { (hex: UInt32) in Color(hex: hex) }

    private static let darkMesh: [Color] = [
        0x000000, 0x05060B, 0x000000,
        0x070A16, 0x0B0B0D, 0x0E0A06,
        0x000000, 0x080A14, 0x020202
    ].map { (hex: UInt32) in Color(hex: hex) }

    static func colors(dark: Bool) -> [Color] {
        dark ? darkMesh : lightMesh
    }

    private struct Cloud {
        let x: Double
        let y: Double
        let r: Double
        let hex: UInt32
        let speed: Double
    }

    private static let lightClouds: [Cloud] = [
        Cloud(x: 0.2, y: 0.3, r: 0.7, hex: 0xE6E9F2, speed: 0.07),
        Cloud(x: 0.85, y: 0.65, r: 0.6, hex: 0xF1E6D4, speed: 0.05),
        Cloud(x: 0.4, y: 0.9, r: 0.55, hex: 0xE9EBF2, speed: 0.06)
    ]

    private static let darkClouds: [Cloud] = [
        Cloud(x: 0.2, y: 0.3, r: 0.7, hex: 0x0A0E1E, speed: 0.07),
        Cloud(x: 0.85, y: 0.65, r: 0.6, hex: 0x140E07, speed: 0.05),
        Cloud(x: 0.4, y: 0.9, r: 0.55, hex: 0x0A0C18, speed: 0.06)
    ]

    static func drawClouds(_ context: inout GraphicsContext, size: CGSize, time: TimeInterval, dark: Bool) {
        let t = time.truncatingRemainder(dividingBy: 3_600)
        let clouds = dark ? darkClouds : lightClouds
        for (index, cloud) in clouds.enumerated() {
            let phase = Double(index) * 1.7
            let cx = (cloud.x + sin(t * cloud.speed + phase) * 0.08) * Double(size.width)
            let cy = (cloud.y + cos(t * cloud.speed * 0.8 + phase) * 0.06) * Double(size.height)
            let radius = cloud.r * Double(max(size.width, size.height))
            let center = CGPoint(x: cx, y: cy)
            let rect = CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)
            let color = Color(hex: cloud.hex)
            context.fill(Path(ellipseIn: rect),
                         with: .radialGradient(Gradient(colors: [color, color.opacity(0)]),
                                               center: center, startRadius: 0, endRadius: CGFloat(radius)))
        }
    }
}

/// The paper everything is printed on: grain, a slow wash of ink, and a
/// soft light under the finger. Still with Reduce Motion.
struct AmbientBackground: View {
    /// A point (in global coordinates) to light up, such as a finger.
    var focus: CGPoint? = nil
    var animated = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    private var moving: Bool { animated && !reduceMotion }

    var body: some View {
        ZStack {
            Palette.paper
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !moving)) { timeline in
                wash(time: moving ? timeline.date.timeIntervalSinceReferenceDate : 0)
            }
            if let focus = focus {
                RadialGradient(colors: [Palette.glow, Palette.glow.opacity(0)],
                               center: .center, startRadius: 0, endRadius: 200)
                    .frame(width: 400, height: 400)
                    .position(focus)
                    .blendMode(scheme == .dark ? .plusLighter : .normal)
                    .transition(.opacity)
            }
            PaperGrain()
        }
        .ignoresSafeArea()
        .animation(.easeOut(duration: 0.35), value: focus == nil)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// MeshGradient needs the iOS 18 SDK (Swift 6 toolchains) to compile and
    /// iOS 18 to run; otherwise the clouds are drawn by hand.
    @ViewBuilder
    private func wash(time: TimeInterval) -> some View {
        #if compiler(>=6.0)
        if #available(iOS 18.0, *) {
            MeshGradient(width: 3, height: 3,
                         points: InkWash.points(time: time),
                         colors: InkWash.colors(dark: scheme == .dark))
        } else {
            clouds(time: time)
        }
        #else
        clouds(time: time)
        #endif
    }

    private func clouds(time: TimeInterval) -> some View {
        Canvas { context, size in
            InkWash.drawClouds(&context, size: size, time: time, dark: scheme == .dark)
        }
    }
}

// MARK: Depth

/// Device tilt, smoothed and measured from however the phone is being held,
/// for the small parallax the Home Screen has. Updates run only while
/// something on screen uses them.
final class TiltMotion: ObservableObject {
    static let shared = TiltMotion()

    @Published private(set) var tilt = CGPoint.zero
    private let manager = CMMotionManager()
    private var reference: CGPoint? = nil
    private var users = 0

    func start() {
        users += 1
        guard users == 1, manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30
        manager.startDeviceMotionUpdates(to: OperationQueue.main) { [weak self] motion, _ in
            guard let self = self, let gravity = motion?.gravity else { return }
            self.update(CGPoint(x: gravity.x, y: gravity.y))
        }
    }

    func stop() {
        users = max(users - 1, 0)
        guard users == 0 else { return }
        manager.stopDeviceMotionUpdates()
        reference = nil
        tilt = .zero
    }

    private func update(_ gravity: CGPoint) {
        // The reference drifts toward the current pose, so only movement
        // counts — holding the phone at an angle isn't a tilt.
        var ref = reference ?? gravity
        ref.x += (gravity.x - ref.x) * 0.02
        ref.y += (gravity.y - ref.y) * 0.02
        reference = ref
        let targetX = max(-1, min(1, (gravity.x - ref.x) * 4))
        let targetY = max(-1, min(1, (gravity.y - ref.y) * 4))
        let next = CGPoint(x: tilt.x + (targetX - tilt.x) * 0.25, y: tilt.y + (targetY - tilt.y) * 0.25)
        if abs(next.x - tilt.x) > 0.002 || abs(next.y - tilt.y) > 0.002 {
            tilt = next
        }
    }
}

/// A card leans a few degrees with the phone, and a sheen slides across
/// it like light on paper. Off with Reduce Motion.
struct DeviceTilt: ViewModifier {
    var enabled: Bool
    var cornerRadius: CGFloat
    @ObservedObject private var motion = TiltMotion.shared
    @State private var started = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    init(enabled: Bool, cornerRadius: CGFloat) {
        self.enabled = enabled
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        let active = enabled && !reduceMotion
        let tx: CGFloat = active ? motion.tilt.x : 0
        let ty: CGFloat = active ? motion.tilt.y : 0
        return content
            .overlay {
                sheen(tx, ty)
                    .allowsHitTesting(false)
            }
            .rotation3DEffect(.degrees(Double(ty) * 3.5), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .rotation3DEffect(.degrees(Double(-tx) * 3.5), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .animation(Motion.settle, value: active)
            .onAppear {
                guard !reduceMotion, !started else { return }
                started = true
                motion.start()
            }
            .onDisappear {
                guard started else { return }
                started = false
                motion.stop()
            }
    }

    private func sheen(_ tx: CGFloat, _ ty: CGFloat) -> some View {
        let dark = scheme == .dark
        let light: Color = dark ? Color.white.opacity(0.06) : Color.white.opacity(0.5)
        let shade: Color = dark ? Color.black.opacity(0.0) : Color.black.opacity(0.025)
        return LinearGradient(colors: [light, Color.clear, shade],
                              startPoint: UnitPoint(x: 0.2 + tx * 0.4, y: 0 + ty * 0.3),
                              endPoint: UnitPoint(x: 0.8 + tx * 0.4, y: 1 + ty * 0.3))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: Brush

/// Draws strokes up to `progress` (counted in strokes): finished strokes in
/// ink, the one being written in the accent with a bloom and a wet brush
/// tip, the rest as a faint guide.
enum StrokePainter {
    static func draw(_ context: inout GraphicsContext, size: CGSize, strokes: [Path], progress: Double,
                     guide: Bool = true, lineWidth: CGFloat = 3.6) {
        let scale = min(size.width, size.height) / 109
        let dx = (size.width - 109 * scale) / 2
        let dy = (size.height - 109 * scale) / 2
        let transform = CGAffineTransform(translationX: dx, y: dy).scaledBy(x: scale, y: scale)
        let width = lineWidth * scale
        let style = StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        let bloom = StrokeStyle(lineWidth: width * 3.4, lineCap: .round, lineJoin: .round)
        for (index, stroke) in strokes.enumerated() {
            let scaled = stroke.applying(transform)
            if guide {
                context.stroke(scaled, with: .color(Palette.ink3.opacity(0.3)), style: style)
            }
            let fraction = min(max(progress - Double(index), 0), 1)
            guard fraction > 0 else { continue }
            if fraction < 1 {
                let wet = scaled.trimmedPath(from: 0, to: CGFloat(fraction))
                context.stroke(wet, with: .color(Palette.accent.opacity(0.16)), style: bloom)
                context.stroke(wet, with: .color(Palette.accent), style: style)
                if let tip = wet.currentPoint {
                    let r = width * 2.2
                    let dot = CGRect(x: tip.x - r, y: tip.y - r, width: r * 2, height: r * 2)
                    context.fill(Path(ellipseIn: dot),
                                 with: .radialGradient(Gradient(colors: [Palette.accent.opacity(0.5),
                                                                         Palette.accent.opacity(0)]),
                                                       center: tip, startRadius: 0, endRadius: r))
                }
            } else {
                context.stroke(scaled, with: .color(Palette.ink), style: style)
            }
        }
    }
}

/// The app's mark: 墨, written stroke by stroke as it appears, the wet
/// stroke in the accent. It can also follow `progress` (0…1) from a gesture.
struct SumiMark: View {
    var size: CGFloat = 120
    var progress: Double? = nil
    var delay: Double = 0.25
    var guide = false
    @State private var start = Date()
    @State private var writing = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let strokes: [Path] = sumiMarkPaths.map { SVGPath.parse($0) }
    private static let perStroke = 0.16

    private var animating: Bool { progress == nil && writing && !reduceMotion }

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !animating)) { timeline in
            Canvas { context, canvasSize in
                StrokePainter.draw(&context, size: canvasSize, strokes: SumiMark.strokes,
                                   progress: currentProgress(at: timeline.date), guide: guide, lineWidth: 4.4)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            start = Date()
            let total = delay + Double(SumiMark.strokes.count) * SumiMark.perStroke + 0.3
            DispatchQueue.main.asyncAfter(deadline: .now() + total) { writing = false }
        }
        .accessibilityHidden(true)
    }

    private func currentProgress(at date: Date) -> Double {
        let count = Double(SumiMark.strokes.count)
        if let progress = progress { return min(max(progress, 0), 1) * count }
        if reduceMotion || !writing { return count }
        let elapsed = date.timeIntervalSince(start) - delay
        return min(max(elapsed / SumiMark.perStroke, 0), count)
    }
}

/// The 田-shaped guide of Japanese practice paper (練習用紙).
struct GuideGrid: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { p in
                p.move(to: CGPoint(x: w / 2, y: 0))
                p.addLine(to: CGPoint(x: w / 2, y: h))
                p.move(to: CGPoint(x: 0, y: h / 2))
                p.addLine(to: CGPoint(x: w, y: h / 2))
            }
            .stroke(Palette.hairline, style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Page dots, as on the Home Screen: the current page stretches into a
/// capsule, the others stay small. Vertical, for vertical paging.
struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Palette.ink : Palette.ink3.opacity(0.45))
                    .frame(width: 6, height: index == current ? 20 : 6)
            }
        }
        .animation(Motion.flick, value: current)
        .accessibilityElement()
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}

/// "Swipe up to …" with a light sweeping across it, the way the Lock Screen
/// once invited people to slide to unlock. Static with Reduce Motion.
struct ShimmerText: View {
    let text: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1
    @State private var nudge = false

    var body: some View {
        label
            .foregroundStyle(Palette.ink2)
            .overlay {
                if !reduceMotion {
                    sweep
                }
            }
            .onAppear {
                if !reduceMotion {
                    phase = 1
                    nudge = true
                }
            }
    }

    private var label: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: "chevron.compact.up")
                .font(.title3.weight(.semibold))
                .offset(y: nudge ? -2 : 1)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: nudge)
            Text(text)
        }
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var sweep: some View {
        GeometryReader { geo in
            LinearGradient(colors: [Color.clear, Palette.ink, Color.clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: geo.size.width * 0.45)
                .offset(x: phase * geo.size.width * 1.4)
                // Scoped to the sweep, so the endless repeat can never leak
                // into the layout of whatever the text sits in.
                .animation(.linear(duration: 2.6).repeatForever(autoreverses: false), value: phase)
        }
        .mask(label)
        .allowsHitTesting(false)
    }
}

/// The heart that pops on a double-tap: it springs in past full size, a
/// ring spreads from it, then it floats up and fades.
struct HeartBurst: View {
    @State private var popped = false
    @State private var ring = false
    @State private var gone = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.sakura.opacity(ring ? 0 : 0.45), lineWidth: ring ? 1 : 8)
                .frame(width: 120, height: 120)
                .scaleEffect(ring ? 2 : 0.5)
            Image(systemName: "heart.fill")
                .font(.system(size: 96, weight: .regular))
                .foregroundStyle(LinearGradient(colors: [Palette.sakura, Color.pink],
                                                startPoint: .top, endPoint: .bottom))
                .shadow(color: Palette.sakura.opacity(0.35), radius: 18, x: 0, y: 8)
                .scaleEffect(popped ? (gone ? 0.9 : 1) : 0.2)
                .offset(y: gone ? -36 : 0)
                .opacity(gone ? 0 : (popped ? 1 : 0))
        }
        .onAppear {
            withAnimation(.spring(duration: 0.4, bounce: 0.55)) { popped = true }
            withAnimation(.easeOut(duration: 0.65)) { ring = true }
            withAnimation(.easeIn(duration: 0.3).delay(0.55)) { gone = true }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// KanjiVG stroke paths for 墨 (the app's mark), in stroke order.
/// © Ulrich Apel and contributors, CC BY-SA 3.0.
let sumiMarkPaths: [String] = [
    "M27.61,14.13c0.41,0.41,0.92,1.58,1.15,2.09c1.53,3.46,2.64,10.9,3.62,17.8c0.21,1.48,0.42,2.93,0.62,4.31",
    "M29.87,15.79c13.42-1.47,34.16-3.02,45.52-3.76c4.17-0.27,6.52,0.51,5.48,5.15c-0.85,3.8-2.39,9.71-4.18,14.89c-0.54,1.58-1.09,3.07-1.61,4.39",
    "M32.32,26.76c10.31-1.13,35.06-3.26,45.56-3.63",
    "M33.97,36.76c10.78-0.88,27.81-2.52,40.87-3.19",
    "M52.77,16.19c0.89,0.89,1.35,2.19,1.35,3.48c0,9.08-0.11,31.68-0.11,34.72",
    "M34.88,45.31c2.08,0.62,4.24,0.49,6.37,0.37c7.32-0.41,17.01-1.64,25.88-2.21c2.12-0.14,4.21-0.34,6.31,0.04",
    "M26.13,56.71c2.71,0.86,5.74,0.41,8.49,0.24c12.57-0.81,26.02-2.27,43-2.43c2.43-0.02,4.85,0.2,7.25,0.66",
    "M23.06,65.49c-1.14,4.87-6.59,10.54-8.06,11.76",
    "M38.02,63.69c2.14,1.4,4.35,4.68,5.2,7.68",
    "M61.25,61.4c2.65,1.49,5,5.1,6,7.93",
    "M83.46,61.32c4,2.13,9.85,8.78,10.85,12.11",
    "M33.19,81.83c1.93,0.75,4.81,0.43,6.8,0.24c9.46-0.9,21.3-1.96,30.88-2.39c2.34-0.11,4.73-0.36,7.03,0.19",
    "M53.14,68.77c0.79,0.79,1.07,2.23,1.07,3.75c0,10.62-0.07,7.66-0.07,21.7",
    "M20.24,96.64c2.77,0.99,6.13,0.93,9.01,0.66c15.72-1.49,37.08-2.69,51.25-3.34c3.26-0.15,6.36,0.08,9.52,0.75"
]

// MARK: Shared pieces

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
    /// KanjiVG stroke paths in stroke order (109 x 109 coordinate space).
    var strokePaths: [String]

    var id: String { glyph }
    var primaryMeaning: String { meanings.first ?? "" }
    var meaningList: String { meanings.joined(separator: ", ") }

    enum CodingKeys: String, CodingKey {
        case glyph, level, strokes, meanings, on, kun, kind, parts, phonetic
        case mnemonic, words, sentence, translation, usage, strokePaths
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
        strokePaths = (try? c.decode([String].self, forKey: .strokePaths)) ?? []
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

/// Light, dark, or whatever the system is set to.
enum Appearance: String, Codable, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Automatic"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var scheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct AppSettings: Codable, Equatable {
    var newPerDay = 10
    var batchSize = 5
    var retention = 0.9
    var writing = true
    var typeReadings = false
    var autoSpeak = true
    var haptics = true
    var furigana: FuriganaMode = .adaptive
    var face: JPFace = .gothic
    var appearance: Appearance = .system
    var dayStartHour = 4
    var reminder = false
    var reminderHour = 19
    var reminderMinute = 0
    var askedReminder = false
    /// The Japanese voice picked in Settings; empty means the best installed.
    var voiceID = ""
    /// Gesture teaching: the feed teaches one gesture per card for the first
    /// five cards; the hold tip on kanji pages shows until it's used once.
    var coachStep = 0
    var coachTips = false

    init() {}

    enum CodingKeys: String, CodingKey {
        case newPerDay, batchSize, retention, writing, typeReadings, autoSpeak, haptics, furigana, face, appearance
        case dayStartHour, reminder, reminderHour, reminderMinute, askedReminder, voiceID, coachStep, coachTips
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
        typeReadings = (try? c.decode(Bool.self, forKey: .typeReadings)) ?? d.typeReadings
        autoSpeak = (try? c.decode(Bool.self, forKey: .autoSpeak)) ?? d.autoSpeak
        haptics = (try? c.decode(Bool.self, forKey: .haptics)) ?? d.haptics
        furigana = (try? c.decode(FuriganaMode.self, forKey: .furigana)) ?? d.furigana
        face = (try? c.decode(JPFace.self, forKey: .face)) ?? d.face
        appearance = (try? c.decode(Appearance.self, forKey: .appearance)) ?? d.appearance
        dayStartHour = (try? c.decode(Int.self, forKey: .dayStartHour)) ?? d.dayStartHour
        reminder = (try? c.decode(Bool.self, forKey: .reminder)) ?? d.reminder
        reminderHour = (try? c.decode(Int.self, forKey: .reminderHour)) ?? d.reminderHour
        reminderMinute = (try? c.decode(Int.self, forKey: .reminderMinute)) ?? d.reminderMinute
        askedReminder = (try? c.decode(Bool.self, forKey: .askedReminder)) ?? d.askedReminder
        voiceID = (try? c.decode(String.self, forKey: .voiceID)) ?? d.voiceID
        coachStep = (try? c.decode(Int.self, forKey: .coachStep)) ?? d.coachStep
        coachTips = (try? c.decode(Bool.self, forKey: .coachTips)) ?? d.coachTips
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
    var saved: [String] = []
    var bestCombo = 0

    init() {}

    enum CodingKeys: String, CodingKey {
        case version, cards, settings, days, log, notes, priority, readPassages, onboarded, packs
        case saved, bestCombo
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
        saved = (try? c.decode([String].self, forKey: .saved)) ?? []
        bestCombo = (try? c.decode(Int.self, forKey: .bestCombo)) ?? 0
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
    enum Kind: Hashable {
        /// A graded card.
        case card
        /// An ungraded sentence that puts a kanji just seen in context.
        case context
        /// A new kanji being introduced in a lesson.
        case teach
    }

    let id = UUID()
    let glyph: String
    let facet: Facet
    let wordIndex: Int
    var kind: Kind = .card
}

enum SessionMode: Hashable {
    case review, lesson, practice
}

struct SessionLaunch: Identifiable, Hashable {
    let id = UUID()
    var mode: SessionMode
    var items: [StudyItem]
    var lessonGlyphs: [String] = []
    /// Kanji with an example sentence; reviews weave in a context page
    /// after every seventh card for one of them.
    var contextGlyphs: Set<String> = []
}

struct SessionResult {
    var answered = 0
    var firstTry = 0
    var bestCombo = 0
    var missed: [String] = []
    var started = Date()
}

/// One vertical feed for everything: lesson pages, then their quiz, or a
/// review run. Every move can be taken back with a swipe down.
final class SessionModel: ObservableObject {
    let mode: SessionMode
    @Published private(set) var queue: [StudyItem]
    @Published private(set) var completed = 0
    @Published private(set) var total: Int
    @Published private(set) var result = SessionResult()
    @Published private(set) var canUndo = false
    @Published private(set) var combo = 0

    private var failed = Set<String>()
    private var history: [Snapshot] = []

    private struct Snapshot {
        var save: SaveFile
        var queue: [StudyItem]
        var completed: Int
        var total: Int
        var result: SessionResult
        var failed: Set<String>
        var combo: Int
    }

    init(mode: SessionMode, items: [StudyItem], contextGlyphs: Set<String> = []) {
        self.mode = mode
        let teach = items.filter { $0.kind == .teach }
        var cards = SessionModel.interleave(items.filter { $0.kind == .card })
        if mode == .review && !contextGlyphs.isEmpty {
            cards = SessionModel.weaveContext(into: cards, glyphs: contextGlyphs)
        }
        self.queue = teach + cards
        self.total = teach.count + items.filter { $0.kind == .card }.count
    }

    var current: StudyItem? { queue.first }
    var upcoming: StudyItem? { queue.count > 1 ? queue[1] : nil }
    /// The card under the next one — the third card of the deck.
    var afterNext: StudyItem? { queue.count > 2 ? queue[2] : nil }
    /// The page "back" would restore — the one on screen before the last move.
    var previousItem: StudyItem? { history.last?.queue.first }
    var isFinished: Bool { queue.isEmpty }
    var progress: Double { total == 0 ? 1 : Double(completed) / Double(total) }

    private static func key(_ item: StudyItem) -> String { item.glyph + "#" + item.facet.rawValue }

    private func remember(_ store: Store) {
        history.append(Snapshot(save: store.data, queue: queue, completed: completed, total: total,
                                result: result, failed: failed, combo: combo))
        if history.count > 60 { history.removeFirst() }
        canUndo = true
    }

    /// Records an answer. A miss goes back into the feed a few cards later,
    /// so it's retrieved again while the correction is fresh.
    func commit(_ rating: Rating, ms: Int, miss: MissReason?, store: Store) {
        guard let item = queue.first, item.kind == .card else { return }
        remember(store)
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
            combo = 0
        } else {
            if !failed.contains(key) {
                r.firstTry += 1
                combo += 1
                r.bestCombo = max(r.bestCombo, combo)
            }
            completed += 1
        }
        result = r
        queue = next
        if store.data.bestCombo < r.bestCombo { store.data.bestCombo = r.bestCombo }
    }

    /// Moves past a lesson page or a context page.
    func advancePage(store: Store) {
        guard let item = queue.first, item.kind != .card else { return }
        remember(store)
        var next = queue
        next.removeFirst()
        if item.kind == .teach { completed += 1 }
        queue = next
    }

    /// "I already know this one" on a lesson page: it's marked known and its
    /// quiz questions disappear.
    func skipKnown(_ glyph: String, store: Store) {
        remember(store)
        store.markKnown([glyph])
        let before = queue.count
        queue.removeAll { $0.glyph == glyph }
        total = max(total - (before - queue.count), completed)
    }

    /// Brings back the previous page exactly as it was.
    @discardableResult
    func undo(store: Store) -> Bool {
        guard let last = history.popLast() else { return false }
        if mode != .practice { store.data = last.save }
        queue = last.queue
        completed = last.completed
        total = last.total
        result = last.result
        failed = last.failed
        combo = last.combo
        canUndo = !history.isEmpty
        return true
    }

    func skipCurrent() {
        guard !queue.isEmpty else { return }
        queue.removeFirst()
        total = max(completed + queue.filter { $0.kind != .context }.count, completed)
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

    /// After every seventh card, an ungraded sentence page for the kanji just
    /// seen — variety for attention, context for meaning.
    static func weaveContext(into items: [StudyItem], glyphs: Set<String>) -> [StudyItem] {
        var out: [StudyItem] = []
        var sinceLast = 0
        for (index, item) in items.enumerated() {
            out.append(item)
            sinceLast += 1
            if sinceLast >= 7 && glyphs.contains(item.glyph) && index < items.count - 1 {
                out.append(StudyItem(glyph: item.glyph, facet: item.facet, wordIndex: item.wordIndex, kind: .context))
                sinceLast = 0
            }
        }
        return out
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
    case library
    case kanji(String)
    case passage(String)
}

final class Router: ObservableObject {
    @Published var path: [Route] = []
    /// The study session on screen, if any (shown full-screen).
    @Published var session: SessionLaunch? = nil
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
        guard !items.isEmpty else { return nil }
        let withSentences = Set(library.kanji.filter { !$0.sentence.isEmpty }.map(\.glyph))
        return SessionLaunch(mode: .review, items: items, contextGlyphs: withSentences)
    }

    func lessonLaunch(extra: Bool) -> SessionLaunch? {
        let size = data.settings.batchSize
        let count = extra ? size : min(size, lessonsLeftToday)
        let batch = Array(lessonQueue.prefix(max(count, 1)))
        guard !batch.isEmpty else { return nil }
        // Each new kanji gets a page of its own; the quiz follows in the
        // same feed.
        let teach = batch.map { StudyItem(glyph: $0.glyph, facet: .meaning, wordIndex: 0, kind: .teach) }
        return SessionLaunch(mode: .lesson, items: teach + lessonItems(for: batch), lessonGlyphs: batch.map(\.glyph))
    }

    func practiceLaunch(_ glyphs: [String]) -> SessionLaunch? {
        let items = practiceItems(for: glyphs)
        return items.isEmpty ? nil : SessionLaunch(mode: .practice, items: items)
    }

    func isSaved(_ glyph: String) -> Bool { data.saved.contains(glyph) }

    func toggleSaved(_ glyph: String) {
        if let index = data.saved.firstIndex(of: glyph) {
            data.saved.remove(at: index)
        } else {
            data.saved.insert(glyph, at: 0)
        }
    }

    var savedKanji: [Kanji] { data.saved.compactMap { library.byGlyph[$0] } }

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
        .preferredColorScheme(store.data.settings.appearance.scheme)
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
        .onAppear(perform: applyPreferences)
        .onChange(of: store.data.settings) { _, _ in applyPreferences() }
    }

    /// Haptics and the voice are used outside SwiftUI views, so they mirror
    /// the saved settings.
    private func applyPreferences() {
        Haptics.enabled = store.data.settings.haptics
        Speaker.preferredVoiceID = store.data.settings.voiceID
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
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

extension Store {
    /// The first few kanji waiting for review, most overdue first.
    func duePreview(limit: Int) -> [String] {
        var seen: [String] = []
        for card in dueCards().sorted(by: { $0.due < $1.due }) where !seen.contains(card.glyph) {
            seen.append(card.glyph)
            if seen.count == limit { break }
        }
        return seen
    }
}

/// One deck, one number, one gesture. The cards waiting for you sit on the
/// paper as a small deck; swipe up (or tap it) and the top card lifts off
/// under your finger as the session rises to meet it.
struct HomeView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @Binding var showSettings: Bool

    var body: some View {
        TimelineView(.everyMinute) { context in
            HomeScreen(state: store.homeState, preview: store.duePreview(limit: 3), now: context.date)
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
        .fullScreenCover(item: $router.session) { launch in
            StudyCover(launch: launch)
                .environmentObject(store)
                .environmentObject(router)
        }
    }
}

/// The home screen's content. Gesture state lives here, so following a
/// finger redraws only this view; what's due is worked out once, above.
struct HomeScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let state: HomeState
    let preview: [String]
    let now: Date
    @ScaledMetric(relativeTo: .largeTitle) private var countSize: CGFloat = 64
    @State private var lift: CGFloat = 0
    @State private var armed = false
    @State private var finger: CGPoint? = nil

    var body: some View {
        screen(state, now: now)
            .background {
                AmbientBackground(focus: finger)
            }
    }

    private func screen(_ state: HomeState, now: Date) -> some View {
        VStack(spacing: 0) {
            Caption(text: now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .padding(.top, Space.xs)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Space.l)
            centerpiece(state)
                .padding(.horizontal, Space.l)
            Spacer(minLength: Space.l)
            footer(state)
                .padding(.horizontal, Space.l)
                .padding(.bottom, Space.l)
                .actionColumn()
                .opacity(1 - Double(min(-lift / 120, 0.7)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(startGesture(state))
        .background(startKey(state))
    }

    @ViewBuilder
    private func centerpiece(_ state: HomeState) -> some View {
        switch state {
        case .review(let count):
            VStack(spacing: Space.xxl) {
                HomeDeck(glyphs: preview, lift: lift)
                    .onTapGesture { start(state) }
                countBlock(count: count, unit: count == 1 ? "review" : "reviews",
                           estimate: Format.estimate(seconds: Double(count) * 8))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(reviewLabel(count))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { start(state) }
        case .learn(let batch):
            VStack(spacing: Space.xxl) {
                HomeDeck(glyphs: batch.map(\.glyph), lift: lift)
                    .onTapGesture { start(state) }
                countBlock(count: batch.count, unit: "new kanji",
                           estimate: Format.estimate(seconds: Double(batch.count) * 50))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(learnLabel(batch.count))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { start(state) }
        case .rest(let next, _, _):
            restBlock(next: next)
        }
    }

    private func countBlock(count: Int, unit: String, estimate: String) -> some View {
        VStack(spacing: Space.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                Text("\(count)")
                    .font(.system(size: min(countSize, 88), weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(count)))
                    .foregroundStyle(Palette.ink)
                Text(unit)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Palette.ink2)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Text(estimate)
                .font(.subheadline)
                .foregroundStyle(Palette.ink2)
        }
        .offset(y: lift * 0.2)
    }

    private func restBlock(next: Date?) -> some View {
        VStack(spacing: Space.l) {
            Hanko(glyph: "済", size: 88)
            VStack(spacing: Space.xs) {
                Text("All done")
                    .font(.display(.largeTitle, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Group {
                    if let next = next {
                        Text("Next review \(next, format: .relative(presentation: .named))")
                    } else {
                        Text("Nothing left to learn — import more in Settings.")
                    }
                }
                .font(.body)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func learnLabel(_ count: Int) -> String {
        count == 1 ? "1 new kanji to learn" : "\(count) new kanji to learn"
    }

    private func reviewLabel(_ count: Int) -> String {
        count == 1 ? "1 review waiting" : "\(count) reviews waiting"
    }

    @ViewBuilder
    private func footer(_ state: HomeState) -> some View {
        switch state {
        case .review:
            startHint("Swipe up to review", label: "Review", state: state)
        case .learn:
            startHint("Swipe up to learn", label: "Learn", state: state)
        case .rest(_, let canLearnMore, let passage):
            restLinks(canLearnMore: canLearnMore, passage: passage)
        }
    }

    private func startHint(_ text: String, label: String, state: HomeState) -> some View {
        ShimmerText(text: text)
            .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
            .contentShape(Rectangle())
            .onTapGesture { start(state) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(label))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { start(state) }
    }

    /// When the day's work is done, a few quiet ways to keep going.
    private func restLinks(canLearnMore: Bool, passage: Passage?) -> some View {
        VStack(spacing: Space.s) {
            if let passage = passage {
                Button {
                    router.path.append(.passage(passage.id))
                } label: {
                    Label("Read “\(Ruby.plain(passage.title))”", systemImage: "text.book.closed")
                }
                .buttonStyle(GlassPillStyle())
            }
            if !store.data.saved.isEmpty {
                Button {
                    if let launch = store.practiceLaunch(store.data.saved) { router.session = launch }
                } label: {
                    Label("Practice saved kanji", systemImage: "bookmark")
                }
                .buttonStyle(GlassPillStyle())
            }
            if canLearnMore {
                Button {
                    if let launch = store.lessonLaunch(extra: true) { router.session = launch }
                } label: {
                    Label("Learn more today", systemImage: "plus")
                }
                .buttonStyle(GlassPillStyle())
            }
        }
        .frame(minHeight: Metrics.buttonHeight)
    }

    private func canStart(_ state: HomeState) -> Bool {
        switch state {
        case .review, .learn: return true
        case .rest: return false
        }
    }

    private func sessionLaunch(for state: HomeState) -> SessionLaunch? {
        switch state {
        case .review: return store.reviewLaunch()
        case .learn: return store.lessonLaunch(extra: false)
        case .rest: return nil
        }
    }

    private func start(_ state: HomeState) {
        guard router.session == nil, let launch = sessionLaunch(for: state) else { return }
        Haptics.soft()
        router.session = launch
    }

    /// The deck follows the finger with resistance and the paper lights up
    /// under it; a tick says "let go now", and momentum counts, so a quick
    /// flick is enough.
    private func startGesture(_ state: HomeState) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                guard canStart(state) else { return }
                finger = value.location
                let up = min(value.translation.height, 0)
                lift = Motion.rubberband(up, dimension: 360)
                let ready = up < -110
                if ready != armed {
                    if ready { Haptics.tick() }
                    armed = ready
                }
            }
            .onEnded { value in
                finger = nil
                guard canStart(state) else { return }
                let projected = value.translation.height + Motion.project(value.velocity.height)
                if projected < -110 && value.velocity.height < 300 {
                    start(state)
                }
                armed = false
                withAnimation(Motion.flick) { lift = 0 }
            }
    }

    private func startKey(_ state: HomeState) -> some View {
        Button("") { start(state) }
            .keyboardShortcut(.defaultAction)
            .opacity(0)
            .accessibilityHidden(true)
            .disabled(!canStart(state))
    }
}

/// The cards waiting, fanned a little like a deck set down on a desk. The
/// top card leans with the phone; during a swipe it lifts off first and the
/// ones beneath follow more slowly.
struct HomeDeck: View {
    @EnvironmentObject var store: Store
    let glyphs: [String]
    var lift: CGFloat = 0
    @ScaledMetric(relativeTo: .largeTitle) private var baseWidth: CGFloat = 148

    private struct DeckCard: Identifiable {
        let id: Int
        let glyph: String
    }

    private var width: CGFloat { min(baseWidth, 190) }
    private var height: CGFloat { width * 1.3 }

    /// Bottom card first, so the top card draws last.
    private var cards: [DeckCard] {
        let top = Array(glyphs.prefix(3))
        var result: [DeckCard] = []
        for index in top.indices.reversed() {
            result.append(DeckCard(id: index, glyph: top[index]))
        }
        return result
    }

    var body: some View {
        ZStack {
            ForEach(cards) { card in
                deckCard(card.glyph, depth: card.id)
            }
        }
        .frame(width: width * 1.4, height: height * 1.12)
        .accessibilityHidden(true)
    }

    private func deckCard(_ glyph: String, depth: Int) -> some View {
        let d = CGFloat(depth)
        let fan: [Double] = [0, -7, 6]
        let shift: [CGFloat] = [0, -16, 18]
        let follow: CGFloat = depth == 0 ? 1 : 0.45 - 0.15 * d
        let settle = Double(min(-lift / 300, 1))
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return Text(glyph)
            .font(.jpFixed(width * 0.5, face: store.data.settings.face))
            .foregroundStyle(Palette.ink)
            .frame(width: width, height: height)
            .background {
                ZStack {
                    Palette.card
                    PaperGrain(strength: 0.7)
                }
            }
            .clipShape(shape)
            .overlay {
                shape.stroke(Palette.edge, lineWidth: 1)
            }
            .background {
                shape.fill(Palette.card)
                    .elevation(depth == 0 ? 1 : 0.6)
            }
            .modifier(DeviceTilt(enabled: depth == 0, cornerRadius: 22))
            .scaleEffect(1 - 0.04 * d)
            .rotationEffect(.degrees(fan[depth] * (1 - settle * 0.6)))
            .offset(x: shift[depth], y: d * 6 + lift * follow)
    }
}

/// Everything about one kanji, laid out to be scanned top to bottom: the
/// glyph on its own sheet of practice paper, then what it means and how it
/// sounds, a memory hook, real words and a real sentence. Anything with a
/// sound plays when tapped.
struct KanjiArticle: View {
    @EnvironmentObject var store: Store
    let glyph: String
    var detailed = false
    var autoplayStrokes = false
    @State private var holding = false
    @State private var autoplaying = false
    @State private var burst = false
    @State private var burstToken = 0
    @State private var editingHook = false
    @State private var hookDraft = ""
    @FocusState var hookFocused: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var glyphSize: CGFloat = 150
    @ScaledMetric(relativeTo: .caption2) private var labelWidth: CGFloat = 36

    var body: some View {
        if let kanji = store.library.byGlyph[glyph] {
            VStack(alignment: .leading, spacing: Space.xxl) {
                hero(kanji)
                identity(kanji)
                hook(kanji)
                if !kanji.words.isEmpty { words(kanji) }
                if !kanji.sentence.isEmpty { sentence(kanji) }
                if detailed { notes(kanji) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: autoplayStrokes) { _, active in
                if active { autoplay(kanji) }
            }
        }
    }

    // MARK: Hero

    private func hero(_ kanji: Kanji) -> some View {
        VStack(spacing: Space.m) {
            heroSheet(kanji)
                .visualEffect { content, proxy in
                    let y = proxy.frame(in: .scrollView).minY
                    let pulled: CGFloat = y < 0 ? y : 0
                    return content
                        .scaleEffect(max(0.82, 1 + pulled / 900), anchor: .top)
                        .offset(y: -pulled * 0.25)
                        .opacity(Double(max(0.35, 1 + pulled / 500)))
                }
            metaChips(kanji)
            if !kanji.strokePaths.isEmpty && !store.data.settings.coachTips {
                Text("Hold for strokes and sound · double-tap to save")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// The glyph on practice paper, lifted off the page. Hold to watch it
    /// written and hear it; double-tap to save it.
    private func heroSheet(_ kanji: Kanji) -> some View {
        let side = min(glyphSize, 200)
        let shape = RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous)
        let saveName: String = store.isSaved(kanji.glyph) ? "Remove from saved" : "Save"
        return ZStack {
            GuideGrid()
                .padding(Space.l)
            StrokeGlyph(kanji: kanji, size: side, playing: holding || autoplaying, loops: holding)
            if burst {
                SaveBurst(saved: store.isSaved(kanji.glyph))
                    .id(burstToken)
            }
        }
        .frame(width: side * 1.5, height: side * 1.5)
        .background {
            ZStack {
                Palette.card
                PaperGrain(strength: 0.8)
            }
        }
        .clipShape(shape)
        .overlay {
            shape.stroke(Palette.edge, lineWidth: 1)
        }
        .background {
            shape.fill(Palette.card)
                .elevation(1)
        }
        .modifier(DeviceTilt(enabled: true, cornerRadius: Radius.sheet))
        .contentShape(shape)
        .onTapGesture(count: 2) { toggleSave(kanji) }
        .onLongPressGesture(minimumDuration: 0.3, maximumDistance: 12, perform: {
            startHold(kanji)
        }, onPressingChanged: { pressing in
            if !pressing && holding {
                holding = false
                Haptics.stop()
            }
        })
        .accessibilityAction(named: "Play stroke order and sound") { autoplay(kanji) }
        .accessibilityAction(named: saveName) { toggleSave(kanji) }
        .onAppear { if autoplayStrokes { autoplay(kanji) } }
    }

    private func metaChips(_ kanji: Kanji) -> some View {
        HStack(spacing: Space.xs) {
            metaChip(kanji.level.label)
            if kanji.strokes > 0 {
                metaChip(kanji.strokes == 1 ? "1 stroke" : "\(kanji.strokes) strokes")
            }
            if let kind = kanji.kind {
                metaChip("\(kind.japanese) \(kind.title)")
            }
            if store.isSaved(kanji.glyph) {
                Image(systemName: "bookmark.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 30, height: 28)
                    .glassCapsule(tint: Palette.accent)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("Saved")
            }
        }
        .animation(Motion.flick, value: store.isSaved(kanji.glyph))
    }

    private func metaChip(_ text: String) -> some View {
        MixedText(text, style: .caption, bold: true)
            .foregroundStyle(Palette.ink2)
            .lineLimit(1)
            .padding(.horizontal, Space.s)
            .frame(height: 28)
            .glassCapsule()
    }

    // MARK: Meaning and readings

    private func identity(_ kanji: Kanji) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(kanji.meaningList.capitalizedFirst)
                .font(.display(.largeTitle, weight: .bold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: Space.s) {
                if !kanji.on.isEmpty {
                    readingRow("On", kanji.on.joined(separator: "・"))
                }
                if !kanji.kun.isEmpty {
                    readingRow("Kun", kunLine(kanji))
                }
            }
        }
    }

    /// One reading family: a small label, then the readings; tap to hear.
    private func readingRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(Palette.accent)
                .frame(width: labelWidth, alignment: .leading)
            Text(value)
                .font(.jp(19, face: store.data.settings.face, relativeTo: .body))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture { Speaker.shared.say(value) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Plays the readings")
    }

    private func kunLine(_ kanji: Kanji) -> String {
        kanji.kun.map { reading -> String in
            let split = splitKun(reading.replacingOccurrences(of: "-", with: ""))
            return split.okurigana.isEmpty ? split.stem : "\(split.stem)(\(split.okurigana))"
        }
        .joined(separator: "・")
    }

    // MARK: Hook

    private func hook(_ kanji: Kanji) -> some View {
        let own = store.note(for: kanji.glyph)
        return VStack(alignment: .leading, spacing: Space.m) {
            Caption(text: own.isEmpty ? "Memory hook" : "Your hook")
            if !kanji.parts.isEmpty {
                FlowLayout(spacing: Space.xs, lineSpacing: Space.xs) {
                    ForEach(kanji.parts, id: \.self) { part in
                        partChip(part)
                    }
                }
            }
            if editingHook {
                hookEditor(kanji)
            } else {
                MixedText(own.isEmpty ? kanji.mnemonic : own, style: .body)
                    .foregroundStyle(Palette.ink)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                Button(own.isEmpty ? "Write your own" : "Edit your own") {
                    hookDraft = own
                    withAnimation(Motion.settle) { editingHook = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { hookFocused = true }
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderless)
            }
        }
        .padding(Space.l)
        .padding(.leading, Space.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(SheetSurface())
        .overlay(alignment: .leading) {
            Capsule()
                .fill(Palette.accent.gradient)
                .frame(width: 3)
                .padding(.vertical, Space.l)
                .padding(.leading, Space.xs)
                .allowsHitTesting(false)
        }
    }

    private func partChip(_ part: Part) -> some View {
        HStack(spacing: Space.xxs) {
            Text(part.glyph)
                .font(.jp(17, bold: true, face: store.data.settings.face, relativeTo: .body))
                .foregroundStyle(Palette.ink)
            Text(part.meaning)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Palette.ink2)
        }
        .padding(.horizontal, Space.s)
        .frame(minHeight: 32)
        .background(Palette.surface, in: Capsule())
        .accessibilityElement(children: .combine)
    }

    private func hookEditor(_ kanji: Kanji) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            TextField("A picture or story that makes it stick for you", text: $hookDraft, axis: .vertical)
                .lineLimit(2...6)
                .focused($hookFocused)
                .padding(Space.s)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .stroke(Palette.accent.opacity(hookFocused ? 0.6 : 0), lineWidth: 1.5)
                }
                .animation(Motion.settle, value: hookFocused)
            HStack {
                Button("Cancel") {
                    withAnimation(Motion.settle) { editingHook = false }
                }
                .foregroundStyle(Palette.ink2)
                Spacer()
                Button("Save") {
                    store.setNote(hookDraft, for: kanji.glyph)
                    withAnimation(Motion.settle) { editingHook = false }
                    Haptics.tap()
                }
                .fontWeight(.semibold)
            }
            .font(.subheadline)
            .buttonStyle(.borderless)
            .frame(minHeight: Metrics.minTap)
        }
        .transition(.blurFade)
    }

    // MARK: Words and sentence

    private func words(_ kanji: Kanji) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Caption(text: "Words")
            VStack(spacing: 0) {
                ForEach(Array(kanji.words.enumerated()), id: \.element.id) { pair in
                    wordRow(pair.element, kanji: kanji)
                    if pair.offset < kanji.words.count - 1 {
                        Divider()
                            .padding(.leading, Space.l)
                    }
                }
            }
            .modifier(SheetSurface())
        }
    }

    /// Word and reading stacked on the left, meaning on the right: the eye
    /// runs down the Japanese column, and nothing has to truncate.
    private func wordRow(_ word: Word, kanji: Kanji) -> some View {
        HStack(alignment: .center, spacing: Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                jpText(word.word, highlight: kanji.glyph, size: 21, face: store.data.settings.face, fixed: false)
                Text(word.readings.joined(separator: " / "))
                    .font(.jp(13, relativeTo: .footnote))
                    .foregroundStyle(Palette.ink2)
            }
            .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: Space.s)
            Text(word.meaning)
                .font(.subheadline)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
            Image(systemName: "speaker.wave.2")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.ink3)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.s)
        .frame(minHeight: Metrics.minTap + 8)
        .contentShape(Rectangle())
        .onTapGesture { Speaker.shared.say(word.primaryReading) }
        .hoverEffect(.highlight)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Plays the pronunciation")
    }

    private func sentence(_ kanji: Kanji) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Caption(text: "In a sentence")
            VStack(alignment: .leading, spacing: Space.s) {
                RubyText(markup: kanji.sentence, size: 20, highlight: kanji.glyph)
                Text(kanji.translation)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(SheetSurface())
            .contentShape(Rectangle())
            .onTapGesture { Speaker.shared.say(Ruby.spoken(kanji.sentence)) }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Plays the sentence")
        }
    }

    // MARK: Notes

    @ViewBuilder
    private func notes(_ kanji: Kanji) -> some View {
        let confusions = store.library.confusions(for: kanji.glyph)
        let usage = kanji.usage ?? ""
        let memory = store.memoryLine(for: kanji.glyph)
        if !usage.isEmpty || !confusions.isEmpty || memory != nil || kanji.kind != nil {
            VStack(alignment: .leading, spacing: Space.m) {
                Caption(text: "Notes")
                if let kind = kanji.kind {
                    noteLine(symbol: "seal", text: "\(kind.japanese) · \(kind.title). \(kind.explanation)")
                }
                if !usage.isEmpty {
                    noteLine(symbol: "text.bubble", text: usage)
                }
                ForEach(confusions) { confusion in
                    noteLine(symbol: "square.on.square", text: confusion.tip)
                }
                if let memory = memory {
                    noteLine(symbol: "brain.head.profile", text: memory)
                }
            }
        }
    }

    private func noteLine(symbol: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.ink3)
                .frame(width: 20)
            MixedText(text, style: .subheadline)
                .foregroundStyle(Palette.ink2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Actions

    /// Hold: the strokes draw while the word is spoken, a soft tap marking
    /// each stroke — the same as in the study feed.
    private func startHold(_ kanji: Kanji) {
        if let reading = kanji.words.first?.primaryReading { Speaker.shared.say(reading) }
        if !store.data.settings.coachTips { store.data.settings.coachTips = true }
        guard !kanji.strokePaths.isEmpty else { return }
        holding = true
        Haptics.strokes(count: kanji.strokePaths.count, interval: StrokeOrderView.perStroke)
    }

    private func autoplay(_ kanji: Kanji) {
        if let reading = kanji.words.first?.primaryReading { Speaker.shared.say(reading) }
        guard !kanji.strokePaths.isEmpty else { return }
        autoplaying = true
        Haptics.strokes(count: kanji.strokePaths.count, interval: StrokeOrderView.perStroke)
        DispatchQueue.main.asyncAfter(deadline: .now() + StrokeOrderView.duration(for: kanji.strokePaths.count)) {
            autoplaying = false
        }
    }

    private func toggleSave(_ kanji: Kanji) {
        withAnimation(Motion.flick) { store.toggleSaved(kanji.glyph) }
        Haptics.saved()
        burstToken += 1
        let token = burstToken
        burst = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if burstToken == token {
                withAnimation(.easeOut(duration: 0.2)) { burst = false }
            }
        }
    }
}

/// A sheet of paper on the page: card color, a hairline edge, a soft shadow.
struct SheetSurface: ViewModifier {
    var radius: CGFloat = Radius.card

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .background {
                shape.fill(Palette.card)
                    .elevation(0.5)
            }
            .overlay {
                shape.stroke(Palette.edge, lineWidth: 1)
                    .allowsHitTesting(false)
            }
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
        case saved = "Saved"
        case texts = "Texts"
        var id: String { rawValue }
    }

    private var searchPrompt: String {
        shelf == .texts ? "Search texts" : "Kanji, meaning or reading"
    }

    private let columns = [GridItem(.adaptive(minimum: 64, maximum: 92), spacing: Space.xs)]

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
            VStack(alignment: .leading, spacing: Space.xxl) {
                Picker("Library", selection: $shelf.animation(Motion.settle)) {
                    ForEach(Shelf.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: Metrics.actionWidth)
                .frame(maxWidth: .infinity)

                Group {
                    switch shelf {
                    case .kanji:
                        kanjiSection
                    case .saved:
                        savedSection
                    case .texts:
                        textsSection
                    }
                }
                .transition(.blurFade)
            }
            .padding(.horizontal, Space.l)
            .padding(.top, Space.s)
            .padding(.bottom, Space.xxxl)
            .frame(maxWidth: Metrics.gridWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.paper)
        .navigationTitle("Library")
        .searchable(text: $query, prompt: Text(searchPrompt))
    }

    @ViewBuilder
    private var kanjiSection: some View {
        let results = kanjiResults
        if results.isEmpty {
            ContentUnavailableView.search(text: trimmed)
        } else {
            VStack(alignment: .leading, spacing: Space.xxl) {
                ForEach(store.library.levelsWithContent) { level in
                    let inLevel = results.filter { $0.level == level }
                    if !inLevel.isEmpty {
                        levelBlock(level, kanji: inLevel)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var savedSection: some View {
        let results = kanjiResults
        let saved = store.savedKanji.filter { trimmed.isEmpty || results.contains($0) }
        if saved.isEmpty {
            ContentUnavailableView("Nothing saved yet", systemImage: "bookmark",
                                   description: Text("Swipe left on a card while studying, or double-tap a kanji, to keep it here."))
        } else {
            VStack(alignment: .leading, spacing: Space.xl) {
                grid(saved)
                Button {
                    if let launch = store.practiceLaunch(saved.map(\.glyph)) { router.session = launch }
                } label: {
                    Label("Practice saved", systemImage: "rectangle.stack")
                }
                .buttonStyle(GlassPillStyle(prominent: true))
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func grid(_ kanji: [Kanji]) -> some View {
        LazyVGrid(columns: columns, spacing: Space.xs) {
            ForEach(kanji) { k in
                Button {
                    router.path.append(.kanji(k.glyph))
                } label: {
                    GlyphCell(kanji: k)
                }
                .buttonStyle(PressableStyle(scale: 0.92))
                .scrollTransition(.interactive, axis: .vertical) { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0.35)
                        .scaleEffect(phase.isIdentity ? 1 : 0.86)
                        .blur(radius: phase.isIdentity ? 0 : 2)
                        .offset(y: CGFloat(phase.value) * 12)
                }
            }
        }
    }

    /// A level: its name, how much of it is known (rolling up as it grows),
    /// then its kanji.
    private func levelBlock(_ level: JLPTLevel, kanji: [Kanji]) -> some View {
        let all = store.library.kanjiList(for: level)
        let known = all.filter { store.stage(of: $0.glyph) >= .known }.count
        let share: CGFloat = all.isEmpty ? 0 : CGFloat(known) / CGFloat(all.count)
        return VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.label)
                        .font(.display(.title2, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text(level.name)
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                Spacer()
                VStack(alignment: .trailing, spacing: Space.xxs + 2) {
                    Text("\(known) of \(all.count) known")
                        .font(.footnote.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink2)
                        .contentTransition(.numericText(value: Double(known)))
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.ink.opacity(0.08))
                        Capsule().fill(Palette.accent.gradient)
                            .frame(width: max(84 * share, share > 0 ? 6 : 0))
                    }
                    .frame(width: 84, height: 4)
                    .accessibilityHidden(true)
                }
            }
            grid(kanji)
        }
    }

    @ViewBuilder
    private var textsSection: some View {
        let results = passageResults
        if results.isEmpty {
            ContentUnavailableView.search(text: trimmed)
        } else {
            VStack(spacing: Space.s) {
                ForEach(results) { passage in
                    Button {
                        router.path.append(.passage(passage.id))
                    } label: {
                        PassageRow(passage: passage)
                    }
                    .buttonStyle(PressableStyle(scale: 0.98))
                    .scrollTransition(.interactive, axis: .vertical) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0.4)
                            .scaleEffect(phase.isIdentity ? 1 : 0.95)
                    }
                }
            }
        }
    }
}

/// A kanji in the library, on its own small tile. Its ink deepens as it
/// settles in memory — faint when new, full black once known — so progress
/// is visible without a single chart.
struct GlyphCell: View {
    @EnvironmentObject var store: Store
    let kanji: Kanji

    private func inkOpacity(_ stage: Stage) -> Double {
        switch stage {
        case .new: return 0.24
        case .learning: return 0.48
        case .familiar: return 0.72
        case .known, .mastered: return 1
        }
    }

    var body: some View {
        let stage = store.stage(of: kanji.glyph)
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
        Text(kanji.glyph)
            .font(.jp(30, face: store.data.settings.face, relativeTo: .title))
            .foregroundStyle(Palette.ink.opacity(inkOpacity(stage)))
            .frame(maxWidth: .infinity, minHeight: 66)
            .background {
                shape.fill(stage == .new ? Palette.card.opacity(0.55) : Palette.card)
            }
            .overlay {
                shape.stroke(Palette.edge, lineWidth: 1)
            }
            .overlay(alignment: .topTrailing) {
                if store.isSaved(kanji.glyph) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Palette.accent)
                        .padding(7)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(.hoverEffect, shape)
            .hoverEffect(.lift)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(kanji.glyph), \(kanji.primaryMeaning)")
            .accessibilityValue(stage.title)
            .accessibilityAddTraits(.isButton)
    }
}

/// A reading text on its own sheet: genre, title, translation, and a ring
/// showing how much of its kanji you already know.
struct PassageRow: View {
    @EnvironmentObject var store: Store
    let passage: Passage

    var body: some View {
        HStack(alignment: .center, spacing: Space.m) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Caption(text: passage.genre)
                Text(Ruby.plain(passage.title))
                    .font(.jp(20, bold: true, relativeTo: .title3))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                Text(passage.titleEN)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(2)
            }
            Spacer(minLength: Space.s)
            CoverageRing(value: store.coverage(of: passage))
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.ink3)
        }
        .padding(Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(SheetSurface())
        .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hoverEffect(.lift)
        .accessibilityElement(children: .combine)
    }
}

/// A small ring for "how much of this is known".
struct CoverageRing: View {
    let value: Double

    var body: some View {
        let share = CGFloat(min(max(value, 0), 1))
        ZStack {
            Circle()
                .stroke(Palette.ink.opacity(0.08), lineWidth: 4)
            Circle()
                .trim(from: 0, to: share)
                .stroke(Palette.accent.gradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(Format.percent(value))
                .font(.figure(.caption2, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Palette.ink2)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 46, height: 46)
        .accessibilityElement()
        .accessibilityLabel("\(Format.percent(value)) of its kanji known")
    }
}

struct KanjiView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let glyph: String
    @State private var confirmReset = false

    private var saved: Bool { store.isSaved(glyph) }

    var body: some View {
        ScrollView {
            KanjiArticle(glyph: glyph, detailed: true)
                .padding(.horizontal, Space.l)
                .padding(.top, Space.s)
                .padding(.bottom, Space.xxxl)
                .readableColumn()
        }
        .background(Palette.paper)
        .navigationTitle(glyph)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    withAnimation(Motion.flick) { store.toggleSaved(glyph) }
                    Haptics.saved()
                } label: {
                    Label(saved ? "Remove from saved" : "Save", systemImage: saved ? "bookmark.fill" : "bookmark")
                        .contentTransition(.symbolEffect(.replace))
                }
                Menu {
                    menuItems
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
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
                if let launch = store.practiceLaunch([glyph]) { router.session = launch }
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
                .padding(.top, Space.s)
                .padding(.bottom, Space.xxxl)
                .readableColumn()
            }
            .background(Palette.paper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Speaker.shared.say(passage.lines.map { Ruby.spoken($0.jp) }.joined(separator: "\n"))
                    } label: {
                        Label("Listen", systemImage: "speaker.wave.2")
                    }
                    Button {
                        withAnimation(Motion.settle) { showTranslation.toggle() }
                    } label: {
                        Label(showTranslation ? "Hide translation" : "Show translation",
                              systemImage: showTranslation ? "character.bubble.fill" : "character.bubble")
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
            }
            .sheet(item: $lookup) { unit in
                WordSheet(unit: unit)
                    .environmentObject(store)
                    .presentationDetents([.medium])
                    .presentationCornerRadius(Radius.sheet)
            }
            .onDisappear {
                if passage.question == nil { store.markRead(passage.id) }
            }
        } else {
            ContentUnavailableView("Text not found", systemImage: "doc.text")
        }
    }

    private func header(_ passage: Passage) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: Space.xs) {
                Caption(text: passage.genre, color: Palette.accent)
                Text("·")
                    .foregroundStyle(Palette.ink3)
                Caption(text: passage.level.label)
            }
            RubyText(markup: passage.title, size: 30)
            Text(passage.titleEN)
                .font(.display(.title3, weight: .regular))
                .foregroundStyle(Palette.ink2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func lines(_ passage: Passage) -> some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            ForEach(Array(passage.lines.enumerated()), id: \.offset) { _, line in
                VStack(alignment: .leading, spacing: Space.xs) {
                    if let speaker = line.speaker {
                        Text(Ruby.plain(speaker))
                            .font(.jp(13, bold: true, relativeTo: .caption))
                            .foregroundStyle(Palette.accent)
                    }
                    RubyText(markup: line.jp, size: 21, onTap: { lookup = $0 })
                    if showTranslation {
                        Text(line.en)
                            .font(.subheadline)
                            .foregroundStyle(Palette.ink2)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.blurFade)
                    }
                }
            }
        }
    }

    private func notesView(_ notes: [PassageNote]) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Caption(text: "Notes")
            VStack(alignment: .leading, spacing: Space.l) {
                ForEach(notes, id: \.self) { note in
                    HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                        Image(systemName: note.symbol)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.accent)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: Space.xxs) {
                            Text(note.lens)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Palette.ink)
                            MixedText(note.text, style: .subheadline)
                                .foregroundStyle(Palette.ink2)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(SheetSurface())
        }
    }

    private func questionView(_ question: Question, passage: Passage) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Caption(text: "Check your reading")
            MixedText(question.prompt, style: .headline, bold: true)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: Space.xs) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                    optionButton(option, index: index, question: question, passage: passage)
                }
            }
            if let picked = choice, let explanation = question.explanation {
                MixedText((picked == question.answer ? "Right. " : "Not quite. ") + explanation, style: .subheadline)
                    .foregroundStyle(Palette.ink2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.blurFade)
            }
        }
    }

    /// An answer on its own sheet. Once one is chosen, the right answer
    /// turns green with a check, a wrong pick turns red, the rest step back.
    private func optionButton(_ option: String, index: Int, question: Question, passage: Passage) -> some View {
        let answered = choice != nil
        let isRight = index == question.answer
        let picked = choice == index
        let tint: Color = answered && isRight ? Palette.matcha : (picked ? Palette.shu : Palette.ink)
        let symbol: String = answered && isRight ? "checkmark.circle.fill" : (picked ? "xmark.circle.fill" : "circle")
        return Button {
            guard choice == nil else { return }
            withAnimation(Motion.flick) { choice = index }
            store.markRead(passage.id)
            if isRight { Haptics.success() } else { Haptics.error() }
        } label: {
            HStack(spacing: Space.s) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(answered ? tint : Palette.ink3)
                    .contentTransition(.symbolEffect(.replace))
                MixedText(option, style: .body)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Space.m)
            .padding(.vertical, Space.s)
            .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .fill(answered && (isRight || picked) ? tint.opacity(0.1) : Palette.card)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .stroke(answered && (isRight || picked) ? tint.opacity(0.5) : Palette.edge, lineWidth: 1)
            }
            .opacity(answered && !isRight && !picked ? 0.55 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.98))
        .disabled(answered)
        .accessibilityAddTraits(picked ? .isSelected : [])
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
    @State private var voices: [AVSpeechSynthesisVoice] = Speaker.japaneseVoices

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
                aboutHeader
                studySection
                displaySection
                soundSection
                reminderSection
                librarySection
                infoSection
                resetSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: store.data.settings.voiceID) { _, id in previewVoice(id) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
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
        .preferredColorScheme(store.data.settings.appearance.scheme)
    }

    // MARK: Sections

    /// The mark and a one-line summary of where you are, like the account
    /// card at the top of the Settings app.
    private var aboutHeader: some View {
        Section {
            HStack(spacing: Space.m) {
                SumiMark(size: 56, delay: 0.2)
                    .padding(4)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Palette.edge, lineWidth: 1)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sumi")
                        .font(.display(.title2, weight: .bold))
                    Text(progressLine)
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink2)
                }
            }
            .padding(.vertical, Space.xxs)
            .accessibilityElement(children: .combine)
        }
    }

    private var progressLine: String {
        let started = store.library.kanji.filter { store.isStarted($0.glyph) }.count
        let total = store.library.kanji.count
        return "\(started) of \(total) kanji started"
    }

    private var studySection: some View {
        Section {
            Picker(selection: $store.data.settings.newPerDay) {
                ForEach(paceOptions, id: \.self) { n in
                    Text(n == 0 ? "Paused" : "\(n)").tag(n)
                }
            } label: {
                row("New kanji a day", symbol: "sparkles", color: Palette.accent)
            }
            Toggle(isOn: $store.data.settings.writing) {
                row("Writing practice", symbol: "pencil.and.scribble", color: Palette.murasaki)
            }
            Toggle(isOn: $store.data.settings.typeReadings) {
                row("Type readings", symbol: "keyboard", color: Palette.asagi)
            }
        } header: {
            Text("Study")
        } footer: {
            Text("Reviews always come before new kanji. Writing unlocks for each kanji once you recognize it reliably.")
        }
    }

    private var displaySection: some View {
        Section {
            Picker(selection: $store.data.settings.appearance) {
                ForEach(Appearance.allCases) { option in
                    Text(option.title).tag(option)
                }
            } label: {
                row("Appearance", symbol: "circle.lefthalf.filled", color: Color.gray)
            }
            Picker(selection: $store.data.settings.face) {
                ForEach(JPFace.allCases) { face in
                    Text(face.title).tag(face)
                }
            } label: {
                row("Typeface", symbol: "textformat", color: Palette.ink2)
            }
            Picker(selection: $store.data.settings.furigana) {
                ForEach(FuriganaMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            } label: {
                row("Furigana", symbol: "character.textbox", color: Palette.kohaku)
            }
        } header: {
            Text("Display")
        } footer: {
            Text(store.data.settings.furigana.detail)
        }
    }

    private var soundSection: some View {
        Section {
            Toggle(isOn: $store.data.settings.autoSpeak) {
                row("Play audio", symbol: "speaker.wave.2.fill", color: Palette.shu)
            }
            if !voices.isEmpty {
                Picker(selection: $store.data.settings.voiceID) {
                    Text("Automatic").tag("")
                    ForEach(voices, id: \.identifier) { voice in
                        Text(voiceName(voice)).tag(voice.identifier)
                    }
                } label: {
                    row("Voice", symbol: "waveform", color: Palette.sakura)
                }
            }
            if Haptics.isSupported {
                Toggle(isOn: $store.data.settings.haptics) {
                    row("Haptics", symbol: "iphone.radiowaves.left.and.right", color: Palette.matcha)
                }
            }
        } header: {
            Text("Sound and touch")
        } footer: {
            Text("For the most natural Japanese, download an Enhanced or Premium voice in Settings › Accessibility › Spoken Content › Voices.")
        }
    }

    private var reminderSection: some View {
        Section {
            Toggle(isOn: reminderBinding) {
                row("Daily reminder", symbol: "bell.badge.fill", color: Palette.shu)
            }
            if store.data.settings.reminder {
                DatePicker(selection: reminderTime, displayedComponents: .hourAndMinute) {
                    row("Time", symbol: "clock.fill", color: Palette.kohaku)
                }
            }
        } footer: {
            Text("The reminder says exactly how many reviews are waiting, and is never sent when there's nothing to do.")
        }
    }

    private var librarySection: some View {
        Section {
            Button {
                showKnownPicker = true
            } label: {
                row("Mark kanji I know", symbol: "checkmark.seal.fill", color: Palette.matcha)
            }
            Button {
                importing = true
            } label: {
                row("Import", symbol: "square.and.arrow.down.fill", color: Palette.accent)
            }
            Button {
                exportDocument = BackupDocument(data: store.exportData())
                exporting = true
            } label: {
                row("Export backup", symbol: "square.and.arrow.up.fill", color: Palette.asagi)
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
        } header: {
            Text("Library")
        }
        .foregroundStyle(Palette.ink)
    }

    private var infoSection: some View {
        Section {
            NavigationLink {
                AboutView()
            } label: {
                row("How Sumi works", symbol: "book.closed.fill", color: Palette.murasaki)
            }
            NavigationLink {
                PrivacyView()
            } label: {
                row("Privacy", symbol: "hand.raised.fill", color: Palette.accent)
            }
        }
    }

    private var resetSection: some View {
        Section {
            Button("Reset progress", role: .destructive) { confirmReset = true }
        } footer: {
            Text("Sumi 1.0 · Stroke order from KanjiVG")
                .frame(maxWidth: .infinity)
                .padding(.top, Space.l)
        }
    }

    /// A Settings row: a colored tile, then the title.
    private func row(_ title: String, symbol: String, color: Color) -> some View {
        Label {
            Text(title)
                .foregroundStyle(Palette.ink)
        } icon: {
            SettingsIcon(symbol: symbol, color: color)
        }
    }

    private func voiceName(_ voice: AVSpeechSynthesisVoice) -> String {
        "\(voice.name) · \(Speaker.qualityName(voice.quality))"
    }

    /// Picking a voice plays it, as in Spoken Content settings.
    private func previewVoice(_ id: String) {
        Speaker.preferredVoiceID = id
        Speaker.shared.say("こんにちは")
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
            .background(Palette.paper)
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
                            .background(isOn ? Palette.accent : Palette.card,
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
        let symbol: String
        let title: String
        let text: String
        var id: String { title }
    }

    private let points: [Point] = [
        Point(symbol: "clock.arrow.circlepath", title: "Reviews arrive just before you'd forget",
              text: "A memory model (FSRS-6) estimates how well you hold each kanji and schedules the next review for when recall drops to about 90%."),
        Point(symbol: "brain", title: "You always answer first",
              text: "Recalling an answer strengthens memory far more than re-reading it."),
        Point(symbol: "hand.thumbsup", title: "Three honest answers",
              text: "Swiping up means you knew it. Swipe right when you didn't, or double-tap when it was effortless and the next review moves further out."),
        Point(symbol: "text.word.spacing", title: "Readings live in words",
              text: "A kanji alone rarely has one right reading, so readings are practiced inside real words."),
        Point(symbol: "pencil.and.outline", title: "Recognize, then read, then write",
              text: "Writing unlocks once you recognize a kanji reliably. Write it in the air or on paper, then reveal it to check the strokes."),
        Point(symbol: "flame", title: "Small wins, no pressure",
              text: "Runs of first-try answers build a combo. Miss one and it quietly resets; there are no streaks to lose."),
        Point(symbol: "book", title: "Real Japanese",
              text: "Every kanji comes with words and a sentence, and short texts show furigana only above kanji you haven't learned."),
        Point(symbol: "lightbulb", title: "Mistakes are noticed for you",
              text: "Near misses get a hint and a second try. Kanji you keep forgetting automatically get more support.")
    ]

    private let gestures: [Point] = [
        Point(symbol: "hand.tap", title: "Tap", text: "Reveal, then hear it again"),
        Point(symbol: "arrow.up", title: "Swipe up", text: "Next (counts as known)"),
        Point(symbol: "arrow.down", title: "Swipe down", text: "Back to the previous card"),
        Point(symbol: "arrow.right", title: "Swipe right", text: "Forgot"),
        Point(symbol: "arrow.left", title: "Swipe left", text: "Save for later"),
        Point(symbol: "heart", title: "Double-tap", text: "Easy — or “I know this” on a new kanji"),
        Point(symbol: "hand.point.up.left", title: "Hold", text: "Stroke order and sound"),
        Point(symbol: "arrow.down.right.and.arrow.up.left", title: "Pinch", text: "Close")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xxl) {
                header
                gestureCard
                ForEach(points) { point in
                    pointRow(point)
                        .scrollTransition(.interactive, axis: .vertical) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0.3)
                                .offset(y: CGFloat(phase.value) * 18)
                        }
                }
                credits
            }
            .padding(.horizontal, Space.l)
            .padding(.vertical, Space.l)
            .readableColumn()
        }
        .background(Palette.paper)
        .navigationTitle("How Sumi works")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: Space.m) {
            SumiMark(size: 120, delay: 0.3)
            Text("Ink, a little each day.")
                .font(.display(.title, weight: .bold))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
            Text("Sumi keeps the schedule, the pacing and the bookkeeping out of sight, so each screen asks for one thing.")
                .font(.body)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.s)
    }

    private var gestureCard: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Caption(text: "Gestures")
            VStack(spacing: 0) {
                ForEach(gestures) { gesture in
                    gestureRow(gesture)
                    if gesture.id != gestures.last?.id {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .modifier(SheetSurface())
            Text("Every gesture also has a VoiceOver action and a keyboard key: Space or Return, the arrow keys, E for easy, P for strokes and Esc to close.")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func gestureRow(_ gesture: Point) -> some View {
        HStack(spacing: Space.m) {
            Image(systemName: gesture.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: 28)
            Text(gesture.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
            Spacer(minLength: Space.s)
            Text(gesture.text)
                .font(.subheadline)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, Space.m)
        .frame(minHeight: Metrics.minTap + 4)
        .accessibilityElement(children: .combine)
    }

    private func pointRow(_ point: Point) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
            Image(systemName: point.symbol)
                .font(.title3.weight(.medium))
                .foregroundStyle(Palette.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(point.title)
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                Text(point.text)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var credits: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Stroke order data: KanjiVG by Ulrich Apel and contributors (kanjivg.tagaini.net), licensed CC BY-SA 3.0.")
            Text("JLPT levels are a study guide. The JLPT hasn't published official kanji lists since 2010; Sumi isn't affiliated with the Japan Foundation or JEES.")
        }
        .font(.footnote)
        .foregroundStyle(Palette.ink2)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, Space.s)
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
        .background(Palette.paper)
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: Onboarding

/// A short story told with the app's own gesture: swipe up. Four pages —
/// the mark writes itself, memory is drawn, the gestures introduce
/// themselves, then a pace is picked — and on the last page the whole sheet
/// lifts away under the finger like the Lock Screen, uncovering Home.
struct OnboardingView: View {
    @EnvironmentObject var store: Store
    @State private var page = 0
    @State private var drag: CGFloat = 0
    @State private var height: CGFloat = 900
    @State private var pace: Int? = 10
    @State private var showPicker = false
    @State private var markedKnown = false
    @State private var leaving = false
    @State private var gone = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let pageCount = 4
    private var lastPage: Int { OnboardingView.pageCount - 1 }
    /// On the last page, a swipe up moves the whole sheet, not the pages.
    private var exiting: Bool { page == lastPage && drag < 0 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AmbientBackground()
                ForEach(0..<OnboardingView.pageCount, id: \.self) { index in
                    panel(index, position: position(of: index, height: geo.size.height))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .offset(y: panelOffset(index, height: geo.size.height))
                        .accessibilityHidden(index != page)
                }
                PageDots(count: OnboardingView.pageCount, current: page)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .padding(.trailing, Space.s)
            }
            .offset(y: exiting ? drag : 0)
            .opacity(gone ? 0 : 1)
            .contentShape(Rectangle())
            .gesture(storyGesture)
            .onAppear { height = geo.size.height }
            .onChange(of: geo.size.height) { _, newHeight in height = newHeight }
        }
        .background(keys)
        .accessibilityScrollAction { edge in
            switch edge {
            case .bottom: forward()
            case .top: back()
            default: break
            }
        }
        .presentationBackground(Color.clear)
        .interactiveDismissDisabled()
        .preferredColorScheme(store.data.settings.appearance.scheme)
        .sheet(isPresented: $showPicker, onDismiss: {
            if markedKnown { begin() }
        }) {
            KnownPickerView(onConfirm: { markedKnown = true })
                .environmentObject(store)
        }
    }

    // MARK: Paging

    /// 0 when a page is centred, −1 one page above, +1 one page below.
    private func position(of index: Int, height: CGFloat) -> CGFloat {
        let shift: CGFloat = exiting ? 0 : drag
        return CGFloat(index - page) + shift / max(height, 1)
    }

    private func panelOffset(_ index: Int, height: CGFloat) -> CGFloat {
        let shift: CGFloat = exiting ? 0 : drag
        return CGFloat(index - page) * height + shift
    }

    private var storyGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !leaving else { return }
                let t = value.translation.height
                drag = page == 0 && t > 0 ? Motion.rubberband(t, dimension: height) : t
            }
            .onEnded { value in
                guard !leaving else { return }
                let projected = value.translation.height + Motion.project(value.velocity.height)
                let threshold = height * 0.22
                if projected < -threshold && value.velocity.height < 300 {
                    if page == lastPage {
                        begin(velocity: value.velocity.height)
                    } else {
                        turn(to: page + 1, velocity: value.velocity.height)
                    }
                } else if projected > threshold && page > 0 && value.velocity.height > -300 {
                    turn(to: page - 1, velocity: value.velocity.height)
                } else {
                    withAnimation(Motion.flick) { drag = 0 }
                }
            }
    }

    /// Changes page without a jump: the drag is re-expressed relative to the
    /// new page, then springs to rest at the finger's speed.
    private func turn(to target: Int, velocity: CGFloat = 0) {
        guard target >= 0, target <= lastPage, target != page else { return }
        drag += CGFloat(target - page) * height
        page = target
        let remaining = -drag
        let relative = remaining == 0 ? 0 : Double(velocity / remaining)
        Haptics.snap()
        withAnimation(reduceMotion ? Animation.easeOut(duration: 0.25) : Motion.page(velocity: max(relative, 0))) {
            drag = 0
        }
    }

    private func forward() {
        if page == lastPage { begin() } else { turn(to: page + 1) }
    }

    private func back() {
        turn(to: page - 1)
    }

    private var keys: some View {
        ZStack {
            Button("") { forward() }
                .keyboardShortcut(.defaultAction)
            Button("") { forward() }
                .keyboardShortcut(.downArrow, modifiers: [])
            Button("") { back() }
                .keyboardShortcut(.upArrow, modifiers: [])
        }
        .opacity(0)
        .accessibilityHidden(true)
    }

    // MARK: Pages

    @ViewBuilder
    private func panel(_ index: Int, position: CGFloat) -> some View {
        switch index {
        case 0: markPage(position)
        case 1: memoryPage(position)
        case 2: handsPage(position)
        default: pacePage(position)
        }
    }

    /// How present a page is: 1 when centred, 0 a page away.
    private func presence(_ position: CGFloat) -> Double {
        Double(max(0, 1 - abs(position)))
    }

    /// Elements drift at their own speeds as pages move (parallax).
    private func drift(_ position: CGFloat, _ rate: CGFloat) -> CGFloat {
        reduceMotion ? 0 : -position * height * rate
    }

    private func headline(_ title: String, body: String, position: CGFloat) -> some View {
        VStack(spacing: Space.s) {
            Text(title)
                .font(.display(.largeTitle, weight: .bold))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(body)
                .font(.body)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Space.xl)
        .readableColumn()
        .offset(y: drift(position, -0.08))
        .opacity(presence(position))
    }

    private func markPage(_ position: CGFloat) -> some View {
        VStack(spacing: Space.xxl) {
            Spacer()
            SumiMark(size: 168, delay: 0.5)
                .offset(y: drift(position, 0.25))
                .scaleEffect(1 - abs(position) * 0.15)
            VStack(spacing: Space.xs) {
                Text("Sumi")
                    .font(.display(.largeTitle, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Text("Kanji, one quiet step at a time.")
                    .font(.title3)
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
            }
            .opacity(presence(position))
            Spacer()
            ShimmerText(text: "Swipe up")
                .padding(.bottom, Space.xxl)
                .opacity(presence(position))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Space.l)
    }

    private func memoryPage(_ position: CGFloat) -> some View {
        VStack(spacing: Space.xxl) {
            Spacer()
            MemoryCurve(progress: presence(position))
                .frame(height: 170)
                .frame(maxWidth: 420)
                .padding(.horizontal, Space.xl)
                .offset(y: drift(position, 0.3))
            headline("Just before you'd forget",
                     body: "Each kanji comes back at the moment it starts to fade, so every review counts. A few minutes a day is enough.",
                     position: position)
            Spacer()
        }
    }

    private func handsPage(_ position: CGFloat) -> some View {
        VStack(spacing: Space.xxl) {
            Spacer()
            headline("Your hands already know how",
                     body: "No buttons. The card is the control.",
                     position: position)
            GestureList(presence: presence(position), active: page == 2)
                .frame(maxWidth: 400)
                .padding(.horizontal, Space.l)
                .offset(y: drift(position, 0.18))
            Spacer()
        }
    }

    private func pacePage(_ position: CGFloat) -> some View {
        VStack(spacing: Space.xl) {
            Spacer()
            headline("How many new kanji a day?",
                     body: "Reviews always come first. You can change this any time in Settings.",
                     position: position)
            PaceCarousel(selection: $pace, options: [3, 5, 10, 15, 20, 30])
                .offset(y: drift(position, 0.2))
                .opacity(presence(position))
            Button {
                showPicker = true
            } label: {
                Label("I already know some kanji", systemImage: "checkmark.circle")
            }
            .buttonStyle(GlassPillStyle())
            .opacity(presence(position))
            Spacer()
            ShimmerText(text: "Swipe up to begin")
                .padding(.bottom, Space.xxl)
                .opacity(presence(position))
                .contentShape(Rectangle())
                .onTapGesture { begin() }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Begin"))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { begin() }
        }
    }

    // MARK: Leaving

    private func begin(velocity: CGFloat = 0) {
        guard !leaving else { return }
        leaving = true
        store.data.settings.newPerDay = pace ?? 10
        Haptics.snap()
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.25)) { gone = true } completion: { finish() }
            return
        }
        if page != lastPage {
            page = lastPage
            drag = 0
        }
        let target = -(height * 1.2)
        let remaining = target - min(drag, 0)
        let relative = remaining == 0 ? 0 : Double(velocity / remaining)
        withAnimation(Motion.page(velocity: max(relative, 0))) {
            drag = min(target, -1)
        } completion: {
            finish()
        }
    }

    /// The sheet has already gone, so the cover leaves without a slide.
    private func finish() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { store.data.onboarded = true }
    }
}

/// The spacing effect, drawn: memory fades after each review, and each
/// review — timed just before it fades too far — makes it fade more
/// slowly. The line writes itself as its page arrives.
struct MemoryCurve: View {
    var progress: Double

    private static let reviews: [CGFloat] = [0.2, 0.43, 0.7]
    private static let decay: [Double] = [5.2, 3.0, 1.7, 0.9]

    var body: some View {
        Canvas { context, size in
            let curve = MemoryCurve.curve(in: size)
            let baseline = Path { p in
                p.move(to: CGPoint(x: 0, y: size.height - 1))
                p.addLine(to: CGPoint(x: size.width, y: size.height - 1))
            }
            context.stroke(baseline, with: .color(Palette.hairline), lineWidth: 1)
            let shown = CGFloat(min(max(progress, 0), 1))
            let drawn = curve.trimmedPath(from: 0, to: shown)
            context.stroke(drawn, with: .color(Palette.accent.opacity(0.15)),
                           style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
            context.stroke(drawn, with: .color(Palette.accent),
                           style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            for (index, x) in MemoryCurve.reviews.enumerated() where x < shown {
                let center = CGPoint(x: x * size.width, y: MemoryCurve.y(1, height: size.height))
                let r: CGFloat = 6
                context.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                             with: .color(Palette.card))
                context.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                               with: .color(Palette.accent), lineWidth: 2.5)
                let label = context.resolve(Text("review \(index + 1)")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Palette.ink2))
                context.draw(label, at: CGPoint(x: center.x, y: center.y - 16), anchor: .bottom)
            }
            if let tip = drawn.currentPoint, shown > 0, shown < 1 {
                let r: CGFloat = 9
                context.fill(Path(ellipseIn: CGRect(x: tip.x - r, y: tip.y - r, width: r * 2, height: r * 2)),
                             with: .radialGradient(Gradient(colors: [Palette.accent.opacity(0.5), Palette.accent.opacity(0)]),
                                                   center: tip, startRadius: 0, endRadius: r))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("A memory curve: recall fades between reviews, and fades more slowly after each one.")
    }

    private static func y(_ recall: Double, height: CGFloat) -> CGFloat {
        let top = height * 0.18
        let usable = height * 0.78
        return top + CGFloat(1 - recall) * usable
    }

    private static func curve(in size: CGSize) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: y(1, height: size.height)))
        let ends: [CGFloat] = reviews + [1]
        var start: CGFloat = 0
        for (index, end) in ends.enumerated() {
            let steps = 28
            for step in 1...steps {
                let x = start + (end - start) * CGFloat(step) / CGFloat(steps)
                let recall = exp(-Double(x - start) * decay[index])
                path.addLine(to: CGPoint(x: x * size.width, y: y(recall, height: size.height)))
            }
            if index < ends.count - 1 {
                path.addLine(to: CGPoint(x: end * size.width, y: y(1, height: size.height)))
            }
            start = end
        }
        return path
    }
}

/// The gesture vocabulary, each row arriving in turn as its page settles.
struct GestureList: View {
    let presence: Double
    let active: Bool

    private struct Row: Identifiable {
        let id: Int
        let symbol: String
        let gesture: String
        let action: String
    }

    private let rows: [Row] = [
        Row(id: 0, symbol: "hand.tap.fill", gesture: "Tap", action: "Reveal the answer"),
        Row(id: 1, symbol: "arrow.up", gesture: "Swipe up", action: "Next card"),
        Row(id: 2, symbol: "arrow.right", gesture: "Swipe right", action: "Forgot"),
        Row(id: 3, symbol: "arrow.left", gesture: "Swipe left", action: "Save for later"),
        Row(id: 4, symbol: "heart.fill", gesture: "Double-tap", action: "Easy"),
        Row(id: 5, symbol: "hand.point.up.left.fill", gesture: "Hold", action: "Strokes and sound")
    ]

    var body: some View {
        VStack(spacing: Space.xs) {
            ForEach(rows) { row in
                rowView(row)
            }
        }
    }

    private func rowView(_ row: Row) -> some View {
        let appear = min(max(presence * 2.2 - Double(row.id) * 0.18, 0), 1)
        return HStack(spacing: Space.m) {
            Image(systemName: row.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.accent)
                .symbolEffect(.bounce, value: active)
                .frame(width: 40, height: 40)
                .glassBackground(Circle())
            Text(row.gesture)
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.ink)
            Spacer(minLength: Space.s)
            Text(row.action)
                .font(.subheadline)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 2)
        .opacity(appear)
        .offset(x: CGFloat(1 - appear) * 24)
        .accessibilityElement(children: .combine)
    }
}

/// A horizontal wheel of numbers. The centred one is chosen; the others
/// turn away in 3D, shrink and soften. Swipe, tap a number, or use
/// VoiceOver's adjust gesture.
struct PaceCarousel: View {
    @Binding var selection: Int?
    let options: [Int]
    private let itemWidth: CGFloat = 78

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(options, id: \.self) { value in
                            item(value)
                                .id(value)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, max((geo.size.width - itemWidth) / 2, 0), for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $selection)
                .onAppear {
                    if let value = selection { proxy.scrollTo(value, anchor: .center) }
                }
            }
        }
        .frame(height: 100)
        .overlay(alignment: .bottom) {
            Capsule()
                .fill(Palette.accent)
                .frame(width: 22, height: 4)
                .allowsHitTesting(false)
        }
        .onChange(of: selection) { _, _ in Haptics.tick() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("New kanji a day")
        .accessibilityValue("\(selection ?? 10)")
        .accessibilityAdjustableAction { direction in
            let current = options.firstIndex(of: selection ?? 10) ?? 0
            switch direction {
            case .increment: selection = options[min(current + 1, options.count - 1)]
            case .decrement: selection = options[max(current - 1, 0)]
            @unknown default: break
            }
        }
    }

    private func item(_ value: Int) -> some View {
        Text("\(value)")
            .font(.figure(.largeTitle, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(Palette.accent)
            .frame(width: itemWidth, height: 92)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(Motion.settle) { selection = value }
            }
            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                content
                    .rotation3DEffect(.degrees(phase.value * -55), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                    .scaleEffect(CGFloat(1 - abs(phase.value) * 0.35))
                    .opacity(1 - abs(phase.value) * 0.6)
                    .blur(radius: CGFloat(abs(phase.value) * 1.5))
            }
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


// MARK: Stroke order

/// Parses SVG path data (the KanjiVG subset: M, L, H, V, C, S, Q, T, Z in
/// absolute and relative forms) into a SwiftUI path in a 109 × 109 box.
enum SVGPath {
    private enum Token {
        case command(Character)
        case number(Double)
    }

    private static func tokenize(_ d: String) -> [Token] {
        var tokens: [Token] = []
        var buffer = ""
        var seenDot = false

        func flush() {
            if !buffer.isEmpty, let value = Double(buffer) { tokens.append(.number(value)) }
            buffer = ""
            seenDot = false
        }

        for ch in d {
            if ch.isLetter && ch != "e" && ch != "E" {
                flush()
                tokens.append(.command(ch))
            } else if ch == "-" || ch == "+" {
                if let last = buffer.last, last == "e" || last == "E" {
                    buffer.append(ch)
                } else {
                    flush()
                    buffer.append(ch)
                }
            } else if ch == "." {
                if seenDot { flush() }
                buffer.append(ch)
                seenDot = true
            } else if ch.isASCII && ch.isNumber {
                buffer.append(ch)
            } else if ch == "e" || ch == "E" {
                buffer.append(ch)
            } else {
                flush()
            }
        }
        flush()
        return tokens
    }

    static func parse(_ d: String) -> Path {
        let tokens = tokenize(d)
        var path = Path()
        var i = 0
        var command: Character = "M"
        var current = CGPoint.zero
        var start = CGPoint.zero
        var lastCubic: CGPoint? = nil
        var lastQuad: CGPoint? = nil

        func read(_ count: Int) -> [CGFloat]? {
            guard i + count <= tokens.count else { return nil }
            var values: [CGFloat] = []
            for offset in 0..<count {
                guard case .number(let value) = tokens[i + offset] else { return nil }
                values.append(CGFloat(value))
            }
            i += count
            return values
        }

        func skipJunk() {
            if i < tokens.count, case .number = tokens[i] { i += 1 }
        }

        while i < tokens.count {
            if case .command(let c) = tokens[i] {
                command = c
                i += 1
            }
            let relative = command.isLowercase
            let base = relative ? current : .zero
            switch command {
            case "M", "m":
                guard let v = read(2) else { skipJunk(); continue }
                let p = CGPoint(x: base.x + v[0], y: base.y + v[1])
                path.move(to: p)
                current = p
                start = p
                lastCubic = nil
                lastQuad = nil
                command = relative ? "l" : "L"
            case "L", "l":
                guard let v = read(2) else { skipJunk(); continue }
                let p = CGPoint(x: base.x + v[0], y: base.y + v[1])
                path.addLine(to: p)
                current = p
                lastCubic = nil
                lastQuad = nil
            case "H", "h":
                guard let v = read(1) else { skipJunk(); continue }
                let p = CGPoint(x: (relative ? current.x : 0) + v[0], y: current.y)
                path.addLine(to: p)
                current = p
                lastCubic = nil
                lastQuad = nil
            case "V", "v":
                guard let v = read(1) else { skipJunk(); continue }
                let p = CGPoint(x: current.x, y: (relative ? current.y : 0) + v[0])
                path.addLine(to: p)
                current = p
                lastCubic = nil
                lastQuad = nil
            case "C", "c":
                guard let v = read(6) else { skipJunk(); continue }
                let c1 = CGPoint(x: base.x + v[0], y: base.y + v[1])
                let c2 = CGPoint(x: base.x + v[2], y: base.y + v[3])
                let p = CGPoint(x: base.x + v[4], y: base.y + v[5])
                path.addCurve(to: p, control1: c1, control2: c2)
                current = p
                lastCubic = c2
                lastQuad = nil
            case "S", "s":
                guard let v = read(4) else { skipJunk(); continue }
                let reflected = lastCubic.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                let c2 = CGPoint(x: base.x + v[0], y: base.y + v[1])
                let p = CGPoint(x: base.x + v[2], y: base.y + v[3])
                path.addCurve(to: p, control1: reflected, control2: c2)
                current = p
                lastCubic = c2
                lastQuad = nil
            case "Q", "q":
                guard let v = read(4) else { skipJunk(); continue }
                let c = CGPoint(x: base.x + v[0], y: base.y + v[1])
                let p = CGPoint(x: base.x + v[2], y: base.y + v[3])
                path.addQuadCurve(to: p, control: c)
                current = p
                lastQuad = c
                lastCubic = nil
            case "T", "t":
                guard let v = read(2) else { skipJunk(); continue }
                let c = lastQuad.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                let p = CGPoint(x: base.x + v[0], y: base.y + v[1])
                path.addQuadCurve(to: p, control: c)
                current = p
                lastQuad = c
                lastCubic = nil
            case "Z", "z":
                path.closeSubpath()
                current = start
                lastCubic = nil
                lastQuad = nil
                if i < tokens.count, case .number = tokens[i] { command = "L" }
            default:
                skipJunk()
            }
        }
        return path
    }
}

/// Draws a kanji stroke by stroke: finished strokes in ink, the stroke
/// being written in the accent with a soft bloom and a wet tip, the rest as
/// a faint guide.
struct StrokeOrderView: View {
    private let strokes: [Path]
    let playing: Bool
    var loops: Bool
    @State private var start = Date()

    static let perStroke: Double = 0.42

    init(paths: [String], playing: Bool, loops: Bool = true) {
        self.strokes = paths.map { SVGPath.parse($0) }
        self.playing = playing
        self.loops = loops
    }

    static func duration(for strokeCount: Int) -> Double {
        Double(strokeCount) * perStroke + 0.6
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !playing)) { timeline in
            Canvas { context, size in
                StrokePainter.draw(&context, size: size, strokes: strokes,
                                   progress: progress(at: timeline.date))
            }
        }
        .onAppear { start = Date() }
        .onChange(of: playing) { _, isPlaying in
            if isPlaying { start = Date() }
        }
        .accessibilityElement()
        .accessibilityLabel("Stroke order, \(strokes.count) strokes")
    }

    private func progress(at date: Date) -> Double {
        let count = Double(strokes.count)
        guard playing else { return count }
        let elapsed = date.timeIntervalSince(start) / StrokeOrderView.perStroke
        return loops ? elapsed.truncatingRemainder(dividingBy: count + 1.5) : min(elapsed, count)
    }
}

/// A kanji glyph that turns into its stroke-order animation while playing,
/// crossfading with a slight blur so the swap reads as ink, not a cut.
struct StrokeGlyph: View {
    @EnvironmentObject var store: Store
    let kanji: Kanji
    let size: CGFloat
    var playing = false
    var loops = true

    var body: some View {
        ZStack {
            if playing && !kanji.strokePaths.isEmpty {
                StrokeOrderView(paths: kanji.strokePaths, playing: true, loops: loops)
                    .frame(width: size, height: size)
                    .transition(.blurFade)
            } else {
                Text(kanji.glyph)
                    .font(.jpFixed(size, face: store.data.settings.face))
                    .foregroundStyle(Palette.ink)
                    .transition(.blurFade)
            }
        }
        .frame(width: size * 1.1, height: size * 1.1)
        .animation(.easeInOut(duration: 0.2), value: playing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Kanji \(kanji.glyph)")
    }
}

/// The bookmark that pops when something is saved, with a ring of light.
struct SaveBurst: View {
    let saved: Bool
    @State private var pop = false
    @State private var ring = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.accent.opacity(ring ? 0 : 0.4), lineWidth: ring ? 1 : 6)
                .frame(width: 96, height: 96)
                .scaleEffect(ring ? 1.9 : 0.5)
            Image(systemName: saved ? "bookmark.fill" : "bookmark.slash")
                .font(.system(size: 60, weight: .semibold))
                .foregroundStyle(saved ? Palette.accent : Palette.ink2)
                .shadow(color: Palette.accent.opacity(saved ? 0.3 : 0), radius: 14, x: 0, y: 6)
                .scaleEffect(pop ? 1 : 0.4)
                .opacity(pop ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.35, bounce: 0.45)) { pop = true }
            withAnimation(.easeOut(duration: 0.6)) { ring = true }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: Study cover

/// Study is one full-screen feed, like a video app: no bars, no buttons,
/// and the Home indicator fades away. Every answer is saved the moment it's
/// given, so leaving — pinch, pull the first card down, Esc, or the
/// VoiceOver escape gesture — never loses anything. The cover itself is
/// clear, so Home shows through whenever a card is pulled away.
struct StudyCover: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @StateObject private var model: SessionModel
    @State private var previousBest = 0
    let launch: SessionLaunch

    init(launch: SessionLaunch) {
        self.launch = launch
        _model = StateObject(wrappedValue: SessionModel(mode: launch.mode, items: launch.items,
                                                        contextGlyphs: launch.contextGlyphs))
    }

    var body: some View {
        ZStack {
            if model.isFinished {
                RecapView(model: model, previousBest: previousBest, glyphs: launch.lessonGlyphs,
                          onDone: close(animated:))
            }
            if !model.isFinished {
                ReelsFeed(model: model, onClose: close(animated:))
                    .transition(.opacity)
            }
        }
        .presentationBackground(Color.clear)
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(store.data.settings.appearance.scheme)
        .onAppear { previousBest = store.data.bestCombo }
    }

    /// Gestures that close the session have already moved the card out of
    /// the way, so the cover then goes without a slide of its own.
    private func close(animated: Bool) {
        Speaker.shared.stop()
        Haptics.stop()
        store.saveNow()
        if animated {
            router.session = nil
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { router.session = nil }
        }
    }
}

/// Fades a view in from a blur, the way system content materializes.
struct BlurFade: ViewModifier {
    let amount: CGFloat

    func body(content: Content) -> some View {
        content
            .blur(radius: amount)
            .opacity(amount == 0 ? 1 : 0)
    }
}

extension AnyTransition {
    static var blurFade: AnyTransition {
        .modifier(active: BlurFade(amount: 10), identity: BlurFade(amount: 0))
    }
}

// MARK: Feed

/// Where the cards sit: inset from the screen's edges, with corners
/// concentric with the display's, and room underneath for the stack to
/// peek out.
struct StackGeometry {
    let size: CGSize
    let insets: EdgeInsets

    static let margin: CGFloat = 10
    /// How far each card below shows beneath the one above it.
    static let peek: CGFloat = 11

    var cardWidth: CGFloat { min(size.width - 2 * StackGeometry.margin, 640) }
    var top: CGFloat { insets.top + 34 }
    var bottom: CGFloat { max(insets.bottom, 10) + 30 }
    var cardHeight: CGFloat { max(size.height - top - bottom, 240) }
    var cardSize: CGSize { CGSize(width: cardWidth, height: cardHeight) }

    var cornerRadius: CGFloat {
        if size.width > 700 { return 30 }
        return insets.bottom > 0 ? 44 : 26
    }
}

/// The study feed as a deck of paper cards. The card on top is the one in
/// hand; the next two peek out beneath it. Swipe up and the top card lifts
/// away while the deck rises to meet your finger; swipe down and the
/// previous card drops back on top as the deck settles under it. Momentum
/// decides the outcome, and every turn finishes at the speed of the flick.
struct ReelsFeed: View {
    @EnvironmentObject var store: Store
    @ObservedObject var model: SessionModel
    let onClose: (Bool) -> Void
    @State private var dragY: CGFloat = 0
    @State private var pinch: CGFloat = 1
    @State private var vanishing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Pulling the first card down closes the session.
    private var pullingToClose: Bool { dragY > 0 && model.previousItem == nil }
    private var pinching: Bool { pinch < 1 || vanishing }
    private var closing: Bool { pullingToClose || pinching }

    var body: some View {
        GeometryReader { geo in
            deck(StackGeometry(size: geo.size, insets: geo.safeAreaInsets))
        }
        .ignoresSafeArea(.container)
        .simultaneousGesture(pinchToClose)
        .background(escapeKey)
        .accessibilityAction(.escape) { onClose(true) }
    }

    private func deck(_ g: StackGeometry) -> some View {
        let travel = min(abs(dragY) / max(g.size.height, 1), 1)
        let returning = dragY > 0 && model.previousItem != nil
        return ZStack(alignment: .top) {
            backdrop(travel: travel)
            if let second = model.afterNext {
                stacked(second, g: g, slot: slot(2, travel: travel, returning: returning), travel: travel)
            }
            if let next = model.upcoming {
                stacked(next, g: g, slot: slot(1, travel: travel, returning: returning), travel: travel)
            }
            if let item = model.current {
                live(item, g: g, travel: travel, returning: returning)
            }
            if returning, let previous = model.previousItem {
                incoming(previous, g: g, travel: travel)
            }
            topBar(g)
        }
        .frame(width: g.size.width, height: g.size.height)
    }

    /// A card's place in the deck: 0 on top, 1 and 2 peeking out beneath.
    private func slot(_ base: CGFloat, travel: CGFloat, returning: Bool) -> CGFloat {
        if dragY < 0 { return base - travel }
        if returning { return base + travel }
        return base
    }

    /// How far a closing gesture has gone, from 0 to 1.
    private func closeAmount(_ travel: CGFloat) -> CGFloat {
        if vanishing { return 1 }
        if pinch < 1 { return min(max((1 - pinch) / 0.35, 0), 1) }
        return pullingToClose ? travel : 0
    }

    /// The paper fades as a card is pulled away, uncovering Home — the way
    /// a photo's background fades as you pull it down to close it.
    private func backdrop(travel: CGFloat) -> some View {
        let shut = closeAmount(travel)
        let paper: Double = Double(1 - min(shut * 2.5, 1))
        return ZStack {
            Color.black.opacity(Double(0.22 * (1 - shut)) * (1 - paper))
            AmbientBackground()
                .opacity(paper)
        }
        .ignoresSafeArea()
    }

    private func stacked(_ item: StudyItem, g: StackGeometry, slot: CGFloat, travel: CGFloat) -> some View {
        let s = max(slot, 0)
        let scale: CGFloat = 1 - 0.05 * s
        let lift: CGFloat = StackGeometry.peek * s
        let shade: Double = Double(min(s, 2)) * 0.05
        let beyond: Double = s > 2 ? Double(max(0, 3 - s)) : 1
        let shut: Double = Double(1 - closeAmount(travel))
        return ReelPage(model: model, item: item, live: false, dragY: .constant(0), pageSize: g.cardSize,
                        cornerRadius: g.cornerRadius, travel: g.size.height, frozen: true, onClose: { _ in })
            .overlay {
                RoundedRectangle(cornerRadius: g.cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(shade))
                    .allowsHitTesting(false)
            }
            .scaleEffect(scale, anchor: .bottom)
            .offset(y: g.top + lift)
            .opacity(beyond * shut)
    }

    private func live(_ item: StudyItem, g: StackGeometry, travel: CGFloat, returning: Bool) -> some View {
        let recede: CGFloat = returning ? travel : 0
        let pulled: CGFloat = pullingToClose ? 1 - 0.12 * travel : 1
        let scale: CGFloat = pinching ? pinch : (1 - 0.05 * recede) * pulled
        let rise: CGFloat = StackGeometry.peek * recede
        let follows = !reduceMotion && (dragY < 0 || pullingToClose)
        let fade: Double = vanishing ? 0 : (reduceMotion && dragY < 0 ? Double(1 - travel) : 1)
        let shade: Double = Double(recede) * 0.05
        return ReelPage(model: model, item: item, live: true, dragY: $dragY, pageSize: g.cardSize,
                        cornerRadius: g.cornerRadius, travel: g.size.height, frozen: pinching, onClose: onClose)
            .id(item.id)
            .overlay {
                RoundedRectangle(cornerRadius: g.cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(shade))
                    .allowsHitTesting(false)
            }
            .modifier(DeviceTilt(enabled: dragY == 0 && !pinching, cornerRadius: g.cornerRadius))
            .scaleEffect(scale, anchor: returning ? .bottom : .center)
            .offset(y: g.top + rise + (follows ? dragY : 0))
            .opacity(fade)
    }

    private func incoming(_ item: StudyItem, g: StackGeometry, travel: CGFloat) -> some View {
        let drop: CGFloat = reduceMotion ? 0 : dragY - g.size.height
        let fade: Double = reduceMotion ? Double(travel) : 1
        return ReelPage(model: model, item: item, live: false, dragY: .constant(0), pageSize: g.cardSize,
                        cornerRadius: g.cornerRadius, travel: g.size.height, frozen: true, onClose: { _ in })
            .offset(y: g.top + drop)
            .opacity(fade)
    }

    private func topBar(_ g: StackGeometry) -> some View {
        HStack(spacing: Space.s) {
            progressLine
            ComboChip(combo: model.combo)
        }
        .frame(width: g.cardWidth - Space.l, height: 26)
        .offset(y: g.insets.top + 3)
        .opacity(closing ? 0 : 1)
        .animation(.easeOut(duration: 0.15), value: closing)
        .allowsHitTesting(false)
    }

    private var progressLine: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.ink.opacity(0.09))
                Capsule()
                    .fill(Palette.ink.opacity(0.8))
                    .frame(width: max(geo.size.width * CGFloat(min(max(model.progress, 0), 1)), 3))
            }
        }
        .frame(height: 3)
        .animation(Motion.settle, value: model.progress)
        .accessibilityElement()
        .accessibilityLabel("\(model.completed) of \(model.total) done")
    }

    /// Pinching shrinks the card under the fingers, as when closing a
    /// photo; let go small enough and it's gone.
    private var pinchToClose: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard !vanishing, model.current != nil else { return }
                let m = value.magnification
                pinch = m < 1 ? max(m, 0.4) : 1
            }
            .onEnded { value in
                guard !vanishing, model.current != nil else { return }
                if value.magnification < 0.8 {
                    vanish()
                } else {
                    withAnimation(Motion.flick) { pinch = 1 }
                }
            }
    }

    private func vanish() {
        Haptics.snap()
        withAnimation(Motion.settle) {
            vanishing = true
            pinch = 0.6
        } completion: {
            onClose(false)
        }
    }

    private var escapeKey: some View {
        Button("") { onClose(true) }
            .keyboardShortcut(.cancelAction)
            .opacity(0)
            .accessibilityHidden(true)
    }
}

/// Consecutive first-try answers, on glass. It appears at three, rolls up
/// with the run and simply disappears on a miss — no penalty, no lost
/// streak.
struct ComboChip: View {
    let combo: Int

    var body: some View {
        ZStack {
            if combo >= 3 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.caption2.weight(.bold))
                        .symbolEffect(.bounce, value: combo)
                    Text("\(combo)")
                        .font(.figure(.footnote, weight: .bold))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(combo)))
                }
                .foregroundStyle(Palette.matcha)
                .padding(.horizontal, Space.s)
                .frame(height: 26)
                .glassCapsule(tint: Palette.matcha)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(combo) in a row")
            }
        }
        .animation(Motion.flick, value: combo)
    }
}

/// One card of the deck. There are no buttons: the card is the control.
///
///   tap          reveal · then hear it again
///   swipe ↑      next — counted as known, unless marked Forgot or Easy
///   swipe ↓      back to the previous card (on the first card: close)
///   swipe →      Forgot          swipe ←   Save
///   double-tap   Easy — or, on a new kanji, "I already know this"
///   hold         stroke order and sound together
///   pinch        close
///
/// Hardware keys and VoiceOver actions cover every gesture, and first-run
/// hints teach them one per card.
struct ReelPage: View {
    @EnvironmentObject var store: Store
    @ObservedObject var model: SessionModel
    let item: StudyItem
    let live: Bool
    @Binding var dragY: CGFloat
    /// The card's own size.
    let pageSize: CGSize
    let cornerRadius: CGFloat
    /// The distance a page turn travels (the screen's height).
    let travel: CGFloat
    /// True while a pinch is in progress; swipes wait.
    let frozen: Bool
    let onClose: (Bool) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var revealed = false
    @State private var marked = false
    @State private var easy = false
    @State private var dragX: CGFloat = 0
    @State private var axis: Axis? = nil
    @State private var armed = false
    @State private var leaving = false
    @State private var holding = false
    @State private var pressing = false
    @State private var autoStrokes = false
    @State private var touch: CGPoint? = nil
    @State private var showHeart = false
    @State private var heartToken = 0
    @State private var showSaveBurst = false
    @State private var saveToken = 0
    @State private var shownAt = Date()
    @State private var answerMs = 0
    @State private var typed = ""
    @State private var verdict: Bool? = nil
    @State private var hint: String? = nil
    @State private var usedHint = false
    @State private var inferredMiss: MissReason? = nil
    @State private var shakes: CGFloat = 0
    @FocusState var fieldFocused: Bool

    private static let sideThreshold: CGFloat = 80

    private var settings: AppSettings { store.data.settings }
    private var kanji: Kanji? { store.library.byGlyph[item.glyph] }
    private var isCard: Bool { item.kind == .card }
    private var typing: Bool { isCard && item.facet == .reading && settings.typeReadings }
    private var hero: CGFloat { min(pageSize.width * 0.5, pageSize.height * 0.28, 220) }
    private var card: Card? { store.card(item.glyph, item.facet) }
    private var canAdvance: Bool { !typing || verdict != nil }
    private var isPlayable: Bool { item.facet != .reading || word != nil || !isCard }
    private var strokesShowing: Bool { holding || autoStrokes }

    private var word: Word? {
        guard let k = kanji, !k.words.isEmpty else { return nil }
        return k.words[item.wordIndex % k.words.count]
    }

    /// The memory hook appears only when it helps: new, relearning or
    /// repeatedly forgotten cards, or once marked forgotten.
    private var needsSupport: Bool {
        if marked { return true }
        guard let c = card else { return true }
        return c.phase != .review || c.leech
    }

    var body: some View {
        if let k = kanji, isPlayable {
            if live {
                livePage(k)
            } else {
                pageContent(k)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        } else {
            Color.clear.onAppear {
                if live { model.skipCurrent() }
            }
        }
    }

    // MARK: Layout

    private func livePage(_ k: Kanji) -> some View {
        withAccessibility(withGestures(pageContent(k), k), k)
            .background(hiddenKeys(k))
            .onAppear { appear(k) }
    }

    /// The card, with the actions a sideways swipe will take waiting
    /// beneath it, as with Mail's swipe actions.
    private func pageContent(_ k: Kanji) -> some View {
        let turn: Double = reduceMotion ? 0 : Double(dragX) / 45
        return ZStack {
            swipeActions
            paperCard(k)
                .offset(x: dragX)
                .rotationEffect(.degrees(turn), anchor: .bottom)
        }
        .frame(width: pageSize.width, height: pageSize.height)
    }

    /// A sheet of paper: grain, a lit edge, a contact shadow and a soft
    /// ambient one, and a light that follows the finger.
    private func paperCard(_ k: Kanji) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return ZStack(alignment: .bottom) {
            cardFill
            centerColumn(k)
                .scaleEffect(pressing && !reduceMotion ? 0.98 : 1)
                .animation(Motion.settle, value: pressing)
            bottomArea(k)
        }
        .frame(width: pageSize.width, height: pageSize.height)
        .clipShape(shape)
        .overlay {
            shape.stroke(Palette.edge, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            statusChips(k)
        }
        .overlay {
            bursts
        }
        .background {
            shape.fill(Palette.card)
                .elevation(1)
        }
    }

    private var cardFill: some View {
        ZStack {
            Palette.card
            PaperGrain(strength: 0.7)
            if marked {
                LinearGradient(colors: [Palette.shu.opacity(0), Palette.shu.opacity(0.1)],
                               startPoint: .top, endPoint: .bottom)
                    .transition(.opacity)
            }
            if easy {
                LinearGradient(colors: [Palette.sakura.opacity(0), Palette.sakura.opacity(0.08)],
                               startPoint: .top, endPoint: .bottom)
                    .transition(.opacity)
            }
            if let touch = touch {
                RadialGradient(colors: [Palette.glow, Palette.glow.opacity(0)],
                               center: .center, startRadius: 0, endRadius: 230)
                    .frame(width: 460, height: 460)
                    .position(touch)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: touch == nil)
        .animation(Motion.settle, value: marked)
        .animation(Motion.settle, value: easy)
        .allowsHitTesting(false)
    }

    private var swipeActions: some View {
        let forgotShown: Double = dragX > 0 && isCard ? Double(min(dragX / 48, 1)) : 0
        let saveShown: Double = dragX < 0 && item.kind != .context ? Double(min(-dragX / 48, 1)) : 0
        return HStack {
            actionBadge(symbol: marked ? "arrow.uturn.backward" : "arrow.counterclockwise",
                        tint: Palette.shu, armed: armed && dragX > 0, shown: forgotShown)
            Spacer()
            actionBadge(symbol: store.isSaved(item.glyph) ? "bookmark.slash.fill" : "bookmark.fill",
                        tint: Palette.accent, armed: armed && dragX < 0, shown: saveShown)
        }
        .padding(.horizontal, Space.l)
        .accessibilityHidden(true)
    }

    /// A glass disc that fills with color once letting go would commit.
    private func actionBadge(symbol: String, tint: Color, armed: Bool, shown: Double) -> some View {
        let scale: CGFloat = armed ? 1.1 : 0.7 + 0.3 * CGFloat(shown)
        return Image(systemName: symbol)
            .font(.title2.weight(.semibold))
            .foregroundStyle(armed ? Palette.onAccent : tint)
            .frame(width: 58, height: 58)
            .background {
                Circle()
                    .fill(tint)
                    .opacity(armed ? 1 : 0)
            }
            .glassBackground(Circle())
            .symbolEffect(.bounce, value: armed)
            .scaleEffect(scale)
            .opacity(shown)
            .animation(Motion.flick, value: armed)
    }

    private func statusChips(_ k: Kanji) -> some View {
        HStack(spacing: Space.xs) {
            if marked {
                chip("Forgot", symbol: "arrow.counterclockwise", tint: Palette.shu)
            }
            if easy {
                chip("Easy", symbol: "heart.fill", tint: Palette.sakura)
            }
            if store.isSaved(k.glyph) && item.kind != .context {
                chip("Saved", symbol: "bookmark.fill", tint: Palette.accent)
            }
        }
        .padding(.top, Space.m)
        .animation(Motion.flick, value: marked)
        .animation(Motion.flick, value: easy)
        .allowsHitTesting(false)
    }

    private func chip(_ title: String, symbol: String, tint: Color) -> some View {
        Label(title, systemImage: symbol)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, Space.s)
            .frame(height: 30)
            .glassCapsule(tint: tint)
            .transition(.scale(scale: 0.6).combined(with: .opacity))
    }

    @ViewBuilder
    private var bursts: some View {
        if showHeart {
            HeartBurst()
                .id(heartToken)
        }
        if showSaveBurst {
            SaveBurst(saved: store.isSaved(item.glyph))
                .id(saveToken)
        }
    }

    private func centerColumn(_ k: Kanji) -> some View {
        VStack(spacing: Space.l) {
            Spacer(minLength: 56)
            mainContent(k)
            Spacer(minLength: 76)
        }
        .padding(.horizontal, Space.xl)
        .frame(maxWidth: Metrics.readableWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    @ViewBuilder
    private func mainContent(_ k: Kanji) -> some View {
        switch item.kind {
        case .teach:
            teachContent(k)
        case .context:
            contextContent(k)
        case .card:
            cardContent(k)
        }
    }

    // MARK: Cards

    @ViewBuilder
    private func cardContent(_ k: Kanji) -> some View {
        prompt(k)
        if revealed {
            answer(k)
                .transition(reduceMotion ? AnyTransition.opacity : AnyTransition.blurFade)
        } else {
            Caption(text: facetLabel)
                .transition(.opacity)
        }
    }

    private var facetLabel: String {
        switch item.facet {
        case .meaning: return "Meaning"
        case .reading: return typing ? "Type the reading" : "Say the reading"
        case .writing: return "Write it in the air"
        }
    }

    @ViewBuilder
    private func prompt(_ k: Kanji) -> some View {
        switch item.facet {
        case .meaning:
            StrokeGlyph(kanji: k, size: revealed ? hero * 0.72 : hero, playing: strokesShowing, loops: holding)
        case .reading:
            if let w = word {
                VStack(spacing: Space.s) {
                    if strokesShowing && !k.strokePaths.isEmpty {
                        StrokeGlyph(kanji: k, size: hero * 0.6, playing: true, loops: holding)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                    jpText(w.word, highlight: k.glyph, size: min(hero * 0.55, 80), face: settings.face)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                    Text(w.meaning)
                        .font(.body)
                        .foregroundStyle(Palette.ink2)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                .animation(Motion.settle, value: strokesShowing)
            }
        case .writing:
            if revealed {
                StrokeGlyph(kanji: k, size: hero * 0.8, playing: strokesShowing, loops: holding)
            } else {
                VStack(spacing: Space.s) {
                    Text(k.meaningList.capitalizedFirst)
                        .font(.display(.title, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                    Text(readingLine(k))
                        .font(.jp(18, relativeTo: .title3))
                        .foregroundStyle(Palette.ink2)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    @ViewBuilder
    private func answer(_ k: Kanji) -> some View {
        VStack(spacing: Space.s) {
            switch item.facet {
            case .meaning, .writing:
                Text(k.meaningList.capitalizedFirst)
                    .font(.display(.title, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                Text(readingLine(k))
                    .font(.jp(17, relativeTo: .body))
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
            case .reading:
                if let w = word {
                    readingAnswer(w)
                }
            }
            if needsSupport {
                MixedText(hookText(k), style: .callout)
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.xs)
            }
            if card?.leech ?? false {
                lookAlikes(k)
            }
        }
    }

    private func readingAnswer(_ w: Word) -> some View {
        VStack(spacing: Space.xxs) {
            Text(w.readings.joined(separator: " / "))
                .font(.jp(32, relativeTo: .title))
                .foregroundStyle(readingColor)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(.center)
            if verdict == false && !typed.isEmpty {
                Text(typed)
                    .font(.jp(17, relativeTo: .body))
                    .strikethrough()
                    .foregroundStyle(Palette.shu)
                    .accessibilityLabel("You typed \(typed)")
            }
        }
    }

    private var readingColor: Color {
        if marked { return Palette.shu }
        if verdict == true { return Palette.matcha }
        return Palette.ink
    }

    private func lookAlikes(_ k: Kanji) -> some View {
        VStack(spacing: Space.xs) {
            ForEach(store.library.confusions(for: k.glyph)) { confusion in
                MixedText(confusion.tip, style: .footnote)
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Lesson and context pages

    /// A new kanji on one card. The layout steps down — fewer words, no
    /// sentence — until it fits, so nothing ever needs scrolling.
    private func teachContent(_ k: Kanji) -> some View {
        ViewThatFits(in: .vertical) {
            teachLayout(k, words: 3, sentence: true)
            teachLayout(k, words: 2, sentence: false)
            teachLayout(k, words: 0, sentence: false)
        }
        .frame(maxHeight: max(pageSize.height - 150, 200))
    }

    private func teachLayout(_ k: Kanji, words: Int, sentence: Bool) -> some View {
        VStack(spacing: Space.m) {
            Caption(text: "New kanji", color: Palette.accent)
            StrokeGlyph(kanji: k, size: hero * 0.8, playing: strokesShowing, loops: holding)
            VStack(spacing: Space.xxs) {
                Text(k.meaningList.capitalizedFirst)
                    .font(.display(.title2, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(readingLine(k))
                    .font(.jp(17, relativeTo: .body))
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
            }
            if !k.parts.isEmpty {
                MixedText(k.parts.map { "\($0.glyph) \($0.meaning)" }.joined(separator: " + "), style: .footnote)
                    .foregroundStyle(Palette.ink2)
            }
            MixedText(hookText(k), style: .callout)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            if words > 0 {
                teachWords(k, limit: words)
            }
            if sentence && !k.sentence.isEmpty {
                teachSentence(k)
            }
        }
    }

    private func teachWords(_ k: Kanji, limit: Int) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(k.words.prefix(limit))) { w in
                teachWordRow(w, k: k)
            }
        }
        .frame(maxWidth: 420)
        .background(Palette.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
    }

    private func teachWordRow(_ w: Word, k: Kanji) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            jpText(w.word, highlight: k.glyph, size: 18, face: settings.face, fixed: false)
                .fixedSize()
            Text(w.primaryReading)
                .font(.jp(13, relativeTo: .footnote))
                .foregroundStyle(Palette.ink2)
                .fixedSize()
            Spacer(minLength: Space.s)
            Text(w.meaning)
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, Space.xs + 2)
    }

    private func teachSentence(_ k: Kanji) -> some View {
        VStack(spacing: Space.xxs) {
            RubyText(markup: k.sentence, size: 17, highlight: k.glyph)
            Text(k.translation)
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func contextContent(_ k: Kanji) -> some View {
        VStack(spacing: Space.l) {
            Caption(text: "In context")
            RubyText(markup: k.sentence, size: 22, highlight: k.glyph)
            Text(k.translation)
                .font(.callout)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Bottom: typing and first-run hints

    private func bottomArea(_ k: Kanji) -> some View {
        VStack(spacing: Space.m) {
            if typing && verdict == nil {
                typedField(k)
            }
            if let tip = coachTip {
                coachLine(tip)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, Space.l)
        .padding(.bottom, Space.l)
    }

    /// One gesture is taught per card for the first five cards, then the
    /// hints are gone for good.
    private var coachTip: String? {
        let step = settings.coachStep
        switch item.kind {
        case .teach:
            return step == 0 ? "Swipe up for next · double-tap if you know it" : nil
        case .context:
            return step < 5 ? "Swipe up to continue" : nil
        case .card:
            if !revealed { return step == 0 && !typing ? "Tap to reveal" : nil }
            switch step {
            case 0: return "Swipe up for next"
            case 1: return "Forgot it? Swipe right"
            case 2: return "Knew it instantly? Double-tap"
            case 3: return "Swipe left to save · hold for strokes and sound"
            case 4: return "Pinch to close"
            default: return nil
            }
        }
    }

    @ViewBuilder
    private func coachLine(_ tip: String) -> some View {
        if tip.hasPrefix("Swipe up") {
            ShimmerText(text: tip)
                .accessibilityHidden(true)
        } else {
            Text(tip)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.m)
                .frame(minHeight: 34)
                .glassCapsule()
                .accessibilityHidden(true)
        }
    }

    /// The answer field: glass, with an accent ring that lights while it has
    /// focus, and a shake when a near miss earns a second try.
    private func typedField(_ k: Kanji) -> some View {
        VStack(spacing: Space.xs) {
            if let hint = hint {
                MixedText(hint, style: .subheadline)
                    .foregroundStyle(Palette.kohaku)
                    .multilineTextAlignment(.center)
                    .transition(.blurFade)
            }
            HStack(spacing: Space.xs) {
                Image(systemName: "character.cursor.ibeam")
                    .font(.body.weight(.medium))
                    .foregroundStyle(fieldFocused ? Palette.accent : Palette.ink3)
                    .symbolEffect(.bounce, value: fieldFocused)
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
                Image(systemName: "return")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.ink3)
                    .opacity(typed.isEmpty ? 0 : 1)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Space.l)
            .frame(height: Metrics.buttonHeight)
            .glassCapsule()
            .overlay {
                Capsule()
                    .stroke(Palette.accent.opacity(fieldFocused ? 0.6 : 0), lineWidth: 1.5)
                    .allowsHitTesting(false)
            }
            .animation(Motion.settle, value: fieldFocused)
            .modifier(Shake(animatableData: shakes))
        }
        .actionColumn()
    }

    // MARK: Gestures

    private func withGestures<Content: View>(_ content: Content, _ k: Kanji) -> some View {
        content
            .contentShape(Rectangle())
            .simultaneousGesture(lightTracking)
            .gesture(pageDrag(k))
            .onTapGesture(count: 2) { doubleTap(k) }
            .onTapGesture { tap(k) }
            .onLongPressGesture(minimumDuration: 0.3, maximumDistance: 12, perform: {
                startHold(k)
            }, onPressingChanged: { isPressing in
                pressing = isPressing
                if !isPressing { endHold() }
            })
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    touch = location
                case .ended:
                    touch = nil
                }
            }
    }

    /// The glow under the finger; it never claims the touch.
    private var lightTracking: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if axis == nil { touch = value.location }
            }
            .onEnded { _ in
                touch = nil
            }
    }

    private func pageDrag(_ k: Kanji) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                dragChanged(value.translation, k)
            }
            .onEnded { value in
                dragEnded(value.translation, velocity: value.velocity, k)
            }
    }

    private func dragChanged(_ t: CGSize, _ k: Kanji) {
        guard !leaving, !holding, !frozen else { return }
        if axis == nil {
            axis = abs(t.height) >= abs(t.width) ? .vertical : .horizontal
            touch = nil
        }
        if axis == .vertical {
            let up = t.height < 0
            let allowed = !up || canAdvance
            dragY = allowed ? t.height : Motion.rubberband(t.height, dimension: travel)
            if up && allowed && isCard && !revealed && t.height < -24 {
                reveal(k)
            }
        } else {
            let allowed = t.width < 0 ? item.kind != .context : isCard
            dragX = sideOffset(t.width, allowed: allowed)
            updateArmed(allowed && abs(t.width) > ReelPage.sideThreshold)
        }
    }

    /// 1:1 until just past the commit point, then rubber-banded; a direction
    /// with no action resists from the start.
    private func sideOffset(_ x: CGFloat, allowed: Bool) -> CGFloat {
        guard allowed else { return Motion.rubberband(x, dimension: pageSize.width * 0.3) }
        let limit = ReelPage.sideThreshold * 1.4
        guard abs(x) > limit else { return x }
        let extra = Motion.rubberband(abs(x) - limit, dimension: pageSize.width)
        return x < 0 ? -(limit + extra) : limit + extra
    }

    /// A selection tick the moment a sideways swipe would commit if released.
    private func updateArmed(_ value: Bool) {
        guard value != armed else { return }
        if value { Haptics.tick() }
        armed = value
    }

    private func dragEnded(_ t: CGSize, velocity: CGSize, _ k: Kanji) {
        guard !leaving else { return }
        let locked = axis ?? .vertical
        axis = nil
        let wasArmed = armed
        armed = false
        if frozen {
            withAnimation(Motion.flick) {
                dragY = 0
                dragX = 0
            }
            return
        }
        if locked == .vertical {
            let projected = t.height + Motion.project(velocity.height)
            let goesUp = projected < -travel * 0.3 && velocity.height < 250
            let goesDown = projected > travel * 0.3 && velocity.height > -250
            if goesUp && canAdvance {
                advance(k, velocity: velocity.height)
            } else if goesDown {
                if model.canUndo {
                    goBack(velocity: velocity.height)
                } else {
                    pullAway(velocity: velocity.height)
                }
            } else {
                if goesUp { Haptics.rigid() }
                withAnimation(Motion.flick) { dragY = 0 }
            }
        } else {
            if wasArmed {
                if t.width < 0 {
                    toggleSave(k)
                } else {
                    setMarked(!marked, k)
                }
            }
            withAnimation(Motion.flick) { dragX = 0 }
        }
    }

    // MARK: Actions

    private func appear(_ k: Kanji) {
        shownAt = Date()
        if item.kind == .teach {
            // The first card waits for the cover to finish rising.
            let delay = model.canUndo ? 0.2 : 0.55
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if !leaving { playStrokes(k, deliberate: false) }
            }
        }
        if typing {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { fieldFocused = true }
        }
    }

    /// Space, Return and ↑: reveal first, then move on.
    private func primary(_ k: Kanji) {
        if isCard && !revealed {
            if typing { fieldFocused = true } else { reveal(k) }
        } else {
            advance(k)
        }
    }

    private func tap(_ k: Kanji) {
        guard !leaving else { return }
        switch item.kind {
        case .context:
            listen(k)
        case .teach:
            playStrokes(k, deliberate: true)
        case .card:
            if !revealed {
                if typing { fieldFocused = true } else { reveal(k) }
            } else {
                listen(k)
            }
        }
    }

    private func doubleTap(_ k: Kanji) {
        guard !leaving else { return }
        switch item.kind {
        case .teach:
            knowAlready()
        case .card:
            if !revealed { reveal(k) }
            let nowEasy = !easy
            withAnimation(Motion.flick) {
                easy = nowEasy
                if nowEasy { marked = false }
            }
            if nowEasy { celebrate() } else { Haptics.tap() }
        case .context:
            listen(k)
        }
    }

    /// "I already know this" on a lesson card: a heart, then the kanji and
    /// its quiz questions dissolve away; a spaced check verifies it later.
    private func knowAlready() {
        leaving = true
        celebrate()
        let glyph = item.glyph
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(Motion.settle) {
                model.skipKnown(glyph, store: store)
            }
        }
    }

    private func celebrate() {
        heartToken += 1
        let token = heartToken
        showHeart = true
        Haptics.heart()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            if heartToken == token { showHeart = false }
        }
    }

    private func reveal(_ k: Kanji, autoplay: Bool = true) {
        guard !revealed, isCard else { return }
        answerMs = Int(Date().timeIntervalSince(shownAt) * 1000)
        withAnimation(reduceMotion ? Animation.easeOut(duration: 0.15) : Motion.reveal) { revealed = true }
        Haptics.soft()
        guard autoplay else { return }
        if item.facet == .writing {
            playStrokes(k, deliberate: false)
        } else if settings.autoSpeak {
            speak(k, deliberate: false)
        }
    }

    private func listen(_ k: Kanji) {
        if item.kind == .context {
            Speaker.shared.say(Ruby.spoken(k.sentence))
        } else {
            speak(k, deliberate: true)
        }
    }

    private func speak(_ k: Kanji, deliberate: Bool) {
        if let reading = word?.primaryReading ?? k.words.first?.primaryReading {
            Speaker.shared.say(reading, deliberate: deliberate)
        }
    }

    /// Hold: the strokes draw, a soft touch marks each one, and the word is
    /// spoken — sight, touch and sound starting on the same frame.
    private func startHold(_ k: Kanji) {
        guard !leaving else { return }
        if item.kind == .context {
            listen(k)
            return
        }
        if isCard && item.facet != .meaning && !revealed { reveal(k, autoplay: false) }
        speak(k, deliberate: true)
        if !settings.coachTips { store.data.settings.coachTips = true }
        guard !k.strokePaths.isEmpty else { return }
        holding = true
        Haptics.strokes(count: k.strokePaths.count, interval: StrokeOrderView.perStroke)
    }

    private func endHold() {
        guard holding else { return }
        holding = false
        Haptics.stop()
    }

    private func playStrokes(_ k: Kanji, deliberate: Bool) {
        if deliberate || settings.autoSpeak { speak(k, deliberate: deliberate) }
        guard !k.strokePaths.isEmpty else { return }
        autoStrokes = true
        Haptics.strokes(count: k.strokePaths.count, interval: StrokeOrderView.perStroke)
        DispatchQueue.main.asyncAfter(deadline: .now() + StrokeOrderView.duration(for: k.strokePaths.count)) {
            autoStrokes = false
        }
    }

    /// Swipe right (or →): marking Forgot also reveals the answer; marking
    /// it again clears it — which is how a typed slip still counts.
    private func setMarked(_ forgot: Bool, _ k: Kanji) {
        guard isCard, !leaving else { return }
        if forgot && !revealed { reveal(k) }
        guard forgot != marked else { return }
        withAnimation(Motion.flick) {
            marked = forgot
            if forgot { easy = false }
        }
        if forgot { Haptics.forgot() } else { Haptics.tap() }
    }

    private func toggleSave(_ k: Kanji) {
        guard !leaving, item.kind != .context else { return }
        withAnimation(Motion.flick) { store.toggleSaved(k.glyph) }
        Haptics.saved()
        saveToken += 1
        let token = saveToken
        showSaveBurst = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if saveToken == token {
                withAnimation(.easeOut(duration: 0.2)) { showSaveBurst = false }
            }
        }
    }

    // MARK: Page turns

    private func advance(_ k: Kanji, velocity: CGFloat = 0) {
        guard !leaving, canAdvance else { return }
        leaving = true
        fieldFocused = false
        touch = nil
        Speaker.shared.stop()
        Haptics.stop()
        slide(to: -travel, velocity: velocity) {
            finishAdvance()
        }
    }

    private func goBack(velocity: CGFloat = 0) {
        guard !leaving, model.canUndo else { return }
        leaving = true
        fieldFocused = false
        touch = nil
        Speaker.shared.stop()
        Haptics.stop()
        slide(to: travel, velocity: velocity) {
            model.undo(store: store)
        }
    }

    /// Finishes a page turn as a spring that starts at the finger's speed,
    /// then swaps cards in one unanimated transaction so the card that
    /// arrived simply becomes the live one.
    private func slide(to target: CGFloat, velocity: CGFloat, then action: @escaping () -> Void) {
        let remaining = target - dragY
        let relative = remaining == 0 ? 0 : Double(velocity / remaining)
        withAnimation(Motion.page(velocity: max(relative, 0))) {
            dragY = target
        } completion: {
            Haptics.snap()
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                dragY = 0
                action()
            }
        }
    }

    /// Pulling the first card down carries it off the bottom of the screen,
    /// uncovering Home, and the session closes behind it.
    private func pullAway(velocity: CGFloat) {
        leaving = true
        fieldFocused = false
        let target = travel
        let remaining = target - dragY
        let relative = remaining <= 0 ? 0 : Double(velocity / remaining)
        withAnimation(Motion.page(velocity: max(relative, 0))) {
            dragY = target
        } completion: {
            onClose(false)
        }
    }

    private func finishAdvance() {
        switch item.kind {
        case .card:
            if settings.coachStep < 5 { store.data.settings.coachStep += 1 }
            grade(marked ? .again : (easy ? .easy : .good))
        case .teach, .context:
            model.advancePage(store: store)
        }
    }

    private func grade(_ rating: Rating) {
        let ms = answerMs > 0 ? answerMs : Int(Date().timeIntervalSince(shownAt) * 1000)
        var miss: MissReason? = nil
        if rating == .again {
            switch item.facet {
            case .meaning: miss = .meaning
            case .reading: miss = inferredMiss ?? .reading
            case .writing: miss = nil
            }
        }
        model.commit(rating, ms: ms, miss: miss, store: store)
        if rating != .again && [5, 10, 20, 50, 100].contains(model.combo) {
            Haptics.success()
        }
    }

    // MARK: Keyboard and VoiceOver

    /// Space or Return reveals, then moves on; ↑ next, ↓ back, → forgot,
    /// ← save, E easy, P strokes and sound.
    private func hiddenKeys(_ k: Kanji) -> some View {
        ZStack {
            Button("") { primary(k) }
                .keyboardShortcut(.space, modifiers: [])
            Button("") { primary(k) }
                .keyboardShortcut(.return, modifiers: [])
            Button("") { primary(k) }
                .keyboardShortcut(.upArrow, modifiers: [])
            Button("") { goBack() }
                .keyboardShortcut(.downArrow, modifiers: [])
            Button("") { setMarked(!marked, k) }
                .keyboardShortcut(.rightArrow, modifiers: [])
            Button("") { toggleSave(k) }
                .keyboardShortcut(.leftArrow, modifiers: [])
            Button("") { doubleTap(k) }
                .keyboardShortcut("e", modifiers: [])
            Button("") { playStrokes(k, deliberate: true) }
                .keyboardShortcut("p", modifiers: [])
        }
        .opacity(0)
        .accessibilityHidden(true)
        .disabled(typing && verdict == nil)
    }

    private var accessibilityHintText: String {
        if isCard && !revealed { return "Reveals the answer" }
        return "Swipe up or down with one finger for actions"
    }

    private var forgotActionName: String { marked ? "Clear forgot" : "Forgot" }
    private var easyActionName: String { easy ? "Clear easy" : "Easy" }
    private var saveActionName: String { store.isSaved(item.glyph) ? "Remove from saved" : "Save" }

    private func withAccessibility<Content: View>(_ content: Content, _ k: Kanji) -> some View {
        content
            .accessibilityElement(children: typing ? .contain : .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(Text(accessibilityHintText))
            .accessibilityAction { tap(k) }
            .accessibilityActions {
                accessibilityButtons(k)
            }
    }

    @ViewBuilder
    private func accessibilityButtons(_ k: Kanji) -> some View {
        Button("Next") { advance(k) }
        if isCard {
            Button(forgotActionName) { setMarked(!marked, k) }
            Button(easyActionName) { doubleTap(k) }
        }
        if item.kind == .teach {
            Button("I already know this") { doubleTap(k) }
        }
        if item.kind != .context {
            Button(saveActionName) { toggleSave(k) }
        }
        Button("Play stroke order and sound") { playStrokes(k, deliberate: true) }
        Button("Previous") { goBack() }
        Button("Close") { onClose(true) }
    }

    // MARK: Typed readings

    private func check(_ k: Kanji) {
        guard verdict == nil, let w = word else { return }
        let answer = Kana.normalize(Romaji.toHiragana(typed, final: true))
        guard !answer.isEmpty else { return }
        typed = answer
        let targets = w.readings.map { Kana.normalize($0) }
        if targets.contains(answer) {
            settle(correct: true, k)
            return
        }
        if !usedHint, let message = nearMissHint(answer, targets: targets, kanji: k) {
            usedHint = true
            withAnimation(Motion.settle) { hint = message }
            typed = ""
            withAnimation(.default) { shakes += 1 }
            Haptics.warning()
            return
        }
        if inferredMiss == nil { inferredMiss = .reading }
        settle(correct: false, k)
    }

    private func settle(correct: Bool, _ k: Kanji) {
        fieldFocused = false
        hint = nil
        verdict = correct
        reveal(k)
        withAnimation(Motion.flick) { marked = !correct }
        if correct { Haptics.success() } else { Haptics.forgot() }
    }

    /// One free retry for answers that are almost right, pointing at exactly
    /// what to notice. The kind of slip is recorded silently.
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

    private func hookText(_ k: Kanji) -> String {
        let own = store.note(for: k.glyph)
        return own.isEmpty ? k.mnemonic : own
    }
}

// MARK: Recap

/// The end of a session: a seal, a headline, the numbers rolling up, and
/// the same gesture that began it. Swiping up lifts the page away to
/// uncover Home.
struct RecapView: View {
    @EnvironmentObject var store: Store
    @ObservedObject var model: SessionModel
    let previousBest: Int
    let glyphs: [String]
    let onDone: (Bool) -> Void
    @State private var offerReminder = false
    @State private var lift: CGFloat = 0
    @State private var height: CGFloat = 900
    @State private var appeared = false
    @State private var counted = false
    @State private var leaving = false
    @State private var gone = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var title: String {
        switch model.mode {
        case .lesson: return "Learned"
        case .review: return "Reviewed"
        case .practice: return "Practiced"
        }
    }

    private var detail: String {
        switch model.mode {
        case .lesson: return "They'll come back in a few hours, while still fresh."
        case .review: return "Each one returns just before you'd forget it."
        case .practice: return "Practice doesn't change your schedule."
        }
    }

    private var accuracy: Int {
        let graded = max(model.result.answered, 1)
        return Int((min(Double(model.result.firstTry) / Double(graded), 1) * 100).rounded())
    }

    private var comboLine: String? {
        let best = model.result.bestCombo
        guard best >= 5, best > previousBest else { return nil }
        return "New best — \(best) in a row"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: Space.xl)
            summary
            Spacer(minLength: Space.xl)
            footer
        }
        .padding(.horizontal, Space.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            AmbientBackground()
        }
        .background {
            GeometryReader { geo in
                Color.clear.onAppear { height = geo.size.height }
            }
        }
        .contentShape(Rectangle())
        .offset(y: lift)
        .opacity(gone ? 0 : 1)
        .gesture(finishGesture)
        .background(finishKey)
        .onAppear {
            if model.mode != .practice { Haptics.success() }
            withAnimation(Motion.reveal.delay(0.15)) { appeared = true }
            withAnimation(.spring(duration: 1.0, bounce: 0.1).delay(0.45)) { counted = true }
            // Ask about reminders once, in context, after a real session.
            offerReminder = model.mode != .practice && !store.data.settings.askedReminder && !store.data.settings.reminder
        }
    }

    private var summary: some View {
        VStack(spacing: Space.xl) {
            Hanko(glyph: model.mode == .lesson ? "学" : "済", size: 104)
            VStack(spacing: Space.xs) {
                Text(title)
                    .font(.display(.largeTitle, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(.body)
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .modifier(BlurFade(amount: appeared || reduceMotion ? 0 : 8))
            if model.mode != .lesson && model.result.answered > 0 {
                stats
            }
            if model.mode == .lesson && !glyphs.isEmpty {
                learnedRow
            }
            if let comboLine = comboLine {
                Label(comboLine, systemImage: "flame.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.matcha)
                    .padding(.horizontal, Space.m)
                    .frame(height: 34)
                    .glassCapsule(tint: Palette.matcha)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .frame(maxWidth: Metrics.actionWidth)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Finishes the session"))
        .accessibilityAction { finish() }
    }

    /// Three numbers on a sheet, rolling up from zero.
    private var stats: some View {
        HStack(spacing: 0) {
            stat(counted ? model.result.answered : 0, suffix: "", label: "answered")
            Divider().frame(height: 36)
            stat(counted ? accuracy : 0, suffix: "%", label: "first try")
            Divider().frame(height: 36)
            stat(counted ? model.result.bestCombo : 0, suffix: "", label: "best run")
        }
        .padding(.vertical, Space.m)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Palette.edge, lineWidth: 1)
        }
        .elevation(0.6)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared || reduceMotion ? 0 : 16)
    }

    private func stat(_ value: Int, suffix: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)\(suffix)")
                .font(.figure(.title, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText(value: Double(value)))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    /// The kanji just learned, fanned out like a hand of cards.
    private var learnedRow: some View {
        let shown = Array(glyphs.prefix(6))
        return HStack(spacing: -8) {
            ForEach(Array(shown.enumerated()), id: \.offset) { pair in
                miniCard(pair.element, index: pair.offset, count: shown.count)
            }
        }
        .padding(.top, Space.xs)
    }

    private func miniCard(_ glyph: String, index: Int, count: Int) -> some View {
        let middle = Double(count - 1) / 2
        let angle = (Double(index) - middle) * 5
        let drop = abs(Double(index) - middle) * 4
        return Text(glyph)
            .font(.jpFixed(30, face: store.data.settings.face))
            .foregroundStyle(Palette.ink)
            .frame(width: 56, height: 70)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Palette.edge, lineWidth: 1)
            }
            .elevation(0.6)
            .rotationEffect(.degrees(appeared ? angle : 0), anchor: .bottom)
            .offset(y: appeared ? CGFloat(drop) : 40)
            .opacity(appeared ? 1 : 0)
            .animation(Motion.flick.delay(0.25 + Double(index) * 0.06), value: appeared)
    }

    private var footer: some View {
        VStack(spacing: Space.l) {
            if offerReminder {
                Button {
                    Reminders.enable(store) { _ in }
                    offerReminder = false
                } label: {
                    Label("Remind me daily", systemImage: "bell")
                }
                .buttonStyle(GlassPillStyle())
            }
            ShimmerText(text: "Swipe up to finish")
                .accessibilityHidden(true)
        }
        .padding(.bottom, Space.xl)
        .opacity(appeared ? 1 : 0)
    }

    private var finishGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !leaving else { return }
                let t = value.translation.height
                lift = t < 0 ? t : Motion.rubberband(t, dimension: height)
            }
            .onEnded { value in
                guard !leaving else { return }
                let projected = value.translation.height + Motion.project(value.velocity.height)
                if projected < -height * 0.25 && value.velocity.height < 300 {
                    finish(velocity: value.velocity.height)
                } else {
                    withAnimation(Motion.flick) { lift = 0 }
                }
            }
    }

    private var finishKey: some View {
        Button("") { finish() }
            .keyboardShortcut(.return, modifiers: [])
            .opacity(0)
            .accessibilityHidden(true)
    }

    private func finish(velocity: CGFloat = 0) {
        guard !leaving else { return }
        leaving = true
        if offerReminder { store.data.settings.askedReminder = true }
        Haptics.snap()
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.25)) { gone = true } completion: { onDone(false) }
            return
        }
        let target = -(height * 1.2)
        let remaining = target - lift
        let relative = remaining == 0 ? 0 : Double(velocity / remaining)
        withAnimation(Motion.page(velocity: max(relative, 0))) {
            lift = target
        } completion: {
            onDone(false)
        }
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
    {"glyph": "一", "level": 5, "strokes": 1, "meanings": ["one"], "on": ["イチ", "イツ"], "kun": ["ひと", "ひと.つ"], "kind": "indicative", "parts": [], "mnemonic": "A single flat stroke — one finger laid on the table.", "words": [{"word": "一つ", "reading": "ひとつ", "meaning": "one (thing)"}, {"word": "一人", "reading": "ひとり", "meaning": "one person; alone"}, {"word": "一月", "reading": "いちがつ", "meaning": "January"}], "sentence": "{一人|ひとり}で{東京|とうきょう}へ{行|い}きました。", "translation": "I went to Tokyo on my own.", "usage": "Japanese has two counting systems: いち、に、さん… from Chinese, and native ひとつ、ふたつ… for counting things up to ten.", "strokePaths": ["M11,54.25c3.19,0.62,6.25,0.75,9.73,0.5c20.64-1.5,50.39-5.12,68.58-5.24c3.6-0.02,5.77,0.24,7.57,0.49"]},
    {"glyph": "二", "level": 5, "strokes": 2, "meanings": ["two"], "on": ["ニ"], "kun": ["ふた", "ふた.つ"], "kind": "indicative", "parts": [], "mnemonic": "Two lines stacked — the longer bottom one is a shelf holding up the top.", "words": [{"word": "二つ", "reading": "ふたつ", "meaning": "two (things)"}, {"word": "二人", "reading": "ふたり", "meaning": "two people"}, {"word": "二月", "reading": "にがつ", "meaning": "February"}], "sentence": "{猫|ねこ}が{二匹|にひき}います。", "translation": "There are two cats.", "usage": "One and two people are irregular: 一人 ひとり, 二人 ふたり. From three on it's number + にん.", "strokePaths": ["M25.25,32.4c1.77,0.37,4.78,0.56,6.55,0.37c10.82-1.15,28.82-3.4,41.24-3.76c2.95-0.09,4.73,0.18,6.21,0.36", "M12,80.75c2.37,0.5,6.73,0.67,9.09,0.5c23.79-1.75,45.04-4.12,67.49-4.74c3.95-0.11,6.32,0.24,8.3,0.49"]},
    {"glyph": "三", "level": 5, "strokes": 3, "meanings": ["three"], "on": ["サン"], "kun": ["み", "み.つ", "みっ.つ"], "kind": "indicative", "parts": [], "mnemonic": "Three lines — count them. The middle one is the shortest.", "words": [{"word": "三つ", "reading": "みっつ", "meaning": "three (things)"}, {"word": "三月", "reading": "さんがつ", "meaning": "March"}, {"word": "三人", "reading": "さんにん", "meaning": "three people"}], "sentence": "りんごを{三|みっ}つください。", "translation": "Three apples, please.", "usage": "Months are simply number + 月: 三月 is March, the end of the Japanese school and business year.", "strokePaths": ["M27.5,23.65c3.09,0.73,6.29,0.36,9.4,0.06c10.2-1,27-2.94,38.97-3.57c3.06-0.16,6.09-0.2,9.14,0.23", "M28.75,55.14c3.13,0.76,6.46,0.43,9.64,0.2c10.03-0.72,23.97-2.63,34.73-3.12c2.7-0.12,5.45-0.16,8.13,0.3", "M13,87.83c3.94,1.01,7.72,0.96,11.75,0.72c18.41-1.07,41.27-3.39,61.12-4.07c3.63-0.13,7.2-0.1,10.75,0.78"]},
    {"glyph": "四", "level": 5, "strokes": 5, "meanings": ["four"], "on": ["シ"], "kun": ["よ", "よ.つ", "よっ.つ", "よん"], "kind": "borrowed", "parts": [{"glyph": "囗", "meaning": "enclosure"}, {"glyph": "儿", "meaning": "legs"}], "mnemonic": "A room (囗) with legs (儿) inside: four walls, four corners.", "words": [{"word": "四つ", "reading": "よっつ", "meaning": "four (things)"}, {"word": "四月", "reading": "しがつ", "meaning": "April"}, {"word": "四人", "reading": "よにん", "meaning": "four people"}], "sentence": "{四月|しがつ}に{日本|にほん}へ{行|い}きます。", "translation": "I'm going to Japan in April.", "usage": "し sounds like 死 (death), so よん is usually preferred — some buildings even skip room 4.", "strokePaths": ["M14.5,31.48c1.51,1.51,2.25,3.27,2.53,5.2c1.14,7.9,2.61,25.18,4.39,40.83c0.29,2.55,0.34,3.81,0.64,6.24", "M17.85,34.04c21.65-1.92,51.52-3.92,67.82-4.3c4.85-0.11,6.31,2.62,6.04,5.38c-0.9,9.02-4.17,28.29-6.41,39.62c-0.49,2.49-0.94,4.6-1.3,6.13", "M40.5,36c0.08,0.64,0.12,1.65-0.16,2.57c-2.22,7.3-5.1,14.55-13.35,22.68", "M59.75,34.25c0.8,1.05,1.44,2.29,1.49,3.92c0.11,3.62,0.05,7.05,0.05,9.89c0,6.94,0.71,7.54,9.47,7.54c4.99,0,8.86-0.72,10.25-1.72", "M22.73,79.32c13.77-0.57,43.64-1.8,61.18-2.08"]},
    {"glyph": "五", "level": 5, "strokes": 4, "meanings": ["five"], "on": ["ゴ"], "kun": ["いつ", "いつ.つ"], "kind": "borrowed", "parts": [], "mnemonic": "Between a sky line and a ground line, a figure twists like a 5 written in a hurry.", "words": [{"word": "五つ", "reading": "いつつ", "meaning": "five (things)"}, {"word": "五月", "reading": "ごがつ", "meaning": "May"}, {"word": "五日", "reading": "いつか", "meaning": "the 5th (of the month); five days"}], "sentence": "{毎朝|まいあさ}{五時|ごじ}に{起|お}きます。", "translation": "I get up at five every morning.", "usage": "Early May has Golden Week, a cluster of national holidays when much of Japan travels.", "strokePaths": ["M31.75,23.15c2.8,0.67,5.54,0.42,8.36,0.12c9.3-0.99,22.18-2.4,34.14-3.21c2.49-0.17,5.04-0.33,7.5,0.2", "M55.75,25.25c0.62,1.25,1.02,3.01,0.5,5c-3.12,11.88-14,44.12-19.75,59", "M25.5,55.25c2.07,1.24,4.73,1.03,7,0.81c15.49-1.45,29.89-3.03,42.25-4.06c3-0.25,4.25,1.75,3.5,3.75c-2.24,5.96-6,20.75-7.75,31.5", "M11.25,90.5c3.04,0.81,6.52,0.63,9.63,0.41c15.71-1.1,43.9-2.8,67.75-3.8c3.41-0.14,6.9-0.4,10.25,0.39"]},
    {"glyph": "六", "level": 5, "strokes": 4, "meanings": ["six"], "on": ["ロク"], "kun": ["む", "む.つ", "むっ.つ"], "kind": "borrowed", "parts": [{"glyph": "亠", "meaning": "lid"}, {"glyph": "八", "meaning": "spread legs"}], "mnemonic": "A lid (亠) over spread legs (八): a little hut where six people huddle.", "words": [{"word": "六つ", "reading": "むっつ", "meaning": "six (things)"}, {"word": "六月", "reading": "ろくがつ", "meaning": "June"}, {"word": "六百", "reading": "ろっぴゃく", "meaning": "six hundred"}], "sentence": "{会議|かいぎ}は{六時|ろくじ}からです。", "translation": "The meeting starts at six.", "usage": "Sounds merge in numbers: ろく + ひゃく becomes ろっぴゃく.", "strokePaths": ["M51.87,17.5c1.78,1.78,2.71,3.48,2.71,6.5c0,6.46,0.12,9.16,0.12,14.35", "M13.5,42.13c3.27,0.74,7.11,0.89,9.93,0.64c21.56-1.9,41.78-5.02,61.41-5.47c4.8-0.11,7.49,0.31,11.06,1.07", "M38.11,58.6c0.51,1.37,0.42,3.67-0.49,5.29C33.38,71.38,24,82.38,15.41,88.75", "M70.16,59.92c9.96,8.61,18.18,18.54,23.16,28.99"]},
    {"glyph": "七", "level": 5, "strokes": 2, "meanings": ["seven"], "on": ["シチ"], "kun": ["なな", "なな.つ", "なの"], "kind": "borrowed", "parts": [], "mnemonic": "An upside-down 7 with a line through it, like a European-style seven.", "words": [{"word": "七つ", "reading": "ななつ", "meaning": "seven (things)"}, {"word": "七月", "reading": "しちがつ", "meaning": "July"}, {"word": "七時", "reading": "しちじ", "meaning": "seven o'clock"}], "sentence": "{毎朝|まいあさ}{七時|しちじ}に{家|いえ}を{出|で}ます。", "translation": "I leave home at seven every morning.", "usage": "なな is often used instead of しち, because しち is easy to mishear as いち.", "strokePaths": ["M15.5,51.75c1.82,0.5,4.38,0.88,6.96,0.5c16.91-2.45,50.92-8.12,64.44-8.74c3.02-0.14,4.84,0.24,6.35,0.49", "M43,20c1.38,1.38,2.15,3.25,2.15,5.26C45.15,29.5,45,71.84,45,76c0,10.5,2.25,12.25,20.25,12.25c18.75,0,20-3.75,20-2.75"]},
    {"glyph": "八", "level": 5, "strokes": 2, "meanings": ["eight"], "on": ["ハチ"], "kun": ["や", "や.つ", "やっ.つ", "よう"], "kind": "borrowed", "parts": [], "mnemonic": "Two strokes spreading apart like the foot of a mountain.", "words": [{"word": "八つ", "reading": "やっつ", "meaning": "eight (things)"}, {"word": "八月", "reading": "はちがつ", "meaning": "August"}, {"word": "八百", "reading": "はっぴゃく", "meaning": "eight hundred"}], "sentence": "{八時|はちじ}に{学校|がっこう}へ{行|い}きます。", "translation": "I go to school at eight.", "usage": "八 widens toward the bottom (末広がり, 'spreading toward the end'), so it's considered a lucky number.", "strokePaths": ["M37.22,45c0.28,1.5,0.2,3.21-0.86,5.48c-4.23,9.02-11.48,20.4-24.1,32.02", "M48,27.25c9.38,0.25,21.12,30,37.27,45.72c3.79,3.69,6.73,5.66,9.98,7.03"]},
    {"glyph": "九", "level": 5, "strokes": 2, "meanings": ["nine"], "on": ["キュウ", "ク"], "kun": ["ここの", "ここの.つ"], "kind": "borrowed", "parts": [{"glyph": "丿", "meaning": "slanted stroke"}, {"glyph": "乙", "meaning": "hook"}], "mnemonic": "A slanted arm (丿) and a hooked elbow (乙) reaching for the ninth cookie.", "words": [{"word": "九つ", "reading": "ここのつ", "meaning": "nine (things)"}, {"word": "九月", "reading": "くがつ", "meaning": "September"}, {"word": "九時", "reading": "くじ", "meaning": "nine o'clock"}], "sentence": "{九月|くがつ}はまだ{暑|あつ}いです。", "translation": "September is still hot.", "usage": "く sounds like 苦 (suffering), so like 4 it's sometimes avoided. Times always use く: 九時 くじ.", "strokePaths": ["M41.88,14.38c1,1.38,1.5,3.25,1.5,5.12c0,40.13-9.12,57.5-28.5,68.75", "M13.5,45.75c2.88,0.85,5.78,0.05,8.58-0.66c8.47-2.14,39.88-9.79,40.92-9.84c2.5-0.12,4.75,0.5,4.25,4.75c-0.5,4.25-5.5,20.75-7,32.5c-2.23,17.46,2,19.37,18.21,19.37c13.79,0,19.01-1.07,19.27-10.12"]},
    {"glyph": "十", "level": 5, "strokes": 2, "meanings": ["ten"], "on": ["ジュウ", "ジッ"], "kun": ["とお", "と"], "parts": [], "mnemonic": "A plus sign: two hands of five fingers crossed together make ten.", "words": [{"word": "十", "reading": "とお", "meaning": "ten (things)"}, {"word": "十月", "reading": "じゅうがつ", "meaning": "October"}, {"word": "十日", "reading": "とおか", "meaning": "the 10th (of the month); ten days"}], "sentence": "{十分|じゅっぷん}{待|ま}ってください。", "translation": "Please wait ten minutes.", "usage": "十分 can be じゅっぷん (ten minutes) or じゅうぶん (enough) — context decides.", "strokePaths": ["M11.88,50.98c3.18,0.89,6.62,0.61,9.87,0.35c19.92-1.58,45.23-4.76,63.38-5.82c3.85-0.23,7.23-0.07,11,0.56", "M52.22,11.63c1.4,1.4,2.2,3.96,2.2,6.26c0,1.13-0.03,51.22-0.19,73.41c-0.03,3.96-0.06,6.83-0.08,8.08"]},
    {"glyph": "百", "level": 5, "strokes": 6, "meanings": ["hundred"], "on": ["ヒャク"], "kun": ["もも"], "kind": "phonetic", "phonetic": "白 (ハク) hints at the sound ヒャク", "parts": [{"glyph": "一", "meaning": "one"}, {"glyph": "白", "meaning": "white"}], "mnemonic": "One (一) over white (白): live to a hundred and everything turns white.", "words": [{"word": "百", "reading": "ひゃく", "meaning": "hundred"}, {"word": "三百", "reading": "さんびゃく", "meaning": "three hundred"}, {"word": "百円", "reading": "ひゃくえん", "meaning": "100 yen"}], "sentence": "このペンは{百円|ひゃくえん}です。", "translation": "This pen is 100 yen.", "usage": "Sounds shift after some numbers: 三百 さんびゃく, 六百 ろっぴゃく, 八百 はっぴゃく.", "strokePaths": ["M16.13,20.23c2.22,0.54,6.29,0.75,8.51,0.54c21.49-2.02,41.86-4.39,59.22-4.98c3.7-0.12,5.92,0.26,7.77,0.53", "M52.31,21.75c0.19,1.38,0.19,2.5-0.38,3.93c-1.65,4.19-4.81,9.19-8.66,14.68", "M30.75,42.82c0.96,0.96,1.64,2.45,1.72,4.19c0.41,8.74,0.96,32.92,1.18,43.74c0.05,2.48,0.08,4.12,0.1,4.5", "M33.55,44.8c10.35-1.37,35.73-4.38,38.78-4.59c3.15-0.22,4.92,1.17,4.92,4.24c0,4.48-0.68,32-0.92,44.06c-0.06,3.02-0.1,5.05-0.11,5.48", "M34.14,66.95c10.24-1.08,32.11-3.2,41.44-3.57", "M34.97,92.87c8.78-0.87,30.53-2.12,40.06-2.39"]},
    {"glyph": "千", "level": 5, "strokes": 3, "meanings": ["thousand"], "on": ["セン"], "kun": ["ち"], "parts": [{"glyph": "丿", "meaning": "slanted stroke"}, {"glyph": "十", "meaning": "ten"}], "mnemonic": "Ten (十) wearing a slanted cap (丿): ten, multiplied up to a thousand.", "words": [{"word": "千", "reading": "せん", "meaning": "thousand"}, {"word": "三千", "reading": "さんぜん", "meaning": "three thousand"}, {"word": "千円", "reading": "せんえん", "meaning": "1,000 yen"}], "sentence": "{千円|せんえん}{札|さつ}しかありません。", "translation": "I only have a 1,000-yen note.", "usage": "Large numbers are grouped by 万 (10,000), not by thousands: 10,000 is 一万 いちまん.", "strokePaths": ["M70.38,10.17c-0.13,1.58-0.83,2.64-2.17,3.67c-5.71,4.41-21.46,11.91-41.57,16.82", "M12.13,50.83c3.36,0.94,7.21,0.75,10.63,0.49c17.76-1.34,37.63-4.16,66.24-4.94c3.08-0.08,6.08-0.14,9.13,0.38", "M54.56,25.25c1.03,1.03,2.01,3,2.01,5.18c0,0.9-0.07,46.38-0.19,63.58c-0.02,2.93-0.04,5.04-0.06,5.99"]},
    {"glyph": "円", "level": 5, "strokes": 4, "meanings": ["yen", "circle"], "on": ["エン"], "kun": ["まる.い"], "parts": [], "mnemonic": "A shop window frame with a bar across it — the price tag says yen.", "words": [{"word": "円", "reading": "えん", "meaning": "yen; circle"}, {"word": "千円", "reading": "せんえん", "meaning": "1,000 yen"}, {"word": "一万円", "reading": "いちまんえん", "meaning": "10,000 yen"}], "sentence": "このケーキは{五百円|ごひゃくえん}です。", "translation": "This cake is 500 yen.", "usage": "Both ¥ and 円 are read えん. 百円ショップ (100-yen shops) sell almost everything.", "strokePaths": ["M21.75,19.8c0.91,0.91,1.47,3.23,1.5,5.45c0.2,13.9,0.03,47.69,0.03,62.5c0,2-0.03,4.99-0.03,6", "M24.06,21.56c15.07-1.68,49.46-5.58,57.92-6.31c2.9-0.25,4.78,1.88,4.78,4.27c0,13.48,0,53.21,0,67.48c0,9.75-4.25,6.5-8.5,1.5", "M52.25,20.75c0.88,0.88,1.5,2,1.5,3.71c0,6.76,0,27.54,0,31.04", "M24.75,59.75c14.62-1.75,43-4.25,60.5-5.25"]},
    {"glyph": "日", "level": 5, "strokes": 4, "meanings": ["sun", "day"], "on": ["ニチ", "ジツ"], "kun": ["ひ", "-び", "-か"], "kind": "pictograph", "parts": [], "mnemonic": "The sun, once drawn as a circle with a dot, squared off over time.", "words": [{"word": "日曜日", "reading": "にちようび", "meaning": "Sunday"}, {"word": "毎日", "reading": "まいにち", "meaning": "every day"}, {"word": "今日", "reading": "きょう", "meaning": "today"}], "sentence": "{今日|きょう}は{日曜日|にちようび}です。", "translation": "Today is Sunday.", "usage": "Shop hours often list 日・祝, meaning 'Sundays and holidays'. 今日 is read きょう as a whole word — a special reading.", "strokePaths": ["M31.5,24.5c1.12,1.12,1.74,2.75,1.74,4.75c0,1.6-0.16,38.11-0.09,53.5c0.02,3.82,0.05,6.35,0.09,6.75", "M33.48,26c0.8-0.05,37.67-3.01,40.77-3.25c3.19-0.25,5,1.75,5,4.25c0,4-0.22,40.84-0.23,56c0,3.48,0,5.72,0,6", "M34.22,55.25c7.78-0.5,35.9-2.5,44.06-2.75", "M34.23,86.5c10.52-0.75,34.15-2.12,43.81-2.25"]},
    {"glyph": "月", "level": 5, "strokes": 4, "meanings": ["moon", "month"], "on": ["ゲツ", "ガツ"], "kun": ["つき"], "kind": "pictograph", "parts": [], "mnemonic": "A crescent moon with two wisps of cloud drifting across it.", "words": [{"word": "月", "reading": "つき", "meaning": "moon; month"}, {"word": "月曜日", "reading": "げつようび", "meaning": "Monday"}, {"word": "一月", "reading": "いちがつ", "meaning": "January"}], "sentence": "{今夜|こんや}は{月|つき}がきれいですね。", "translation": "The moon is beautiful tonight, isn't it?", "usage": "月がきれいですね is famously — if probably apocryphally — credited to Natsume Sōseki as a subtle way to say 'I love you'.", "strokePaths": ["M34.25,16.25c1,1,1.48,2.38,1.5,4c0.38,33.62,2.38,59.38-11,73.25", "M36.25,19c4.12-0.62,31.49-4.78,33.25-5c4-0.5,5.5,1.12,5.5,4.75c0,2.76-0.5,49.25-0.5,69.5c0,13-6.25,4-8.75,1.75", "M37.25,38c10.25-1.5,27.25-3.75,36.25-4.5", "M37,58.25c8.75-1.12,27-3.5,36.25-4"]},
    {"glyph": "火", "level": 5, "strokes": 4, "meanings": ["fire"], "on": ["カ"], "kun": ["ひ", "-び", "ほ-"], "kind": "pictograph", "parts": [], "mnemonic": "A campfire: flames leaping up with sparks flying out on both sides.", "words": [{"word": "火", "reading": "ひ", "meaning": "fire"}, {"word": "火曜日", "reading": "かようび", "meaning": "Tuesday"}, {"word": "花火", "reading": "はなび", "meaning": "fireworks"}], "sentence": "{火|ひ}に{気|き}をつけてください。", "translation": "Please be careful with fire.", "usage": "花火 (fireworks, literally 'flower fire') are the highlight of summer festivals.", "strokePaths": ["M24.25,34c3.27,3.33,8.5,13,9.5,17.75", "M83,27.25c0.5,1.38,0.22,2.74-0.5,4.25c-2.38,5-7.5,12.12-12.75,17.25", "M52.5,14.25c1,1.25,1.5,3.12,1.5,5C54,69,39.62,80,21,91.5", "M52.75,50c12.49,14.06,25.01,28.42,33.62,36.13c2.7,2.42,4.9,4.02,8.38,4.87"]},
    {"glyph": "水", "level": 5, "strokes": 4, "meanings": ["water"], "on": ["スイ"], "kun": ["みず"], "kind": "pictograph", "parts": [], "mnemonic": "A main stream running down the middle with splashes to the left and right.", "words": [{"word": "水", "reading": "みず", "meaning": "water"}, {"word": "水曜日", "reading": "すいようび", "meaning": "Wednesday"}, {"word": "水着", "reading": "みずぎ", "meaning": "swimsuit"}], "sentence": "{水|みず}を{一杯|いっぱい}ください。", "translation": "A glass of water, please.", "usage": "Restaurants bring お水 (water, with the polite お) free of charge.", "strokePaths": ["M52.77,15.08c1.08,1.08,1.67,2.49,1.76,5.52c0.4,14.55-0.26,62.16-0.26,67.12c0,9.78-7.52,0.03-9.02-1.22", "M17.5,45.75c1.75,0.62,3.73,0.43,5.25,0C25.88,44.88,36.09,41,38.59,40s4.47,1.24,3.75,3.5C39,54,28.25,69,19,74.75", "M81.22,27.5c-0.22,1.25-0.72,2.25-1.52,2.97c-5.64,5.1-12.45,9.78-22.45,13.78", "M57,46c8.82,10.73,19.23,21.46,28.42,27.42c2.16,1.4,4.52,3,7.08,3.58"]},
    {"glyph": "木", "level": 5, "strokes": 4, "meanings": ["tree", "wood"], "on": ["ボク", "モク"], "kun": ["き", "こ-"], "kind": "pictograph", "parts": [], "mnemonic": "A trunk with branches reaching up and roots spreading below.", "words": [{"word": "木", "reading": "き", "meaning": "tree; wood"}, {"word": "木曜日", "reading": "もくようび", "meaning": "Thursday"}, {"word": "木村", "reading": "きむら", "meaning": "Kimura (surname)"}], "sentence": "{公園|こうえん}に{大|おお}きい{木|き}があります。", "translation": "There's a big tree in the park.", "usage": "木 appears in many surnames: 木村, 鈴木, 佐々木.", "strokePaths": ["M19.5,39.86c2.45,0.57,5.23,0.8,8.04,0.57C40.75,39.38,63,36.5,79.78,36.15c2.8-0.06,4.54,0.1,7.34,0.5", "M51.75,10.5c1.19,1.19,2,3,2,5c0,8.65,0,55.15-0.14,74.75c-0.03,4.19-0.07,7.15-0.11,8.25", "M50.75,39.5c0,1.12-0.61,2.44-1.42,3.95C41.75,57.5,26.7,73.93,15.75,80.25", "M54.5,39c4.62,6,23,25.75,31.76,34.61c2.27,2.29,4.61,4.39,7.49,5.64"]},
    {"glyph": "金", "level": 5, "strokes": 8, "meanings": ["gold", "money"], "on": ["キン", "コン"], "kun": ["かね", "かな-"], "parts": [{"glyph": "人", "meaning": "roof"}, {"glyph": "王", "meaning": "king"}], "mnemonic": "Under a roof (人), a king (王) guards two glittering nuggets of gold.", "words": [{"word": "お金", "reading": "おかね", "meaning": "money"}, {"word": "金曜日", "reading": "きんようび", "meaning": "Friday"}, {"word": "金", "reading": "きん", "meaning": "gold"}], "sentence": "{金曜日|きんようび}に{友|とも}だちと{会|あ}います。", "translation": "I'm meeting a friend on Friday.", "usage": "In everyday speech money is お金, with the polite prefix お.", "strokePaths": ["M51.75,11.88c0.25,1.52-0.22,3.57-0.8,4.84C47.73,23.79,33.13,47.1,14.5,58", "M52.25,18.25c9.5,7.5,34.14,30.88,37.21,32.67c3.12,1.82,4.14,2.66,5.54,2.83", "M34.02,47.08c1.69,0.65,3.85,0.36,5.6,0.21c6.91-0.6,14.33-1.69,23.99-2.64c2.07-0.2,4.1-0.4,6.15,0.12", "M30.18,64.96c1.95,0.67,4.47,0.31,6.47,0.12c9.24-0.87,17.42-1.58,31.35-2.53c2.3-0.16,4.68-0.36,6.96,0.08", "M51.47,48.82c0.89,0.85,0.89,3.76,0.89,4.43c0,3.64,0.27,38.71,0.22,39.82", "M31,74.75c3.25,3,7.48,9.27,8.5,12", "M73.01,72.11c0.24,1.14,0.11,2.46-0.54,3.51C70.38,79,66.44,83.22,63,86", "M18.5,94.86c2.88,1.01,6.41,0.4,9.37,0.15c16.55-1.42,32.95-2.12,51.51-3c3.13-0.15,6.32-0.27,9.38,0.59"]},
    {"glyph": "土", "level": 5, "strokes": 3, "meanings": ["earth", "soil"], "on": ["ド", "ト"], "kun": ["つち"], "kind": "pictograph", "parts": [], "mnemonic": "A cross planted in a mound — the bottom line is the ground, wider than the top.", "words": [{"word": "土", "reading": "つち", "meaning": "soil; earth"}, {"word": "土曜日", "reading": "どようび", "meaning": "Saturday"}, {"word": "土地", "reading": "とち", "meaning": "land; plot"}], "sentence": "{土曜日|どようび}は{休|やす}みです。", "translation": "Saturday is a day off.", "usage": "Calendars mark the week with one kanji per day: 月 火 水 木 金 土 日 — the moon, five elements and the sun.", "strokePaths": ["M26.63,50.89c1.63,0.4,4.64,0.6,6.26,0.4C43.5,50,62.12,48,75.66,46.92c2.71-0.22,4.36,0.19,5.72,0.39", "M52.17,17.37c1.17,1.17,2.02,3.13,2.02,4.64c0,10.25,0.14,61.06,0.14,63.36", "M15.38,87.73c2.12,0.54,6.01,0.73,8.12,0.54C46,86.25,69,84.62,90.34,83.79c3.53-0.14,5.65,0.26,7.41,0.53"]},
    {"glyph": "年", "level": 5, "strokes": 6, "meanings": ["year"], "on": ["ネン"], "kun": ["とし"], "parts": [], "mnemonic": "A person bent under a sheaf of harvested grain — one harvest, one year.", "words": [{"word": "今年", "reading": "ことし", "meaning": "this year"}, {"word": "来年", "reading": "らいねん", "meaning": "next year"}, {"word": "毎年", "reading": "まいとし/まいねん", "meaning": "every year"}], "sentence": "{来年|らいねん}、{日本|にほん}に{住|す}みたいです。", "translation": "Next year, I want to live in Japan.", "usage": "Japan also counts years by imperial era: 2019 was 令和元年, the first year of Reiwa.", "strokePaths": ["M40.01,11.89c0.24,1.61-0.01,2.86-0.84,4.46c-2.53,4.84-6.91,11.4-15.86,19.62", "M39.13,23.62c2.25,0.38,4.4,0.18,5.79,0.03c11.7-1.27,21.33-2.9,33.22-4.07c2.3-0.23,4.2,0,5.35,0.26", "M30.13,43.59c1.36,0.33,3.87,0.46,5.21,0.33c10.91-1.05,28.53-3.42,40.78-4.26c2.26-0.15,3.63,0.16,4.76,0.32", "M33.75,44.5c1,1.25,1,1.97,1.01,3.5C34.8,52.33,35,65.29,35,66.25", "M13.88,67.74c1.97,0.47,5.61,0.66,7.57,0.47c20.21-2.03,36.35-4.62,66.65-5.31c3.29-0.08,5.26,0.22,6.91,0.46", "M56.56,25.46c1.12,1.12,1.79,3.54,1.79,4.94c0,0.89-0.05,44.26-0.13,61.6c-0.01,3.12-0.03,5.39-0.05,6.38"]},
    {"glyph": "時", "level": 5, "strokes": 10, "meanings": ["time", "hour"], "on": ["ジ"], "kun": ["とき"], "kind": "phonetic", "phonetic": "寺 (ジ) gives the sound ジ", "parts": [{"glyph": "日", "meaning": "sun"}, {"glyph": "寺", "meaning": "temple"}], "mnemonic": "Sun (日) + temple (寺): the temple bell rings by the sun to tell the time.", "words": [{"word": "時間", "reading": "じかん", "meaning": "time; hours"}, {"word": "何時", "reading": "なんじ", "meaning": "what time"}, {"word": "時々", "reading": "ときどき", "meaning": "sometimes"}], "sentence": "{今|いま}、{何時|なんじ}ですか。", "translation": "What time is it now?", "usage": "Watch the irregular hours: 四時 よじ, 七時 しちじ, 九時 くじ.", "strokePaths": ["M16,29.84c0.75,0.66,1.21,1.62,1.21,3.07c0,1.18-0.16,30.08-0.21,40.85c-0.01,2.42-0.02,3.95-0.02,4.08", "M17.78,30.74c4.65-0.63,16.12-2.07,17.6-2.25c1.52-0.18,3,1.5,2.88,2.57c-0.24,2.17-0.36,24.9-0.35,40.79c0,1.63-0.12,3.35-0.12,4.43", "M18.75,52c4.5-0.75,13.5-2.12,18.22-2.35", "M17.8,74.52c6.2-0.92,11.45-1.89,18.94-2.7", "M51.44,29.03c1.37,0.44,3.63,0.34,5,0.19c9.79-1.09,16.34-2.34,25.62-3.08c2.27-0.18,3.9-0.04,5.04,0.18", "M67.59,11.37c0.89,0.9,1.59,2.24,1.59,3.75c0,8.39,0.03,27.02,0.03,27.6", "M45.38,45.35c1.49,0.44,4.21,0.59,5.71,0.44c11.29-1.16,25.66-3.29,39.2-3.99c2.48-0.13,3.97,0.21,5.21,0.43", "M46,60.99c1.43,0.46,4.04,0.58,5.49,0.46c12.01-1.07,26.89-3.07,39.07-3.89c2.38-0.16,4.41,0.22,5.6,0.44", "M78.07,46.08c1.11,1.11,1.66,2.56,1.71,5.06c0.23,12.03-0.09,34.43-0.09,38.52c0,9.83-5.42,2.19-7.66-0.04", "M56.75,70.38c2.87,1.76,6.55,6.38,7.27,9.12"]},
    {"glyph": "今", "level": 5, "strokes": 4, "meanings": ["now"], "on": ["コン", "キン"], "kun": ["いま"], "parts": [{"glyph": "人", "meaning": "roof"}], "mnemonic": "Someone ducks under a roof (人) right now — the rain has just started.", "words": [{"word": "今", "reading": "いま", "meaning": "now"}, {"word": "今日", "reading": "きょう", "meaning": "today"}, {"word": "今年", "reading": "ことし", "meaning": "this year"}, {"word": "今晩", "reading": "こんばん", "meaning": "this evening"}], "sentence": "{今日|きょう}は{忙|いそが}しいです。", "translation": "I'm busy today.", "usage": "今日 (きょう) and 今年 (ことし) are whole-word readings — learn them as words, not kanji by kanji.", "strokePaths": ["M49.42,14.25c0.1,1.11-0.11,2.93-0.71,4.47C44.5,29.5,32,47.25,11.5,61.75", "M50.66,18.99c6.1,7.28,32.37,31.03,39.1,36.36c2.28,1.81,5.21,2.58,7.49,3.09", "M39.23,50.26c1.27,0.24,2.64,0.37,4.13,0.18c5.39-0.68,11.02-1.69,15.86-2.31c1.8-0.23,3.66-0.38,4.8-0.08", "M33.25,67.75c2.12,0.38,3.57,0.61,6,0.25c6.31-0.93,18.5-3.25,25.24-4.44C68.48,62.85,70,65,68,68.75C63.33,77.5,58.75,85,53,94.5"]},
    {"glyph": "何", "level": 5, "strokes": 7, "meanings": ["what"], "on": ["カ"], "kun": ["なに", "なん"], "kind": "phonetic", "phonetic": "可 (カ) gives the sound カ", "parts": [{"glyph": "亻", "meaning": "person"}, {"glyph": "可", "meaning": "possible"}], "mnemonic": "A person (亻) sees something that might be possible (可) and asks: what?", "words": [{"word": "何", "reading": "なに", "meaning": "what"}, {"word": "何時", "reading": "なんじ", "meaning": "what time"}, {"word": "何人", "reading": "なんにん", "meaning": "how many people"}], "sentence": "これは{何|なん}ですか。", "translation": "What is this?", "usage": "なに becomes なん before d-, n- and t- sounds and before counters: 何ですか, 何時, 何人.", "strokePaths": ["M32.5,13.75c0.23,2.1-0.19,3.81-0.8,5.66c-3.95,11.84-9.67,23.37-20.45,37.34", "M26.76,36.5c1.24,1.5,1.54,3.04,1.54,5.5c0,9.46-0.13,30.79-0.17,44.62c-0.01,2.6-0.01,4.94-0.01,6.88", "M38.88,26.64c1.74,0.5,4.68,0.67,6.41,0.5c13.21-1.27,33.84-4.77,46.26-5.86c2.88-0.25,4.63,0.24,6.08,0.49", "M40.87,44c0.75,0.75,1.26,1.62,1.36,2.21c0.67,4.06,1.44,10.16,2.25,16.3c0.27,2.04,0.26,2.01,0.47,3.75", "M43.27,45.6c6.28-1.17,15.14-2.97,19.73-3.72c3.13-0.51,4.4,0.31,3.68,3.51c-0.86,3.86-2.49,10.33-3.28,14.14", "M45.59,63.17c3.71-0.39,9.45-1.24,14.45-1.85c1.89-0.23,3.82-0.47,5.75-0.69", "M83.25,24.75c1,1,1.74,2.18,1.81,4.99c0.33,13.52-0.21,56.44-0.21,61.04c0,10.71-6.35,2.71-9.18-0.77"]},
    {"glyph": "前", "level": 5, "strokes": 9, "meanings": ["front", "before"], "on": ["ゼン"], "kun": ["まえ"], "parts": [{"glyph": "月", "meaning": "flesh"}, {"glyph": "刂", "meaning": "knife"}], "mnemonic": "Antlers on top, then flesh (月) and a knife (刂): the hunter always walks in front.", "words": [{"word": "前", "reading": "まえ", "meaning": "front; before"}, {"word": "午前", "reading": "ごぜん", "meaning": "a.m.; morning"}, {"word": "名前", "reading": "なまえ", "meaning": "name"}], "sentence": "{駅|えき}の{前|まえ}で{待|ま}っています。", "translation": "I'm waiting in front of the station.", "usage": "駅前 ('in front of the station') is the classic meeting spot in every Japanese town.", "strokePaths": ["M33.5,14.5c3.34,2.07,8.64,8.5,9.48,11.72", "M72.67,12c0.26,1.14,0.07,2.23-0.52,3.19c-2.12,3.41-6.02,8.65-8.6,11.31", "M13.38,33.24c2.63,0.72,7.46,0.94,10.08,0.72c21.67-1.83,39.8-3.58,62.68-4.61c4.37-0.2,7.01,0.34,9.2,0.7", "M24.65,45.46c1.1,1.29,1.63,2.92,1.63,4.17c0,3.05,0.1,28.65,0.08,40.62c0,3.23-0.03,5.46-0.1,6", "M27.01,46.8c2.3-0.41,13.37-2.3,17.2-2.9c2.2-0.34,3.51,1.1,3.51,3.24c0,1.02-0.16,30.82-0.16,44.63c0,5.48-3.79,2.98-5.93,0.53", "M27.65,60.01c5.72-0.76,13.63-1.81,18.59-2.32", "M27.57,73.47c4.41-0.51,13.3-1.54,18.4-1.89", "M62.27,47.58c1.2,1.2,1.76,2.67,1.76,4.58c0,8.93-0.01,15.1-0.09,18.59c-0.04,1.49-0.09,2.76-0.16,4.05", "M78.85,39.25c1.26,1.26,2.01,2.88,2.01,5.02c0,14.56-0.01,42.91-0.01,47.87c0,8.62-5.96,1-7.46-0.25"]},
    {"glyph": "後", "level": 5, "strokes": 9, "meanings": ["after", "behind", "later"], "on": ["ゴ", "コウ"], "kun": ["のち", "うし.ろ", "あと", "おく.れる"], "parts": [{"glyph": "彳", "meaning": "step"}, {"glyph": "幺", "meaning": "thread"}, {"glyph": "夂", "meaning": "slow feet"}], "mnemonic": "Stepping (彳) with a thread (幺) tangled round slow feet (夂) — you fall behind.", "words": [{"word": "後ろ", "reading": "うしろ", "meaning": "behind; back"}, {"word": "午後", "reading": "ごご", "meaning": "p.m.; afternoon"}, {"word": "後で", "reading": "あとで", "meaning": "later"}], "sentence": "{仕事|しごと}の{後|あと}で{会|あ}いましょう。", "translation": "Let's meet after work.", "usage": "In speech, times use 午前 (a.m.) and 午後 (p.m.); printed timetables usually use the 24-hour clock.", "strokePaths": ["M34.25,18.38c0,1.3-0.24,2.26-0.93,3.05c-3.57,4.07-8.94,8.7-15.91,13.39", "M38.75,36.62c0.14,1.32-0.42,2.67-1.13,3.79c-3.45,5.4-11.43,14.17-22.37,22.71", "M28.4,54.36c0.81,0.81,1.38,2.02,1.38,3.28c0,0.68,0.03,25.57-0.07,35.86c-0.02,1.74-0.04,3.05-0.05,3.75", "M61.16,12.62c0.29,1.07,0.21,2.43-0.39,3.54c-2.52,4.6-6.1,9.01-9.88,12.93c-1.01,1.05-1.26,2.17,0,2.68c2.96,1.19,6.3,3.11,8.88,5.07", "M76.35,20.12c0.27,1.25-0.3,2.56-1,3.31c-7.6,8.19-16.6,16.57-26.61,25.32c-1.25,1.1-0.74,1.76,0.74,1.41C55.72,48.69,74.5,44.4,82.5,43", "M77.88,36.25c3.66,2.21,9.46,9.07,10.38,12.5", "M57.75,53c0.09,1.13,0.02,2.27-0.4,3.33c-2.2,5.51-7.08,13.22-15.6,20.92", "M59.31,59.82c1.17,0.13,2.31,0.02,3.29-0.09c2.65-0.29,9.84-1.39,13.62-2.29c2.59-0.62,3.24,0.68,2.67,2.4C75.25,70.75,59.25,88.88,43.02,96.5", "M54.75,67.5c2.52,0,19.5,15.75,31.17,24.23c2.31,1.68,4.74,3.38,7.58,4.01"]},
    {"glyph": "人", "level": 5, "strokes": 2, "meanings": ["person"], "on": ["ジン", "ニン"], "kun": ["ひと"], "kind": "pictograph", "parts": [], "mnemonic": "Two legs mid-stride: a person seen from the side.", "words": [{"word": "人", "reading": "ひと", "meaning": "person"}, {"word": "日本人", "reading": "にほんじん", "meaning": "Japanese person"}, {"word": "三人", "reading": "さんにん", "meaning": "three people"}], "sentence": "あの{人|ひと}は{先生|せんせい}です。", "translation": "That person is a teacher.", "usage": "Nationality is country + 人 (じん): アメリカ人, 日本人. Counting people is number + 人 (にん).", "strokePaths": ["M54.5,20c0.37,2.12,0.23,4.03-0.22,6.27C51.68,39.48,38.25,72.25,16.5,87.25", "M46,54.25c6.12,6,25.51,22.24,35.52,29.72c3.66,2.73,6.94,4.64,11.48,5.53"]},
    {"glyph": "子", "level": 5, "strokes": 3, "meanings": ["child"], "on": ["シ", "ス"], "kun": ["こ"], "kind": "pictograph", "parts": [], "mnemonic": "A baby swaddled in a blanket, arms stretched out wide (一).", "words": [{"word": "子ども", "reading": "こども", "meaning": "child"}, {"word": "女の子", "reading": "おんなのこ", "meaning": "girl"}, {"word": "男の子", "reading": "おとこのこ", "meaning": "boy"}], "sentence": "{子|こ}どもが{公園|こうえん}で{遊|あそ}んでいます。", "translation": "Children are playing in the park.", "usage": "子 was a classic ending for women's given names of earlier generations: 花子, 洋子.", "strokePaths": ["M33.28,19.04c1.84,0.71,3.7,0.86,5.4,0.63c4.95-0.67,27.95-4.58,29.86-4.92c3.46-0.62,4.06,1.36,2.11,3.58c-1.95,2.22-11.41,13.17-16.35,17.19", "M52.48,37.74c6.42,2.97,11.75,30.73,5.24,52.57c-2.8,9.38-8.09,2.96-10.47,0.99", "M12.25,51.48c3.75,1.14,8.79,1.03,12.48,0.49c16.77-2.47,42.86-5.84,58.53-6.75c4.26-0.25,9.11-0.34,13.11,0.57"]},
    {"glyph": "女", "level": 5, "strokes": 3, "meanings": ["woman", "female"], "on": ["ジョ", "ニョ"], "kun": ["おんな", "め"], "kind": "pictograph", "parts": [], "mnemonic": "A figure kneeling gracefully with arms crossed.", "words": [{"word": "女の人", "reading": "おんなのひと", "meaning": "woman"}, {"word": "女性", "reading": "じょせい", "meaning": "woman (formal)"}, {"word": "女の子", "reading": "おんなのこ", "meaning": "girl"}], "sentence": "{女|おんな}の{人|ひと}が{歌|うた}っています。", "translation": "A woman is singing.", "usage": "Look for 女 on toilet and bath signs. At hot springs, the curtain marked 女湯 is the women's bath.", "strokePaths": ["M53.21,18.37c0.54,2.13,0.26,3.41-0.25,5.25C50.38,33,42.62,52.75,35.75,64c-1.39,2.27-1,3.5,1,3.5c11.63,0,28.46,7.48,38.83,16.41c2.56,2.21,4.68,4.51,6.17,6.84", "M69.62,42.18c0.5,1.7,0.63,3.57-0.01,5.93C65.93,61.8,54.61,81.6,27,91.75", "M13.88,50.43c3.48,1.39,7.26,0.85,10.88,0.53c19.52-1.7,42.04-4.08,60.61-4.63c3.66-0.11,7.21-0.1,10.62,1.42"]},
    {"glyph": "男", "level": 5, "strokes": 7, "meanings": ["man", "male"], "on": ["ダン", "ナン"], "kun": ["おとこ"], "kind": "compound", "parts": [{"glyph": "田", "meaning": "rice field"}, {"glyph": "力", "meaning": "power"}], "mnemonic": "Power (力) in the rice field (田): the field worker.", "words": [{"word": "男の人", "reading": "おとこのひと", "meaning": "man"}, {"word": "男性", "reading": "だんせい", "meaning": "man (formal)"}, {"word": "男の子", "reading": "おとこのこ", "meaning": "boy"}], "sentence": "{男|おとこ}の{子|こ}が{走|はし}っています。", "translation": "A boy is running.", "usage": "At hot springs, 男湯 is the men's bath. 男性 and 女性 are the polite forms you'll see on forms and signs.", "strokePaths": ["M26.5,14.25c0.88,0.88,1.56,1.99,1.73,2.98c0.84,4.77,2.47,16.75,3.34,26.04c0.18,1.95,0.37,2.37,0.55,4.23", "M29,15.95c11.38-1.45,41.21-4.57,49.56-4.71c3.9-0.07,5.44,1.51,4.91,5.29c-0.45,3.21-3.15,15.19-4.94,22.23c-0.41,1.62-0.79,2.99-1.4,4.19", "M54,15.97c0.77,0.77,1,1.91,1,2.79c0.02,6.32,0.2,22,0.2,22.75", "M30.98,30.82C45,29.12,57.12,28,80.53,26.34", "M32.87,44.74c11.38-1.24,28.38-2.99,44.14-3.7", "M19.98,60.98c2.15,0.67,4.58,0.78,6.77,0.53c13.46-1.53,42.24-5.66,51.88-6.86c5.26-0.66,6.86,1.04,5.72,6.27c-1.92,8.83-9,27.39-15.66,33.19c-5.11,4.45-7.44,2.14-9.69-0.86", "M53.22,46.43c0.28,1.32,0.29,3.04-0.2,4.57C49.12,63.12,38,81.25,17.14,92.06"]},
    {"glyph": "先", "level": 5, "strokes": 6, "meanings": ["ahead", "previous", "tip"], "on": ["セン"], "kun": ["さき"], "kind": "compound", "parts": [{"glyph": "儿", "meaning": "legs"}], "mnemonic": "A foot stepping out ahead of a pair of legs (儿) — the one who went first.", "words": [{"word": "先生", "reading": "せんせい", "meaning": "teacher"}, {"word": "先週", "reading": "せんしゅう", "meaning": "last week"}, {"word": "先", "reading": "さき", "meaning": "ahead; tip"}], "sentence": "{先週|せんしゅう}、{京都|きょうと}へ{行|い}きました。", "translation": "Last week I went to Kyoto.", "usage": "先生 is also the title for doctors, lawyers and politicians. お先に失礼します ('excuse me for leaving first') is said when leaving work before colleagues.", "strokePaths": ["M37.51,21c0.07,0.62,0.15,1.61-0.14,2.49C35.25,29.88,31.62,37.38,24.5,45", "M38.13,32.04c1.5,0.09,3.95-0.16,4.64-0.22c6.48-0.57,20.36-1.82,27.82-2.94c1.65-0.25,3.66-0.13,5.16,0.27", "M52.81,12.38c1.28,1.28,2.01,3.12,2.01,4.75c0,0.75-0.05,31.92-0.07,32.87", "M15.88,53.26c3.42,0.98,7.15,0.5,10.62,0.22c15.99-1.3,38.99-3.55,59-4.4c2.94-0.13,5.84-0.03,8.75,0.47", "M45.18,55.68c0.32,1.45,0.15,2.48-0.15,3.85C43.24,67.65,35,86.62,20,96.38", "M60.49,53.62c1.07,1.07,1.38,2.71,1.38,4.98c0,7.78-0.22,14.88-0.22,21.89c0,15.14,1.1,16.04,15.85,16.04c14.62,0,15.64-1.78,15.64-11.29"]},
    {"glyph": "生", "level": 5, "strokes": 5, "meanings": ["life", "birth", "raw"], "on": ["セイ", "ショウ"], "kun": ["い.きる", "う.まれる", "は.える", "なま"], "kind": "pictograph", "parts": [{"glyph": "土", "meaning": "ground"}], "mnemonic": "A sprout pushing up through the ground (土) — life being born.", "words": [{"word": "学生", "reading": "がくせい", "meaning": "student"}, {"word": "先生", "reading": "せんせい", "meaning": "teacher"}, {"word": "生まれる", "reading": "うまれる", "meaning": "to be born"}, {"word": "生", "reading": "なま", "meaning": "raw; draft"}], "sentence": "{私|わたし}は{大学生|だいがくせい}です。", "translation": "I'm a university student.", "usage": "生 has more readings than almost any other kanji, so learn it word by word: 生ビール (なま, draft beer), 一生 (いっしょう, a lifetime).", "strokePaths": ["M31.26,25.89c0.36,1.36,0.35,2.65-0.05,3.79c-2.34,6.69-7.24,17.22-14.96,24.19", "M31.13,40.67c2.37,0.33,4.03,0.07,5.64-0.12c9.5-1.1,25.15-4.12,35.35-5.83c2.51-0.42,4.86-0.73,7.38-0.33", "M52.31,12.63c1.28,1.28,2.01,3.12,2.01,5.23c0,4.01,0,65.14,0,69.77", "M29.38,64.03c2.64,0.67,5.38,0.31,8.04-0.02C49.45,62.51,62.16,61,72.5,59.86c2.38-0.26,4.99-0.76,7.38-0.23", "M15.75,90.25c3.04,0.75,6.21,0.94,8.4,0.8C40.62,90,68.12,86.5,83.3,85.75c3.63-0.18,7.68,0,10.07,0.73"]},
    {"glyph": "学", "level": 5, "strokes": 8, "meanings": ["study", "learning"], "on": ["ガク"], "kun": ["まな.ぶ"], "parts": [{"glyph": "子", "meaning": "child"}], "mnemonic": "A child (子) under a roof with three sparks of knowledge above — the schoolhouse.", "words": [{"word": "学生", "reading": "がくせい", "meaning": "student"}, {"word": "大学", "reading": "だいがく", "meaning": "university"}, {"word": "学校", "reading": "がっこう", "meaning": "school"}], "sentence": "{日本語|にほんご}を{学|まな}んでいます。", "translation": "I'm studying Japanese.", "usage": "In 学校, がく + こう becomes がっこう: the く shrinks to a small っ. You'll see this sound change everywhere.", "strokePaths": ["M29.5,17.25c3.5,3,6.5,7.25,7.75,9.75", "M49,12c1.25,2,4.75,8.25,5.25,11.5", "M75,11c0.25,1.75-0.12,2.75-0.75,4.25c-1.29,3.1-4.25,7.38-6.5,9.75", "M21.25,33.75c-0.12,4.75-2,12.5-3.75,16.25", "M23.5,36.5c17-1.62,42.38-5.5,60-5.75c9.5-0.13,4.12,5.12,0,9", "M37.25,46.5c1,0.25,3.75,0.25,5.5-0.25s18.25-4,20-4s2.75,0.75,1,2.25S54.5,53.5,53,54.75", "M50.75,55.75c4,8.75,7.18,24.67,1.75,38c-2.75,6.75-7.75,1.25-9.75-2", "M15.75,67.75c1.75,1,4.64,1.36,7.5,1c15.88-2,44.43-6.25,61.37-5.5c2.5,0.11,4.72,0.25,6.39,1"]},
    {"glyph": "名", "level": 5, "strokes": 6, "meanings": ["name", "fame"], "on": ["メイ", "ミョウ"], "kun": ["な"], "kind": "compound", "parts": [{"glyph": "夕", "meaning": "evening"}, {"glyph": "口", "meaning": "mouth"}], "mnemonic": "Evening (夕) + mouth (口): in the dark you call out your name so people know who you are.", "words": [{"word": "名前", "reading": "なまえ", "meaning": "name"}, {"word": "有名", "reading": "ゆうめい", "meaning": "famous"}, {"word": "名刺", "reading": "めいし", "meaning": "business card"}], "sentence": "お{名前|なまえ}は{何|なん}ですか。", "translation": "What's your name?", "usage": "Family names come first in Japanese: in 山田太郎, Yamada is the family name. Business cards (名刺) are offered and received with both hands.", "strokePaths": ["M54.2,12.64c0.3,1.61-0.07,2.99-0.69,4.24c-3.49,7.13-13.28,19.29-25.96,27.54", "M53.25,24.16c0.88,0.47,1.95,0.5,3.28,0.37c4.37-0.43,11.99-2.47,17.81-4.1c4.18-1.17,5.46,1.02,4.41,3.51C72.25,39.38,43.88,69.62,16,77.5", "M43.62,40.88c3.62,2,8,6,9.68,9.58", "M42,67.81c0.91,0.91,1.62,2.19,1.83,3.33c0.5,2.82,2.15,14.38,3.05,20.86c0.3,2.12,0.52,3.7,0.59,4.25", "M44.53,69.52c10.82-1.38,32.39-4.4,38.01-4.53c2.76-0.06,4.08,1.63,3.25,4.64c-1.13,4.06-3.52,14.04-4.64,20.36", "M47.99,93.99c7.26-0.61,19.65-1.61,29.54-2.37c2.19-0.17,4.24-0.28,6.04-0.31"]},
    {"glyph": "友", "level": 5, "strokes": 4, "meanings": ["friend"], "on": ["ユウ"], "kun": ["とも"], "kind": "compound", "parts": [{"glyph": "ナ", "meaning": "hand"}, {"glyph": "又", "meaning": "hand"}], "mnemonic": "Two hands (ナ and 又) reaching for each other — friends.", "words": [{"word": "友だち", "reading": "ともだち", "meaning": "friend"}, {"word": "友人", "reading": "ゆうじん", "meaning": "friend (formal)"}, {"word": "親友", "reading": "しんゆう", "meaning": "best friend"}], "sentence": "{友|とも}だちと{映画|えいが}を{見|み}ました。", "translation": "I watched a film with a friend.", "usage": "友だち is everyday; 友人 sounds formal and appears in writing and speeches. Same meaning, different register.", "strokePaths": ["M17.88,37.23c2.13,0.54,5.78,0.58,7.89,0.29c17.48-2.39,35.98-4.39,54.65-5.48c3.54-0.21,5.68,0.01,7.46,0.28", "M48.22,14.14c0.53,2.11,0.53,4.3,0.31,6.73C47,38,33,72.5,15.5,85.25", "M42.66,54.86c1.09,0.27,2.51,0.28,3.59,0.14c6.88-0.88,16.62-3.25,22.43-4.88c3.45-0.97,4.6,1.45,3.11,4.55C66.5,65.62,48.12,87.75,24,96.5", "M41.25,63.5c5.15,0.45,27.5,18.62,40.93,26.36c3.2,1.84,6.65,3.76,10.32,4.39"]},
    {"glyph": "上", "level": 5, "strokes": 3, "meanings": ["up", "above"], "on": ["ジョウ"], "kun": ["うえ", "あ.げる", "あ.がる", "のぼ.る"], "kind": "indicative", "parts": [], "mnemonic": "A line rising up from the ground line.", "words": [{"word": "上", "reading": "うえ", "meaning": "above; top"}, {"word": "上手", "reading": "じょうず", "meaning": "skilful"}, {"word": "上がる", "reading": "あがる", "meaning": "to go up"}], "sentence": "{机|つくえ}の{上|うえ}に{本|ほん}があります。", "translation": "There's a book on the desk.", "usage": "Learners hear 日本語が上手ですね a lot. The modest reply is いいえ、まだまだです ('no, I still have a long way to go').", "strokePaths": ["M52.31,15.88c1.15,1.15,2.01,3.12,2.01,5.12c0,0.82-0.22,63.62-0.25,64.63", "M58,44.75c7-0.62,14.25-2.5,17.75-3c1.38-0.2,3.5-0.38,4.75,0", "M13.38,88.28c3.6,1.15,7.45,0.62,11.13,0.34c16.23-1.23,41.16-2.66,60.24-2.92c3.65-0.05,7.47-0.32,11,0.82"]},
    {"glyph": "下", "level": 5, "strokes": 3, "meanings": ["down", "below"], "on": ["カ", "ゲ"], "kun": ["した", "さ.げる", "くだ.さる", "お.りる"], "kind": "indicative", "parts": [], "mnemonic": "A line hanging down from the ceiling line.", "words": [{"word": "下", "reading": "した", "meaning": "below; under"}, {"word": "地下鉄", "reading": "ちかてつ", "meaning": "subway"}, {"word": "下手", "reading": "へた", "meaning": "unskilful"}], "sentence": "{椅子|いす}の{下|した}に{猫|ねこ}がいます。", "translation": "There's a cat under the chair.", "usage": "On railways, 上り trains run toward Tokyo or the main city, and 下り trains run away from it.", "strokePaths": ["M13.25,22.5c0.94,0.23,5.18,0.96,7.74,0.75c17.87-1.5,46.54-4.75,66.38-4.75c2.92,0,6.42,0.75,7.88,1.25", "M52.97,23.25c0.93,1.07,1.56,2.75,1.56,5.3c0,8.65-0.2,39.42-0.27,57.2c-0.02,3.86-0.02,5.89-0.02,8.25", "M67.83,37.17C72.75,39.5,79.88,47.62,82,52.12"]},
    {"glyph": "中", "level": 5, "strokes": 4, "meanings": ["middle", "inside"], "on": ["チュウ"], "kun": ["なか"], "kind": "indicative", "parts": [{"glyph": "口", "meaning": "box"}], "mnemonic": "A box (口) pierced straight through the middle.", "words": [{"word": "中", "reading": "なか", "meaning": "inside; middle"}, {"word": "中国", "reading": "ちゅうごく", "meaning": "China"}, {"word": "一日中", "reading": "いちにちじゅう", "meaning": "all day long"}], "sentence": "かばんの{中|なか}に{何|なに}がありますか。", "translation": "What's in the bag?", "usage": "Shop signs: 営業中 means 'open', 準備中 means 'getting ready' (closed). Here 中 means 'in the middle of'.", "strokePaths": ["M19.89,36.87c1,1,1.74,2.25,2.01,3.65c1.13,5.71,2.58,13.06,4.17,22.97c0.27,1.68,0.55,4.43,0.83,6.26", "M23.33,39.51C37.12,37.62,70.88,34,84,33.24c4.38-0.25,6,1.14,5.12,4.42c-1.53,5.7-5.61,20.18-6.12,22.09", "M27.74,64.84C40.12,63.62,61.86,62.2,79,60.77c2.36-0.2,5.75-0.27,7.25-0.27", "M52.5,11.5c1.44,1.44,2.25,3.5,2.25,5.06c0,0.9,0.06,56.6-0.15,76.69c-0.03,3.3-0.07,5.6-0.1,6.5"]},
    {"glyph": "大", "level": 5, "strokes": 3, "meanings": ["big", "large"], "on": ["ダイ", "タイ"], "kun": ["おお.きい"], "kind": "pictograph", "parts": [], "mnemonic": "A person stretching their arms wide: 'it was THIS big!'", "words": [{"word": "大きい", "reading": "おおきい", "meaning": "big"}, {"word": "大学", "reading": "だいがく", "meaning": "university"}, {"word": "大人", "reading": "おとな", "meaning": "adult"}], "sentence": "{大|おお}きい{家|いえ}ですね。", "translation": "What a big house.", "usage": "Menus often offer 大盛り (おおもり), a large serving, next to the regular size.", "strokePaths": ["M19.38,48.25c1.49,0.51,5.03,0.89,7.6,0.49C41.12,46.5,63,43,77.19,42.44c2.7-0.11,4.87-0.06,7.31,0.33", "M49.5,18c0.88,2.12,1.03,4.16,0.99,6.32C50,57,37.75,81.12,18,91.75", "M49.5,46c9,10.5,28.5,36.25,37.49,43.28c3.06,2.39,5.62,3.75,7.01,3.97"]},
    {"glyph": "小", "level": 5, "strokes": 3, "meanings": ["small", "little"], "on": ["ショウ"], "kun": ["ちい.さい", "こ-", "お-"], "parts": [], "mnemonic": "One tiny stroke in the middle with two little drops beside it.", "words": [{"word": "小さい", "reading": "ちいさい", "meaning": "small"}, {"word": "小学校", "reading": "しょうがっこう", "meaning": "elementary school"}, {"word": "小川", "reading": "おがわ", "meaning": "stream; brook"}], "sentence": "{小|ちい}さい{犬|いぬ}が{好|す}きです。", "translation": "I like small dogs.", "usage": "As a prefix, 小 can mean small or slight: 小雨 (こさめ) is a light drizzle.", "strokePaths": ["M54.71,18.37c1.4,1.4,2.26,3.13,2.26,5.77c0,14.56-0.26,54.91-0.26,59.87c0,11.25-7.21,1.5-8.71,0.25", "M31.95,47.68c0.17,0.82,0.1,1.72-0.34,2.9C29.5,56.38,24.38,66.25,16.75,73", "M80.96,47.12C86.62,52,95.25,64.62,97,72"]},
    {"glyph": "右", "level": 5, "strokes": 5, "meanings": ["right"], "on": ["ウ", "ユウ"], "kun": ["みぎ"], "parts": [{"glyph": "ナ", "meaning": "hand"}, {"glyph": "口", "meaning": "mouth"}], "mnemonic": "A hand (ナ) bringing food to the mouth (口) — most people eat with their right hand.", "words": [{"word": "右", "reading": "みぎ", "meaning": "right"}, {"word": "右手", "reading": "みぎて", "meaning": "right hand"}, {"word": "右側", "reading": "みぎがわ", "meaning": "right side"}], "sentence": "{次|つぎ}の{角|かど}を{右|みぎ}に{曲|ま}がってください。", "translation": "Please turn right at the next corner.", "usage": "In Tokyo, people stand on the left of escalators; in Osaka, on the right.", "strokePaths": ["M53.5,21.5c0.62,1.12,0.69,2.23,0.25,4C49.62,42,39.5,61,25.25,74.25", "M13,42.15c1.9,0.56,5.9,0.52,7.79,0.34c23.41-2.24,49.76-5.74,67.67-6.3c3.24-0.1,6.45,0.31,9.17,0.81", "M41.75,66.5c0.75,0.75,1.35,1.93,1.54,2.95c0.94,5,2.38,16.66,3.07,22.76c0.24,2.15,0.39,2.8,0.39,3.54", "M43.25,68c5.25-0.5,29.75-3.25,37-3.75c1.75-0.12,3.24,1.52,3,2.75c-1,5.12-3.38,18-4.5,23.25", "M47,93.25c5.79-0.2,19.51-1.58,28.25-2.23c2.21-0.17,4.18-0.27,5.75-0.27"]},
    {"glyph": "左", "level": 5, "strokes": 5, "meanings": ["left"], "on": ["サ"], "kun": ["ひだり"], "parts": [{"glyph": "ナ", "meaning": "hand"}, {"glyph": "工", "meaning": "tool"}], "mnemonic": "A hand (ナ) steadying a tool (工) — the left hand holds while the right one works.", "words": [{"word": "左", "reading": "ひだり", "meaning": "left"}, {"word": "左手", "reading": "ひだりて", "meaning": "left hand"}, {"word": "左側", "reading": "ひだりがわ", "meaning": "left side"}], "sentence": "{左|ひだり}に{銀行|ぎんこう}があります。", "translation": "There's a bank on the left.", "usage": "Cars drive on the left in Japan, so look right first when you cross the road.", "strokePaths": ["M20.75,40.17c2.95,0.49,5.68,0.29,8.64-0.05c14.5-1.68,29.75-4.47,47.22-5.96c2.83-0.24,5.87-0.58,8.64,0.26", "M55.48,12.5c0.27,1.57,0.21,4.18-0.29,5.93C46.59,48.64,32.07,74.14,11.25,91", "M43.25,64.59c1.25,0.29,2.38,0.29,3.86,0.17c4.86-0.37,17.91-2.17,26.92-3.77c1.88-0.33,3.97-0.5,5.97-0.11", "M58.54,66.75c1.04,1.04,1.91,2.62,1.91,4.03c0,6.84,0.04,13.22,0.04,18.72", "M28.5,92.25c2.76,0.84,5.92,0.51,8.75,0.34c14.54-0.9,32.08-2.65,48.13-3.26c3.25-0.12,6.38-0.17,9.49,0.93"]},
    {"glyph": "山", "level": 5, "strokes": 3, "meanings": ["mountain"], "on": ["サン"], "kun": ["やま"], "kind": "pictograph", "parts": [], "mnemonic": "Three peaks, the middle one the tallest.", "words": [{"word": "山", "reading": "やま", "meaning": "mountain"}, {"word": "富士山", "reading": "ふじさん", "meaning": "Mt. Fuji"}, {"word": "山田", "reading": "やまだ", "meaning": "Yamada (surname)"}], "sentence": "{富士山|ふじさん}に{登|のぼ}りたいです。", "translation": "I want to climb Mt. Fuji.", "usage": "Mountain names use the on'yomi: 富士山 is ふじさん, never 'Fuji-yama'.", "strokePaths": ["M52.49,15.5c1.38,1.38,2.26,3.5,2.26,5.75c0,0.75-0.22,58.3-0.25,59.25", "M21.49,54.5c0.88,0.88,1.39,2.25,1.26,3.75c-0.58,6.99-1,16-2.5,23c-0.7,3.26,0.11,4,2,3.75c17-2.25,47.12-5.12,65.5-6", "M89.24,49c0.94,0.94,1.64,2.38,1.51,4.25c-0.25,3.68-1.83,20.3-2.55,28.77c-0.22,2.64-0.39,4.51-0.45,4.98"]},
    {"glyph": "川", "level": 5, "strokes": 3, "meanings": ["river"], "on": ["セン"], "kun": ["かわ"], "kind": "pictograph", "parts": [], "mnemonic": "Three streams of water flowing down side by side.", "words": [{"word": "川", "reading": "かわ", "meaning": "river"}, {"word": "小川", "reading": "おがわ", "meaning": "stream; brook"}, {"word": "川口", "reading": "かわぐち", "meaning": "river mouth; Kawaguchi"}], "sentence": "{川|かわ}で{泳|およ}ぎました。", "translation": "I swam in the river.", "usage": "After another word, かわ often softens to がわ: 小川 おがわ, 品川 しながわ.", "strokePaths": ["M27.22,25.68c0.91,1.57,1.18,3.45,1.19,5.37C28.5,43.5,28.5,69,17.39,84.15", "M53.75,23.63c0.94,0.94,1.41,2.37,1.41,3.9c0,0.58-0.01,28.48-0.08,41.71c-0.02,3.31-0.04,5.74-0.06,6.63", "M85.56,15.63c1.09,1.09,1.76,2.62,1.76,4.25c0,0.74,0.23,46.86,0.09,66.12c-0.03,4.31-0.06,7.61-0.09,8.63"]},
    {"glyph": "天", "level": 5, "strokes": 4, "meanings": ["heaven", "sky"], "on": ["テン"], "kun": ["あめ", "あま"], "parts": [{"glyph": "一", "meaning": "line above"}, {"glyph": "大", "meaning": "big person"}], "mnemonic": "A line (一) above a big person (大): what's above your head is the sky.", "words": [{"word": "天気", "reading": "てんき", "meaning": "weather"}, {"word": "天国", "reading": "てんごく", "meaning": "heaven; paradise"}, {"word": "天ぷら", "reading": "てんぷら", "meaning": "tempura"}], "sentence": "{明日|あした}の{天気|てんき}はどうですか。", "translation": "What's the weather like tomorrow?", "usage": "天気予報 (てんきよほう), the weather forecast, is a fixture of morning TV.", "strokePaths": ["M21.63,24.83c1.81,0.46,5.14,0.4,6.94,0.21c14.55-1.53,35.18-4.16,50.1-5.25c3.01-0.22,4.83,0.22,6.34,0.45", "M25.31,51.64c2.09,0.31,3.47,0.4,5.94,0.11c10.62-1.25,35.88-4.38,45.96-4.93c1.74-0.1,3.62,0.03,5.99,0.45", "M50.32,26c0.68,1,1.3,3.43,1.29,5.37c-0.24,30.51-14.86,50.88-33.86,60.25", "M50.1,51.39C58.71,60,75.07,78.48,86.59,87.05c2.33,1.73,4.41,3.08,7.91,4.2"]},
    {"glyph": "気", "level": 5, "strokes": 6, "meanings": ["spirit", "air", "mood"], "on": ["キ", "ケ"], "kun": [], "parts": [{"glyph": "气", "meaning": "steam"}, {"glyph": "メ", "meaning": "cross"}], "mnemonic": "Steam (气) rising with a swirl (メ) inside: energy, spirit, the air around you.", "words": [{"word": "天気", "reading": "てんき", "meaning": "weather"}, {"word": "元気", "reading": "げんき", "meaning": "healthy; energetic"}, {"word": "気持ち", "reading": "きもち", "meaning": "feeling"}], "sentence": "お{元気|げんき}ですか。", "translation": "How have you been?", "usage": "お元気ですか is for someone you haven't seen in a while — it isn't a daily 'how are you'.", "strokePaths": ["M37.75,9.25c0.25,1.62-0.25,2.75-1,4.25C35.63,15.74,28,25.25,24,29", "M36.5,21.25c1.33-0.03,3.29-0.05,4.8-0.32c9.2-1.68,18.17-3.46,26.98-5.27c1.63-0.33,3.71-0.64,5.21-0.91", "M31.25,32.75c1.5,0.38,3.3,0.26,4.96,0.08c7.67-0.83,19.54-2.58,29.14-4.39c1.94-0.37,3.64-0.41,4.91-0.45", "M18.5,47c1.88,0.75,4,0.88,6.25,0.5c15.08-2.51,35-5.62,48.25-8c4.73-0.85,5.6,0.47,4.5,6.25c-4,21,0.71,40.32,11.5,50c7.25,6.5,6.5,0.75,6-5.25", "M57,51.75c0.12,1.62-0.17,3.03-1,4.75C49.5,70,40.25,82.75,25.75,93.25", "M30,63.75C41.5,68,54.5,78,62.25,90.5"]},
    {"glyph": "雨", "level": 5, "strokes": 8, "meanings": ["rain"], "on": ["ウ"], "kun": ["あめ", "あま-"], "kind": "pictograph", "parts": [], "mnemonic": "Four raindrops falling from a cloud that hangs under the sky line.", "words": [{"word": "雨", "reading": "あめ", "meaning": "rain"}, {"word": "大雨", "reading": "おおあめ", "meaning": "heavy rain"}, {"word": "雨水", "reading": "あまみず", "meaning": "rainwater"}], "sentence": "{雨|あめ}が{降|ふ}っています。", "translation": "It's raining.", "usage": "梅雨 (つゆ), the rainy season, soaks most of Japan in June and July.", "strokePaths": ["M25.75,22.37c1.87,0.4,4.47,0.62,6.32,0.4c11.68-1.39,28.28-3.77,41.25-4.64c2.49-0.17,4.37-0.12,7.18,0.28", "M15.5,41.25c1.25,1.5,1.66,3.26,1.89,5.19c1.24,10.69,2.19,26.61,2.66,36.31c0.13,2.7,0.2,5,0.2,6", "M18.25,44.25c1.42-0.09,62.76-5.33,69.5-6c2.5-0.25,4.61,1,4.5,3.75c-0.5,12.75-1.77,28.11-6,44.75c-1.88,7.38-5.38,1.88-8.5-1.25", "M52.25,23.5C53.31,24.56,54,26.25,54,28c0,0.82-0.25,37.8-0.43,53c-0.04,3.43-0.07,5.74-0.07,6.25", "M31,53.5c4.21,1.24,8.95,3.94,11.25,6", "M30.5,68.75c3.8,1.26,9.68,5.89,11.75,8", "M66.88,48.88c4.98,1.99,10.63,5.97,12.62,7.62", "M67.25,66.5c2.75,1,9,5.5,11,7.75"]},
    {"glyph": "本", "level": 5, "strokes": 5, "meanings": ["book", "origin", "main"], "on": ["ホン"], "kun": ["もと"], "kind": "indicative", "parts": [{"glyph": "木", "meaning": "tree"}, {"glyph": "一", "meaning": "line at the root"}], "mnemonic": "A tree (木) with a line marking its root: the origin — and books are the root of knowledge.", "words": [{"word": "本", "reading": "ほん", "meaning": "book"}, {"word": "日本", "reading": "にほん/にっぽん", "meaning": "Japan"}, {"word": "三本", "reading": "さんぼん", "meaning": "three (long, thin things)"}], "sentence": "{毎晩|まいばん}、{本|ほん}を{読|よ}みます。", "translation": "I read every night.", "usage": "本 also counts long, thin things — pens, bottles, trains: 一本 いっぽん, 二本 にほん, 三本 さんぼん.", "strokePaths": ["M20.5,33.5c1.93,0.62,4.91,1.07,8.1,0.75C42.43,32.88,66,30.75,79.64,30c3.2-0.18,7.22,0.25,9.23,0.5", "M52.1,11.12c1.25,1.25,2.05,3.23,2.05,4.99c0,0.84,0,57.16-0.02,76.76c-0.01,3.96-0.01,6.42-0.02,6.62", "M51.75,33.5c0,1-0.41,2.22-1.29,3.88C43.62,50.25,30.12,65.5,13.25,75.5", "M54.75,35.5c4.92,5.74,23.48,23.33,32.85,31.27c2.58,2.18,5.16,4.41,8.52,5.23", "M33.88,73.92c1.5,0.46,2.74,0.75,5.3,0.59c9.95-0.63,21.2-2.13,27.96-2.95c1.93-0.23,3.62-0.31,6-0.02"]},
    {"glyph": "休", "level": 5, "strokes": 6, "meanings": ["rest", "day off"], "on": ["キュウ"], "kun": ["やす.む"], "kind": "compound", "parts": [{"glyph": "亻", "meaning": "person"}, {"glyph": "木", "meaning": "tree"}], "mnemonic": "A person (亻) leaning against a tree (木): taking a rest.", "words": [{"word": "休む", "reading": "やすむ", "meaning": "to rest; to take time off"}, {"word": "休み", "reading": "やすみ", "meaning": "holiday; break"}, {"word": "夏休み", "reading": "なつやすみ", "meaning": "summer vacation"}], "sentence": "{少|すこ}し{休|やす}みましょう。", "translation": "Let's take a short break.", "usage": "Shop signs: 定休日 is the regular closing day; 本日休業 means 'closed today'.", "strokePaths": ["M35,16.5c0.25,1.75,0.25,4.25-0.88,6.8C28.91,35.01,22.37,46.02,10.5,60.29", "M26.28,42.5c0.72,1.25,1.26,3.48,1.26,4.75c0,12.75-0.07,29.88-0.26,42.25c-0.02,1.54-0.04,2.97-0.04,4.25", "M37.65,38.83c2.45,0.97,5.18,0.75,7.73,0.54c11.76-0.97,24.94-3.35,37.49-4.01c2.65-0.14,5.39-0.22,7.99,0.39", "M61.43,14c0.82,0.75,1.87,2.12,1.87,3.7c0,8.8,0.05,53.72-0.12,72.05c-0.03,2.88-0.06,4.91-0.08,5.75", "M62.43,38.32c0,2.18-1.1,4.31-1.9,6.04C54.57,57.4,44.96,71.84,35,78.75", "M64.12,38.08c4.45,8.37,16.21,25.33,24.99,33.19c1.96,1.76,4.35,4.18,6.9,5"]},
    {"glyph": "見", "level": 5, "strokes": 7, "meanings": ["see", "look"], "on": ["ケン"], "kun": ["み.る", "み.える", "み.せる"], "kind": "compound", "parts": [{"glyph": "目", "meaning": "eye"}, {"glyph": "儿", "meaning": "legs"}], "mnemonic": "An eye (目) on legs (儿), walking around to see everything.", "words": [{"word": "見る", "reading": "みる", "meaning": "to see; to watch"}, {"word": "見せる", "reading": "みせる", "meaning": "to show"}, {"word": "花見", "reading": "はなみ", "meaning": "cherry-blossom viewing"}], "sentence": "{窓|まど}から{海|うみ}が{見|み}えます。", "translation": "You can see the sea from the window.", "usage": "In shops, 見せてください ('please show me') is how you ask to look at an item.", "strokePaths": ["M32.5,15.46c0.96,0.96,1.18,2.1,1.18,3.52c0,1.12,0.07,27.43-0.02,39.27c-0.02,3.12-0.02,5.21,0.02,5.5", "M34.65,17.15c9.23-1.27,22.23-2.65,31.1-3.65c2.99-0.34,4.26,1.01,4.26,3.55c0,2.5-0.1,28.08-0.14,38.96c-0.01,2.91-0.02,4.75-0.02,4.79", "M34.84,31.1c7.28-0.6,25.03-2.98,33.9-3.38", "M34.86,44.63C43.38,44,59,42.12,68.6,41.51", "M34.71,59.66C44.5,59,58.38,57.5,68.45,57.03", "M41.99,66.75c0.26,1.5,0.01,2.99-0.41,4.04c-2.7,6.83-13.83,20.83-28.41,27.87", "M54.49,61.37c1.07,1.07,1.33,2.59,1.38,4.43c0.2,8.19,0.04,6.2,0.04,18.2c0,10.12,1.23,11.53,18.54,11.53c18.81,0,19.81-1.53,19.81-10.12"]},
    {"glyph": "行", "level": 5, "strokes": 6, "meanings": ["go", "conduct"], "on": ["コウ", "ギョウ"], "kun": ["い.く", "ゆ.く", "おこな.う"], "kind": "pictograph", "parts": [{"glyph": "彳", "meaning": "step"}], "mnemonic": "A crossroads seen from above: which way will you go?", "words": [{"word": "行く", "reading": "いく", "meaning": "to go"}, {"word": "銀行", "reading": "ぎんこう", "meaning": "bank"}, {"word": "旅行", "reading": "りょこう", "meaning": "trip; travel"}], "sentence": "{明日|あした}、{銀行|ぎんこう}に{行|い}きます。", "translation": "I'm going to the bank tomorrow.", "usage": "On train displays, 東京行 means 'bound for Tokyo'.", "strokePaths": ["M32.49,12c-0.12,1-0.45,1.9-1.1,2.62C28.29,18.06,22.2,22.6,12.5,28", "M36.5,31.75c0.07,0.73,0.08,2.28-0.39,3.18C32.12,42.5,23.83,52.5,11,62.75", "M25.57,51.75c0.9,0.9,1.23,2.25,1.23,3.26c0,0.72,0.04,24.47-0.07,35.49c-0.02,2.19-0.04,3.87-0.07,4.75", "M50.5,18.45c1.44,0.35,3.81,0.52,5.23,0.35c7.14-0.8,16.01-2.43,24.49-3.06c2.38-0.18,3.83-0.06,5.02,0.11", "M43.13,41.42c1.5,0.38,4.27,0.58,5.76,0.38c12.86-1.67,28.86-4.05,41.85-5.38c2.49-0.26,4.01,0.18,5.26,0.37", "M71.52,41.33c1.26,1.26,1.76,2.79,1.76,5.27c0,14.56-0.26,38.66-0.26,43.62c0,8.03-7.21-0.5-8.71-1.75"]},
    {"glyph": "来", "level": 5, "strokes": 7, "meanings": ["come", "next"], "on": ["ライ"], "kun": ["く.る", "きた.る"], "kind": "borrowed", "parts": [{"glyph": "木", "meaning": "tree"}], "mnemonic": "A tree (木) with a crossbar: once a drawing of wheat, a crop that came from far away.", "words": [{"word": "来る", "reading": "くる", "meaning": "to come"}, {"word": "来年", "reading": "らいねん", "meaning": "next year"}, {"word": "来週", "reading": "らいしゅう", "meaning": "next week"}], "sentence": "{友|とも}だちが{家|いえ}に{来|き}ました。", "translation": "A friend came over to my place.", "usage": "来る is irregular: 来ます (きます), 来ない (こない), 来て (きて).", "strokePaths": ["M25.54,28.33c1.61,0.39,4.58,0.53,6.19,0.39c16.32-1.46,27.01-3.46,43.69-3.67c2.69-0.03,4.31,0.18,5.65,0.38", "M30.12,37.62c2.85,2.07,7.16,7.91,7.88,11.12", "M74.52,33c0.08,0.98-0.11,1.9-0.58,2.77c-1.33,3.04-4.7,7.77-9.06,10.86", "M16.62,57c2.28,0.5,4.9,0.74,8.42,0.5c14.81-1,39.08-3.5,58.03-4.25c3.54-0.14,6.33,0.25,8.55,0.5", "M51.67,10.75c1.33,1,2.18,2.75,2.18,4.5c0,0.9,0.06,58.96-0.17,78c-0.03,2.77-0.07,4.71-0.1,5.5", "M49.75,56.5c0,1.5-0.44,2.48-0.82,3.11C42.37,70.49,29,83.75,15.75,90.5", "M55,56.25c4.38,3.88,19.75,19,29.73,26.28c2.82,2.06,6.52,4.5,10.02,5.22"]},
    {"glyph": "食", "level": 5, "strokes": 9, "meanings": ["eat", "food"], "on": ["ショク"], "kun": ["た.べる", "く.う"], "parts": [{"glyph": "人", "meaning": "lid"}, {"glyph": "良", "meaning": "good"}], "mnemonic": "A lid (人) over something good (良): a covered dish of good food.", "words": [{"word": "食べる", "reading": "たべる", "meaning": "to eat"}, {"word": "食べ物", "reading": "たべもの", "meaning": "food"}, {"word": "食堂", "reading": "しょくどう", "meaning": "cafeteria; dining hall"}], "sentence": "{朝|あさ}ご{飯|はん}を{食|た}べましたか。", "translation": "Did you have breakfast?", "usage": "Say いただきます before eating and ごちそうさまでした afterwards — both are expected at the table.", "strokePaths": ["M52.75,10.5c0.11,0.98-0.19,2.67-0.97,3.93C45,25.34,31.75,41.19,14,51.5", "M52.75,16.25c5.09,4.8,25.71,19.61,33.7,24.9c2.68,1.78,5.37,2.79,8.55,3.35", "M52.25,29.25c1,1,1.5,2.25,1.5,3.5c0,2,0,3,0,5.5", "M38,40c0.83,0.47,2.19,1,3.86,0.83c9.39-0.96,21.95-2.76,23.25-2.84c1.67-0.1,3.14,0.88,3.11,2.53C68.2,41.8,67,53.25,66.34,62.4c-0.07,0.94-0.13,1.36-0.13,1.99", "M40.83,51.73C47.25,51.25,59.5,50,66,49.75", "M40.69,63.9c7.04-0.52,16.55-1.62,24.6-2.04", "M38.25,40.25c1.12,1.12,1.5,2.62,1.5,4c0,9.12,0,43.62,0,47.25c0,4,1,4.88,4.12,2.88c2.93-1.87,6.75-5.25,10.88-8.38", "M74,64c0.25,1.25,0.09,2.57-0.75,3.5c-3.5,3.88-4.5,4.88-7.25,7.5", "M51.5,71C55.75,71,77,90,81,92.75c2.49,1.71,4.62,2.62,7.5,3.5"]},
    {"glyph": "話", "level": 5, "strokes": 13, "meanings": ["talk", "story"], "on": ["ワ"], "kun": ["はな.す", "はなし"], "parts": [{"glyph": "言", "meaning": "words"}, {"glyph": "舌", "meaning": "tongue"}], "mnemonic": "Words (言) + tongue (舌): talking.", "words": [{"word": "話す", "reading": "はなす", "meaning": "to speak; to talk"}, {"word": "電話", "reading": "でんわ", "meaning": "telephone"}, {"word": "話", "reading": "はなし", "meaning": "talk; story"}], "sentence": "{母|はは}と{電話|でんわ}で{話|はな}しました。", "translation": "I talked with my mother on the phone.", "usage": "Casual calls open with もしもし. In business calls you give your company and name first.", "strokePaths": ["M24.99,14c2.36,1.5,6.1,6.17,6.7,8.5", "M11.37,32.83c1.41,0.42,3.07,0.29,4.51,0.17c8.29-0.7,16.95-1.9,23.59-2.81c1.28-0.17,3.22,0.11,3.87,0.23", "M17.78,47.06c1.05,0.32,2.15,0.35,3.23,0.29c4.11-0.23,10.69-1.59,14.43-1.97c1.31-0.13,2.68-0.13,4.04-0.13", "M18.58,59.33c1.2,0.36,2.8,0.13,4.04,0.08c3.71-0.16,8.38-0.79,12.92-1.36c1.43-0.18,2.85-0.34,4.3-0.08", "M17.4,71.9c0.81,0.68,1.33,1.82,1.49,2.87c0.73,4.61,1.4,8.31,2.2,13.18c0.22,1.33,0.43,2.62,0.63,3.8", "M19.64,73.54c6.67-1.14,13.31-2.75,19.46-3.66c1.85-0.27,2.96,1.26,2.7,2.51c-0.89,4.19-2.46,8.16-4.05,14.07", "M22.49,89.55c4.76-0.55,8.86-1.17,14.02-1.72c0.93-0.1,1.91,0.04,2.97-0.09", "M81.75,13.75c-0.12,1.25-0.79,2.39-1.66,3.06c-4.84,3.69-15.34,9.94-29.34,14.94", "M45.39,45.8c1.55,0.34,4.36,0.62,6.73,0.34C62.8,44.9,76.37,43.07,91,42.23c2.28-0.13,4.49-0.01,6.75,0.29", "M68.87,27.19c1.4,1.4,1.85,3.06,1.85,4.88c0,1.44-0.21,28.18-0.21,35.16", "M52.07,67.83c0.93,1.17,1.22,1.76,1.35,2.34c1.38,6.2,2.13,12.33,3.08,20.33c0.13,1.14,0.27,2.31,0.42,3.53", "M54.62,69.29c12.9-1.37,25.41-2.73,32.68-3.31c2.94-0.24,3.79,2.4,3.37,3.8c-1.47,4.87-3.03,11.64-5.04,18.35", "M56.64,91.74c7.5-0.57,16.99-1.13,27.14-1.93c1.37-0.11,2.75-0.22,4.13-0.34"]},
    {"glyph": "語", "level": 5, "strokes": 14, "meanings": ["language", "word"], "on": ["ゴ"], "kun": ["かた.る"], "kind": "phonetic", "phonetic": "吾 (ゴ) gives the sound ゴ", "parts": [{"glyph": "言", "meaning": "words"}, {"glyph": "吾", "meaning": "I, me"}], "mnemonic": "Words (言) + I (吾): the words I speak — my language.", "words": [{"word": "日本語", "reading": "にほんご", "meaning": "Japanese (language)"}, {"word": "英語", "reading": "えいご", "meaning": "English"}, {"word": "物語", "reading": "ものがたり", "meaning": "tale; story"}], "sentence": "{英語|えいご}と{日本語|にほんご}が{話|はな}せます。", "translation": "I can speak English and Japanese.", "usage": "Country + 語 gives its language: 中国語, 韓国語. English is 英語, from 英 for England.", "strokePaths": ["M26,15.25c2.82,1.41,7.29,5.8,8,8", "M12.37,32.97c1.25,0.28,2.88,0.66,4.36,0.53c7.02-0.59,17.78-1.75,25.95-3c1.52-0.23,3.57-0.38,5.16,0.03", "M18.73,45.76c0.38,0.18,2.71,0.2,3.1,0.18c3.97-0.21,9.79-1.19,14.46-2.31c1.67-0.4,2.71-0.38,3.86-0.08", "M18.73,58.89c0.89,0.23,1.89,0.36,3.35,0.15c3.89-0.54,10.71-1.51,14.85-2.29c0.7-0.13,1.82-0.26,2.61-0.1", "M17.14,71.9c0.63,0.62,1.12,1.65,1.23,2.57c0.63,5.03,1.51,10.28,2.23,15.59c0.14,1.03,0.27,2.02,0.41,2.93", "M19.37,73.6c5.67-0.94,15.47-2.73,20.36-3.48c1.49-0.22,2.39,1.05,2.18,2.08c-0.71,3.44-2.27,9.75-3.23,13.89", "M21.47,89.02c3.95-0.45,10.71-1.19,16.28-1.61c1.21-0.09,2.36-0.17,3.41-0.22", "M51.79,17.49c1.38,0.26,3.91,0.28,5.27,0.15C63.88,17,72.62,15.62,80,15.32c2.3-0.1,3.67,0.04,4.81,0.15", "M67.75,20.25c0.37,1.25,0.5,2.38,0.23,3.75c-0.75,3.78-6.03,23.83-7.96,31.58", "M52.18,36.96c1.82,0.66,4.17,0.95,5.84,0.66c8.48-1.5,16.13-3.06,22.74-4.1c2.49-0.39,4.05,1.27,3.71,2.93c-0.6,2.93-2.48,11.43-3.74,17.86", "M46.33,58.46c1.13,0.24,3.94,0.2,5.07,0.08c12.34-1.29,19.11-2.39,40.88-4.02c1.88-0.14,3.75-0.02,4.69,0.09", "M52.5,69.88c0.93,0.93,1.42,2.28,1.54,3.31c0.71,6.06,1.42,12.65,2.06,19.3c0.15,1.5,0.28,2.44,0.4,3.75", "M54.99,71.67c9.47-1.45,23.75-3.41,28.85-3.9c2.14-0.21,3.28,0.98,2.86,2.93c-0.84,3.88-3.08,12.57-4.39,17.58", "M57.2,91.49c5.94-0.55,14.67-1.24,23.54-1.76c1.3-0.08,2.63-0.13,3.97-0.2"]},
    {"glyph": "読", "level": 5, "strokes": 14, "meanings": ["read"], "on": ["ドク", "トク"], "kun": ["よ.む"], "kind": "phonetic", "parts": [{"glyph": "言", "meaning": "words"}, {"glyph": "売", "meaning": "sell"}], "mnemonic": "Words (言) + sell (売): a news-seller reading the headlines aloud.", "words": [{"word": "読む", "reading": "よむ", "meaning": "to read"}, {"word": "読書", "reading": "どくしょ", "meaning": "reading (books)"}, {"word": "読み方", "reading": "よみかた", "meaning": "way of reading"}], "sentence": "{新聞|しんぶん}を{読|よ}みますか。", "translation": "Do you read the newspaper?", "usage": "読み方 is the word to use when you ask how a kanji is read: この漢字の読み方は？", "strokePaths": ["M22.38,14.75c2.25,1.63,5.81,6.71,6.37,9.25", "M10.37,33.08c1.61,0.48,3.62,0.35,5.27,0.14c5.96-0.76,13.52-1.42,20.1-2.38c1.5-0.22,3.09-0.43,4.6-0.16", "M16.23,46.31c1.17,0.37,2.73,0.18,3.93-0.01c3.99-0.62,8.33-1.2,11.58-1.97c1.35-0.32,3.26-0.58,4.65-0.58", "M16.73,58.58c1.02,0.35,2.46,0.15,3.53,0.04c3.8-0.4,9.57-1.17,12.55-1.77c1.45-0.29,2.94-0.48,4.22-0.14", "M15.64,70.4c0.71,0.61,1.08,1.37,1.12,2.29c0.79,3.76,1.71,9.85,2.52,15.05c0.16,1.05,0.32,2.06,0.48,3", "M17.75,72.05c6.09-0.91,11.59-1.7,17.42-2.67c1.7-0.28,2.73,1.3,2.49,2.58c-0.85,4.46-1.61,6.91-2.88,12.78", "M20.47,88.3c4.06-0.46,7.76-1.19,12.79-1.92c0.92-0.13,1.88-0.26,2.9-0.39", "M46.37,26.71c2.31,0.59,4.67,0.42,7,0.15c9.97-1.14,21.82-2.23,29.77-3.06c2.36-0.25,4.38-0.21,6.71,0.14", "M65.76,13.25c1.06,1.06,1.59,2.08,1.59,3.25c0,8.5-0.07,17.03-0.19,20.46", "M52.53,38.58c2.22,0.42,4.15,0.3,5.98,0.08C64,38,71.21,37.1,78,36.47c1.61-0.15,3.63-0.29,5.23,0.04", "M46.14,48.1c-0.11,3.93-1.7,12-2.6,14.35", "M47,49.96c11.42-1.27,28-3.71,41.35-4.28c9.15-0.39,0.43,7.14-0.74,8.35", "M59.49,59.25c0.5,1.52,0.71,3.09,0.29,4.83c-2.76,11.61-6.54,22.94-15.26,30.61", "M71.64,56.26c1.11,1.24,1.65,2.67,1.69,4.37c0.11,4.62-0.13,16.99-0.13,24.62c0,9.5,0.8,10.52,11.3,10.52c11,0,11.38-1.02,11.38-7.31"]},
    {"glyph": "校", "level": 5, "strokes": 10, "meanings": ["school"], "on": ["コウ"], "kun": [], "kind": "phonetic", "phonetic": "交 (コウ) gives the sound コウ", "parts": [{"glyph": "木", "meaning": "tree"}, {"glyph": "交", "meaning": "mix"}], "mnemonic": "Tree (木) + mix (交): children mixing together under the trees of the schoolyard.", "words": [{"word": "学校", "reading": "がっこう", "meaning": "school"}, {"word": "高校", "reading": "こうこう", "meaning": "high school"}, {"word": "校長", "reading": "こうちょう", "meaning": "principal"}], "sentence": "{学校|がっこう}は{八時半|はちじはん}に{始|はじ}まります。", "translation": "School starts at half past eight.", "usage": "The Japanese school year begins in April, under the cherry blossoms.", "strokePaths": ["M11.53,40.68c1.1,0.32,2.6,0.45,4.53,0.32c5.4-0.35,16.57-3,23.14-4.04c1.25-0.2,2.3-0.18,3.07,0", "M28.99,17.25c1.07,1.07,1.76,3.25,1.76,5.25c0,0.77-0.03,48.09-0.18,65.25c-0.03,3.03-0.05,5.16-0.07,6", "M30.25,40.75c0,1.25-0.49,2.66-0.96,3.77C25.28,53.91,20.88,62.25,15,70", "M33.75,51.25c2.75,1.5,6,5.25,7.25,7.75", "M66.39,15.5c0.99,0.99,1.38,1.88,1.38,3.62c0,4.25-0.02,7.62-0.08,10.41", "M48.12,31.71c2.3,0.29,3.9,0.44,6.09,0.2c10.28-1.16,20.32-2.66,32.45-3.53c2.35-0.17,4.03-0.01,5.33,0.32", "M59.24,38.93c0.2,0.53,0.06,2.27-0.4,3.14C57,45.5,53.75,49.5,50,52.5", "M79.27,38.5c4.34,3.07,8.73,8.68,10.9,12.41", "M79.15,49.18c0.35,1.32,0.17,2.62-0.54,4.18C72.25,67.25,58.75,83.25,44,91.25", "M55.95,55.88c6.3,3.37,21.64,22.12,31.45,30.33c2.64,2.21,5.07,4.15,8.6,4.44"]},
    {"glyph": "車", "level": 5, "strokes": 7, "meanings": ["car", "vehicle"], "on": ["シャ"], "kun": ["くるま"], "kind": "pictograph", "parts": [], "mnemonic": "A cart seen from above: an axle through the middle with a wheel at each end.", "words": [{"word": "車", "reading": "くるま", "meaning": "car"}, {"word": "電車", "reading": "でんしゃ", "meaning": "train"}, {"word": "自転車", "reading": "じてんしゃ", "meaning": "bicycle"}], "sentence": "{車|くるま}で{会社|かいしゃ}に{行|い}きます。", "translation": "I drive to work.", "usage": "車 on its own means a car; trains are 電車, 'electric vehicles'.", "strokePaths": ["M26,26c2.85,0.69,6.1,0.14,8.98-0.1c11.09-0.93,25.8-2.64,38.89-3.51c2.68-0.18,5.22-0.16,7.88,0.23", "M27.5,37.92c0.81,0.5,1.83,2.39,1.98,3.05c0.85,3.73,1.83,11.31,2.95,18.54c0.32,2.09,0.41,3.2,0.75,5.24", "M30.36,39.49c14.52-1.61,36.14-4.11,47.63-4.5c3.46-0.12,4.17,1.57,4.03,3.08c-0.42,4.32-2.01,13.81-3.5,20.19c-0.21,0.89-0.51,1.87-0.76,3", "M32.5,51.25c13.75-1.5,34.25-3.75,47-4.25", "M34.25,63.25C46,61.62,65,59.75,77,59.25", "M16,77.86c3.62,0.89,7.38,0.77,10.63,0.39c18.51-2.14,39.85-4.55,57.12-5.45c3.05-0.16,6.5-0.05,9.5,0.63", "M52.5,11.51c1.36,1.36,2.06,2.78,2.14,6.02c0.03,1.07-0.07,48.79-0.19,70.7c-0.02,4.27-0.05,7.36-0.07,8.65"]},
    {"glyph": "電", "level": 5, "strokes": 13, "meanings": ["electricity"], "on": ["デン"], "kun": [], "parts": [{"glyph": "雨", "meaning": "rain"}], "mnemonic": "Under the rain clouds (雨), a lightning bolt with a hooked tail strikes: electricity.", "words": [{"word": "電車", "reading": "でんしゃ", "meaning": "train"}, {"word": "電話", "reading": "でんわ", "meaning": "telephone"}, {"word": "電気", "reading": "でんき", "meaning": "electricity; light"}], "sentence": "{電車|でんしゃ}が{来|き}ました。", "translation": "The train is here.", "usage": "電 means electricity in nearly every word — 'turn off the light' is 電気を消して.", "strokePaths": ["M34.66,16.19c2.31,0.7,4.78,0.25,7.11-0.04c6.03-0.75,16.15-1.97,23.49-2.76c2.19-0.23,4.03-0.14,6.05,0.1", "M19.51,29.11c-0.2,5.55-1.93,11.7-3.21,17.3", "M20.85,32.18C37.62,30.38,70,25.62,86.4,25.2c9.1-0.24,2.35,6.05-0.78,9.53", "M50.92,17.26c1.1,1.1,1.83,2.49,1.83,3.76c0,3.98-0.16,17.08-0.23,23.73c-0.02,2.1-0.04,3.56-0.04,3.89", "M32.75,36.46c3.42,0.53,8.09,2.12,9.96,3", "M31.25,45c3.16,0.57,8.05,2.68,9.77,3.64", "M65.5,33.47c3.66,0.79,7.81,2.37,9.28,3.03", "M65.54,41.89c2.82,0.77,6.67,3.06,8.21,4.34", "M25.86,55.87c0.89,1.04,1.07,1.52,1.21,2.88c0.47,4.62,2.55,21.84,2.55,22.22c0,0.43,0.19,1.93,0.37,2.79", "M28.04,57.11c10.79-1,41.49-4.23,43.85-4.37c4.11-0.24,5.36,1.76,4.73,4.82c-0.27,1.31-2.37,9.94-4.05,17.74c-0.2,0.95-0.69,2.39-0.69,3.04", "M29.46,68.34c7.42-0.97,36.17-3.47,44.14-3.8", "M31.02,80.34C42.25,79,59.5,77.75,71.25,76.75", "M48.42,57.62c1.08,1.13,1.45,2.8,1.45,4.78c0,4.85-0.1,12.75-0.1,18.85c0,12.75,1.48,14.5,20.5,14.5c19.23,0,20.18-2.75,20.18-10.82"]},
    {"glyph": "田", "level": 4, "strokes": 5, "meanings": ["rice field"], "on": ["デン"], "kun": ["た"], "kind": "pictograph", "parts": [], "mnemonic": "A rice field divided into four neat plots.", "words": [{"word": "田んぼ", "reading": "たんぼ", "meaning": "rice paddy"}, {"word": "田中", "reading": "たなか", "meaning": "Tanaka (surname)"}, {"word": "山田", "reading": "やまだ", "meaning": "Yamada (surname)"}], "sentence": "{田中|たなか}さんは{田|た}んぼで{働|はたら}いています。", "translation": "Tanaka-san works in the rice paddies.", "usage": "Rice paddies shaped many surnames: 田中 ('in the fields'), 山田 ('mountain field').", "strokePaths": ["M18.25,27.48c1.2,1.2,2.11,2.68,2.28,3.95C22,42.25,23.52,62.11,24.81,80c0.17,2.4,0.34,3.75,0.49,6", "M20.85,29.29c8.52-0.54,50.04-3.17,61.58-4.05c4.84-0.37,7.32,2.01,7.04,5.63c-0.69,8.8-2.83,30.69-3.99,46.64c-0.18,2.44-0.34,4.75-0.47,6.86", "M53.25,29c0.88,0.88,1.19,2.12,1.19,3.5c0,9.52,0.31,46.37,0.31,47.25", "M24,55.5c5.75-0.5,55.12-3.25,62.5-3.5", "M25.98,83.07c14.77-0.82,39.39-2.07,58.18-2.83"]},
    {"glyph": "春", "level": 4, "strokes": 9, "meanings": ["spring"], "on": ["シュン"], "kun": ["はる"], "parts": [{"glyph": "日", "meaning": "sun"}], "mnemonic": "Three tiers of new growth and a person stretching under the sun (日): spring.", "words": [{"word": "春", "reading": "はる", "meaning": "spring"}, {"word": "春休み", "reading": "はるやすみ", "meaning": "spring break"}, {"word": "青春", "reading": "せいしゅん", "meaning": "youth"}], "sentence": "{春|はる}になると、{桜|さくら}が{咲|さ}きます。", "translation": "When spring comes, the cherry blossoms bloom.", "usage": "The school and business year starts in April, so spring means fresh starts.", "strokePaths": ["M28.31,25.18c1.46,0.37,4.15,0.5,5.61,0.37c12.83-1.18,22.33-2.3,36.29-3.51c2.43-0.21,4.29-0.04,6.12,0.36", "M28.5,38.67c1.54,0.38,4.11,0.3,5.65,0.13c11.6-1.3,22.23-2.92,35.13-4.38c2.7-0.31,4.72-0.16,5.88,0.12", "M15.38,53.48c3.09,1.06,6.46,0.72,9.62,0.27c20.13-2.87,36.38-5.75,54.15-7.79c3.03-0.35,5.97-0.37,8.98,0.11", "M52.75,11.25c1,1.5,1.02,3.53,0.54,5.9C50.12,32.62,39.5,68,12.5,80.75", "M53.25,41.25c2.29,0.15,29.6,28.08,35.99,32.9c2.21,1.67,5.05,2.38,7.26,2.85", "M37.77,64.94c0.83,0.83,1.28,1.93,1.28,2.97c0,0.87-0.18,22.16-0.24,29.84c-0.01,1.59-0.02,2.59-0.02,2.68", "M39.76,67.17c6.94-0.86,24.26-3.55,25.85-3.68c1.67-0.13,3.11,1.38,3.11,2.72c0,1.26-0.16,20.65-0.24,29.04c-0.02,2.16-0.03,3.57-0.03,3.73", "M40.08,80.98c4.54-0.35,23.04-1.98,27.22-2.31", "M40.08,96.98c4.29-0.23,22.79-1.73,27.47-1.81"]},
    {"glyph": "夏", "level": 4, "strokes": 10, "meanings": ["summer"], "on": ["カ", "ゲ"], "kun": ["なつ"], "parts": [{"glyph": "夂", "meaning": "slow feet"}], "mnemonic": "A heavy head on top, slow dragging feet (夂) below: too hot to hurry in summer.", "words": [{"word": "夏", "reading": "なつ", "meaning": "summer"}, {"word": "夏休み", "reading": "なつやすみ", "meaning": "summer vacation"}, {"word": "真夏", "reading": "まなつ", "meaning": "midsummer"}], "sentence": "{夏休|なつやす}みに{海|うみ}へ{行|い}きました。", "translation": "I went to the beach during the summer holidays.", "usage": "Summer is festival (祭り) season: yukata, fireworks and street food.", "strokePaths": ["M19.75,17.56c2.06,0.37,5.85,0.54,7.9,0.37c16.1-1.31,35.23-3.18,51.51-3.76c3.43-0.12,5.5,0.18,7.21,0.36", "M51.24,18.88c0.26,1,0.13,2-0.12,2.58C50,24.04,49,25.66,46.25,28", "M35.25,29.57c0.96,0.96,1.46,1.8,1.46,2.98c0,0.6-0.1,13.36-0.09,21.19c0,3.31,0.03,5.75,0.09,6", "M37.77,31.62c7.99-1.02,29.58-3.88,31.4-3.95c2.55-0.11,4.33,0.83,4.34,3.39c0,0.9,0.01,12.2,0.01,21.69c0,1.49,0,2.95,0,4.32", "M37.89,39.64c7.86-0.76,28.11-2.76,34.79-3.17", "M37.91,47.78c10.21-1.03,25.21-2.41,34.37-3.1", "M38.23,57.09c9.27-0.84,25.52-2.59,33.82-3.02", "M47.01,59.25c0.24,1.5-0.01,2.75-1,4.14c-3.62,5.1-12.51,15.11-24.34,20.55", "M48.22,66.14c1.28,0.24,2.26,0.12,3.37-0.08c4.42-0.81,6.75-1.76,12.31-2.58c3.81-0.57,3.9,1.65,2.92,3.18C61.47,75.07,40.75,92.5,17.25,98.5", "M40.75,73.72c5.25-0.22,31,16.91,41.72,20.99c2.58,0.98,4.57,1.66,7.03,1.99"]},
    {"glyph": "秋", "level": 4, "strokes": 9, "meanings": ["autumn"], "on": ["シュウ"], "kun": ["あき"], "parts": [{"glyph": "禾", "meaning": "grain"}, {"glyph": "火", "meaning": "fire"}], "mnemonic": "Grain (禾) + fire (火): fields are harvested and the stubble is burned — autumn.", "words": [{"word": "秋", "reading": "あき", "meaning": "autumn"}, {"word": "秋分", "reading": "しゅうぶん", "meaning": "autumn equinox"}, {"word": "秋田", "reading": "あきた", "meaning": "Akita (prefecture)"}], "sentence": "{秋|あき}は{食|た}べ{物|もの}がおいしいです。", "translation": "Food tastes great in autumn.", "usage": "Autumn is called 食欲の秋, 'the season of appetite', for its harvest foods.", "strokePaths": ["M39.62,15.38c-0.12,1.25-0.96,2.35-1.7,2.99c-5.2,4.45-12.22,8.98-23.42,13.39", "M8.74,43.6c0.75,0.21,2.75,0.47,4.74,0.37c7.21-0.34,16.66-1.97,27.75-3.64c1.97-0.3,3-0.46,4.24-0.25", "M29.08,28.16c1.01,1.01,1.42,2.59,1.42,4.09c0,6.99-0.05,40.67-0.05,55.5c0,2.25-0.03,4.04-0.04,5", "M29.43,42.97c0,1.53-0.82,3.59-1.12,4.4c-3.6,9.6-8.94,20.27-16.31,27.88", "M34,52c3.3,1.92,6.1,5.77,7.88,8.25", "M51,41c1.92,2.82,4.72,10.81,5.25,13.62", "M87,35.75c0.25,1.38-0.09,2.6-0.94,4.18c-1.52,2.81-5.43,9.2-9.56,13.07", "M66.46,16.75c1.17,1.12,1.83,2.7,1.86,3.92C69.38,59.88,62,78.5,41.75,91.5", "M67.32,55.54c6.72,12.87,16.04,24.3,22.59,30.72c1.95,1.91,3.71,3.68,6.34,4.48"]},
    {"glyph": "冬", "level": 4, "strokes": 5, "meanings": ["winter"], "on": ["トウ"], "kun": ["ふゆ"], "parts": [{"glyph": "夂", "meaning": "slow feet"}], "mnemonic": "Slow feet (夂) shuffling over two flakes of ice: winter.", "words": [{"word": "冬", "reading": "ふゆ", "meaning": "winter"}, {"word": "冬休み", "reading": "ふゆやすみ", "meaning": "winter break"}, {"word": "真冬", "reading": "まふゆ", "meaning": "midwinter"}], "sentence": "{冬|ふゆ}は{雪|ゆき}が{降|ふ}ります。", "translation": "It snows in winter.", "usage": "In winter, families gather around a こたつ — a low heated table covered with a quilt.", "strokePaths": ["M44.62,15.25c0.14,1.46-0.19,2.53-0.9,3.84c-4.05,7.46-11.32,16.3-21.98,23.66", "M45.86,21.96c0.81,0.29,2.21,0.43,3.89,0.18c5.75-0.88,9.61-1.32,13.36-2.17c4.04-0.92,4.68,1.79,2.97,4.69C58.5,37.5,42.25,59.38,13.75,70.75", "M38.38,32.25c6.13,4.66,30.42,20.84,42.71,27.89c3.8,2.18,8.54,4.17,12.91,4.86", "M47.25,65c5.56,1.41,14.36,5.8,15.75,8", "M40.5,81.75c8.91,2.65,22.25,9.62,25.5,14"]}
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
