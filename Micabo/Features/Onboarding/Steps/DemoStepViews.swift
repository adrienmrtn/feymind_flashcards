import SwiftUI

// Les quatre démonstrations du parcours (lot 11). Chacune montre UNE fonctionnalité, dans un
// aperçu concret, juste après la réponse qui la rend utile : la leçon après les matières, le
// scanner après les blocages, le calendrier et la concentration après le temps par jour, le
// chat après la vraie question. Mika parle à la première personne, et l'aperçu est fait de
// ses réponses (sa matière, son niveau, son examen, son temps) : rien n'y est un exemple pris
// au hasard, rien n'y est un chiffre inventé.
//
// Les aperçus sont dessinés en SwiftUI, avec les briques des stories (`StoryTag`,
// `StoryScanPreview`) : les mots sont ceux de la langue de l'élève.

// MARK: - Ce que les démos disent de l'élève

enum OnbDemo {
    /// **La matière de la démo** : celle de la question d'essai quand l'une des matières
    /// cochées a une famille connue (maths, chimie, SVT, histoire, philosophie), écrite dans la
    /// langue de l'app. Aucune : rien, et la phrase se dit sans matière.
    static func subject(for model: OnboardingModel, locale: UiLocale) -> String? {
        let pick = SampleCard.pick(for: model.subjects)
        guard model.subjects.contains(pick.subject) else { return nil }
        return SubjectDisplay.subject(pick.subject, locale: locale)
    }

    /// **Le sujet de la démo** : l'exemple de sa matière et de son niveau, le même que celui
    /// que propose la première leçon (« La guerre froide » en terminale, « La Révolution
    /// française » au collège).
    static func topic(for model: OnboardingModel, locale: UiLocale) -> String {
        FirstLessonStepView.exampleTopic(for: model, locale: locale)
    }

    /// Le même sujet au milieu d'une phrase : « m'expliquer les fonctions affines ». Les
    /// langues qui ne mettent pas de majuscule aux noms communs la retirent ; l'allemand, le
    /// turc et l'arabe le gardent tel quel.
    static func topicInSentence(for model: OnboardingModel, locale: UiLocale) -> String {
        let text = Self.topic(for: model, locale: locale)
        guard [UiLocale.fr, .es, .en].contains(locale), let first = text.first else { return text }
        return first.lowercased() + text.dropFirst()
    }

    /// Les matières des séances de la semaine : les siennes, dans l'ordre où le plan les lit,
    /// deux au plus (trois ne tenaient pas sur un iPhone SE).
    static func sessionSubjects(for model: OnboardingModel, locale: UiLocale) -> [String] {
        let names = model.subjectNames(locale: locale)
        return Array(names.prefix(2))
    }
}

/// **Le cadre d'un aperçu** : une carte du système visuel. L'aperçu garde des proportions
/// d'illustration en très grand texte : c'est la phrase de Mika qui grandit.
private struct OnbDemoCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v3Card()
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

/// La ligne sous l'aperçu, au-dessus du bouton : ce que la démo ne montre pas.
private struct OnbDemoHint: View {
    let text: String

