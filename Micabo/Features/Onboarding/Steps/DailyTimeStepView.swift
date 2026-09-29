import SwiftUI

// MARK: - Le temps par jour

/// **« Combien de temps par jour ? »** Quatre crans, et une courbe qui répond.
///
/// La réponse ne se lit pas dans une liste, elle se règle au curseur et se **voit** : une
/// carte « progression estimée » porte les quatre courbes en pointillés, et celle du cran
/// choisi se dessine en plein, en violet, plus haut à mesure qu'on donne plus de temps. Un
/// mot sous la carte qualifie le cran — « un bon début », « énorme » — et le curseur, en
/// bas, aimante ses quatre crans avec un coup à chacun.
///
/// **La courbe est une forme, pas une prédiction.** Elle ne porte ni note ni date : elle
/// dit que dix minutes montent, et que trente montent plus vite. C'est tout ce qu'on peut
/// affirmer honnêtement, et c'est déjà ce qui fait bouger le curseur.
///
/// **Le bouton se tient.** Le temps par jour est la seule réponse du quiz qui engage, et
/// « tu es sûr ? » se répond en le tenant une seconde et demie, pendant que le violet le
/// remplit.
struct DailyTimeStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private static let times = OnboardingDailyTime.allCases
    /// Le cran proposé d'office : dix minutes, celui qu'on tient.
    private static let defaultIndex = 1

    private var index: Int {
        guard let minutes = model.dailyMinutes,
              let found = Self.times.firstIndex(where: { $0.rawValue == minutes }) else {
            return Self.defaultIndex
        }
        return found
    }

    private var selection: OnboardingDailyTime { Self.times[index] }

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.quiz.time"),
            contentSpacing: MicaboSpacing.lg,
            scrolls: true
        ) {
            VStack(spacing: 22) {
                OnboardingProgressCurveCard(selected: index, count: Self.times.count)

                HStack(spacing: 6) {
                    ForEach(Array(Self.times.enumerated()), id: \.element.id) { rank, time in
                        timePill(time, isSelected: rank == index) {
                            select(rank)
                        }
                    }
                }

                VStack(spacing: 18) {
                    Text(selection.caption(locale: i18n.locale))
                        .font(MicaboFont.ui(21, weight: .bold))
                        .tracking(-0.4)
                        .foregroundStyle(OnboardingPalette.ink)
                        .contentTransition(.opacity)
                        .animation(OnboardingMotion.select, value: index)
                        .frame(minHeight: 28)

                    OnboardingSnapSlider(
                        index: Binding(get: { index }, set: { select($0) }),
                        count: Self.times.count
                    )
                }
                .padding(.top, 4)
            }
            .onAppear {
                // La réponse existe dès l'affichage : une courbe dessinée sans cran
                // enregistré ferait refuser le bouton sans dire pourquoi.
                if model.dailyMinutes == nil { model.dailyMinutes = Self.times[Self.defaultIndex].rawValue }
            }
        } footer: {
            OnboardingHoldButton(
                title: i18n.t("ios.quiz.time.hold"),
                isEnabled: model.dailyMinutes != nil
            ) {
                model.advance()
            }
        }
    }

    private func select(_ rank: Int) {
        let clamped = min(max(0, rank), Self.times.count - 1)
        guard clamped != index else { return }
        model.dailyMinutes = Self.times[clamped].rawValue
        Haptics.selection()
    }

    /// Une pastille par cran : d'encre pour le cran choisi, en gris texte pour les autres.
    private func timePill(_ time: OnboardingDailyTime, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(i18n.t("ios.quiz.time.short", ["n": "\(time.rawValue)"]))
                .font(MicaboFont.ui(15, weight: .semibold))
                .foregroundStyle(isSelected ? OnboardingPalette.white : OnboardingPalette.gray)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(isSelected ? OnboardingPalette.ink : Color.clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
        .animation(OnboardingMotion.select, value: isSelected)
    }
}

// MARK: - La carte de progression

/// **Quatre courbes en pointillés, et celle qu'on a choisie en plein.**
///
/// Toutes partent du même point, en bas à gauche, et montent d'autant plus haut que le
/// cran est grand : une pour chaque temps possible, en gris, pour qu'on voie d'un coup ce
/// que dix minutes de plus changent. La courbe choisie se dessine par-dessus, en violet,
/// avec un point à chaque bout — et **elle ne se redessine pas, elle se déforme** : passer
/// de dix à trente minutes la fait monter sous les yeux, ce qui se lit comme une seule
/// courbe qui change, pas comme quatre dessins qu'on alterne.
struct OnboardingProgressCurveCard: View {
    let selected: Int
    let count: Int

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var drawn: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(i18n.t("ios.quiz.time.chart"))
                .font(MicaboFont.ui(14, weight: .semibold))
                .foregroundStyle(OnboardingPalette.gray)

