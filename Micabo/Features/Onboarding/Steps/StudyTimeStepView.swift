import SwiftUI

/// **« À quelle heure tu préfères réviser ? »**
///
/// Un curseur horizontal, de cinq heures du matin à onze heures du soir, et au-dessus un
/// ciel qui suit : le soleil se lève à gauche, passe au zénith à midi, se couche à droite,
/// et la lune prend le relais la nuit. La réponse se lit sur le ciel avant de se lire sur
/// l'heure, et c'est ce qui fait qu'on la règle en regardant.
///
/// C'est l'heure du rappel quotidien : l'écran des notifications vient juste après, et
/// c'est cette heure-là que la notification promise portera.
struct StudyTimeStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// De cinq heures à vingt-trois heures. Personne ne se fait rappeler à trois heures.
    private static let hours = Array(5...23)
    private static let defaultHour = 18

    private var hour: Int { model.studyHour ?? Self.defaultHour }

    private var ticks: [GradeTick] {
        Self.hours.map { GradeTick(score: $0, label: hourText($0)) }
    }

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.studyTime.title"),
            subtitle: i18n.t("ios.studyTime.sub"),
            scrolls: false,
            expandsContent: true
        ) {
            VStack(spacing: MicaboSpacing.lg) {
                Spacer(minLength: 0)

                OnboardingSkyCard(hour: hour)

                GradeWheel(
                    choices: ticks,
                    score: Binding(
                        get: { model.studyHour },
                        set: { model.studyHour = $0 }
                    ),
                    fallbackIndex: Self.hours.firstIndex(of: Self.defaultHour),
                    label: i18n.t("ios.studyTime.title"),
                    valueSize: 64,
                    caption: periodText
                )

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } footer: {
            OnboardingContinueButton {
                if model.studyHour == nil { model.studyHour = Self.defaultHour }
                model.advance()
            }
        }
    }

    /// « 18:00 » ou « 6 PM », selon la langue.
    private func hourText(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = i18n.locale.foundation
        formatter.setLocalizedDateFormatFromTemplate("j")
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }

    /// Le moment de la journée, en un mot sous l'heure.
    private var periodText: String {
        switch hour {
        case ..<12: i18n.t("ios.studyTime.morning")
        case ..<18: i18n.t("ios.studyTime.afternoon")
        case ..<21: i18n.t("ios.studyTime.evening")
        default: i18n.t("ios.studyTime.night")
        }
    }
}

// MARK: - Le ciel

/// **Un ciel qui change avec l'heure, et un soleil qui le traverse.** Le jour va de six à
/// vingt-et-une heures : le soleil se lève au bord gauche, culmine à midi, se couche au bord
/// droit. La nuit, une lune fait le même trajet, plus bas, sur un ciel d'encre étoilé. Les
/// couleurs glissent d'une heure à l'autre : c'est le seul endroit du parcours où le fond
/// n'est pas blanc, et il a une raison.
struct OnboardingSkyCard: View {
    let hour: Int

    private struct Sky {
        let hour: Double
        let top: (Double, Double, Double)
        let bottom: (Double, Double, Double)
    }

    /// Les couleurs du ciel à quelques heures repères ; entre deux, on mélange.
    private static let keyframes: [Sky] = [
        Sky(hour: 0, top: (0.09, 0.09, 0.22), bottom: (0.2, 0.17, 0.36)),
        Sky(hour: 5, top: (0.12, 0.12, 0.28), bottom: (0.33, 0.26, 0.45)),
        Sky(hour: 7, top: (0.99, 0.72, 0.52), bottom: (1.0, 0.89, 0.77)),
        Sky(hour: 10, top: (0.55, 0.8, 1.0), bottom: (0.87, 0.95, 1.0)),
        Sky(hour: 13, top: (0.5, 0.78, 1.0), bottom: (0.9, 0.96, 1.0)),
        Sky(hour: 17, top: (0.72, 0.82, 0.98), bottom: (1.0, 0.91, 0.76)),
        Sky(hour: 19, top: (0.93, 0.6, 0.45), bottom: (1.0, 0.78, 0.6)),
        Sky(hour: 21, top: (0.25, 0.2, 0.42), bottom: (0.55, 0.36, 0.45)),
        Sky(hour: 23, top: (0.09, 0.09, 0.22), bottom: (0.2, 0.17, 0.36)),
    ]

    private var top: Color { Self.color(at: Double(hour), \.top) }
    private var bottom: Color { Self.color(at: Double(hour), \.bottom) }

