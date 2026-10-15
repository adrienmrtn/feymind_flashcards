/// **Les phrases de la refonte « parcours »**, dans les cinq langues de l'app.
///
/// Elles vivent à part des 5 000 lignes d'`IosI18nCatalogs` pour se relire d'un coup d'œil,
/// langue contre langue, et toutes leurs clés commencent par `lesson.`. `L10n.t` les cherche
/// en premier. `LessonI18nTests` vérifie que les cinq tables ont les mêmes clés, qu'aucune
/// valeur n'est vide et qu'aucune ne recopie le français.
///
/// Vocabulaire, `docs/refonte-parcours.md` § 1 : leçon, cercle, palier, notes, quiz,
/// flashcards. Tutoiement partout.
enum LessonI18nCatalogs {
    static func table(for locale: String) -> [String: String] {
        switch locale {
        case "en": en
        case "de": de
        case "es": es
        case "tr": tr
        default: fr
        }
    }

    static let fr: [String: String] = [
        // Les refus de la génération
        "lesson.error.freeLimit": "Ta leçon offerte est déjà créée. Passe à Pro pour en créer d'autres.",
        "lesson.error.importPro": "Importer un support, c'est avec Pro.",
        "lesson.error.forbidden": "Cette leçon n'est pas à toi.",
        "lesson.error.generic": "La leçon n'a pas pu s'écrire. Réessaie.",
        // Les cercles du chemin
        "lesson.circle.intro": "Intro",
        "lesson.circle.quiz": "Quiz",
        "lesson.circle.flashcards": "Flashcards",
        "lesson.circle.conclusion": "Conclusion",
    ]

    static let en: [String: String] = [
        "lesson.error.freeLimit": "Your free lesson is already made. Go Pro to create more.",
        "lesson.error.importPro": "Importing material is a Pro feature.",
        "lesson.error.forbidden": "This lesson isn't yours.",
        "lesson.error.generic": "The lesson couldn't be written. Try again.",
        "lesson.circle.intro": "Intro",
        "lesson.circle.quiz": "Quiz",
        "lesson.circle.flashcards": "Flashcards",
        "lesson.circle.conclusion": "Wrap-up",
    ]

    static let de: [String: String] = [
        "lesson.error.freeLimit": "Deine kostenlose Lektion ist schon erstellt. Mit Pro erstellst du weitere.",
        "lesson.error.importPro": "Material importieren geht mit Pro.",
        "lesson.error.forbidden": "Diese Lektion gehört dir nicht.",
        "lesson.error.generic": "Die Lektion konnte nicht geschrieben werden. Versuch es noch mal.",
        "lesson.circle.intro": "Einstieg",
        "lesson.circle.quiz": "Quiz",
        "lesson.circle.flashcards": "Karteikarten",
        "lesson.circle.conclusion": "Abschluss",
    ]

    static let es: [String: String] = [
        "lesson.error.freeLimit": "Tu lección gratis ya está creada. Pásate a Pro para crear más.",
        "lesson.error.importPro": "Importar material es con Pro.",
        "lesson.error.forbidden": "Esta lección no es tuya.",
        "lesson.error.generic": "No se pudo escribir la lección. Inténtalo de nuevo.",
        "lesson.circle.intro": "Introducción",
        "lesson.circle.quiz": "Quiz",
        "lesson.circle.flashcards": "Tarjetas",
        "lesson.circle.conclusion": "Conclusión",
    ]

    static let tr: [String: String] = [
        "lesson.error.freeLimit": "Ücretsiz dersini zaten oluşturdun. Daha fazlası için Pro'ya geç.",
        "lesson.error.importPro": "Materyal içe aktarmak Pro ile mümkün.",
        "lesson.error.forbidden": "Bu ders sana ait değil.",
        "lesson.error.generic": "Ders yazılamadı. Tekrar dene.",
        "lesson.circle.intro": "Giriş",
        "lesson.circle.quiz": "Quiz",
        "lesson.circle.flashcards": "Kartlar",
        "lesson.circle.conclusion": "Sonuç",
    ]
}
