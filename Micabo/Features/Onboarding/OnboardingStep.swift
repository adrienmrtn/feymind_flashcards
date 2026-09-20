import Foundation

/// Les écrans du parcours d'accueil, dans l'ordre. Le parcours est strictement
/// linéaire : aucun retour en arrière, on n'expose donc jamais d'étape précédente.
///
/// **Le parcours a changé de forme.** Il comptait vingt-huit écrans et racontait une
/// méthode : la courbe de l'oubli, la répétition espacée, Feynman, trois écrans sur la
/// préparation d'une épreuve, une démonstration d'import. C'était une leçon avant le
/// produit. Le nouveau montre ce qu'on va faire ensemble en cinq écrans, puis pose les
/// questions dont les réponses servent vraiment à quelque chose.
///
/// Ce qui a disparu, et pourquoi :
///
/// - **La courbe de l'oubli, le graphe de rétention, Feynman, les résultats.** Quatre
///   écrans pour convaincre que la méthode marche, avant d'avoir montré une seule fois ce
///   que l'app fait. On convainc en faisant.
/// - **La démonstration en trois écrans** (déposer, ficher, réviser). Elle rejouait le
///   produit au ralenti pendant vingt secondes. Les écrans 2 à 4 disent la même chose en
///   trois phrases, et le vrai import est à quatre écrans de là.
/// - **Les trois écrans sur l'épreuve.** Ils annonçaient un plan, des examens blancs et un
///   relevé des faiblesses. C'est une brochure : ces choses se découvrent dans un deck.
/// - **L'écran des jours de repos.** La réponse ne sert plus à rien : le plan ne retire plus
///   de jours de sa fenêtre — voir `DeckPace`. Une question dont la réponse n'est lue par
///   personne est pire qu'une question absente.
/// - **L'établissement.** Il servait une preuve sociale locale qu'on ne tenait pas.
///
/// Ce qui est arrivé :
///
/// - **Les cinq écrans d'ouverture**, qui disent le parcours réel : tu déposes, tu poses tes
///   dates, ça devient des fiches et des cartes, et voilà ce qu'il y a autour.
/// - **Le prénom, puis « enchanté ».** C'est le premier moment où l'app s'adresse à
///   quelqu'un plutôt qu'à un utilisateur, et il coûte deux écrans.
/// - **La filière et l'année**, à la place du palier unique. « Lycée » ne dit pas ce qu'on
///   étudie : un terminale STMG et un terminale générale n'ont ni les mêmes matières ni la
///   même épreuve. La question ne se pose qu'aux pays décrits assez finement pour qu'elle
///   ait de vraies réponses (voir `SchoolSystem`) ; ailleurs, le palier large reste.
///
/// **Le pays passe avant la filière**, et la filière avant l'année : chacune décide des
/// réponses de la suivante. La langue se déduit du pays, et ne se demande pas.
///
/// La fin du parcours garde sa progression, et elle est délibérée : le parcours vient d'être
/// construit sous les yeux (`personalizing`), on demande un compte (`signIn`), d'autres l'ont
/// déjà suivi (`socialProof`), et c'est maintenant à cet étudiant-là de s'y mettre
/// (`yourTurn`).
enum OnboardingStep: Int, CaseIterable, Identifiable, Hashable {
    // Ce qu'on va faire ensemble, en six écrans.
    case howItWorks
    /// La mascotte se présente et annonce la suite. Voir `ShowMeStepView`.
    case showMe
    case upload
    case dates
    case turnsInto
    case smartFeatures

    // À qui on parle.
    case name
    case greeting

    // Où il en est.
    case country
    case schoolType
    case year
    case goal

    // Où il veut aller.
    case currentAverage
    case targetAverage
    case together

    // Ce qui l'aidera à s'y tenir.
    case notifications
    case subjects

    // La construction, puis le compte, puis l'offre.
    case personalizing
    case signIn
    case socialProof
    case yourTurn
    case trialOffer
    case trialReminder
    case paywall

    var id: Int { rawValue }

    /// **Le nom de l'étape dans les statistiques.**
    ///
    /// Tiré du nom du cas plutôt que recopié dans une liste : une liste parallèle se
    /// désynchronise au premier écran ajouté, et un entonnoir dont un cran porte le nom
    /// d'un autre écran est pire qu'un entonnoir incomplet. En échange, **renommer un cas
    /// coupe la courbe en deux** — c'est le prix, et il est assumé.
    var analyticsName: String {
        String(describing: self)
    }

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    /// **L'écran de la filière et celui de l'année se sautent** dans les pays dont on ne
    /// connaît que les paliers larges.
    ///
    /// Inventer des filières pour un pays qu'on ne décrit pas produirait des réponses
    /// fausses, et un élève à qui l'on propose une année qui n'existe pas chez lui comprend
    /// tout de suite que l'app n'a pas été écrite pour lui. Le palier large reste alors la
    /// seule chose qu'on demande, et il suffit à la génération.
    func isSkipped(for country: SchoolingCountry) -> Bool {
        switch self {
        case .schoolType, .year: !SchoolSystem.isDetailed(country)
        default: false
        }
    }

    /// Fond de l'étape, et seule source de vérité à ce sujet : l'écran s'y peint, mais
    /// aussi le bandeau qui porte la jauge et la zone d'état au-dessus. Une bande claire
    /// posée au-dessus d'un écran sombre se lit comme un bug d'affichage.
    ///
    /// Deux écrans seulement quittent le blanc : l'ouverture et le passage de relais.
    /// L'attente y est revenue — un lavis violet tenu cinq secondes derrière une mascotte
    /// violette la faisait disparaître. La variété d'un parcours ne vient pas de ses fonds,
    /// elle vient de ce qu'il y a à regarder.
    var surface: OnboardingSurface {
        switch self {
        // L'accroche est sur blanc : la mascotte et ses tuiles pastel y ont toute la place,
        // et le crème teinté de vert se battait avec la tuile verte.
        case .yourTurn: .ink
        default: .canvas
        }
    }

    /// **L'humeur de la mascotte, écran par écran.**
    ///
    /// C'est la réaction du personnage à ce qu'il est en train de demander : il salue quand
    /// il demande un prénom, penche la tête quand il demande où l'on étudie, réfléchit
    /// devant la moyenne, lit quand on choisit ses matières, se redresse quand c'est fait.
    /// Une même tête sur vingt écrans n'est pas un personnage, c'est une icône.
    var mascotMood: MicaboMascot.Mood {
        switch self {
        case .name: .waving
        case .greeting, .together, .socialProof, .yourTurn: .proud
        case .country, .schoolType, .goal, .targetAverage: .curious
        case .currentAverage, .personalizing: .thinking
        case .subjects: .reading
        case .trialOffer, .trialReminder, .paywall: .celebrating
        default: .happy
        }
    }

    /// Position de l'étape dans la jauge, entre 0 et 1.
    ///
    /// La jauge couvre le parcours entier, du premier écran au paywall : elle ne
    /// disparaît sur aucune étape, et elle avance toujours dans le même sens. Le
    /// plancher garde un filet visible dès le premier écran, pour qu'elle ne
    /// ressemble jamais à une barre cassée.
    var progress: Double {
        let last = Double(OnboardingStep.allCases.count - 1)
        guard last > 0 else { return 1 }
        return max(0.02, Double(rawValue) / last)
    }
}
