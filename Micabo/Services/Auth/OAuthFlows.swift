import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// Où le fournisseur renvoie l'utilisateur après l'avoir authentifié.
///
/// Le schéma est celui déclaré dans `Info.plist`. Il doit être **le même** dans la liste des
/// « Redirect URLs » du tableau de bord Supabase, sinon le retour est refusé côté serveur avant
/// même d'arriver ici.
enum AuthRedirect {
    static let scheme = "micabo"
    static let host = "auth-callback"

    static var url: URL {
        URL(string: "\(scheme)://\(host)")!
    }
}

/// Le couple vérificateur / défi du flux PKCE.
///
/// Sans lui, un flux OAuth sur mobile est interceptable : le code de retour passe par une URL
/// que n'importe quelle app enregistrée sur le même schéma peut recevoir. Le vérificateur, lui,
/// ne quitte jamais le processus : le serveur ne rend un jeton que si le SHA-256 du
/// vérificateur correspond au défi envoyé au départ.
struct PKCEPair {
    let verifier: String
    let challenge: String

    init() {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        verifier = Data(bytes).base64URLEncodedString()
        challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
    }
}

extension Data {
    /// Base64 « URL safe » : c'est la seule graphie qu'accepte un paramètre de requête.
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Le nombre à usage unique de la connexion Apple.
///
/// Il est envoyé **haché** à Apple, qui le recopie dans le jeton d'identité qu'il signe, et
/// **en clair** à Supabase, qui compare. C'est ce qui empêche de présenter à Supabase un jeton
/// Apple obtenu ailleurs : il ne porterait pas le bon nonce.
///
/// Le bouton d'Apple construit sa requête lui-même — c'est la seule façon d'utiliser
/// `SignInWithAppleButton`, et ses règles d'interface imposent ce bouton dès qu'on propose sa
/// connexion. Ce type ne porte donc que le nonce ; `AppleNonceLedger` le garde le temps de
/// l'aller-retour.
struct AppleNonce {
    let raw: String
    /// La forme envoyée à Apple : SHA-256 en hexadécimal.
    let hashed: String

    init() {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        raw = Data(bytes).base64URLEncodedString()
        hashed = SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// **Les nonces Apple partis et pas encore revenus, retrouvés par leur empreinte.**
///
/// Le nonce vivait dans un `@State` du bouton, et chaque retour d'Apple en tirait un neuf.
/// Or un seul geste peut rendre **deux** retours : une erreur immédiate, sans feuille, puis
/// la vraie autorisation quelques secondes plus tard. La première renouvelait le nonce, la
/// seconde présentait donc à Supabase un clair qui n'était plus celui qu'Apple avait haché —
/// `invalid nonce: Nonces mismatch`. Du 21 au 30 septembre 2026, versions 1.4 à 1.6, 132 des
/// 142 refus du serveur après une autorisation Apple suivaient une telle erreur immédiate.
///
/// Le registre ne devine plus quel nonce va avec quelle réponse : il le lit. Apple recopie
/// dans le jeton d'identité l'empreinte qu'on lui a confiée, et c'est elle qui désigne le
/// clair. Chaque requête a le sien, et l'ordre des retours ne compte plus.
struct AppleNonceLedger {
    /// Assez pour plusieurs gestes d'affilée ; un nonce plus ancien ne reviendra pas.
    static let capacity = 8

    private var pending: [AppleNonce] = []

    /// Un nonce neuf pour une requête : l'empreinte part chez Apple, le clair reste ici.
    mutating func issue() -> String {
        let nonce = AppleNonce()
        pending.append(nonce)
        if pending.count > Self.capacity {
            pending.removeFirst(pending.count - Self.capacity)
        }
        return nonce.hashed
    }

    /// Le clair de cette empreinte, retiré du registre : un nonce ne sert qu'une fois.
    mutating func redeem(hashed: String) -> String? {
        guard let index = pending.firstIndex(where: { $0.hashed == hashed }) else { return nil }
        return pending.remove(at: index).raw
    }
}

/// Ce qu'on lit dans le jeton d'identité d'Apple, **sans le vérifier**.
///
/// La signature est vérifiée par Supabase, pas ici. Ce qu'on lit ne sert qu'à choisir, parmi
/// les nonces qu'on a soi-même émis, celui à présenter : un jeton forgé qui porterait une
/// empreinte connue serait refusé de l'autre côté, exactement comme avant.
enum AppleIdentityToken {
    /// Le champ `nonce` de la charge utile, ou `nil` si le jeton n'en porte pas.
    static func nonce(in token: String) -> String? {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }

        var base64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)

        guard let data = Data(base64Encoded: base64),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return payload["nonce"] as? String
    }
}

/// Ce qu'on retient d'une autorisation Apple.
struct AppleCredential {
    let idToken: String
    let fullName: String?

