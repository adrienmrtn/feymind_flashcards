import AVFoundation

/// L'autorisation de l'appareil photo, et la seule règle qu'elle porte : un refus est une
/// réponse.
///
/// Le scanner de VisionKit n'a pas de garde-fou. Présenté sans autorisation, il affiche
/// lui-même « Camera Unavailable — Privacy or Restrictions settings have disabled use of the
/// camera » avec son bouton **Settings**, c'est-à-dire précisément ce que la règle 5.1.1(iv)
/// de l'App Store interdit : renvoyer vers les Réglages quelqu'un qui vient de dire non. Ce
/// bouton ne s'enlève pas — il appartient au contrôleur d'Apple, pas à nous. La seule façon
/// de ne jamais l'afficher est de ne jamais ouvrir le scanner sans la caméra.
///
/// D'où le partage : `allowsScanner` décide si la tuile « Scanner des pages » existe, et
/// `request()` pose la question système une fois, une seule. Rien ici n'ouvre les Réglages,
/// ne repose la question, ni ne présente le scanner à vide.
enum CameraAccess {
    /// Ce que le système répond aujourd'hui.
    static var status: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    /// Vrai tant que la caméra reste ouvrable : accordée, ou pas encore demandée.
    ///
    /// `.restricted` compte comme un refus. C'est le contrôle parental, l'app ne peut rien y
    /// changer, et un mineur n'a rien à faire dans les Réglages de confidentialité.
    static func allowsScanner(_ status: AVAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .notDetermined: true
        case .denied, .restricted: false
        @unknown default: false
        }
    }

    /// Vrai quand la caméra a été refusée ou verrouillée. L'écran d'import le dit une fois,
    /// en petit, et passe à la photothèque.
    static func isRefused(_ status: AVAuthorizationStatus) -> Bool {
        !allowsScanner(status)
    }

    /// Demande l'accès, au plus une fois dans la vie de l'app.
    ///
    /// `.notDetermined` est le seul état où iOS affiche la boîte système, celle qui porte
    /// `NSCameraUsageDescription`. Après un refus, `requestAccess` ne montre plus rien et rend
    /// `false` immédiatement : on ne réessaie donc pas, et on n'ouvre pas le scanner derrière.
    static func request() async -> Bool {
        switch status {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }
}
