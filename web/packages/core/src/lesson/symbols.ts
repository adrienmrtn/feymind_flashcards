/**
 * **Copie conforme du serveur** : l'original est `supabase/functions/_shared/symbols.ts`, et c'est lui qui fait foi,
 * parce que c'est lui qui part dans le prompt. `test/shared-parity.test.ts` relit les deux
 * fichiers et échoue à l'octet près si l'un des deux bouge.
 *
 * NE PAS MODIFIER CE FICHIER À LA MAIN. Modifier l'original, puis relancer :
 *   pnpm --filter @micabo/core sync:shared
 */

/**
 * **Les pictogrammes du chemin** : un symbole par thème, jamais deux fois le même dans une
 * leçon. Les ronds du chemin portent un pictogramme au trait (SF Symbols), comme une carte
 * de progression : la grande icône 3D reste celle de la leçon.
 *
 * C'est la même table que `PathSymbol.catalog` dans l'app
 * (`Micabo/DesignSystem/PathSymbol.swift`), dans le même ordre. `symbols.test.ts` vérifie que
 * les deux listes ne divergent pas. L'app vérifie aussi, à l'affichage, que le symbole existe
 * sur le téléphone, et retombe sinon sur un symbole sûr.
 */
export const PATH_SYMBOLS: ReadonlyArray<{ id: string; meaning: string }> = [
  { id: "lightbulb", meaning: "idée clé, définition, principe" },
  { id: "book", meaning: "lecture, texte, œuvre" },
  { id: "books.vertical", meaning: "corpus, auteurs, bibliographie" },
  { id: "text.book.closed", meaning: "manuel, notions de base" },
  { id: "character.book.closed", meaning: "langue, vocabulaire, grammaire" },
  { id: "quote.bubble", meaning: "citation, argument, discours" },
  { id: "bubble.left.and.bubble.right", meaning: "débat, dialogue, communication" },
  { id: "pencil", meaning: "rédaction, méthode d'écriture" },
  { id: "highlighter", meaning: "points à retenir, analyse de texte" },
  { id: "checklist", meaning: "méthode, étapes, procédure" },
  { id: "list.number", meaning: "classement, ordre, plan" },
  { id: "magnifyingglass", meaning: "analyse, étude de cas, enquête" },
  { id: "puzzlepiece", meaning: "mécanisme, liens entre notions" },
  { id: "target", meaning: "objectif, enjeu, problématique" },
  { id: "arrow.triangle.branch", meaning: "choix, alternatives, conséquences" },
  { id: "arrow.triangle.2.circlepath", meaning: "cycle, processus, rétroaction" },
  { id: "link", meaning: "relation, cause et effet" },
  { id: "scalemass", meaning: "équilibre, comparaison, justice" },
  { id: "brain.head.profile", meaning: "psychologie, raisonnement, philosophie" },
  { id: "eye", meaning: "observation, perception, regard" },
  { id: "hourglass", meaning: "temps long, évolution" },
  { id: "clock", meaning: "durée, rythme, horaires" },
  { id: "calendar", meaning: "dates, chronologie, événements" },
  { id: "scroll", meaning: "texte ancien, traité, loi" },
  { id: "crown", meaning: "pouvoir, monarchie, souverain" },
  { id: "flag", meaning: "nation, conflit, conquête" },
  { id: "shield", meaning: "défense, protection, armée" },
  { id: "building.columns", meaning: "institutions, État, antiquité" },
  { id: "person.3", meaning: "société, groupes, population" },
  { id: "person.2.wave.2", meaning: "relations, acteurs, échanges humains" },
  { id: "megaphone", meaning: "propagande, médias, revendication" },
  { id: "hand.raised", meaning: "droits, vote, contestation" },
  { id: "newspaper", meaning: "presse, actualité, information" },
  { id: "doc.text", meaning: "document, source, archive" },
  { id: "signature", meaning: "contrat, accord, traité signé" },
  { id: "globe.europe.africa", meaning: "monde, géopolitique, mondialisation" },
  { id: "map", meaning: "carte, territoire, espace" },
  { id: "mappin.and.ellipse", meaning: "lieu, localisation, repère" },
  { id: "mountain.2", meaning: "relief, paysage, milieu" },
  { id: "water.waves", meaning: "océan, eau, littoral" },
  { id: "leaf", meaning: "nature, écologie, végétaux" },
  { id: "tree", meaning: "forêt, arbre, classification" },
  { id: "cloud.sun", meaning: "climat, météo, atmosphère" },
  { id: "wind", meaning: "flux, air, mouvement" },
  { id: "flame", meaning: "énergie, combustion, révolution" },
  { id: "bolt", meaning: "électricité, choc, rupture" },
  { id: "drop", meaning: "liquide, solution, ressource" },
  { id: "thermometer.medium", meaning: "température, chaleur" },
  { id: "sun.max", meaning: "lumière, soleil, rayonnement" },
  { id: "moon.stars", meaning: "astronomie, nuit, cosmos" },
  { id: "sparkles", meaning: "nouveauté, découverte" },
  { id: "atom", meaning: "physique, matière, particules" },
  { id: "testtube.2", meaning: "chimie, expérience, laboratoire" },
  { id: "microbe", meaning: "micro-organismes, infection, immunité" },
  { id: "allergens", meaning: "cellule, biologie, molécule" },
  { id: "heart", meaning: "cœur, circulation, émotions" },
  { id: "lungs", meaning: "respiration, organes" },
  { id: "brain", meaning: "système nerveux, mémoire" },
  { id: "stethoscope", meaning: "médecine, diagnostic" },
  { id: "pills", meaning: "pharmacologie, traitement" },
  { id: "cross.case", meaning: "santé, soins, urgence" },
  { id: "waveform.path.ecg", meaning: "signal, rythme, physiologie" },
  { id: "pawprint", meaning: "animaux, zoologie" },
  { id: "fish", meaning: "vie aquatique, écosystème" },
  { id: "ladybug", meaning: "insectes, biodiversité" },
  { id: "function", meaning: "fonction, algèbre" },
  { id: "sum", meaning: "somme, suite, série" },
  { id: "percent", meaning: "pourcentage, proportion, taux" },
  { id: "divide", meaning: "division, fraction, rapport" },
  { id: "x.squareroot", meaning: "racine, équation, calcul" },
  { id: "plus.forwardslash.minus", meaning: "opérations, signes, calcul" },
  { id: "number", meaning: "nombres, arithmétique" },
  { id: "infinity", meaning: "limites, infini, analyse" },
  { id: "ruler", meaning: "mesure, longueur, géométrie" },
  { id: "triangle", meaning: "géométrie, figures, trigonométrie" },
  { id: "cube", meaning: "volume, espace, 3D" },
  { id: "chart.bar", meaning: "statistiques, données, comparaison" },
  { id: "chart.pie", meaning: "répartition, parts, budget" },
  { id: "chart.line.uptrend.xyaxis", meaning: "croissance, hausse, courbe" },
  { id: "chart.line.downtrend.xyaxis", meaning: "crise, baisse, déclin" },
  { id: "dollarsign.circle", meaning: "argent, prix, valeur" },
  { id: "eurosign.circle", meaning: "monnaie, euro, finance" },
  { id: "banknote", meaning: "paiement, revenu, salaire" },
  { id: "creditcard", meaning: "crédit, banque, consommation" },
  { id: "cart", meaning: "commerce, consommation, marché" },
  { id: "storefront", meaning: "entreprise, vente, magasin" },
  { id: "briefcase", meaning: "travail, emploi, management" },
  { id: "building.2", meaning: "ville, industrie, urbanisation" },
  { id: "shippingbox", meaning: "échanges, logistique, exportations" },
  { id: "arrow.left.arrow.right", meaning: "échange, commerce international" },
  { id: "hammer", meaning: "construction, artisanat, outils" },
  { id: "wrench.and.screwdriver", meaning: "technique, réparation, ingénierie" },
  { id: "gearshape.2", meaning: "machine, système, fonctionnement" },
  { id: "cpu", meaning: "informatique, processeur, numérique" },
  { id: "desktopcomputer", meaning: "ordinateur, programmation" },
  { id: "network", meaning: "réseau, internet, connexions" },
  { id: "antenna.radiowaves.left.and.right", meaning: "ondes, télécommunications" },
  { id: "lock", meaning: "sécurité, secret, chiffrement" },
  { id: "key", meaning: "clé, solution, accès" },
  { id: "airplane", meaning: "transport, voyage, mobilité" },
  { id: "car", meaning: "automobile, mobilité" },
  { id: "train.side.front.car", meaning: "chemin de fer, révolution industrielle" },
  { id: "ferry", meaning: "navigation, explorations, mer" },
  { id: "music.note", meaning: "musique, rythme, son" },
  { id: "paintpalette", meaning: "arts plastiques, peinture" },
  { id: "theatermasks", meaning: "théâtre, littérature, personnages" },
  { id: "camera", meaning: "image, photographie" },
  { id: "film", meaning: "cinéma, récit visuel" },
  { id: "figure.run", meaning: "sport, mouvement, corps" },
  { id: "fork.knife", meaning: "alimentation, nutrition" },
  { id: "house", meaning: "famille, foyer, habitat" },
  { id: "graduationcap", meaning: "école, éducation, diplôme" },
  { id: "binoculars", meaning: "exploration, prospective" },
  { id: "location", meaning: "orientation, position" },
  { id: "paperplane", meaning: "message, envoi, communication" },
  { id: "bell", meaning: "alerte, signal, rappel" },
];

