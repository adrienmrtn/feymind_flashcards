import StoreKit
import SwiftUI

/// **Le Profil de la refonte** (`docs/refonte-parcours.md` § 12) : la carte profil, « Passer en
/// Pro », puis deux groupes de rangées — les réglages (langue, nous noter) et le support.
/// Les amis et le classement de la semaine restent ceux de `ProfileView`.
enum ProfileLinks {
    static let supportEmail = "maximilien@vikstudios.com"
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
/// toutes les infos et le compte.
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
                    .foregroundStyle(MicaboColor.onInk)
                    .frame(width: 60, height: 60)
                    .background(MicaboColor.accent, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(MicaboFont.subtitle)
                        .foregroundStyle(MicaboColor.ink)
                        .lineLimit(1)
                    if let identity {
                        Text(identity)
                            .font(MicaboFont.ui(14, weight: .bold))
                            .foregroundStyle(MicaboColor.accent)
                            .lineLimit(1)
                    }
                    if let studies {
                        Text(studies)
                            .font(MicaboFont.ui(14, weight: .medium))
                            .foregroundStyle(MicaboColor.inkSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
            .padding(16)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .micaboElevation(.card)
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .soft))
    }
}

/// « Passer en Pro » : la carte d'encre, pour qui n'est pas abonné.
struct ProUpgradeCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                MicaboIconView(icon: .crown, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("lesson.profile.goPro", locale: .resolved()))
                        .font(MicaboFont.label)
                        .foregroundStyle(MicaboColor.onInk)
                    Text(L10n.t("lesson.profile.goProBody", locale: .resolved()))
                        .font(MicaboFont.ui(14, weight: .medium))
                        .foregroundStyle(MicaboColor.onInkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MicaboColor.onInkMuted)
            }
            .padding(16)
            .background(MicaboColor.ink, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
    }
}

/// Un groupe de rangées, sous son petit titre.
struct ProfileGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(MicaboFont.small)
                .tracking(MicaboTracking.caps)
                .textCase(.uppercase)
                .foregroundStyle(MicaboColor.inkSecondary)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                content
            }
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .micaboElevation(.row)
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
                Text(title)
                    .font(MicaboFont.ui(17, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                Spacer(minLength: 8)
                if let value {
                    Text(value)
                        .font(MicaboFont.ui(15, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.right")
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

/// **Réglages** : changer la langue, nous noter.
struct ProfileSettingsGroup: View {
    @Environment(UiLocaleStore.self) private var store: UiLocaleStore?
    @Environment(\.requestReview) private var requestReview

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