    var body: some View {
        Text(text)
            .font(V3Font.caption)
            .foregroundStyle(V3Color.ink2)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - La leçon

/// **« Envoie-moi ton cours de {matière} : j'en fais une leçon. »** Juste après les matières :
/// la photo d'un cours, et la leçon qui en sort, sur un sujet de son niveau, avec ses trois
/// façons de travailler (l'essentiel, le quiz, les cartes).
struct LessonDemoStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var ask: String {
        guard let subject = OnbDemo.subject(for: model, locale: i18n.locale) else {
            return i18n.t("ios.onb11.lesson.askAny")
        }
        return i18n.t("ios.onb11.lesson.ask", ["subject": subject])
    }

    var body: some View {
        OnbQuestion(ask, mood: .happy) {
            OnbDemoCard {
                // La photo envoyée, comme un message : à droite.
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(V3Color.accentBright)
                    Text(i18n.t("ios.onb10.story.photo"))
                        .foregroundStyle(V3Color.ink)
                }
                .font(V3Font.label)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(V3Color.soft, in: RoundedRectangle(cornerRadius: V3Metric.radiusTile, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .trailing)

                VStack(alignment: .leading, spacing: 12) {
                    if let subject = OnbDemo.subject(for: model, locale: i18n.locale) {
                        StoryTag(text: subject, tone: V3Color.accentBright)
                    }
                    Text(OnbDemo.topic(for: model, locale: i18n.locale))
                        .font(V3Font.display(24))
                        .foregroundStyle(V3Color.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 10) {
                        row(.notes, i18n.t("ios.onb11.lesson.notes"))
                        row(.quiz, i18n.t("ios.onb11.lesson.quiz"))
                        row(.cards, i18n.t("ios.onb11.lesson.cards"))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(V3Color.soft, in: RoundedRectangle(cornerRadius: V3Metric.radiusInner, style: .continuous))
            }
        } footer: {
            OnbDemoHint(text: i18n.t("ios.onb11.lesson.hint"))
            V3Button(i18n.t("common.continue")) {
                model.advance()
            }
        }
    }

    private func row(_ icon: MicaboIcon, _ text: String) -> some View {
        HStack(spacing: 12) {
            OnbIcon(icon: icon, size: 24)
            Text(text)
                .font(V3Font.bodyStrong)
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Le scanner

/// **« Un exo qui bloque ? Une photo, et je te guide pas à pas. »** Après les blocages : un
/// énoncé dans le cadre de visée, puis ses étapes jusqu'au résultat. La phrase de Mika suit ce
/// que l'élève a coché (les devoirs, les cours durs).
struct ScanDemoStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// La phrase de Mika : elle reprend le blocage coché qui appelle le scanner.
    static func askKey(worries: Set<StudyWorry>) -> String {
        if worries.contains(.homework) { return "ios.onb11.scan.askHomework" }
        if worries.contains(.hardLessons) { return "ios.onb11.scan.askHard" }
        return "ios.onb11.scan.ask"
    }

    var body: some View {
        OnbQuestion(i18n.t(Self.askKey(worries: model.worries)), mood: .think) {
            OnbDemoCard {
                StoryScanPreview()
            }
        } footer: {
            OnbDemoHint(text: i18n.t("ios.onb11.scan.hint"))
            V3Button(i18n.t("common.continue")) {
                model.advance()
            }
        }
    }
}

// MARK: - Le calendrier et la concentration

/// **« {min} min par jour : je range tes séances dans ton calendrier. »** Juste après le temps
/// choisi : son examen et le temps qu'il reste (le calendrier), la semaine qui commence
/// aujourd'hui, trois séances de ses matières à sa durée, et le minuteur Focus de chaque
/// séance (la concentration).
struct PlanDemoStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var now = Date()

    var body: some View {
        OnbQuestion(
            i18n.t("ios.onb11.plan.ask", ["min": "\(model.minutesPerDay)"]),
            mood: .happy
        ) {
            OnbDemoCard {
                header
                V3WeekStrip(days: Self.week(from: now, examDate: model.datedExam?.date, locale: i18n.locale))
                VStack(spacing: 8) {
                    ForEach(Array(sessions.enumerated()), id: \.offset) { index, subject in
                        session(day: index, subject: subject)
                    }
                }
                focus
            }
        } footer: {
            OnbDemoHint(text: i18n.t("ios.onb11.plan.hint"))
            V3Button(i18n.t("common.continue")) {
                model.advance()
            }
        }
    }

    private var sessions: [String] {
        let subjects = OnbDemo.sessionSubjects(for: model, locale: i18n.locale)
        return subjects.isEmpty ? [i18n.t("ios.onb11.plan.lesson")] : subjects
    }

    /// Le prochain examen et le temps qu'il reste ; sans examen daté, « Ta semaine ».
    @ViewBuilder
    private var header: some View {
        if let exam = model.datedExam, let days = model.examDaysLeft(now: now) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(i18n.t("ios.cal.nextExam"))
                        .font(V3Font.caption)
                        .foregroundStyle(V3Color.ink2)
                    Text(exam.choice.title(locale: i18n.locale))
                        .font(V3Font.display(22))
                        .foregroundStyle(V3Color.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(OnbWords.duration(days: days, locale: i18n.locale))
                    .font(V3Font.label)
                    .foregroundStyle(V3Color.yellowInk)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(V3Color.yellowWash, in: Capsule())
            }
        } else {
            Text(i18n.t("ios.onb11.plan.week"))
                .font(V3Font.display(22))
                .foregroundStyle(V3Color.ink)
        }
    }

    /// Une séance : le jour, la matière, la durée choisie.
    private func session(day offset: Int, subject: String) -> some View {
        let date = Calendar.current.date(byAdding: .day, value: offset, to: now) ?? now
        return HStack(spacing: 10) {
            Text(Self.weekday(date, locale: i18n.locale))
                .font(V3Font.label)
                .foregroundStyle(offset == 0 ? V3Color.accentBright : V3Color.ink2)
                .frame(minWidth: 44, alignment: .leading)
            Text(subject)
                .font(V3Font.bodyStrong)
                .foregroundStyle(V3Color.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(i18n.t("ios.quiz.time.short", ["n": "\(model.minutesPerDay)"]))
                .font(V3Font.label)
                .foregroundStyle(V3Color.ink2)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 38)
        .background(V3Color.soft, in: RoundedRectangle(cornerRadius: V3Metric.radiusTile, style: .continuous))
    }

    /// Le minuteur de chaque séance.
    private var focus: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(V3Color.accentBright)
            Text(i18n.t("ios.onb10.story.focus", [
                "time": i18n.t("ios.quiz.time.short", ["n": "\(model.minutesPerDay)"]),
            ]))
            .foregroundStyle(V3Color.ink)
        }
        .font(V3Font.label)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(V3Color.accentWash, in: Capsule())
    }

    /// « lun. », « Mo », « الإثنين » : le jour d'une séance, court.
    static func weekday(_ date: Date, locale: UiLocale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale.foundation
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: date)
    }

    /// **La semaine qui commence aujourd'hui** : sept jours, aujourd'hui en bleu, l'examen
    /// marqué s'il tombe dedans. Rien n'est encore tenu : c'est sa semaine à venir.
    static func week(from start: Date, examDate: Date?, locale: UiLocale, calendar: Calendar = .current) -> [V3WeekDay] {
        let formatter = DateFormatter()
        formatter.locale = locale.foundation
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            let isExam = examDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
            return V3WeekDay(
                letter: formatter.string(from: date),
                number: calendar.component(.day, from: date),
                isDone: false,
                isToday: offset == 0,
                hasEvent: isExam
            )
        }
    }
}