    /// Apple ne donne le nom qu'à la **première** autorisation, et plus jamais ensuite : ne
    /// pas le lire maintenant, c'est le perdre pour de bon.
    init(_ credential: ASAuthorizationAppleIDCredential) throws {
        guard let data = credential.identityToken,
              let token = String(data: data, encoding: .utf8) else {
            throw AuthError.invalidResponse
        }
        idToken = token
        fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0?.nilIfBlank }
            .joined(separator: " ")
            .nilIfBlank
    }
}

/// La connexion par page web, pour tous les fournisseurs qui n'ont pas de chemin natif.
///
/// `ASWebAuthenticationSession` est le seul navigateur qu'Apple autorise pour ça, et c'est
/// tant mieux : la page s'ouvre dans un Safari isolé, l'app ne voit jamais le mot de passe, et
/// la session partagée permet à quelqu'un déjà connecté à Google de ne rien retaper.
@MainActor
final class OAuthWebFlow: NSObject {
    private var webSession: ASWebAuthenticationSession?

    /// Ouvre la page du fournisseur et rend le code d'autorisation du retour.
    func authorize(provider: String) async throws -> (code: String, verifier: String) {
        let pkce = PKCEPair()
        guard let url = SupabaseAuthClient.shared.authorizeURL(
            provider: provider,
            redirectTo: AuthRedirect.url,
            challenge: pkce.challenge
        ) else {
            throw AuthError.notConfigured
        }

        let code: String = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: AuthRedirect.scheme
            ) { callback, error in
                if let error {
                    let isCancel = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
                    continuation.resume(throwing: isCancel ? AuthError.cancelled : AuthError.server(error.localizedDescription))
                    return
                }

                guard let callback,
                      let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems else {
                    continuation.resume(throwing: AuthError.invalidResponse)
                    return
                }

                // Un refus du fournisseur revient aussi par l'URL de retour : il porte une
                // description, et c'est elle qu'il faut montrer plutôt qu'« échec ».
                if let description = items.first(where: { $0.name == "error_description" })?.value {
                    continuation.resume(throwing: AuthError.server(description.replacingOccurrences(of: "+", with: " ")))
                    return
                }

                guard let code = items.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: AuthError.invalidResponse)
                    return
                }
                continuation.resume(returning: code)
            }

            session.presentationContextProvider = self
            // Sans ça, la session Safari du téléphone est ignorée et l'utilisateur doit
            // retaper son mot de passe Google alors qu'il y est déjà connecté.
            session.prefersEphemeralWebBrowserSession = false
            webSession = session
            session.start()
        }

        return (code, pkce.verifier)
    }
}

extension OAuthWebFlow: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        OAuthPresentation.anchor()
    }
}

/// La fenêtre sur laquelle poser la feuille du système.
///
/// Les deux flux en ont besoin et le calcul est le même : la scène active, sa fenêtre clé, et
/// un repli sur une fenêtre vide plutôt qu'un plantage — une app sans fenêtre au moment d'une
/// connexion n'existe pas, mais `ASPresentationAnchor` n'est pas optionnel.
private enum OAuthPresentation {
    @MainActor
    static func anchor() -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes
            .first { $0.activationState == .foregroundActive }?
            .keyWindow
            ?? scenes.first?.windows.first
        return window ?? ASPresentationAnchor()
    }
}
