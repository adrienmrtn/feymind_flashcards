/** Les trois pages de fond. Titres, extraits, corps : plus rien en dur. */
export const articlesFr = {
  shared: {
    navAria: "Pages",
    nextTitle: "À lire ensuite",
    ctaTitle: "Dépose un cours, regarde ce qu'il devient.",
    ctaBody: "Sur le site comme sur iPhone, avec le même compte et le même plan.",
  },
  method: {
    metaTitle: "La méthode : répétition espacée et rappel actif",
    metaDescription:
      "Relire un cours ne le fait pas retenir. Ce qu'on retrouve de mémoire tient, surtout si la question revient juste avant l'oubli. Comment Micabo applique la répétition espacée, avec les vrais intervalles.",
    h1: "Relire ne suffit pas. Se souvenir, oui.",
    lead1:
      "Une page relue quatre fois donne une impression de maîtrise qui ne survit pas à la copie double. Ce qui progresse, c'est la reconnaissance : « oui, j'ai déjà vu ça ». Et la reconnaissance n'est pas ce qu'un examen demande.",
    lead2:
      "Ce qui tient, c'est ce qu'on a dû **retrouver de mémoire**, et ce qui revient **juste avant qu'on l'oublie**. Deux idées anciennes, mesurées depuis plus d'un siècle, et deux idées pénibles à appliquer à la main. C'est tout le travail de Micabo.",
    activeTitle: "Le rappel actif : la question avant la réponse",
    active1:
      "Se tester est plus efficace que relire, même quand on se trompe. L'effort de récupération est ce qui renforce la trace : une réponse qu'on cherche pendant trois secondes vaut mieux qu'une réponse qu'on lit en une.",
    active2:
      "C'est aussi pour ça qu'une carte porte **une seule chose à retrouver**. Une carte qui demande cinq éléments d'un coup ne se note pas : on en retrouve trois, et il n'existe pas de bouton pour « trois cinquièmes ».",
    spacingTitle: "L'espacement : revenir au dernier moment utile",
    spacing1:
      "Sans révision, ce qu'on retient d'un cours tombe à presque rien en un mois. Chaque rappel remet le compteur à cent, et la descente qui suit est **plus lente que la précédente**. Réviser au bon moment ne demande donc pas plus de temps : ça en demande moins, à mesure que la mémoire se stabilise.",
    spacing2:
      "L'intérêt n'est pas la forme de chaque courbe, c'est **l'endroit où elles se séparent** : la première révision. Ce que la répétition espacée automatise, c'est le choix de cet instant, carte par carte.",
    plannerTitle: "Ce que Micabo calcule à chaque note",
    planner1:
      "Micabo planifie en **SM-2**, la règle d'Anki dans ses réglages par défaut. Une carte neuve passe par des paliers courts, {steps}, avant de sortir en jours. Ensuite, chaque note multiplie l'intervalle par une facilité propre à la carte, qui part de {ease} et bouge selon tes réponses.",
    planner2:
      "Quatre boutons, pas deux : « je sais / je ne sais pas » ne distingue pas la carte retrouvée avec peine de celle qui est venue seule, et c'est justement cet écart qui décide de la date suivante. Voici ce que les quatre boutons annoncent sur une carte neuve :",
    buttonsCaption: "Les intervalles sont calculés par le planificateur de l'app, pas écrits à la main.",
    planner3:
      "L'intervalle est écrit sur le bouton **avant** qu'on appuie. Un planificateur qui décide dans son coin se fait vite désobéir : on note « facile » pour aller plus vite, la carte repart à trois semaines, et on la redécouvre le jour de l'épreuve.",
    stepMinutes: "{n} min",
    stepJoin: ", puis ",
    paceTitle: "Le rythme : ce que la charge demande, pas un quota",
    pace1:
      "Micabo ne demande ni un nombre de cartes par jour, ni un budget de minutes. Il regarde ce que les échéances réclament aujourd'hui, le sert en entier, et annonce le temps que ça prendra. Un étudiant voit environ {seen} cartes en une heure.",
    pace2:
      "Un plafond de cartes neuves existait ici, calibré sur les {reps} passages qu'une carte demande avant d'être acquise. Il avait un défaut décisif : à trois jours d'un partiel, il refusait des cartes de ce partiel au nom du rythme du jour. Retenir du travail le jour où il en faut le plus, c'est se tromper de métier.",
    paceNote:
      "Ce que le plan répartit, ce sont les passages jusqu'au jour J. Une journée manquée ne crée donc pas de trou : elle décale, et le plan se refait au calcul suivant.",
    sheetTitle: "La fiche d'abord, les cartes ensuite",
    sheet1:
      "Une carte suppose qu'on a déjà compris. Se tester sur une notion qu'on n'a pas lue, c'est apprendre une réponse par cœur sans savoir de quoi elle parle : la carte tombera juste, et l'examen non.",
    sheetFigure:
      "Le document déposé devient **une fiche** : le cours remis dans l'ordre, les passages qui comptent marqués. Les cartes en sortent ensuite. C'est le même composant de fiche que dans l'app, sur le cours de démonstration.",
    sheet2:
      "C'est pourquoi Micabo écrit d'abord **la fiche** à partir de ton document : le cours remis dans l'ordre, les passages qui comptent marqués. Les cartes sont tirées de cette fiche, pas du document brut. Tu lis, puis tu te testes.",
    sheet3:
      "Micabo ne définit jamais un terme dont le document ne parle pas. Quand le contexte ne tranche pas, le mot douteux n'apparaît pas dans la fiche : une définition inventée est parfaitement crédible, et c'est ce qui la rend dangereuse.",
    formatsTitle: "Quatre façons d'être interrogé sur la même fiche",
    formats1:
      "Le rappel actif ne se limite pas au recto verso. Sur une même fiche, Micabo pose des QCM, des textes à trou, des cartes, et compose des examens blancs notés. Les questions viennent de tes documents, et le planificateur les traite toutes de la même façon : une réponse retrouvée éloigne la suivante.",
    formatsFigure:
      "Un QCM se reconnaît à ses puces, un texte à trou à sa ligne vide, une carte à son recto muet. **Les quatre formats sont tirés de la même fiche**, et notés sur la même échelle.",
    limitsTitle: "Ce que la méthode ne fait pas",
    limits1:
      "La répétition espacée place les révisions. Elle ne comprend pas à ta place, elle ne rédige pas une dissertation, et elle ne rattrape pas un chapitre commencé la veille : il n'y a pas d'espacement possible sur une nuit.",
    limits2:
      "Elle ignore aussi les dates, par construction : SM-2 ne sait pas qu'un examen a lieu dans trois semaines. C'est exactement ce que le [[exam]] vient corriger.",
    examLink: "mode examen",
  },
  exam: {
    metaTitle: "Le mode examen : donne la date, le plan se resserre",
    metaDescription:
      "La répétition espacée ignore le jour J. Le mode examen de Micabo lui donne une date butoir, resserre les passages à l'approche de l'épreuve, et empêche une carte de repartir au-delà.",
    h1: "Tu donnes la date. Micabo réorganise tout.",
    lead1:
      "La répétition espacée place chaque carte au dernier moment utile, indéfiniment. Elle ne sait pas qu'il y a un partiel le 14. Une carte notée « facile » aujourd'hui repart à trois semaines, même si l'épreuve est dans dix jours, et elle ne reviendra pas avant.",
    lead2:
      "Le mode examen donne au planificateur ce qui lui manque : **une date butoir**, et la note que tu vises. Tu poses le jour J, il replanifie le paquet autour.",
    trapTitle: "Pourquoi un planning normal se fait piéger",
    trap1:
      "Un paquet de deux cents cartes en révision espacée est parfait pour un contrôle continu et mauvais pour une date fixe. Trois choses vont de travers : des cartes tombent après l'examen, d'autres n'ont jamais été introduites, et les plus fragiles reviennent trop tôt pour être utiles le jour J.",
    trap2:
      "La réponse manuelle consiste à réviser tout le paquet la veille. C'est exactement ce que la méthode évite : une session de trois cents cartes en une soirée ne laisse rien le lendemain, et on le sait avant de commencer.",
    capTitle: "Aucune carte ne repart au-delà du jour J",
    cap1:
      "C'est la règle qui fait tout tenir, et elle est plus radicale qu'elle en a l'air. Pendant un examen actif, l'intervalle qu'une carte reçoit est **plafonné à la date de l'épreuve**.",
    cap2:
      "Sans ce plafond, la première bonne réponse défait le plan : la carte s'en va à trois semaines et sort du champ. Avec lui, elle revient une dernière fois avant le jour J. Les intervalles annoncés sous les boutons sont donc plus courts que d'habitude, et la session le dit en haut de l'écran, sinon on croirait le planificateur cassé.",
    planTitle: "Le plan, annoncé avant d'être appliqué",
    plan1:
      "Micabo montre la projection **avant** de déplacer quoi que ce soit : combien de cartes sont couvertes, combien de passages sont placés, sur combien de jours. Une replanification qu'on découvre après coup est une replanification qu'on annule.",
    plan2:
      "La charge se resserre vers la fin sans s'empiler sur la veille : les derniers passages s'étalent sur les {days} derniers jours, décalés d'une carte à l'autre.",
    dailyTitle: "Chaque journée porte un travail nommé",
    daily1:
      "Un plan qui dit « réviser 30 minutes » ne se distingue pas d'un minuteur. Celui de Micabo dit ce qu'il y a à faire : un QCM sur le chapitre 3, un examen blanc, une explication à voix haute, un jour de pause. Tu ouvres l'app, et la journée est déjà écrite.",
    dailyFigure:
      "Le plan se lit dans le sens du temps, et la dernière ligne est l'épreuve. **Un jour manqué décale, il ne creuse pas de trou** : le plan se refait au calcul suivant.",
    intensityTitle: "Trois intensités, selon la note que tu veux",
    intensityLead:
      "Combien de fois chaque carte doit repasser avant l'épreuve n'est pas la même question pour « je veux valider » et pour « je veux le major ». Tu poses la note visée, Micabo en déduit l'intensité :",
    intensityLight: "Légère",
    intensityStandard: "Normale",
    intensityIntense: "Intensive",
    intensityPasses: "passages par carte",
    intensityScale:
      "L'échelle de notes suit ton pays de scolarisation : un 20 français, un 100 québécois et un A-Level britannique ne se comparent pas, et un curseur qui vaudrait partout ne voudrait rien dire nulle part.",
    severalTitle: "Plusieurs examens, plusieurs cours",
    several1:
      "Un examen porte sur les cours que tu lui donnes, et un cours peut être dans plusieurs examens. Quand deux dates se disputent une même carte, c'est **la plus proche** qui plafonne : elle est la première contrainte, et respecter la seconde d'abord raterait les deux.",
    severalNote:
      "Passé le jour J, l'examen cesse de contraindre et le paquet revient à sa planification normale. Rien à désactiver : une date passée n'est plus une date.",
    limitsTitle: "Ce que le mode examen ne fait pas",
    limits1:
      "Il ne fabrique pas du temps. Déclarer un examen pour demain sur deux cents cartes neuves donne un plan honnête et intenable, et Micabo l'affiche tel quel plutôt que de rassurer.",
    limits2:
      "Il ne remplace pas non plus la méthode : [[method]] font le travail, le mode examen ne fait que leur donner une échéance. Si tu viens d'Anki, la [[anki]] dit précisément ce que ça change.",
    methodLink: "le rappel actif et l'espacement",
    ankiLink: "comparaison",
  },
  anki: {
    metaTitle: "Micabo ou Anki : ce qui change vraiment",
    metaDescription:
      "Anki est ouvert, éprouvé et excellent. Micabo écrit les cartes à partir de ton cours et replanifie tout autour d'une date d'examen. Comparaison honnête, y compris là où Anki gagne.",
    eyebrow: "Comparaison",
    h1: "Micabo ou Anki : ce qui change vraiment",
    lead1:
      "Anki est un très bon logiciel. Il est ouvert, il a vingt ans de recul et une communauté qui a tout documenté. Si tu t'en sers déjà et que ça te va, tu n'as aucune raison d'en changer.",
    lead2:
      "La différence n'est pas dans la planification : **c'est le même SM-2**. Elle est avant, dans le temps qu'il faut pour avoir des cartes, et après, dans ce qui arrive quand une date d'examen tombe.",
    tableTitle: "Ligne par ligne",
    tableLead: "Trois lignes vont à Anki, et elles sont écrites telles quelles.",
    tableCaption: "Comparaison de Micabo et d'Anki, critère par critère.",
    colCriterion: "Critère",
    rowAlgo: "L'algorithme",
    rowAlgoMicabo: "SM-2, avec les réglages par défaut d'Anki.",
    rowAlgoAnki: "SM-2 historiquement, FSRS aujourd'hui, et les deux se règlent.",
    rowWrite: "Écrire les cartes",
    rowWriteMicabo: "Le cours devient une fiche, la fiche devient des cartes. Tu relis et tu corriges.",
    rowWriteAnki: "À toi. C'est là que passe l'essentiel du temps.",
    rowDate: "Une date d'examen",
    rowDateMicabo: "Le paquet se replanifie autour du jour J, et rien ne repart au-delà.",
    rowDateAnki: "Pas de notion de date butoir. On avance le paquet à la main.",
    rowQuestions: "Les façons d'être interrogé",
    rowQuestionsMicabo: "Cartes, QCM, textes à trou, examens blancs notés, explication à voix haute.",
    rowQuestionsAnki: "Le recto verso, et les types de cartes qu'on construit soi-même.",
    rowPlatforms: "Les plateformes",
    rowPlatformsMicabo: "iPhone et navigateur, le même compte des deux côtés.",
    rowPlatformsAnki: "Ordinateur, Android, iPhone, navigateur.",
    rowDecks: "Les paquets tout faits",
    rowDecksMicabo: "Aucun catalogue. Tes cours, et ceux que tes amis partagent.",
    rowDecksAnki: "Des milliers de paquets publics, de qualité inégale.",
    rowFriends: "Les cours de tes camarades",
    rowFriendsMicabo: "Un cours partagé se reprend en un geste, et devient le tien.",
    rowFriendsAnki: "Un fichier à s'envoyer.",
    rowStart: "La mise en route",
    rowStartMicabo: "Un document déposé, une fiche à lire, une session le soir même.",
    rowStartAnki: "Des réglages à comprendre avant la première carte.",
    costTitle: "Ce qu'Anki coûte vraiment : du temps",
    cost1:
      "Un paquet Anki utile pour un cours de fac, c'est deux à quatre heures de saisie par chapitre : découper, formuler une question par idée, ne pas empiler cinq éléments sur une carte. Ce travail est instructif, le nier serait malhonnête. Mais c'est le travail qui fait qu'on ouvre Anki en septembre et plus en novembre.",
    costFigure:
      "Polycopié, photos, Word, PowerPoint, vidéo, audio : **tout entre tel quel**, et un paquet Anki aussi. La saisie disparaît, la relecture reste.",
    cost2:
      "Micabo prend cette étape. Le cours devient une fiche remise dans l'ordre, puis des cartes tirées de cette fiche. Tu relis, tu corriges ce qui est faux, tu supprimes ce qui ne sert pas. Ça reste ton travail, mais il commence à la relecture au lieu de commencer à la page blanche.",
    costNote:
      "Le revers est réel : une carte générée peut être mal formulée ou tirée d'un scan mal lu. C'est pour ça que la fiche vient avant les cartes, et que Micabo ne définit pas un terme dont le document ne parle pas. Une fiche qui se trompe ne ressemble pas à une erreur.",
    dateTitle: "Ce qu'Anki ne fait pas : la date",
    date1:
      "C'est la vraie différence de mécanique. La répétition espacée place chaque carte au dernier moment utile, sans fin. Elle ne sait pas qu'il y a un partiel le 14 : une carte notée « facile » repart à trois semaines et ne revient pas avant l'épreuve.",
    date2:
      "Dans Anki, on s'en sort en avançant le paquet à la main, ou en révisant tout la veille. Dans Micabo, tu poses la date et le paquet se replanifie autour, avec un plafond qui empêche une carte de repartir au-delà du jour J. [[exam]] détaille comment.",
    examLink: "Le mode examen",
    pickTitle: "Lequel prendre",
    pickAnki:
      "**Reste sur Anki** si tu aimes régler ton planificateur, si tu veux FSRS, si tu es sur Android, ou si tu tiens à un outil ouvert dont tu possèdes les fichiers.",
    pickMicabo:
      "**Essaie Micabo** si ce qui te bloque n'est pas la révision mais la fabrication des cartes, ou si tes révisions sont organisées autour de dates d'examen plutôt que d'un flux continu.",
    pickBoth:
      "Et si tu hésites : [[method]] est la même dans les deux. C'est elle qui fait le travail, pas le logiciel qui la porte.",
    methodLink: "la méthode",
  },
} as const;
