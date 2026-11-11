import Foundation
import Observation
import UIKit

// MARK: - Ce que Mika rend

/// Une correction : le passage tel que l'élève l'a écrit, sa version corrigée, et la règle.
struct WritingFix: Equatable, Identifiable {
    var id: Int
    var original: String
    var corrected: String
    var why: String
}

/// **La relecture d'un texte**, lue dans la réponse de Mika : un avis d'ensemble, les
/// corrections, un conseil. `plain` porte la réponse quand elle n'avait aucune balise :
/// l'écran l'affiche telle quelle, l'élève voit toujours ce que Mika a dit.
struct WritingReview: Equatable {
    var summary: String?
    var fixes: [WritingFix]
    var tip: String?
    var plain: String?

    var isStructured: Bool { plain == nil }
}

/// Un morceau du texte corrigé : gardé tel quel, ou remplacé par une correction.
enum WritingSegment: Equatable {
    case kept(String)
    case fixed(String)

    var text: String {
        switch self {
        case .kept(let text), .fixed(let text): text
        }
    }

    var isFixed: Bool {
        if case .fixed = self { return true }
        return false
    }
}

// MARK: - Le parseur

/// **Lire la relecture sans rien perdre**, comme `SolverParser` : des balises en anglais
/// (`[SUMMARY]`, `[FIX]`, `[TIP]`) plutôt que du JSON dans le JSON de `mika-chat`. Une balise
/// en gras, numérotée ou traduite se lit quand même ; une réponse sans balise s'affiche telle
/// quelle (`plain`).
enum WritingParser {
    enum Tag {
        case summary
        case fix
        case tip
    }

    /// Les mots de balise reconnus, dans les langues où un modèle pourrait les traduire.
    private static let aliases: [String: Tag] = [
        "summary": .summary, "overview": .summary, "avis": .summary, "bilan": .summary, "resume": .summary,
        "fazit": .summary, "resumen": .summary, "ozet": .summary,
        "fix": .fix, "correction": .fix, "korrektur": .fix, "correccion": .fix, "duzeltme": .fix, "error": .fix,
        "tip": .tip, "conseil": .tip, "astuce": .tip, "tipp": .tip, "consejo": .tip, "ipucu": .tip, "advice": .tip,
    ]

    /// `[FIX]`, `[Fix 2]`, `**[TIP]**`, `[CONSEIL] :`. Le mot de la balise est capturé.
    private static let tagPattern = try! NSRegularExpression(
        pattern: #"\*{0,2}\[\s*([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ ]{0,15}?)\s*\d*\s*\]\*{0,2}\s*:?[ \t]*"#
    )

    /// Ce qui sépare le passage fautif de sa correction.
    private static let arrows = ["=>", "⇒", "->", "→", "➜"]

    /// Les corrections gardées au plus : la consigne en demande six, un modèle bavard n'en
    /// affiche pas trente.
    static let maximumFixes = 10

