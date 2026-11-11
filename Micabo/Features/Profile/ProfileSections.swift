import StoreKit
import SwiftUI

/// **Le Profil de la refonte** (`docs/refonte-parcours.md` § 12) : la carte profil, « Passer en
/// Pro », puis deux groupes de rangées — les réglages (langue, nous noter) et le support.
/// Les amis et le classement de la semaine restent ceux de `ProfileView`.
enum ProfileLinks {
    static let supportEmail = "team@micabo.app"
    static let otherApps = "https://vikstudios.com"

    static var supportURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [URLQueryItem(name: "subject", value: "Micabo")]
        return components.url
    }
}

/// La carte profil : l'initiale, le prénom, le nom d'utilisateur, les études. Un appui ouvre
/// toutes les infos et le compte. La carte claire de l'app, comme celles de Home.
struct ProfileCard: View {
    let name: String
    let identity: String?
    let studies: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(String(name.prefix(1)).uppercased())
                    .font(MicaboFont.number(26))
                    .foregroundStyle(Color.white)
                    .frame(width: 60, height: 60)
                    .background(MicaboStage.fill, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(MicaboFont.ui(19, weight: .black))
                        .foregroundStyle(MicaboColor.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    if let identity {
                        Text(identity)
                            .font(MicaboFont.ui(14, weight: .bold))
                            .foregroundStyle(MicaboColor.accentInk)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let studies {
                        Text(studies)
                            .font(MicaboFont.ui(14, weight: .semibold))
                            .foregroundStyle(MicaboColor.inkSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
            .padding(16)
            .homeCard()
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .soft))
    }
}

/// **« Passer en Pro »**, pour qui n'est pas abonné : la carte forte du Profil, la seule
/// en bleu de la marque — comme la pilule « ✦ Pro » de Home.
struct ProUpgradeCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                MicaboIconView(icon: .crown, size: 34)
                    .frame(width: 52, height: 52)
                    .background(Color.white.opacity(0.18), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("lesson.profile.goPro", locale: .resolved()))
                        .font(MicaboFont.ui(17, weight: .black))
                        .foregroundStyle(MicaboStage.ink)
                    Text(L10n.t("lesson.profile.goProBody", locale: .resolved()))
                        .font(MicaboFont.ui(14, weight: .semibold))
                        .foregroundStyle(MicaboStage.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MicaboStage.inkSecondary)
            }
            .padding(16)
            .background(MicaboStage.fill, in: RoundedRectangle(cornerRadius: MicaboStage.cardRadius, style: .continuous))
            .shadow(color: MicaboBrand.blue.opacity(0.24), radius: 14, y: 7)
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
    }
}

/// Un groupe de rangées, sous son titre — le même titre de section que Home, le Calendrier
/// et Concentration (`StudySectionTitle`).
struct ProfileGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StudySectionTitle(title: title)
            VStack(spacing: 0) {
                content
            }
            .background(HomePalette.card)
            .clipShape(RoundedRectangle(cornerRadius: MicaboStage.tileRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: MicaboStage.tileRadius, style: .continuous).strokeBorder(HomePalette.cardStroke, lineWidth: 1))
            .shadow(color: MicaboBrand.blue900.opacity(0.06), radius: 16, y: 8)
        }
    }
}

/// Une rangée de réglage : son icône, son nom, une valeur ou un chevron.
struct ProfileRow: View {
    let icon: MicaboIcon
    let title: String
    var value: String?
    var showsDivider = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(MicaboPressableButtonStyle())
    }

    var label: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                MicaboIconView(icon: icon, size: 28)
                    .frame(width: 36, height: 36)
                // Le nom de la rangée passe avant sa valeur : « Thème » ne se coupe pas pour
                // laisser la place à « Comme le téléphone ».
                Text(title)
                    .font(MicaboFont.ui(17, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                Spacer(minLength: 8)
                if let value {
                    Text(value)
                        .font(MicaboFont.ui(15, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                Image(systemName: "chevron.forward")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            if showsDivider {
                Rectangle()
                    .fill(MicaboColor.hairline)
                    .frame(height: 1)
                    .padding(.leading, 64)
            }
        }
    }
}

/// **Réglages** : changer la langue, changer le thème, nous noter.
struct ProfileSettingsGroup: View {
    @Environment(UiLocaleStore.self) private var store: UiLocaleStore?
    @Environment(\.requestReview) private var requestReview
    @State private var appearance = AppearanceStore.shared

    var body: some View {
        ProfileGroup(title: L10n.t("lesson.profile.settings", locale: .resolved())) {
            Menu {
                ForEach(UiLocale.allCases) { code in
                    Button {
                        store?.pick(code)
                    } label: {
                        if code == store?.locale {
                            Label(code.nativeName, systemImage: "checkmark")
                        } else {
                            Text(code.nativeName)
                        }
                    }
                }
            } label: {
                ProfileRow(
                    icon: .language,
                    title: L10n.t("lesson.profile.language", locale: .resolved()),
                    value: (store?.locale ?? .resolved()).nativeName
                ) {}
                .label
            }
            Menu {
                ForEach(MicaboAppearance.allCases) { mode in
                    Button {
                        appearance.choose(mode)
                        Haptics.selection()
                    } label: {
                        if mode == appearance.appearance {
                            Label(L10n.t(mode.titleKey, locale: .resolved()), systemImage: "checkmark")
                        } else {
                            Text(L10n.t(mode.titleKey, locale: .resolved()))
                        }
                    }
                }
            } label: {
                ProfileRow(
                    icon: .theme,
                    title: L10n.t("lesson.profile.theme", locale: .resolved()),
                    value: L10n.t(appearance.appearance.titleKey, locale: .resolved())
                ) {}
                .label
            }
            ProfileRow(icon: .rate, title: L10n.t("lesson.profile.rate", locale: .resolved()), showsDivider: false) {
                requestReview()
            }
        }
    }
}

/// **Support** : nous écrire, nos autres apps, les conditions, la confidentialité.
struct ProfileSupportGroup: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ProfileGroup(title: L10n.t("lesson.profile.support", locale: .resolved())) {
            ProfileRow(icon: .mail, title: L10n.t("lesson.profile.contact", locale: .resolved())) {
                if let url = ProfileLinks.supportURL { openURL(url) }
            }
            ProfileRow(icon: .apps, title: L10n.t("lesson.profile.otherApps", locale: .resolved())) {
                if let url = URL(string: ProfileLinks.otherApps) { openURL(url) }
            }
            ProfileRow(icon: .document, title: L10n.t("lesson.profile.terms", locale: .resolved())) {
                if let url = URL(string: PaywallLinks.terms) { openURL(url) }
            }
            ProfileRow(icon: .privacy, title: L10n.t("lesson.profile.privacy", locale: .resolved()), showsDivider: false) {
                if let url = URL(string: PaywallLinks.privacy) { openURL(url) }
            }
        }
    }
}
