import SwiftUI

/// **« Par quel cours on commence ? »** L'élève choisit sa première leçon avant d'entrer dans
/// l'app : un sujet qu'il écrit, ou un cours qu'il a sous la main (une photo, un PDF…).
///
/// Le choix part à la Home (`FirstLessonIntent`), qui lance la création de la leçon ou ouvre
/// l'import à la sortie du parcours. **Le sujet tapé reste sur l'appareil** : les statistiques
/// ne gardent que la forme de la réponse.
///
/// **Le clavier.** Les réponses sont ancrées en bas ; quand le champ du sujet prend le
/// clavier, elles montent au-dessus de lui (`OnbKeyboardRoom`). « OK » range le clavier : Mika
/// réagit au sujet, et le bouton est là.
struct FirstLessonStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onboardingStill) private var still

    @FocusState private var isTyping: Bool
    /// L'élève vient de choisir « J'écris un sujet » : le champ prend le clavier en arrivant.
    @State private var wantsKeyboard = false
    /// La hauteur du pied (les deux boutons), que le clavier recouvre.
    @State private var footerHeight: CGFloat = 0

    /// Ce que Mika dit : la question, puis sa réaction au choix.
    private var bubble: String {
        switch model.firstLessonChoice {
        case .importSource:
            return i18n.t("ios.onb10.react.lesson.import")
        case .topic:
            if !isTyping, let subject = model.firstLessonSubject {
                return i18n.t("ios.onb10.react.lesson.topic", ["topic": subject])
            }
            return i18n.t("ios.onb10.q.lesson")
        case nil:
            return i18n.t("ios.onb10.q.lesson")
        }
    }

    private var hasReacted: Bool {
        model.firstLessonChoice == .importSource || (model.firstLessonSubject != nil && !isTyping)
    }

    /// Un exemple de sujet, tiré de sa première matière et de son niveau.
    private var example: String {
        i18n.t("ios.onb10.lesson.example", ["topic": Self.exampleTopic(for: model, locale: i18n.locale)])
    }

    var body: some View {
        @Bindable var model = model

        OnbQuestion(bubble, mood: hasReacted ? .happy : .wink) {
            VStack(spacing: OnbLayout.rowGap) {
                if model.firstLessonChoice == .topic {
                    topicCard($model.firstLessonTopic)
                } else {
                    V3OptionRow(i18n.t("ios.onb10.lesson.topic"), icon: .quill, isSelected: false) {
                        chooseTopic()
                    }
                }

                V3OptionRow(
                    i18n.t("ios.onb10.lesson.import"),
                    subtitle: i18n.t("ios.onb10.lesson.importHint"),
                    icon: .photo,
                    isSelected: model.firstLessonChoice == .importSource
                ) {
                    chooseImport()
                }
            }

            OnbKeyboardRoom(isActive: self.model.step == .firstLesson, trim: footerHeight)
        } footer: {
            VStack(spacing: 10) {
                V3Button(i18n.t("common.continue"), isEnabled: model.hasAnsweredFirstLesson) {
                    isTyping = false
                    self.model.confirmFirstLesson()
                }
                V3Button(i18n.t("ios.onb10.later"), kind: .ghost) {
                    isTyping = false
                    self.model.skipFirstLesson()
                }
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                // Le pied, ses marges, et la zone sûre du bas : ce qui sépare le contenu du
                // bord de l'écran.
                let safeBottom = MicaboScreen.keyWindow?.safeAreaInsets.bottom ?? 0
                footerHeight = height + 8 + OnbLayout.footerGap(safeBottom: safeBottom) + safeBottom
            }
        }
    }

    // MARK: Le sujet

    /// **« J'écris un sujet », choisie** : la ligne s'ouvre sur son champ. Elle garde la forme
    /// d'une ligne de réponse choisie (filet d'accent, lavis, coche) ; le champ est dedans.
    private func topicCard(_ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                isTyping = true
            } label: {
                HStack(spacing: 14) {
                    OnbIcon(icon: .quill, size: V3Metric.optionIcon)
                    Text(i18n.t("ios.onb10.lesson.topic"))
                        .font(V3Font.option)
                        .foregroundStyle(V3Color.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    V3Check(isOn: true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .none))
            .accessibilityAddTraits(.isSelected)

            topicField(text)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .v3Card(selected: true, radius: V3Metric.radiusInner)
    }

    /// Le champ du sujet, dans la ligne choisie. Les rendus ne dessinent pas un champ du
    /// système : le sujet (ou l'exemple) y est écrit.
    @ViewBuilder
    private func topicField(_ text: Binding<String>) -> some View {
        Group {
            if still {
                Text(text.wrappedValue.nilIfBlank ?? example)
                    .font(V3Font.bodyStrong)
                    .foregroundStyle(text.wrappedValue.nilIfBlank == nil ? V3Color.ink3 : V3Color.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField("", text: text, prompt: Text(example).foregroundStyle(V3Color.ink3))
                    .font(V3Font.bodyStrong)
                    .foregroundStyle(V3Color.ink)
                    .tint(V3Color.accent)
                    .textInputAutocapitalization(.sentences)
                    .focused($isTyping)
                    .submitLabel(.done)
                    .onSubmit { isTyping = false }
                    .accessibilityLabel(Text(i18n.t("ios.onb10.lesson.topic")))
                    .onAppear {
                        guard wantsKeyboard else { return }
                        wantsKeyboard = false
                        isTyping = true
                    }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .modifier(V3SurfaceStyle(radius: V3Metric.radiusTile, fill: V3Color.bg, border: V3Color.accent))
    }

    private func chooseTopic() {
        wantsKeyboard = true
        withAnimation(MicaboMotion.standard) { model.firstLessonChoice = .topic }
    }

    private func chooseImport() {
        isTyping = false
        withAnimation(MicaboMotion.standard) { model.firstLessonChoice = .importSource }
    }

    // MARK: L'exemple

    /// **Un sujet d'exemple**, dans la famille de sa première matière (la même que celle de la
    /// question d'essai) et à son niveau : collège, lycée, ou après le bac.
    static func exampleTopic(for model: OnboardingModel, locale: UiLocale) -> String {
        let family = SampleCard.pick(for: model.subjects).card
        return L10n.t("ios.onb10.lesson.ex.\(family.rawValue).\(band(for: model.tier))", locale: locale)
    }

    /// Les trois hauteurs d'exemple.
    static func band(for tier: EducationTier?) -> String {
        switch tier {
        case .lowerSecondary: "lower"
        case .undergraduate, .graduate, .health, .competitive: "higher"
        default: "upper"
        }
    }
}