    private static func color(at hour: Double, _ part: KeyPath<Sky, (Double, Double, Double)>) -> Color {
        var previous = keyframes[0]
        for frame in keyframes.dropFirst() {
            if hour <= frame.hour {
                let span = frame.hour - previous.hour
                let t = span > 0 ? (hour - previous.hour) / span : 1
                let a = previous[keyPath: part]
                let b = frame[keyPath: part]
                return Color(
                    red: a.0 + (b.0 - a.0) * t,
                    green: a.1 + (b.1 - a.1) * t,
                    blue: a.2 + (b.2 - a.2) * t
                )
            }
            previous = frame
        }
        let last = keyframes[keyframes.count - 1][keyPath: part]
        return Color(red: last.0, green: last.1, blue: last.2)
    }

    /// De 0 au lever (6 h) à 1 au coucher (21 h). En dehors, le soleil continue sous
    /// l'horizon : à cinq heures il attend juste sous le bord gauche, et il monte d'un
    /// cran fluide quand on passe à six.
    private var dayProgress: Double {
        (Double(hour) - 6) / 15
    }

    /// La lune, de 21 h à 5 h, sur le même arc, plus bas ; à six heures elle finit sa course
    /// sous le bord droit pendant que le soleil se lève.
    private var nightProgress: Double {
        if hour >= 21 { return Double(hour - 21) / 9 }
        if hour < 6 { return Double(hour + 3) / 9 }
        // Le jour, la lune attend juste derrière le bord d'où elle repartira : à droite
        // le matin, à gauche l'après-midi. Sans ça, elle traversait tout le ciel à
        // vingt-et-une heures pour revenir à son point de départ.
        return hour < 13 ? 1.08 : -0.08
    }

    private var isDay: Bool { (6...20).contains(hour) }

    private var isNight: Bool { hour < 6 || hour >= 21 }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let horizon = h * 0.78

            ZStack {
                LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)

                // Quelques étoiles, la nuit.
                ForEach(0..<9, id: \.self) { index in
                    Circle()
                        .fill(OnboardingPalette.white)
                        .frame(width: index % 3 == 0 ? 3 : 2, height: index % 3 == 0 ? 3 : 2)
                        .position(
                            x: w * (0.08 + Double(index) * 0.105),
                            y: h * (0.12 + Double((index * 7) % 5) * 0.1)
                        )
                        .opacity(isNight ? 0.85 : 0)
                }

                // Le sol.
                Rectangle()
                    .fill(OnboardingPalette.ink.opacity(isNight ? 0.5 : 0.12))
                    .frame(height: h - horizon)
                    .position(x: w / 2, y: horizon + (h - horizon) / 2)

                // Le soleil et la lune existent toujours, et c'est leur opacité qui
                // change : une vue qui apparaît d'un coup à gauche pendant qu'une autre
                // disparaît à droite ne se lit pas comme un lever, un objet qui continue
                // sa course en s'effaçant, si.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: 0xFFF1B0), Color(hex: 0xFFB629)],
                            center: .center,
                            startRadius: 2,
                            endRadius: 30
                        )
                    )
                    .frame(width: 54, height: 54)
                    .shadow(color: Color(hex: 0xFFB629).opacity(0.55), radius: 22)
                    .opacity(isDay ? 1 : 0)
                    .position(Self.point(progress: dayProgress, width: w, horizon: horizon, peak: h * 0.16))

                Image(systemName: "moon.fill")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(Color(hex: 0xF4F1E6))
                    .shadow(color: OnboardingPalette.white.opacity(0.35), radius: 16)
                    .opacity(isNight ? 1 : 0)
                    .position(Self.point(progress: nightProgress, width: w, horizon: horizon, peak: h * 0.28))
            }
            .animation(.easeInOut(duration: 0.55), value: hour)
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .clipped()
        .accessibilityHidden(true)
    }

    /// L'arc : le bord à zéro et à un, le sommet au milieu.
    private static func point(progress: Double, width: CGFloat, horizon: CGFloat, peak: CGFloat) -> CGPoint {
        let x = 28 + (width - 56) * progress
        // Hors de l'arc, l'astre passe sous l'horizon au lieu de remonter de l'autre côté.
        let lift = (0...1).contains(progress) ? sin(progress * .pi) : -0.35
        let y = horizon - (horizon - peak) * lift
        return CGPoint(x: x, y: y)
    }
}
