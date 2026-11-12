import Foundation

/// **Des compteurs pour le banc d'essai de la fluidité** (`MicaboTests/PerfBenchTests`).
///
/// SwiftUI ne dit pas combien de fois un `body` est relu, ni ce qu'une frappe ou une seconde
/// de minuteur fait redessiner. Un écran pose `PerfProbe.hit("CalendarView")` en tête de son
/// `body`, `L10n.t` compte chaque phrase lue, et le banc compare les compteurs avant et après
/// un geste : une frappe qui relit soixante phrases a fait redessiner tout l'écran.
///
/// **Rien de tout cela n'existe dans l'app livrée** : hors d'une construction de développement,
/// `hit` est vide et le compilateur l'efface. En développement, il ne compte que si un test a
/// mis `isRecording` à vrai.
enum PerfProbe {
    #if DEBUG
    private static let lock = NSLock()
    private nonisolated(unsafe) static var recording = false
    private nonisolated(unsafe) static var counts: [String: Int] = [:]
    #endif

    /// Vrai pendant qu'un test compte.
    static var isRecording: Bool {
        get {
            #if DEBUG
            return recording
            #else
            return false
            #endif
        }
        set {
            #if DEBUG
            lock.lock()
            recording = newValue
            lock.unlock()
            #endif
        }
    }

    @inline(__always)
    static func hit(_ name: String) {
        #if DEBUG
        guard recording else { return }
        lock.lock()
        counts[name, default: 0] += 1
        lock.unlock()
        #endif
    }

    /// Le compteur de `name` depuis le dernier `reset`.
    static func count(_ name: String) -> Int {
        #if DEBUG
        lock.lock()
        defer { lock.unlock() }
        return counts[name] ?? 0
        #else
        return 0
        #endif
    }

    static func reset() {
        #if DEBUG
        lock.lock()
        counts = [:]
        lock.unlock()
        #endif
    }
}