    static func sections(of raw: String) -> [(tag: Tag, text: String)] {
        let text = raw.replacingOccurrences(of: "\r\n", with: "\n")
        let range = NSRange(text.startIndex..., in: text)
        var marks: [(tag: Tag, start: String.Index, end: String.Index)] = []
        for match in tagPattern.matches(in: text, range: range) {
            guard let whole = Range(match.range, in: text),
                  let word = Range(match.range(at: 1), in: text) else { continue }
            let key = SolverSubjectGuess.fold(String(text[word])).trimmingCharacters(in: .whitespaces)
            guard let tag = aliases[key] else { continue }
            marks.append((tag, whole.lowerBound, whole.upperBound))
        }
        var sections: [(tag: Tag, text: String)] = []
        for (index, mark) in marks.enumerated() {
            let end = index + 1 < marks.count ? marks[index + 1].start : text.endIndex
            let body = String(text[mark.end..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            sections.append((mark.tag, body))
        }
        return sections
    }

    static func parse(_ raw: String) -> WritingReview {
        let sections = Self.sections(of: raw)
        guard !sections.isEmpty else {
            let plain = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return WritingReview(summary: nil, fixes: [], tip: nil, plain: plain.isEmpty ? nil : plain)
        }
        var summary: String?
        var tip: String?
        var fixes: [WritingFix] = []
        for section in sections {
            switch section.tag {
            case .summary:
                if !section.text.isEmpty { summary = section.text }
            case .tip:
                if !section.text.isEmpty { tip = section.text }
            case .fix:
                guard fixes.count < maximumFixes, var fix = Self.fix(from: section.text) else { continue }
                fix.id = fixes.count
                fixes.append(fix)
            }
        }
        return WritingReview(summary: summary, fixes: fixes, tip: tip, plain: nil)
    }

    /// Une correction : `passage` puis `=> correction` (sur la ligne suivante ou la même), puis
    /// l'explication. Une correction qui ne change rien n'en est pas une.
    static func fix(from body: String) -> WritingFix? {
        let lines = body.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }

        var original = ""
        var corrected = ""
        var rest: [String] = []
        var found = false
        for (index, line) in lines.enumerated() {
            if found {
                rest.append(line)
                continue
            }
            if let arrow = arrows.first(where: { line.hasPrefix($0) }) {
                original = lines[..<index].joined(separator: " ")
                corrected = String(line.dropFirst(arrow.count))
                found = true
            } else if let arrow = arrows.first(where: { line.contains(" \($0) ") }),
                      let split = line.range(of: " \(arrow) ") {
                original = (lines[..<index] + [String(line[..<split.lowerBound])]).joined(separator: " ")
                corrected = String(line[split.upperBound...])
                found = true
            }
        }
        let from = unquoted(original)
        let to = unquoted(corrected)
        guard found, !from.isEmpty, !to.isEmpty, from != to else { return nil }
        return WritingFix(id: 0, original: from, corrected: to, why: rest.joined(separator: " "))
    }

    /// Un passage sans ses guillemets ni ses tirets de liste : c'est ce qu'on cherche dans le
    /// texte de l'élève.
    static func unquoted(_ text: String) -> String {
        var out = text.trimmingCharacters(in: .whitespaces)
        if out.hasPrefix("- ") || out.hasPrefix("• ") { out = String(out.dropFirst(2)) }
        out = out.replacingOccurrences(of: "**", with: "")
        let quotes = CharacterSet(charactersIn: "«»“”„\"'‘’‹›「」")
        out = out.trimmingCharacters(in: quotes.union(.whitespaces))
        return out
    }

    // MARK: Le texte corrigé

    /// **Le texte de l'élève, corrections appliquées sur l'appareil.** Chaque passage fautif est
    /// cherché tel quel, à sa première place libre ; un passage introuvable (le modèle l'a
    /// réécrit) ne change rien au texte, et sa correction reste affichée dans la liste.
    static func segments(of text: String, fixes: [WritingFix]) -> [WritingSegment] {
        var placed: [(range: Range<String.Index>, replacement: String)] = []
        for fix in fixes where !fix.original.isEmpty {
            var start = text.startIndex
            while start < text.endIndex,
                  let range = text.range(of: fix.original, options: [], range: start..<text.endIndex) {
                if placed.contains(where: { $0.range.overlaps(range) }) {
                    start = range.upperBound
                    continue
                }
                placed.append((range, fix.corrected))
                break
            }
        }
        placed.sort { $0.range.lowerBound < $1.range.lowerBound }
        var segments: [WritingSegment] = []
        var cursor = text.startIndex
        for item in placed {
            if cursor < item.range.lowerBound {
                segments.append(.kept(String(text[cursor..<item.range.lowerBound])))
            }
            segments.append(.fixed(item.replacement))
            cursor = item.range.upperBound
        }
        if cursor < text.endIndex {
            segments.append(.kept(String(text[cursor...])))
        }
        return segments
    }

    static func corrected(_ text: String, fixes: [WritingFix]) -> String {
        segments(of: text, fixes: fixes).map(\.text).joined()
    }
}

// MARK: - Les mots

enum WritingCount {
    /// Les mots d'un texte, comptés comme un traitement de texte (le japonais n'est pas une
    /// langue de l'app : les espaces suffisent).
    static func words(in text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    /// Une tranche, pour les statistiques : jamais la longueur exacte d'un texte d'élève.
    static func bucket(_ words: Int) -> String {
        switch words {
        case ..<50: "lt50"
        case ..<150: "50-150"
        case ..<400: "150-400"
        default: "400+"
        }
    }
}

// MARK: - Ce qu'on demande à Mika

/// **La consigne de relecture, dans la langue de l'app** : les explications arrivent dans la
/// langue de l'élève, et le texte garde la sienne (on corrige un devoir d'anglais en anglais,
/// expliqué en français). Les balises restent en anglais : c'est ce que `WritingParser` lit.
enum WritingPrompts {
    static func check(level: String? = HomeworkLevel.current) -> String {
        HomeworkLevel.appending(level, to: L10n.t("ios.ku7.writing.prompt", locale: .resolved()))
    }

    static var attachmentTitle: String { L10n.t("ios.ku7.writing.attach", locale: .resolved()) }
}

// MARK: - Une relecture

/// **Un texte, de la saisie à la relecture.**
///
/// Tout passe par `mika-chat`, sans fonction nouvelle : le texte part en document joint (lu
/// sur l'appareil quand il vient d'une photo), la consigne en message de l'élève. La porte est
/// **celle de Mika** (`MikaQuota`) : la question offerte à vie, puis le paywall `mika` ; pour
/// un abonné, le plafond du jour. Rien n'est consommé avant que la réponse n'arrive. Une
/// relecture rapporte `mikaAnswer`.
@Observable
@MainActor
final class WritingSession {
    enum Phase: Equatable {
        case editing
        case checking
        case reviewed
        /// La porte est fermée : le texte reste, la relecture attend Pro.
        case locked
        case failed(String)
    }