// MARK: - Le chat avec Mika

/// **« Un cours pas clair ? Demande-moi, même à 23 h. »** Après la vraie question : l'élève
/// demande une explication sur un sujet de sa matière et de son niveau, Mika répond comme il
/// le fait dans l'app (l'idée, un exemple, une question pour vérifier).
struct ChatDemoStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnbQuestion(i18n.t("ios.onb11.chat.ask"), mood: .wink) {
            OnbDemoCard {
                // La question de l'élève, à droite.
                Text(i18n.t("ios.onb11.chat.question", ["topic": OnbDemo.topicInSentence(for: model, locale: i18n.locale)]))
                    .font(V3Font.bodyStrong)
                    .foregroundStyle(V3Color.onAccent)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(V3Color.accent, in: RoundedRectangle(cornerRadius: V3Metric.radiusInner, style: .continuous))
                    .padding(.leading, 40)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                // La réponse de Mika, à gauche.
                HStack(alignment: .top, spacing: 10) {
                    MikaAvatar(size: 30)
                    Text(i18n.t("ios.onb11.chat.answer"))
                        .font(V3Font.body)
                        .foregroundStyle(V3Color.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(V3Color.soft, in: RoundedRectangle(cornerRadius: V3Metric.radiusInner, style: .continuous))
                }
                .padding(.trailing, 24)

                // Le champ, pour dire qu'on écrit ou qu'on envoie une photo.
                HStack(spacing: 10) {
                    Text(i18n.t("ios.onb11.chat.field"))
                        .font(V3Font.body)
                        .foregroundStyle(V3Color.ink3)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "camera.fill")
                        .foregroundStyle(V3Color.ink2)
                    Image(systemName: "arrow.up.circle.fill")
                        .font(V3Font.title)
                        .foregroundStyle(V3Color.accent)
                }
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .frame(minHeight: 46)
                .modifier(V3SurfaceStyle(radius: 23, fill: V3Color.bg))
            }
        } footer: {
            OnbDemoHint(text: i18n.t("ios.onb11.chat.hint"))
            V3Button(i18n.t("common.continue")) {
                model.advance()
            }
        }
    }
}
