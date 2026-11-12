import SwiftUI

// MARK: - Ce que l'élève a déclaré

/// Une pastille de ce que l'élève a déclaré dans le parcours : l'examen et le temps qui
/// reste, une matière, sa première leçon (`PaywallProfile.facts`).
struct PaywallFact: Identifiable, Equatable {
    let id: String
    /// Un symbole du système, ou rien pour une matière.
    let symbol: String?
    let text: String
}

/// **Ce que l'élève a déclaré, sur une ligne** : c'est son plan qu'on lui propose
/// d'essayer, pas un abonnement en général. La ligne ne passe jamais à la ligne : les
/// pastilles qui ne tiennent pas sont retirées par la fin (la leçon, puis les matières).
struct PaywallFactsRow: View {
    let facts: [PaywallFact]

    var body: some View {
        if !facts.isEmpty {
            ViewThatFits(in: .horizontal) {
                ForEach(Array((1 ... facts.count).reversed()), id: \.self) { count in
                    HStack(spacing: 6) {
                        ForEach(facts.prefix(count)) { fact in
                            pill(fact)
                        }
                    }
                    .fixedSize()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    private func pill(_ fact: PaywallFact) -> some View {
        HStack(spacing: 5) {
            if let symbol = fact.symbol {
                Image(systemName: symbol)
                    .font(PaywallStyle.factIcon)
                    .foregroundStyle(V3Color.accentBright)
                    .accessibilityHidden(true)
            }
            Text(fact.text)
                .font(PaywallStyle.fact)
                .foregroundStyle(V3Color.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(height: PaywallStyle.factHeight)
        .background(V3Color.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(V3Color.line, lineWidth: V3Metric.border))
    }
}

// MARK: - Le tableau Gratuit / PRO

/// **Ce que Pro ouvre, face au gratuit** : une ligne par fonction, la vraie limite gratuite
/// dans la première colonne (« 1 », ou « — » quand c'est réservé à Pro), une coche dans la
/// colonne PRO, sur un lavis jaune — le jaune de « PRO » dans toute l'app.
///
/// Derrière une porte de l'app, la ligne de la porte est en tête et surlignée : c'est celle
/// que l'élève vient de toucher.
struct PaywallFeatureTable: View {
    let features: [PaywallFeature]
    var highlighted: PaywallFeature?
    var rowHeight: CGFloat = PaywallStyle.tableRow

    var body: some View {
        VStack(spacing: 0) {
            header
            ForEach(features) { feature in
                row(feature)
            }
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 6)
        .background(alignment: .trailing) {
            // La colonne PRO, d'un lavis jaune, du haut au bas du tableau.
            RoundedRectangle(cornerRadius: PaywallStyle.proColumnRadius, style: .continuous)
                .fill(V3Color.yellowWash)
                .frame(width: PaywallStyle.proColumn)
                .padding(.vertical, 6)
                .padding(.trailing, 6)
        }
        .v3Card(radius: PaywallStyle.tableRadius)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Text(L10n.t("ios.pay11.table.free", locale: .resolved()))
                .font(PaywallStyle.tableHeader)
                .foregroundStyle(V3Color.ink3)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: PaywallStyle.freeColumn)
            PaywallYellowPill(horizontal: 7, vertical: 1) {
                Text(verbatim: "PRO")
                    .font(PaywallStyle.badge)
            }
            .frame(width: PaywallStyle.proColumn)
        }
        .frame(height: PaywallStyle.tableHeaderHeight)
        .accessibilityHidden(true)
    }

    private func row(_ feature: PaywallFeature) -> some View {
        let isLead = feature == highlighted
        let title = L10n.t(feature.titleKey, locale: .resolved())
        return HStack(spacing: 0) {
            HStack(spacing: 10) {
                PaywallGlyph(
                    symbol: feature.symbol,
                    tone: feature.tone,
                    size: PaywallStyle.tableGlyph,
                    column: PaywallStyle.tableGlyphColumn
                )
                Text(title)
                    .font(isLead ? PaywallStyle.tableRowLead : PaywallStyle.tableRowTitle)
                    .foregroundStyle(V3Color.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(freeText(feature))
                .font(PaywallStyle.tableValue)
                .foregroundStyle(feature.freeAllowance == nil ? V3Color.ink3 : V3Color.ink2)
                .frame(width: PaywallStyle.freeColumn)

            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(PaywallStyle.onYellow, PaywallStyle.yellow)
                .font(.system(size: PaywallStyle.tableCheck, weight: .bold))
                .frame(width: PaywallStyle.proColumn)
        }
        .frame(minHeight: rowHeight)
        .background {
            if isLead {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(V3Color.accentWash)
                    .padding(.trailing, PaywallStyle.proColumn)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility(title: title, feature: feature))
    }

    private func freeText(_ feature: PaywallFeature) -> String {
        feature.freeAllowance.map { "\($0)" } ?? "—"
    }

    private func accessibility(title: String, feature: PaywallFeature) -> String {
        let free = feature.freeAllowance.map {
            L10n.t("ios.pay11.a11y.free", locale: .resolved(), vars: ["value": "\($0)"])
        } ?? L10n.t("ios.pay11.a11y.freeNone", locale: .resolved())
        return "\(title). \(free). \(L10n.t("ios.pay11.a11y.pro", locale: .resolved()))"
    }
}

// MARK: - La chronologie, sur une rangée

/// **La chronologie de l'essai, sur une rangée** : trois jalons reliés d'un trait —
/// « Aujourd'hui · Tout est débloqué », « 14 novembre · Je te préviens », « 15 novembre ·
/// 1er paiement : 49,99 € ». La date et la somme du premier paiement se lisent avant le
/// bouton, sans aller chercher la mention.
struct PaywallTimelineStrip: View {
    let steps: [PaywallTimeline.Step]
    var compact = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(steps) { step in
                VStack(alignment: .leading, spacing: 4) {
                    dot(step)
                    Text(step.title)
                        .font(PaywallStyle.stepTitle)
                        .foregroundStyle(V3Color.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(step.detail)
                        .font(compact ? PaywallStyle.stepDetailTight : PaywallStyle.stepDetail)
                        .foregroundStyle(V3Color.ink2)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
        .background(alignment: .topLeading) {
            GeometryReader { proxy in
                let count = CGFloat(max(steps.count, 1))
                let column = (proxy.size.width - 8 * (count - 1)) / count
                let half = PaywallStyle.stepDot / 2
                Path { path in
                    path.move(to: CGPoint(x: half, y: half))
                    path.addLine(to: CGPoint(x: (column + 8) * (count - 1) + half, y: half))
                }
                .stroke(V3Color.line, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            .flipsForRightToLeftLayoutDirection(true)
            .accessibilityHidden(true)
        }
    }

    private func dot(_ step: PaywallTimeline.Step) -> some View {
        ZStack {
            Circle().fill(V3Color.bg)
            Circle().fill(step.tone.opacity(0.2))
            Image(systemName: step.symbol + ".fill")
                .font(.system(size: PaywallStyle.stepDot * 0.45, weight: .semibold))
                .foregroundStyle(step.tone)
        }
        .frame(width: PaywallStyle.stepDot, height: PaywallStyle.stepDot)
        .accessibilityHidden(true)
    }
}