    /// D'où vient le texte, pour les statistiques.
    enum Source: String {
        case typed
        case pasted
        case photo
    }

    /// En dessous, il n'y a pas de quoi corriger.
    static let minimumWords = 3

    var text: String
    private(set) var phase: Phase = .editing
    private(set) var review: WritingReview?
    /// Le texte tel qu'il est parti : la relecture s'y applique, même si l'élève le retouche.
    private(set) var reviewedText = ""
    private(set) var notice: String?
    private(set) var reading = false
    private(set) var readFailure: String?
    var paywall: PaywallTrigger?
    private(set) var source: Source = .typed

    let quota: MikaQuota
    private let xp: XPStore?

    init(text: String = "", quota: MikaQuota = MikaQuota(), xp: XPStore? = .shared) {
        self.text = text
        self.quota = quota
        self.xp = xp
    }

    var wordCount: Int { WritingCount.words(in: text) }

    var canCheck: Bool {
        wordCount >= Self.minimumWords && phase != .checking && !reading
    }

    var segments: [WritingSegment] {
        WritingParser.segments(of: reviewedText, fixes: review?.fixes ?? [])
    }

    var correctedText: String {
        segments.map(\.text).joined()
    }

    // MARK: Le texte

    func paste(_ string: String?) {
        guard let clean = string?.trimmingCharacters(in: .whitespacesAndNewlines), !clean.isEmpty else { return }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? clean : text + "\n\n" + clean
        source = .pasted
        readFailure = nil
    }

    /// Une ou plusieurs photos d'un texte, lues sur l'appareil.
    func read(_ images: [UIImage], recognize: ([UIImage]) async -> String = { await OnDeviceOCR.recognize(images: $0) }) async {
        guard !images.isEmpty, !reading else { return }
        reading = true
        readFailure = nil
        defer { reading = false }
        let found = await recognize(Array(images.prefix(OnDeviceOCR.pageLimit)))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard WritingCount.words(in: found) >= Self.minimumWords else {
            readFailure = L10n.t("ios.ku7.writing.unreadable", locale: .resolved())
            Haptics.warning()
            Analytics.track(.writingUnreadable)
            return
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? found : text + "\n\n" + found
        source = .photo
        Haptics.success()
    }

    // MARK: Relire

    func check(isPro: Bool, service: any AIService) async {
        guard canCheck else { return }
        notice = nil
        switch quota.gate(isPro: isPro) {
        case .allowed:
            break
        case .paywall:
            phase = .locked
            paywall = .mika
            Analytics.track(.mikaBlocked, ["reason": .text("paywall")])
            return
        case .dailyCapReached:
            notice = L10n.t("lesson.mika.capReached", locale: .resolved())
            Haptics.warning()
            Analytics.track(.mikaBlocked, ["reason": .text("cap")])
            return
        }

        let submitted = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(MikaLimits.attachmentCharacters))
        phase = .checking
        let request = MikaChatRequest(
            turns: [MikaTurn(role: .user, text: WritingPrompts.check())],
            attachment: MikaAttachmentPayload(title: WritingPrompts.attachmentTitle, text: submitted),
            language: SolverSession.language,
            level: SolverSession.level
        )
        do {
            let reply = try await service.chat(request)
            let parsed = WritingParser.parse(reply.reply)
            guard parsed.plain != nil || parsed.summary != nil || !parsed.fixes.isEmpty || parsed.tip != nil else {
                throw AIServiceError.invalidResponse
            }
            review = parsed
            reviewedText = submitted
            phase = .reviewed
            quota.noteAnswered()
            xp?.award(.mikaAnswer)
            Haptics.success()
            Analytics.track(.mikaAsked, ["pro": .flag(isPro), "attached": .flag(true)])
            Analytics.track(.writingChecked, [
                "source": .text(source.rawValue),
                "fixes": .number(Double(parsed.fixes.count)),
                "applied": .number(Double(segments.filter(\.isFixed).count)),
                "structured": .flag(parsed.isStructured),
                "words": .text(WritingCount.bucket(WritingCount.words(in: submitted))),
            ])
        } catch {
            phase = .failed(SolverSession.message(for: error))
        }
    }

    /// Un abonné qui revient du paywall : la relecture part toute seule.
    func unlocked(service: any AIService) async {
        guard phase == .locked else { return }
        phase = .editing
        await check(isPro: true, service: service)
    }

    /// Retour au texte, relecture gardée de côté jusqu'à la suivante.
    func edit() {
        phase = .editing
        notice = nil
    }

    /// Un autre texte : tout repart de zéro.
    func restart() {
        text = ""
        review = nil
        reviewedText = ""
        source = .typed
        notice = nil
        readFailure = nil
        phase = .editing
    }
}