            chart
                .frame(height: 190)
        }
        .padding(20)
        .background(OnboardingPalette.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).delay(OnboardingMotion.slideDuration)) { drawn = 1 }
        }
        .accessibilityElement()
        .accessibilityLabel(i18n.t("ios.quiz.time.chart"))
    }

    private var chart: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let start = ProgressCurve.start(in: size)
            let end = ProgressCurve.end(rank: CGFloat(selected), count: count, in: size)

            ZStack(alignment: .topLeading) {
                // Trois lignes de repère, en pointillés fins : la carte a une échelle,
                // même si elle ne l'écrit pas.
                Path { path in
                    for fraction in [0.2, 0.45, 0.7] {
                        path.move(to: CGPoint(x: 0, y: size.height * fraction))
                        path.addLine(to: CGPoint(x: size.width, y: size.height * fraction))
                    }
                }
                .stroke(OnboardingPalette.cardStrong, style: StrokeStyle(lineWidth: 1, dash: [2, 5]))

                // Les courbes possibles, toutes, en pointillés gris.
                ForEach(0..<count, id: \.self) { rank in
                    ProgressCurve(rank: CGFloat(rank), count: count)
                        .stroke(
                            OnboardingPalette.grayLight.opacity(rank == selected ? 0 : 0.7),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 7])
                        )
                        .animation(OnboardingMotion.select, value: selected)
                }

                // La courbe choisie, en plein, qui se déforme d'un cran à l'autre.
                ProgressCurve(rank: CGFloat(selected), count: count)
                    .trim(from: 0, to: drawn)
                    .stroke(OnboardingPalette.accent, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .animation(reduceMotion ? nil : .timingCurve(0.3, 0, 0.2, 1, duration: 0.65), value: selected)

                dot(at: start)

                dot(at: end)
                    .opacity(Double(drawn))
                    .animation(reduceMotion ? nil : .timingCurve(0.3, 0, 0.2, 1, duration: 0.65), value: selected)
            }
        }
    }

    private func dot(at point: CGPoint) -> some View {
        Circle()
            .fill(OnboardingPalette.accent)
            .overlay(Circle().strokeBorder(OnboardingPalette.white, lineWidth: 2.5))
            .frame(width: 13, height: 13)
            .position(point)
    }
}

/// **Une courbe de progression, pour un cran donné.** Le rang est animable : entre deux
/// crans, la courbe est celle du rang intermédiaire, et c'est ce qui la fait se déformer
/// plutôt que sauter.
struct ProgressCurve: Shape {
    var rank: CGFloat
    let count: Int

    var animatableData: CGFloat {
        get { rank }
        set { rank = newValue }
    }

    static func start(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * 0.04, y: size.height * 0.9)
    }

    /// Le point d'arrivée : d'autant plus haut que le cran est grand. Le premier cran
    /// monte peu, le dernier presque en haut ; entre les deux, la montée s'accélère.
    static func end(rank: CGFloat, count: Int, in size: CGSize) -> CGPoint {
        let steps = CGFloat(max(1, count - 1))
        let fraction = min(max(rank / steps, 0), 1)
        // Une courbe des hauteurs : le passage de cinq à dix minutes se voit moins que
        // celui de quinze à trente.
        let lift = 0.22 + 0.68 * pow(fraction, 0.85)
        return CGPoint(x: size.width * 0.96, y: size.height * (0.9 - lift * 0.86))
    }

    func path(in rect: CGRect) -> Path {
        let start = Self.start(in: rect.size)
        let end = Self.end(rank: rank, count: count, in: rect.size)
        let dx = end.x - start.x

        var path = Path()
        path.move(to: start)
        // Lente au départ, franche au milieu, posée à l'arrivée : la forme du progrès que
        // la page raconte, la même pour tous les crans.
        path.addCurve(
            to: end,
            control1: CGPoint(x: start.x + dx * 0.55, y: start.y),
            control2: CGPoint(x: start.x + dx * 0.55, y: end.y)
        )
        return path
    }
}

// MARK: - Le curseur à crans

/// **Une piste, une part parcourue, un bouton rond, et des crans qui aimantent.** Le doigt
/// se pose n'importe où sur la piste : on ne vise pas le bouton, on vise le cran. Un coup
/// à chaque cran franchi.
struct OnboardingSnapSlider: View {
    @Binding var index: Int
    let count: Int

    @GestureState private var isDragging = false

    private static let knob: CGFloat = 32
    private static let track: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let steps = max(1, count - 1)
            let usable = width - Self.knob
            let x = Self.knob / 2 + usable * CGFloat(index) / CGFloat(steps)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(OnboardingPalette.card)
                    .frame(height: Self.track)

                Capsule()
                    .fill(OnboardingPalette.ink)
                    .frame(width: x, height: Self.track)

                ForEach(0..<count, id: \.self) { tick in
                    Circle()
                        .fill(tick <= index ? OnboardingPalette.white.opacity(0.5) : OnboardingPalette.cardStrong)
                        .frame(width: 4, height: 4)
                        .position(x: Self.knob / 2 + usable * CGFloat(tick) / CGFloat(steps), y: Self.knob / 2)
                }

                Circle()
                    .fill(OnboardingPalette.ink)
                    .frame(width: Self.knob, height: Self.knob)
                    .overlay(Circle().strokeBorder(OnboardingPalette.white, lineWidth: 3))
                    .shadow(color: OnboardingPalette.ink.opacity(0.18), radius: 8, y: 4)
                    .scaleEffect(isDragging ? 1.12 : 1)
                    .position(x: x, y: Self.knob / 2)
            }
            .frame(height: Self.knob)
            .contentShape(Rectangle())
            .animation(OnboardingMotion.select, value: index)
            .animation(OnboardingMotion.select, value: isDragging)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in state = true }
                    .onChanged { value in
                        let fraction = (value.location.x - Self.knob / 2) / max(1, usable)
                        let target = Int((fraction * CGFloat(steps)).rounded())
                        index = min(max(0, target), steps)
                    }
            )
        }
        .frame(height: Self.knob)
        .padding(.horizontal, 2)
        .accessibilityElement()
        .accessibilityValue("\(index + 1) / \(count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: index = min(index + 1, count - 1)
            case .decrement: index = max(index - 1, 0)
            @unknown default: break
            }
        }
    }
}
