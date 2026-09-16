import SwiftUI

/// **Lancer une mesure : l'examen blanc et le test de parcours.**
///
/// Les deux se lançaient depuis la page de l'épreuve. Ils se lancent maintenant depuis
/// « Au programme », le jour où le plan les pose, avec le reste de la journée — une mesure
/// proposée hors de son jour casse la cadence que le plan vient d'établir, et deux écrans qui
/// proposent la même chose obligent à se demander lequel est le bon.
///
/// Ce fichier porte donc ce qui était enfermé dans la fiche d'épreuve : la question du micro,
/// et le voile pendant que la copie s'écrit.

// MARK: - As-tu un micro ?

/// **La seule question qui change la copie.** Répondre oui ajoute des questions Feynman,
/// répondues à l'oral. Elle est posée avant l'ouverture, et pas au milieu : une autorisation
/// demandée pendant l'épreuve arrête le chronomètre dans la tête de l'étudiant.
struct StartMockSheet: View {
    var onChoose: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var asking = false
    @State private var failed: String?

    private func t(_ key: String) -> String {
        i18n.t(key)
    }

    var body: some View {
        NavigationStack {
            // Le contenu **défile**, même court : c'est ce qui garantit qu'une traduction plus
            // longue ou un corps de texte agrandi ne se coupe pas au bas de la feuille. La
            // hauteur du cran est taillée pour qu'on n'ait jamais à s'en servir.
            ScrollView {
                VStack(alignment: .leading, spacing: MicaboSpacing.md) {
                    Text(t("app.mock.micHint"))
                        .font(MicaboFont.caption)
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        askMicrophone()
                    } label: {
                        HStack(spacing: MicaboSpacing.xs) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text(asking ? t("app.exams.wait") : t("app.mock.micYes"))
                        }
                    }
                    .buttonStyle(MicaboPrimaryButtonStyle())
                    .disabled(asking)

                    Button {
                        choose(false)
                    } label: {
                        Text(t("app.mock.micNo"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MicaboSecondaryButtonStyle())
                    .disabled(asking)

                    if let failed {
                        Text(failed)
                            .font(MicaboFont.caption)
                            .foregroundStyle(MicaboColor.negative)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, MicaboSpacing.md)
                .padding(.bottom, MicaboSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .micaboScreenBackground()
            .navigationTitle(t("app.mock.micTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("app.common.cancel")) { dismiss() }
                }
            }
        }
    }

    /// Demander le micro **et** la reconnaissance pour de vrai, avant de composer la copie.
    /// Sans ça, on écrirait trois questions orales à quelqu'un qui a refusé l'accès, et il le
    /// découvrirait une fois le chronomètre lancé.
    private func askMicrophone() {
        asking = true
        failed = nil
        Task {
            let dictation = Dictation()
            let ready = await dictation.prepare()
            asking = false
            if ready {
                choose(true)
            } else {
                Haptics.warning()
                failed = dictation.availability == .denied ? t("app.mock.micDenied") : t("app.mock.micBroken")
            }
        }
    }

    private func choose(_ withAudio: Bool) {
        Haptics.selection()
        dismiss()
        onChoose(withAudio)
    }
}

// MARK: - Le temps d'écrire la copie

/// La copie s'écrit sur le serveur, et ça prend le temps d'une génération. On le dit, et on
/// couvre l'écran : un bouton qu'on pourrait toucher deux fois ouvrirait deux copies.
struct MockWritingOverlay: View {
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        ZStack {
            MicaboColor.ink.opacity(0.18).ignoresSafeArea()
            VStack(spacing: MicaboSpacing.sm) {
                ProgressView()
                    .tint(MicaboColor.accent)
                Text(i18n.t("ios.mock.writing"))
                    .font(MicaboFont.captionEmphasis)
                    .foregroundStyle(MicaboColor.ink)
                    .multilineTextAlignment(.center)
            }
            .padding(MicaboSpacing.lg)
            .frame(maxWidth: 260)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous))
        }
        .transition(.opacity)
    }
}
