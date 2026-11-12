import SwiftUI

// MARK: - Les surfaces

extension View {
    /// La carte du scanner : la surface de l'app (blanche le jour, anthracite la nuit), un filet
    /// et une ombre douce. La sienne et pas celle de Home, que Home peut changer.
    func solverCard(radius: CGFloat = MicaboRadius.card, fill: Color = MicaboColor.surface) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1))
            .shadow(color: MicaboBrand.blue900.opacity(0.05), radius: 14, y: 6)
    }
}

/// Raccourci d'écriture : une phrase du scanner dans la langue de l'app.
func solveText(_ key: String, _ vars: [String: String] = [:]) -> String {
    L10n.t("ios.solve.\(key)", locale: .resolved(), vars: vars)
}

// MARK: - La matière

/// La pastille d'une matière : son icône et sa teinte, sur un fond doux.
struct SolverSubjectTile: View {
    let subject: SolverSubject
    var size: CGFloat = 44

    var body: some View {
        MicaboIconView(icon: subject.icon, size: size * 0.66)
            .frame(width: size, height: size)
            .background(subject.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

/// La matière d'un exercice, qu'on change d'un appui.
struct SolverSubjectMenu: View {
    let subject: SolverSubject
    var onPick: (SolverSubject) -> Void
    @State private var picking = false

    var body: some View {
        Button {
            picking = true
        } label: {
            SolverSubjectChip(subject: subject, showsChevron: true)
        }
        .buttonStyle(MicaboPressableButtonStyle())
        .accessibilityLabel(Text(solveText("subject.change")))
        .accessibilityValue(Text(subject.label))
        .confirmationDialog(solveText("subject.change"), isPresented: $picking, titleVisibility: .visible) {
            ForEach(SolverSubject.allCases.filter { $0 != subject }) { option in
                Button(option.label) { onPick(option) }
            }
        }
    }
}

struct SolverSubjectChip: View {
    let subject: SolverSubject
    var showsChevron = false

    var body: some View {
        HStack(spacing: 6) {
            MicaboIconView(icon: subject.icon, size: 18)
            // « Histoire et société », « Geschichte & Gesellschaft » : le nom réduit un peu plutôt
            // que de finir en « … » (lot 7).
            Text(subject.label)
                .font(MicaboFont.ui(14, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MicaboColor.inkSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(subject.tint.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(subject.tint.opacity(0.28), lineWidth: 1))
    }
}

// MARK: - Mika

/// **Mika sur fond clair** : une carte de la surface de l'app, Mika en demi qui dépasse de son
/// bord bas (`MikaPeek.card`, la même taille partout), et ce qu'il dit à côté. Pas de scène
/// bleue : Mika vit sur le papier.
struct SolverMikaCard<Content: View>: View {
    var mood: MikaMood = .idle
    var animates = true
    @ViewBuilder var content: Content

    private let mikaSize = MikaPeek.card

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 18)
                .padding(.leading, 18)
            MikaPeek(mood: mood, width: mikaSize, animates: animates)
                .padding(.trailing, 12)
        }
        .frame(maxWidth: .infinity, minHeight: MikaPeek.height(for: mikaSize) + 12, alignment: .bottom)
        .solverCard()
        .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
    }
}

/// Une petite bulle de Mika dans le fil d'une solution : sa tête dans un rond clair, et le
/// texte dans une bulle lavée de bleu.
struct SolverMikaNote<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            SolverMikaAvatar(size: 34)
            content
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MicaboColor.accentWash, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous).strokeBorder(MicaboColor.accentSoft, lineWidth: 1))
        }
    }
}

/// La tête de Mika dans un petit rond clair, à côté de ce qu'il dit (`MikaAvatar`, fixe).
struct SolverMikaAvatar: View {
    var size: CGFloat = 34
    var mood: MikaMood = .idle

    var body: some View {
        MikaAvatar(size: size)
    }
}

// MARK: - Le texte de Mika

/// Le texte de Mika découpé pour l'écran : les phrases avec leurs formules transposées, et
/// les formules posées seules composées par le moteur (`SolverParser.blocks`).
struct SolverRichText: View {
    let source: String
    var size: CGFloat = 16
    var color: Color = MicaboColor.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(SolverParser.blocks(of: source).enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let text):
                    SheetInlineText(
                        markup: Self.isolatingFormulas(text),
                        style: SheetTextStyle(size: size, weight: .regular, color: color, lineSpacing: 4)
                    )
                case .formula(let latex):
                    SolverFormula(latex: latex, fontSize: size + 3, color: color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let inlineFormula = try! NSRegularExpression(pattern: #"\$[^$\n]+\$"#)

    /// Une formule dans une phrase garde son sens de lecture : en arabe, sans isolement, les
    /// morceaux de `$ax^2 + bx + c = 0$` se rangeaient de droite à gauche avec la phrase.
    static func isolatingFormulas(_ text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        return inlineFormula.stringByReplacingMatches(in: text, range: range, withTemplate: "\u{2066}$0\u{2069}")
    }
}

// MARK: - L'en-tête des écrans clairs

/// La rangée du haut des écrans du scanner : retour, et des actions à droite.
struct SolverTopBar<Trailing: View>: View {
    var back: MicaboHeaderBack
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: MicaboSpacing.sm) {
            MicaboCircleButton(
                systemImage: back.systemImage,
                size: 38,
                accessibilityTitle: back.accessibilityTitle,
                action: back.action
            )
            Spacer(minLength: 0)
            trailing
        }
    }
}

extension SolverTopBar where Trailing == EmptyView {
    init(back: MicaboHeaderBack) {
        self.init(back: back, trailing: { EmptyView() })
    }
}

/// Une date courte et relative : « aujourd'hui », « hier », sinon le jour.
enum SolverDates {
    static func short(_ date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        let locale = UiLocale.resolved().foundation
        if calendar.isDate(date, inSameDayAs: now) {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter.string(from: date)
    }
}