export const DEFAULT_SYMBOL = "lightbulb";

const KNOWN = new Set(PATH_SYMBOLS.map((symbol) => symbol.id));

/** Un symbole rendu par le modèle, ramené au catalogue ; inconnu, il ne vaut rien. */
export function normalizeSymbol(value: unknown): string {
  if (typeof value !== "string") return "";
  const id = value.trim().toLowerCase();
  return KNOWN.has(id) ? id : "";
}

/**
 * **Un symbole par thème, tous différents.** Un symbole absent ou déjà pris est remplacé par
 * le premier libre du catalogue : jamais deux ronds pareils sur un chemin.
 */
export function uniqueSymbols(symbols: string[]): string[] {
  const used = new Set<string>();
  return symbols.map((symbol) => {
    const id = normalizeSymbol(symbol);
    if (id && !used.has(id)) {
      used.add(id);
      return id;
    }
    const free = PATH_SYMBOLS.find((candidate) => !used.has(candidate.id))?.id ?? DEFAULT_SYMBOL;
    used.add(free);
    return free;
  });
}

/** La liste telle qu'elle part dans le prompt. */
export function symbolBrief(): string {
  return PATH_SYMBOLS.map((symbol) => `- ${symbol.id} : ${symbol.meaning}`).join("\n");
}
