/** Les deux pages de droit. Le « vous » reste : ce n'est pas le tutoiement du site. */

export const legalFr = {
  backHome: "Retour à l'accueil",
  eyebrow: "Micabo · iPhone et site",
  updated: "Dernière mise à jour : {date}.",
  updatedDate: "2 septembre 2026",
  privacy: {
    metaTitle: "Confidentialité",
    metaDescription:
      "Ce que Micabo retient de vous, sur iPhone et sur le site, et ce que vous pouvez en faire.",
    heading: "Politique de confidentialité",
    linkLabel: "politique de confidentialité",
    intro1:
      "Cette politique décrit les données que Micabo traite lorsque vous utilisez le site [[site]] ou l'application iPhone (identifiant {bundle}). Les deux clients partagent le même compte et la même base. Elle s'applique aussi si vous n'avez pas encore de compte et que vous consultez le site.",
    intro2:
      "Le responsable du traitement est {editor}, qui édite Micabo. Pour toute question, correction ou suppression : [[contact]].",
    whatTitle: "Ce que Micabo est",
    whatBody:
      "Micabo transforme un cours (PDF, photo, document, vidéo) en fiche et en flashcards, puis les fait revenir avant que vous les oubliiez. Un mode examen resserre les révisions à l'approche d'une date. Vous pouvez partager un cours avec des amis, ou le garder pour vous.",
    dataTitle: "Quelles données nous traitons",
    dataAccount:
      "**Le compte.** Adresse e-mail, identifiants fournis par Apple ou Google si vous choisissez ces connexions, et un nom d'utilisateur. Nous ne stockons pas votre mot de passe : la connexion par courriel se fait par un lien, pas par un secret que nous garderions.",
    dataSchool:
      "**Le parcours scolaire.** Pays d'études, palier, matières, établissement si vous le donnez. Cela sert à écrire la fiche dans la bonne langue et le bon système, et à vous montrer les camarades du même établissement si un cours est partagé.",
    dataCourses:
      "**Vos cours.** Les fichiers ou liens que vous déposez, le texte qui en est extrait, les fiches et les cartes générées, les images de schémas, les examens (nom, date, note visée) et l'historique de révision (quand une carte revient, comment vous l'avez notée).",
    dataFriends:
      "**Les amis.** Les demandes d'ami, la liste de vos amis, et la visibilité que vous posez sur chaque cours au moment de l'import : vous seul, vos amis, ou les camarades de votre établissement. Il n'existe pas de catalogue public où un inconnu tomberait sur vos fiches.",
    dataSubscription:
      "**L'abonnement.** L'état de votre accès Pro (actif, essai, résilié), pas le numéro de votre carte. Le paiement est encaissé par Apple sur iPhone, par Stripe sur le site. RevenueCat tient le droit, pour que l'iPhone et le navigateur soient d'accord.",
    dataWaitlist:
      "**La liste d'attente.** Si vous laissez votre adresse avant d'avoir un compte, nous la gardons pour vous prévenir de l'ouverture, avec la page d'où vous venez. Elle n'est pas liée à un compte et n'est pas visible via l'application.",
    dataFeedback:
      "**Les retours.** Si vous envoyez un bug ou une idée depuis l'app, nous gardons le message, le type (bug ou idée), et le lien avec votre compte, pour y répondre. Ils restent 24 mois, puis sont effacés. Ils ne servent pas à vous profiler.",
    dataUsage:
      "**L'usage des générations.** Un compteur par jour et par fonction (fiche, cartes, explication), sans le contenu du cours. Il sert à limiter les abus, pas à vous profiler.",
    dataDirectory:
      "**L'annuaire.** Votre nom d'utilisateur et, si vous l'avez indiqué, votre établissement. C'est ce que voient un ami ou un camarade, pas votre e-mail ni vos préférences.",
    dataDevice:
      "**Ce qui reste sur l'appareil.** Sur iPhone, certaines pièces (images d'occlusion, audio d'une carte) peuvent ne jamais quitter le téléphone. Les réponses du parcours d'accueil restent d'abord sur l'appareil, puis sont écrites en base une fois le compte ouvert.",
    dataNoSell:
      "Nous ne vendons pas vos données. Nous n'affichons pas de publicité. Nous n'entraînons pas un modèle de langage sur vos cours, sauf si un réglage explicite le propose un jour — et ce réglage n'existe pas aujourd'hui.",
    whyTitle: "Pourquoi nous les traitons",
    whyLead: "Les bases légales, au sens du RGPD :",
    whyContract:
      "**L'exécution du contrat** — créer le compte, importer un cours, écrire la fiche et les cartes, les réviser, synchroniser iPhone et site, gérer l'abonnement.",
    whyLegitimate:
      "**L'intérêt légitime** — sécuriser le service, empêcher les abus, diagnostiquer une panne, et lire les retours que vous nous envoyez. Cet intérêt ne passe pas avant le vôtre : le cloisonnement est dans la base, pas seulement dans l'application.",
    whyLegal:
      "**L'obligation légale** — conserver ce que la facturation ou la comptabilité exigent, le temps prescrit.",
    whyConsent:
      "**Le consentement** — quand vous choisissez de partager un cours, d'ouvrir l'appareil photo, ou de vous connecter avec Apple ou Google.",
    accessTitle: "Qui y a accès",
    accessBody:
      "Vos cours ne sont lisibles que par vous, sauf si vous les avez partagés. Chaque requête à la base est évaluée avec votre identité : il n'existe pas de requête qui puisse demander les cours de quelqu'un d'autre. Les retours que vous envoyez sont lus par l'équipe, à l'adresse [[contact]]. Personne d'autre n'y a accès depuis l'application.",
    accessLead:
      "Des prestataires voient une partie des données, uniquement pour fournir le service :",
    accessSupabase:
      "**Supabase** (Union européenne, région Stockholm) — compte, base, fichiers.",
    accessVercel:
      "**Vercel** — hébergement du site et journaux techniques (adresse IP, URL). Le traitement peut avoir lieu hors de l'Union européenne, sous les clauses contractuelles types du prestataire.",
    accessApple:
      "**Apple et Google** — si vous vous connectez avec eux, ou si vous payez sur l'App Store.",
    accessStripe: "**Stripe** — paiement sur le site.",
    accessRevenuecat:
      "**RevenueCat** — état de l'abonnement, partagé entre iPhone et site.",
    accessFal:
      "**fal.ai et les modèles qu'il appelle** (aujourd'hui, des modèles de langage, notamment de Google) — le texte ou l'image de votre cours, le temps d'écrire la fiche ou les cartes. Ils n'ont pas le droit de s'en servir pour autre chose que cette génération.",
    accessYoutube:
      "**YouTube / Google** — si vous importez une vidéo, nous en lisons les métadonnées et les sous-titres.",
    accessTransfer:
      "Certains de ces prestataires sont établis hors de l'Union européenne. Le transfert n'a alors lieu que pour fournir le service, et s'appuie sur les garanties prévues par le RGPD (décision d'adéquation ou clauses contractuelles types du prestataire).",
    cookiesTitle: "Cookies et traceurs",
    cookiesWeb:
      "Le site pose les cookies nécessaires à la session (vous reconnaître d'une page à l'autre une fois connecté) et un cookie de préférence de langue d'interface (`micabo.ui_locale`), gardé un an, qui retient le français, l'allemand, l'espagnol ou le turc. Nous ne posons pas de cookie de mesure d'audience, ni de publicité, ni de pistage inter-sites. C'est pour cela qu'il n'y a pas de bandeau de consentement : il n'y a rien à refuser de ce côté-là.",
    cookiesIos:
      "L'iPhone n'utilise pas de cookies. Il garde un jeton de session dans le trousseau de l'appareil.",
    retentionTitle: "Combien de temps nous les gardons",
    retentionWhile:
      "Tant que le compte existe. Les retours partent au plus tard au bout de 24 mois. Si vous le supprimez, depuis Réglages sur le site ou dans l'app iPhone, ou en nous écrivant, nous effaçons le profil, les cours (y compris le texte extrait), les fiches, les cartes, l'historique, les examens, les amitiés, les compteurs d'usage, les retours et l'adresse éventuellement laissée sur la liste d'attente.",
    retentionShared:
      "Un cours que vous avez partagé disparaît pour vos amis quand vous le supprimez. Un ami qui a déjà révisé vos cartes conserve son propre historique, pas votre document.",
    retentionAfter:
      "Après suppression, il reste chez des prestataires ce que la loi ou leur contrat impose : factures Stripe ou Apple, identifiant d'abonnement RevenueCat, journaux techniques (Vercel, Supabase) quelques semaines. fal.ai reçoit le texte le temps d'écrire la fiche ; nous ne lui demandons pas de le conserver.",
    rightsTitle: "Vos droits",
    rightsBody:
      "Vous pouvez accéder à vos données, les corriger, les exporter, vous opposer à un traitement, ou demander l'effacement. Pour télécharger une copie : Réglages → « Télécharger mes données ». Pour effacer le compte : Réglages → « Supprimer le compte », sur le site ou dans l'app iPhone. Vous pouvez aussi écrire à [[contact]]. Nous répondons dans le mois.",
    rightsCnil: "Vous pouvez aussi introduire une réclamation auprès de la CNIL (cnil.fr).",
    minorsTitle: "Mineurs",
    minorsBody:
      "Micabo s'adresse à des étudiants, y compris au lycée. Nous ne demandons pas la date de naissance. Si vous avez moins de quinze ans, l'usage du service doit se faire avec l'accord d'un titulaire de l'autorité parentale. Nous n'utilisons pas les données d'un mineur pour de la publicité, ni pour un profilage commercial.",
    iosTitle: "L'iPhone, en plus du site",
    iosBody:
      "L'app peut demander l'accès à vos photos ou à l'appareil photo pour importer un cours. Ce n'est pas obligatoire : le site accepte un fichier déposé. Les notifications, si vous les autorisez, ne servent qu'à vous rappeler une révision. Le même compte ouvre l'app et le site.",
    changesTitle: "Modifications",
    changesBody:
      "Si cette politique change de façon substantielle, nous mettons à jour la date en tête de page. L'usage continu après cette date vaut pour la nouvelle version, sauf si la loi exige un accord distinct.",
    changesAlso: "Les [[terms]] complètent ce texte.",
  },
  terms: {
    metaTitle: "Conditions d'utilisation",
    metaDescription:
      "Les règles du service Micabo, pour l'iPhone et le site : compte, cours, abonnement, responsabilités.",
    heading: "Conditions d'utilisation",
    linkLabel: "conditions d'utilisation",
    intro1:
      "Ces conditions régissent l'usage de Micabo — le site [[site]] et l'application iPhone ({bundle}). En créant un compte ou en utilisant le service, vous les acceptez. Si vous n'êtes pas d'accord, n'ouvrez pas de compte.",
    intro2: "L'éditeur est {editor}. Contact : [[contact]].",
    serviceTitle: "Le service",
    serviceBody:
      "Micabo lit un document de cours que vous déposez et en écrit une fiche et des flashcards. Il les fait revenir selon une répétition espacée (la même règle SM-2 sur iPhone et sur le site). Vous pouvez poser la date d'un examen : le plan de révision se resserre alors vers ce jour. Un même compte ouvre les deux clients.",
    servicePro:
      "Une partie du service est accessible sans abonnement. L'accès Pro (cours et cartes au-delà du plafond gratuit, selon l'offre affichée au moment de l'achat) est payant.",
    accountTitle: "Le compte",
    accountBody:
      "Vous pouvez vous connecter avec Apple, Google, ou un lien envoyé par courriel. Vous êtes responsable de l'accès à votre boîte mail et à ces comptes tiers. Un seul compte par personne.",
    accountDelete:
      "Vous pouvez supprimer le compte depuis Réglages, sur le site ou dans l'app iPhone. Cela efface vos cours, vos cartes et votre historique. Les achats déjà encaissés par Apple ou Stripe restent soumis à leurs règles de remboursement.",
    coursesTitle: "Vos cours",
    coursesOwn:
      "Vous gardez la propriété de ce que vous déposez. Vous nous donnez seulement le droit, limité et révocable, de le lire, de le stocker et de le transformer en fiche et en cartes, pour vous fournir le service — y compris en l'envoyant à un modèle de langage le temps de la génération.",
    coursesRights:
      "Vous ne déposez que des documents que vous avez le droit d'utiliser. Un polycopié de votre professeur, vos notes, une vidéo dont l'import est autorisé : oui. Un ouvrage entier recopié, le devoir d'un autre, un contenu illégal : non. Nous pouvons retirer un cours ou fermer un compte qui casse cette règle.",
    coursesShare:
      "La visibilité se décide à l'import. Un cours privé reste entre vous. Un cours partagé n'est visible que par les personnes que vous avez choisies (amis, ou camarades de l'établissement). Ce n'est pas une bibliothèque ouverte à tous.",
    notTitle: "Ce que Micabo n'est pas",
    notBody:
      "La fiche et les cartes sont générées automatiquement. Elles peuvent se tromper, omettre un passage, ou mal lire un scan. Micabo n'est pas un professeur, ni une garantie de note. Vous restez responsable de ce que vous apprenez et de ce que vous rendez le jour de l'examen.",
    notInvent:
      "Nous nous efforçons de ne pas inventer une définition quand le document ne la porte pas. Ça ne rend pas le résultat infaillible.",
    subTitle: "L'abonnement",
    subPrices:
      "Les prix, la durée et l'essai éventuel sont ceux affichés avant le paiement. Ils peuvent changer pour les nouveaux achats ; un abonnement déjà en cours garde ses conditions jusqu'à son renouvellement.",
    subIos:
      "**Sur iPhone**, le paiement passe par l'App Store. La résiliation, le renouvellement et les remboursements suivent les règles d'Apple. Gérez l'abonnement dans les réglages de votre compte Apple.",
    subWeb:
      "**Sur le site**, le paiement passe par Stripe. La résiliation se fait depuis l'espace de facturation indiqué dans le profil, ou en nous écrivant. Un essai, s'il est proposé, ne se transforme en paiement que si vous le laissez aller à son terme.",
    subBoth:
      "L'accès Pro acheté d'un côté vaut de l'autre : le même compte est Pro sur iPhone et sur le site. Un incident de paiement peut ouvrir une période de grâce ; nous ne fermons pas l'accès à la première heure.",
    forbidTitle: "Ce que vous ne faites pas",
    forbidHarm:
      "Utiliser le service pour nuire à quelqu'un, harceler, ou tricher d'une façon qui viole le règlement de votre établissement.",
    forbidAccess:
      "Tenter d'accéder aux cours d'un autre compte, de contourner le cloisonnement, ou de surcharger volontairement le service.",
    forbidResell:
      "Revendre l'accès, extraire le service par un robot au-delà d'un usage humain normal, ou copier Micabo pour en faire un produit concurrent à partir de nos générations.",
    forbidIllegal:
      "Déposer des contenus illégaux, haineux, ou qui portent atteinte à la vie privée d'autrui.",
    availTitle: "Disponibilité",
    availBody:
      "Nous faisons notre possible pour que iPhone et site restent joignables. Une maintenance, une panne d'un prestataire (hébergeur, modèle, boutique) ou une erreur de génération peut interrompre le service. Nous n'offrons pas de garantie de résultat scolaire, ni de disponibilité ininterrompue.",
    liabilityTitle: "Responsabilité",
    liabilityConsumer:
      "Si vous êtes un consommateur, vos droits légaux (garantie, médiation, clauses abusives) s'appliquent et ces conditions ne les écartent pas.",
    liabilityLimit:
      "Au-delà, Micabo n'est pas responsable des notes obtenues, d'une fiche incomplète, d'un oubli le jour J, ou d'un dommage indirect (temps perdu, examen manqué). Notre responsabilité, si elle était retenue pour un manquement qui nous est imputable, est limitée au montant que vous nous avez versé au cours des douze derniers mois — sauf faute lourde, dol, ou atteinte à l'intégrité de la personne.",
    minorsTitle: "Mineurs",
    minorsBody:
      "Si vous avez moins de quinze ans, un titulaire de l'autorité parentale doit accepter ces conditions et surveiller l'usage. Le partage d'un cours avec des amis reste sous votre responsabilité, et sous la leur.",
    lawTitle: "Droit applicable",
    lawBody:
      "Ces conditions sont régies par le droit français. En cas de litige, et après une tentative de résolution écrite à [[contact]], les tribunaux français sont compétents — sous réserve des règles de protection du consommateur qui vous seraient plus favorables.",
    changesTitle: "Modifications",
    changesBody:
      "Nous pouvons mettre à jour ces conditions. La date en tête de page fait foi. Un changement qui touche au prix d'un abonnement en cours vous est annoncé avant le renouvellement.",
    changesAlso: "La [[privacy]] décrit le traitement de vos données.",
  },
} as const;
