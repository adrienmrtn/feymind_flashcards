import Foundation

#if DEBUG
// MARK: - Les six cours de debug, en français

/// Six cours complets, écrits d'avance, **réservés aux builds de debug** : de quoi remplir
/// la bibliothèque en un geste pour tester les fiches, le plan, les cartes et la révision
/// sans rien générer. Ils suivent la même règle que les cours de démonstration — quatre
/// chapitres, du texte entre chaque objet riche, aucun objet qui en touche un autre — et
/// le même niveau d'exigence : lycée ou début de licence, des faits exacts, des chiffres
/// justes et des calculs vérifiés.
///
/// Les identifiants sont stables d'une langue à l'autre ; les matières sont les noms
/// canoniques de `SubjectCatalog`.
extension DebugCourseCatalog {
    static let french: [OnboardingDemoCourse] = [
        revolutionFR, geneticsFR, probabilityFR, supplyDemandFR, circuitsFR, mitosisFR,
    ]

    // MARK: Histoire : la Révolution française

    private static let revolutionFR = OnboardingDemoCourse(
        id: "debug-revolution",
        emoji: "🇫🇷",
        subject: "Histoire",
        title: "La Révolution française (1789–1799)",
        summary: "Dix ans qui font passer la France de la monarchie absolue à la République : la crise de 1789, la monarchie constitutionnelle, la Terreur, puis le Directoire jusqu'au coup d'État de Bonaparte.",
        accentIndex: 1,
        chapters: [
            DemoChapter(title: "La crise de l'Ancien Régime (1787–1789)", blocks: [
                .paragraph("En 1789, la France est le royaume le plus peuplé d'Europe : environ ==28 millions d'habitants==, gouvernés par un roi qui tient son pouvoir de Dieu et ne le partage avec personne. En dix ans, ce régime vieux de plusieurs siècles s'effondre. Pour comprendre comment, il faut partir de ce qu'on appellera après coup l'**Ancien Régime**."),
                .heading("Une société d'ordres"),
                .paragraph("La société est divisée en trois ordres, inégaux en droit. Le **clergé** prie, la **noblesse** combat, le **tiers état** travaille : c'est du moins ce que dit la théorie. Les deux premiers ordres jouissent de **privilèges** — des droits particuliers, comme l'exemption de la taille, l'impôt direct principal, ou le droit de percevoir des redevances sur les paysans."),
                .callout(
                    title: "Privilège",
                    text: "Littéralement une « loi privée » : un droit ou une exemption accordés à un groupe ou à une personne, et non à tous. Sous l'Ancien Régime, l'inégalité devant la loi et devant l'impôt est **la règle**, pas l'exception.",
                    tone: .definition
                ),
                .paragraph("Le tiers état regroupe tous ceux qui ne sont ni prêtres ni nobles, c'est-à-dire presque tout le monde : les paysans, qui forment l'immense majorité, les artisans et les ouvriers des villes, mais aussi une **bourgeoisie** riche et instruite — négociants, avocats, banquiers — qui supporte de plus en plus mal d'être exclue des honneurs réservés à la naissance."),
                .bars(title: "Poids des trois ordres dans la population (vers 1789)", unit: "%", bars: [
                    DemoBar(label: "Clergé", value: 0.5),
                    DemoBar(label: "Noblesse", value: 1.5),
                    DemoBar(label: "Tiers état", value: 98),
                ]),
                .paragraph("Le graphique montre le cœur du problème : deux pour cent de la population détiennent l'essentiel des privilèges, une grande partie de la terre et presque toutes les hautes fonctions. En janvier 1789, l'abbé Sieyès résume la situation dans un pamphlet célèbre : « Qu'est-ce que le tiers état ? Tout. Qu'a-t-il été jusqu'à présent ? Rien. Que demande-t-il ? À être quelque chose. »"),
                .heading("Trois crises en même temps"),
                .paragraph("La Révolution naît de la rencontre de trois crises. Une **crise financière** d'abord : les guerres, et surtout le soutien à l'indépendance américaine, ont creusé la dette, dont le remboursement absorbe près de ==la moitié des dépenses de l'État==. Les ministres successifs proposent de faire payer les privilégiés ; les privilégiés refusent."),
                .paragraph("Une **crise économique** ensuite : la récolte de 1788, ravagée par la grêle, est catastrophique, et le prix du pain flambe. Le 14 juillet 1789, il atteint son niveau le plus haut du siècle à Paris. Une **crise des idées**, enfin : les philosophes des Lumières — Montesquieu et la séparation des pouvoirs, Rousseau et la souveraineté du peuple, Voltaire et la tolérance — ont appris aux élites à juger le pouvoir au nom de la raison."),
                .figure(.flow(title: "De la crise à la Révolution", steps: ["Dette et banqueroute menaçante", "Les privilégiés refusent l'impôt", "Le roi convoque les états généraux", "Le tiers réclame le vote par tête", "Le tiers se proclame Assemblée nationale"])),
                .paragraph("Acculé, Louis XVI convoque les **états généraux**, une assemblée des trois ordres qui ne s'était pas réunie depuis 1614. Dans tout le royaume, on rédige des **cahiers de doléances** pour dire au roi ce qui ne va pas : près de soixante mille, qui réclament surtout l'égalité devant l'impôt et la fin des abus, mais presque jamais la fin de la monarchie."),
                .callout(
                    title: "Le vote par ordre",
                    text: "Aux états généraux, chaque ordre vote séparément et dispose d'**une voix** : le clergé et la noblesse, unis, battent toujours le tiers par deux voix contre une. Le tiers a obtenu d'avoir autant de députés que les deux autres ordres réunis — encore faut-il qu'on vote **par tête** pour que ce nombre compte.",
                    tone: .insight
                ),
                .paragraph("Tout se joue sur cette question de procédure. Le 17 juin 1789, faute d'accord, les députés du tiers se proclament ==bleu|Assemblée nationale== : ils ne représentent plus un ordre, mais la nation entière. Le 20 juin, trouvant leur salle fermée, ils se réunissent dans la salle du Jeu de paume et jurent de ne pas se séparer avant d'avoir donné une constitution à la France. La souveraineté vient de changer de camp."),
            ]),
            DemoChapter(title: "1789 : la fin de l'absolutisme", blocks: [
                .paragraph("L'été 1789 défait en quelques semaines ce que des siècles avaient construit. La révolution des députés à Versailles est relayée par ==la révolution des Parisiens==, puis par celle des campagnes : c'est cette conjonction qui la rend irréversible."),
                .timeline(title: "L'été et l'automne 1789", events: [
                    DemoEvent(date: "5 mai", label: "Ouverture des états généraux à Versailles"),
                    DemoEvent(date: "20 juin", label: "Serment du Jeu de paume"),
                    DemoEvent(date: "14 juillet", label: "Prise de la Bastille"),
                    DemoEvent(date: "4 août", label: "Abolition des privilèges"),
                    DemoEvent(date: "26 août", label: "Déclaration des droits de l'homme et du citoyen"),
                    DemoEvent(date: "5–6 octobre", label: "Le roi est ramené de Versailles à Paris"),
                ]),
                .paragraph("Début juillet, le roi masse des troupes autour de Paris et renvoie Necker, le ministre populaire. Les Parisiens y voient la préparation d'un coup de force contre l'Assemblée. Le 14 juillet, cherchant de la poudre pour les fusils pris aux Invalides, la foule attaque la **Bastille**, forteresse royale et prison d'État. Elle ne contient que sept prisonniers, mais sa chute est un symbole : le peuple a fait plier le roi."),
                .heading("La nuit du 4 août"),
                .paragraph("Dans les campagnes, une rumeur de complot aristocratique déclenche la **Grande Peur** : des paysans armés attaquent les châteaux et brûlent les registres où sont inscrits les droits seigneuriaux. Pour ramener le calme, l'Assemblée vote, dans la nuit du 4 août, l'==abolition des privilèges== : fin des droits féodaux, de la dîme, de la vénalité des offices, égalité de tous devant l'impôt et devant les emplois."),
                .callout(
                    title: "Déclaration des droits de l'homme et du citoyen",
                    text: "Adoptée le 26 août 1789, elle pose en dix-sept articles les principes du nouveau régime. Article 1 : « Les hommes naissent et demeurent libres et égaux en droits. » Article 3 : la souveraineté réside dans **la nation**. Article 16 : pas de constitution sans séparation des pouvoirs.",
                    tone: .definition
                ),
                .paragraph("La Déclaration est un texte universel — elle parle de l'homme, pas du Français — et c'est pourquoi elle a eu une telle influence hors de France. Mais elle a aussi ses angles morts : elle ne dit rien des femmes, et ne remet pas en cause l'esclavage dans les colonies. En 1791, Olympe de Gouges lui répond par une *Déclaration des droits de la femme et de la citoyenne*."),
                .figure(.split(
                    title: "Deux sources du pouvoir",
                    left: DemoColumn(title: "Ancien Régime", items: ["Monarchie de droit divin", "Société d'ordres", "Privilèges", "Le roi fait la loi", "Des sujets"]),
                    right: DemoColumn(title: "Principes de 1789", items: ["Souveraineté nationale", "Égalité en droits", "Loi commune à tous", "Séparation des pouvoirs", "Des citoyens"])
                )),
                .paragraph("Le face-à-face résume ce qui a changé en 1789 : le pouvoir ne vient plus de Dieu mais de la nation, et la loi n'est plus la volonté d'un seul mais ==l'expression de la volonté générale==. Le roi reste en place, mais il n'est plus que le premier fonctionnaire d'un État dont il ne possède plus la souveraineté."),
                .heading("La monarchie constitutionnelle"),
                .paragraph("De 1789 à 1791, l'Assemblée constituante refait la France. Elle crée les **départements** (1790), nationalise les biens du clergé pour rembourser la dette, et impose au clergé une **Constitution civile** qui fait des prêtres des fonctionnaires élus. La Constitution de 1791 installe une monarchie constitutionnelle : le roi garde le pouvoir exécutif et un droit de veto suspensif ; une Assemblée législative vote les lois."),
                .callout(
                    title: "Le suffrage censitaire",
                    text: "En 1791, seuls votent les **citoyens actifs** : les hommes de plus de 25 ans qui paient un impôt au moins égal à trois journées de travail, soit environ 4,3 millions de Français. Les autres sont citoyens « passifs » : égaux en droits, mais pas en droits politiques.",
                    tone: .warning
                ),
                .paragraph("Ce compromis repose sur la bonne foi du roi, et le roi n'en a pas. Dans la nuit du 20 au 21 juin 1791, Louis XVI s'enfuit avec sa famille vers la frontière de l'Est ; il est reconnu et arrêté à **Varennes**. Le lien de confiance est rompu : pour une partie des Parisiens, un roi qui fuit sa nation ne peut plus la représenter."),
            ]),
            DemoChapter(title: "La République et la Terreur (1792–1794)", blocks: [
                .paragraph("En avril 1792, la France déclare la guerre à l'Autriche. Les révolutionnaires espèrent exporter la liberté ; le roi espère secrètement la défaite, qui le rétablirait. La guerre va ==radicaliser la Révolution== : défaites, trahisons réelles ou supposées, soulèvements intérieurs, et la conviction qu'il faut vaincre à tout prix."),
                .heading("La chute de la monarchie"),
                .paragraph("Le 10 août 1792, les sans-culottes parisiens et les fédérés venus de province prennent d'assaut le palais des Tuileries. Le roi est suspendu, puis emprisonné. Une nouvelle assemblée, la **Convention**, est élue pour la première fois au **suffrage universel masculin**. Le 20 septembre, l'armée française arrête les Prussiens à Valmy ; le 21, la Convention abolit la royauté. La République est née."),
                .keyFigure(value: "21 janv. 1793", label: "Louis XVI, jugé par la Convention et reconnu coupable de trahison, est guillotiné place de la Révolution"),
                .paragraph("L'exécution du roi fait de la France une ennemie pour toutes les monarchies d'Europe : l'Angleterre, l'Espagne et les Provinces-Unies rejoignent la coalition. Pour lever des soldats, la Convention décrète une levée de 300 000 hommes, et l'Ouest s'embrase : c'est le début de la **guerre de Vendée**, qui fera environ deux cent mille morts dans les deux camps."),
                .figure(.split(
                    title: "Deux camps à la Convention",
                    left: DemoColumn(title: "Girondins", items: ["Brissot, Vergniaud", "Appui des provinces", "Méfiance envers Paris", "Libéralisme économique", "Refus des mesures d'exception"]),
                    right: DemoColumn(title: "Montagnards", items: ["Robespierre, Danton, Marat", "Appui des sans-culottes", "Pouvoir central fort", "Contrôle des prix", "Mesures d'exception"])
                )),
                .paragraph("Entre les deux groupes, la **Plaine** — la majorité des députés — fait basculer les votes. Sous la pression des sans-culottes, qui encerclent la Convention le 2 juin 1793, les chefs girondins sont arrêtés. Les Montagnards gouvernent désormais seuls, à travers le **Comité de salut public**, dont Robespierre devient la figure dominante."),
                .heading("La Terreur"),
                .callout(
                    title: "La Terreur",
                    text: "Le gouvernement d'exception de 1793–1794, qui suspend les libertés pour sauver la République menacée par la guerre étrangère et la guerre civile. Ses instruments : la **loi des suspects** (septembre 1793), le Tribunal révolutionnaire, les représentants en mission, et la guillotine.",
                    tone: .definition
                ),
                .paragraph("La Terreur est aussi une politique économique et sociale : le **maximum général** fixe le prix des denrées de première nécessité, la **levée en masse** mobilise tous les hommes de 18 à 25 ans, et la Convention abolit l'esclavage dans les colonies le 4 février 1794. Elle impose un calendrier républicain qui fait partir le temps du 22 septembre 1792, an I de la liberté."),
                .paragraph("Le bilan humain est lourd. Environ ==rose|17 000 condamnations à mort== sont prononcées par les tribunaux, sans compter les exécutions sommaires et les massacres de la guerre civile. Contrairement à une idée reçue, les victimes ne sont pas surtout des nobles : ce sont en majorité des gens du peuple, soupçonnés de révolte, de fraude ou de tiédeur."),
                .bars(title: "Condamnés à mort de la Terreur, selon leur origine sociale", unit: "%", bars: [
                    DemoBar(label: "Ouvriers, artisans", value: 31),
                    DemoBar(label: "Paysans", value: 28),
                    DemoBar(label: "Bourgeoisie", value: 25),
                    DemoBar(label: "Noblesse", value: 8.5),
                    DemoBar(label: "Clergé", value: 6.5),
                ]),
                .paragraph("Ces chiffres, établis par l'historien Donald Greer en 1935, montrent que la Terreur frappe d'abord là où la République se sent menacée — la Vendée, Lyon, Marseille, Toulon —, et donc là où vivent la plupart des gens. Au printemps 1794, les victoires militaires rendent l'exception moins justifiable ; mais la loi du 22 prairial (juin 1794) accélère encore les procès : c'est la **Grande Terreur**."),
                .callout(
                    title: "Le 9 thermidor",
                    text: "Le 27 juillet 1794 (9 thermidor an II), des députés qui craignent pour leur propre tête font arrêter Robespierre et ses proches. Ils sont guillotinés le lendemain. La Terreur prend fin, non parce que ses adversaires l'ont vaincue de l'extérieur, mais parce que ==ses propres acteurs== s'en sont retournés.",
                    tone: .insight
                ),
            ]),
            DemoChapter(title: "Du Directoire à Bonaparte (1795–1799), et ce qu'il en reste", blocks: [
                .paragraph("Après Thermidor, les républicains modérés veulent ==terminer la Révolution== : ni retour du roi, ni retour de la Terreur. La Constitution de l'an III (1795) est conçue pour empêcher à la fois la dictature d'un homme et celle d'une assemblée."),
                .heading("Un régime fragile"),
                .paragraph("Le pouvoir exécutif est confié à cinq **directeurs**, le pouvoir législatif à deux conseils — les Cinq-Cents, qui proposent les lois, et les Anciens, qui les votent. Le suffrage redevient censitaire. Le régime est pris en étau entre les royalistes, qui gagnent les élections de 1797, et les néo-jacobins, qui gagnent celles de 1798 : chaque fois, le Directoire annule le résultat par un coup de force, et s'appuie de plus en plus sur l'armée."),
                .table(title: "Les régimes de la décennie", headers: ["Régime", "Dates", "Qui gouverne", "Suffrage"], rows: [
                    ["Monarchie absolue", "jusqu'en 1789", "Le roi seul", "Aucun"],
                    ["Monarchie constitutionnelle", "1791–1792", "Le roi et l'Assemblée législative", "Censitaire"],
                    ["République : la Convention", "1792–1795", "La Convention, le Comité de salut public", "Universel masculin"],
                    ["République : le Directoire", "1795–1799", "Cinq directeurs, deux conseils", "Censitaire"],
                    ["Consulat", "à partir de 1799", "Bonaparte, Premier consul", "Plébiscites"],
                ]),
                .paragraph("Le tableau se lit comme une courbe : le pouvoir s'élargit jusqu'en 1793, puis se resserre. Et à chaque étape, le suffrage suit le même mouvement. La Révolution a posé le principe de la souveraineté nationale, mais elle n'a jamais cessé de se disputer sur ==qui a le droit de parler au nom de la nation==."),
                .paragraph("Pendant ce temps, un jeune général s'impose. Napoléon Bonaparte a écrasé une insurrection royaliste à Paris en 1795, conquis l'Italie en 1796–1797, puis mené l'expédition d'Égypte. Rentré en France auréolé de ses victoires, il s'allie à Sieyès, devenu directeur, qui cherche « un sabre » pour réviser la Constitution."),
                .callout(
                    title: "Le coup d'État du 18 brumaire",
                    text: "Le 9 novembre 1799 (18 brumaire an VIII), Bonaparte et Sieyès renversent le Directoire ; le lendemain, les grenadiers dispersent les Cinq-Cents. Le Consulat qui suit concentre le pouvoir entre les mains du Premier consul. On date traditionnellement de ce jour **la fin de la Révolution**.",
                    tone: .example
                ),
                .heading("Ce qui reste de la Révolution"),
                .paragraph("Bonaparte garde une grande partie de l'héritage : le Code civil de 1804 consacre l'égalité devant la loi, la propriété et la fin de la féodalité. Il en efface d'autres : il rétablit l'esclavage en 1802, et remplace la souveraineté des assemblées par la sienne. L'héritage révolutionnaire se lit donc en deux colonnes : des principes acquis pour toujours, et des combats qui dureront tout le XIXe siècle."),
                .list([
                    "Acquis durables : fin des privilèges et de la société d'ordres, égalité devant la loi et l'impôt, départements, système métrique, état civil laïque",
                    "Principes posés : souveraineté nationale, droits de l'homme, séparation des pouvoirs",
                    "Combats inachevés : suffrage universel (1848), abolition définitive de l'esclavage (1848), droit de vote des femmes (1944)",
                ]),
                .paragraph("Les dates de la dernière ligne montrent qu'il a fallu un siècle et demi pour tenir toutes les promesses de 1789. C'est ce décalage entre ==les principes proclamés et leur application== qui fait de la Révolution un moment fondateur : elle a donné aux générations suivantes les mots avec lesquels réclamer ce qu'elle-même n'avait pas accordé."),
                .figure(.flow(title: "La dynamique de la décennie", steps: ["1789 : la nation prend la souveraineté", "1791 : compromis avec le roi", "1792 : guerre et République", "1793–1794 : Terreur", "1795–1799 : stabilisation, puis l'armée"])),
                .paragraph("Ce schéma est la colonne vertébrale d'une composition sur la période. Chaque étape répond à l'échec de la précédente : le compromis de 1791 échoue à cause du roi, la République modérée à cause de la guerre, la Terreur à cause de ses excès, et le Directoire faute de légitimité. Expliquer ==pourquoi chaque étape mène à la suivante==, c'est comprendre la Révolution plutôt que la réciter."),
                .callout(
                    title: "L'erreur classique",
                    text: "Écrire que la Révolution abolit la monarchie en 1789. En 1789, elle abolit l'**absolutisme** et les privilèges ; la monarchie constitutionnelle dure jusqu'au 10 août 1792, et la République n'est proclamée qu'en septembre 1792.",
                    tone: .warning
                ),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Quels sont les trois ordres de la société d'Ancien Régime ?",
                back: "Le clergé et la noblesse, ordres privilégiés (environ 2 % de la population), et le tiers état (environ 98 %), qui paie l'essentiel des impôts.",
                figure: .split(
                    title: "Une société d'ordres",
                    left: DemoColumn(title: "Privilégiés", items: ["Clergé", "Noblesse"]),
                    right: DemoColumn(title: "Non privilégiés", items: ["Tiers état"])
                ),
                chapter: 0
            ),
            DemoCard(
                kind: .choice,
                front: "Que vote l'Assemblée dans la nuit du 4 août 1789 ?",
                back: "L'abolition des privilèges : fin des droits féodaux, de la dîme et de la vénalité des offices, égalité devant l'impôt.",
                choices: ["La Déclaration des droits de l'homme", "L'abolition des privilèges", "L'abolition de la royauté", "La Constitution civile du clergé"],
                answerIndex: 1,
                chapter: 1
            ),
            DemoCard(
                kind: .cloze,
                front: "Louis XVI est arrêté à … en juin 1791, alors qu'il fuit vers la frontière de l'Est.",
                back: "Varennes",
                chapter: 1
            ),
            DemoCard(kind: .basic, front: "Pourquoi la question du vote par ordre ou par tête est-elle décisive en 1789 ?", back: "Par ordre, le clergé et la noblesse l'emportent toujours à deux voix contre une. Par tête, le tiers état, qui a autant de députés que les deux autres ordres réunis, peut obtenir la majorité avec quelques alliés.", hint: "Comptez les voix dans chaque cas.", chapter: 0),
            DemoCard(kind: .cloze, front: "Le 17 juin 1789, les députés du tiers état se proclament … .", back: "Assemblée nationale", chapter: 0),
            DemoCard(kind: .choice, front: "Quand la République est-elle proclamée en France ?", back: "En septembre 1792 : la Convention abolit la royauté le 21 septembre, au lendemain de Valmy.", choices: ["Juillet 1789", "Juin 1791", "Septembre 1792", "Juillet 1794"], answerIndex: 2, chapter: 2),
            DemoCard(kind: .basic, front: "Qu'est-ce que la Terreur ?", back: "Le gouvernement d'exception de 1793–1794 qui suspend les libertés pour sauver la République en guerre : loi des suspects, Tribunal révolutionnaire, environ 17 000 condamnations à mort. Elle prend fin avec la chute de Robespierre le 9 thermidor an II (27 juillet 1794).", chapter: 2),
            DemoCard(kind: .cloze, front: "L'article 1 de la Déclaration de 1789 affirme : « Les hommes naissent et demeurent libres et … en droits. »", back: "égaux", chapter: 1),
            DemoCard(kind: .choice, front: "Quel groupe social compte le plus de condamnés à mort pendant la Terreur ?", back: "Les gens du peuple : ouvriers, artisans et paysans forment près de six condamnés sur dix ; les nobles, environ 8 %.", choices: ["La noblesse", "Le clergé", "Les ouvriers, artisans et paysans", "Les officiers de l'armée"], answerIndex: 2, chapter: 2),
            DemoCard(kind: .basic, front: "Qu'est-ce que le suffrage censitaire ?", back: "Un droit de vote réservé à ceux qui paient un certain montant d'impôt (le cens). En 1791, seuls les citoyens « actifs », environ 4,3 millions d'hommes, votent.", chapter: 1),
            DemoCard(kind: .cloze, front: "Le coup d'État du 18 … an VIII (9 novembre 1799) porte Bonaparte au pouvoir.", back: "brumaire", chapter: 3),
            DemoCard(kind: .choice, front: "Combien de directeurs exercent le pouvoir exécutif sous le Directoire ?", back: "Cinq, face à deux conseils : les Cinq-Cents et les Anciens.", choices: ["Un", "Trois", "Cinq", "Sept"], answerIndex: 2, chapter: 3),
        ]
    )

    // MARK: SVT : génétique et ADN

    private static let geneticsFR = OnboardingDemoCourse(
        id: "debug-genetics",
        emoji: "🧬",
        subject: "SVT",
        title: "Génétique et ADN",
        summary: "La molécule d'ADN, sa réplication, le passage du gène à la protéine, les mutations qui créent la diversité, et les lois de Mendel qui en décrivent la transmission.",
        accentIndex: 4,
        chapters: [
            DemoChapter(title: "La molécule d'ADN", blocks: [
                .paragraph("Chaque cellule de votre corps contient, dans son noyau, environ ==deux mètres d'ADN== repliés dans quelques micromètres. Cette molécule porte l'information qui permet de construire et de faire fonctionner un être vivant, et elle la transmet d'une cellule à ses filles, d'un parent à ses enfants."),
                .heading("Une double hélice"),
                .paragraph("L'ADN — l'acide désoxyribonucléique — est un long enchaînement de **nucléotides**. Chaque nucléotide est formé de trois éléments : un groupement phosphate, un sucre, le désoxyribose, et une **base azotée**. Il existe quatre bases : l'adénine (A), la thymine (T), la guanine (G) et la cytosine (C). C'est l'ordre de ces bases le long de la molécule qui constitue l'information génétique."),
                .callout(
                    title: "Complémentarité des bases",
                    text: "Les deux brins de l'ADN sont reliés par leurs bases, toujours appariées de la même façon : **A avec T** (deux liaisons hydrogène), **G avec C** (trois liaisons hydrogène). Connaître un brin, c'est donc connaître l'autre.",
                    tone: .definition
                ),
                .paragraph("Cette règle avait été repérée avant qu'on comprenne la structure : en 1950, Erwin Chargaff montre que dans l'ADN de toutes les espèces, il y a autant d'adénine que de thymine, et autant de guanine que de cytosine. Les proportions de A et de G, en revanche, varient d'une espèce à l'autre."),
                .formula("A = T \\;\\;\\;\\; G = C \\;\\;\\;\\; A + G = T + C", caption: "Les règles de Chargaff, en proportions de bases : conséquence de l'appariement"),
                .paragraph("En 1953, James Watson et Francis Crick proposent le modèle de la **double hélice**, en s'appuyant sur les clichés de diffraction aux rayons X obtenus par Rosalind Franklin. Les deux brins s'enroulent l'un autour de l'autre comme une échelle torsadée : les montants sont les chaînes de sucres et de phosphates, les barreaux sont les paires de bases. Les deux brins sont ==antiparallèles== : ils courent en sens opposés."),
                .heading("Gènes, chromosomes, génome"),
                .paragraph("Dans une cellule humaine, l'ADN est découpé en **46 chromosomes**, 23 hérités de la mère et 23 du père. Un **gène** est un segment d'ADN qui porte l'information pour fabriquer une protéine ; il occupe une place précise sur un chromosome, son **locus**. L'ensemble de l'ADN d'un organisme est son **génome** : chez l'humain, environ 3,2 milliards de paires de bases par jeu de chromosomes."),
                .bars(title: "Nombre de gènes codant des protéines (ordres de grandeur)", unit: "milliers", bars: [
                    DemoBar(label: "Bactérie E. coli", value: 4.3),
                    DemoBar(label: "Levure", value: 6),
                    DemoBar(label: "Drosophile", value: 14),
                    DemoBar(label: "Ver C. elegans", value: 20),
                    DemoBar(label: "Humain", value: 20),
                ]),
                .paragraph("Le graphique réserve une surprise : un ver d'un millimètre possède à peu près autant de gènes que nous. La complexité d'un organisme ne tient donc pas au nombre de ses gènes, mais à ==la façon dont ils sont utilisés== — quand, où et combien. Chez l'humain, les gènes codant des protéines n'occupent d'ailleurs qu'environ 1,5 % du génome."),
                .table(title: "Le vocabulaire de base", headers: ["Mot", "Définition"], rows: [
                    ["Gène", "Segment d'ADN qui code une protéine"],
                    ["Allèle", "Une version d'un gène, qui diffère par sa séquence"],
                    ["Locus", "L'emplacement d'un gène sur un chromosome"],
                    ["Génotype", "Les allèles que possède un individu"],
                    ["Phénotype", "Les caractères observables qui en résultent"],
                ]),
                .paragraph("Ces cinq mots reviennent dans tout le reste du cours, et chacun désigne un niveau différent : la molécule, sa variante, sa place, ce qu'un individu possède, et ce qu'on voit de lui. Un phénotype dépend du génotype, mais aussi de l'environnement : deux jumeaux vrais ont le même génotype, pas forcément la même taille."),
            ]),
            DemoChapter(title: "La réplication de l'ADN", blocks: [
                .paragraph("Avant chaque division, une cellule doit copier ses 3,2 milliards de paires de bases — deux fois, puisqu'elle en a deux jeux — pour en donner un exemplaire complet à chacune de ses filles. Cette copie s'appelle la **réplication**, et elle est d'une fidélité ==presque parfaite==."),
                .heading("Un mécanisme semi-conservatif"),
                .paragraph("Le principe découle directement de la complémentarité. Les deux brins de la double hélice se séparent, comme une fermeture éclair qu'on ouvre ; chaque brin sert alors de **modèle** pour fabriquer un brin neuf, en plaçant en face de chaque base sa base complémentaire. On obtient deux molécules identiques à la molécule de départ."),
                .figure(.flow(title: "Les étapes de la réplication", steps: ["L'hélicase ouvre la double hélice", "Chaque brin sert de modèle", "L'ADN polymérase ajoute les nucléotides complémentaires", "Deux molécules identiques, chacune avec un brin ancien et un brin neuf"])),
                .paragraph("Chaque molécule fille contient donc un brin hérité de la molécule mère et un brin nouvellement synthétisé : on dit que la réplication est **semi-conservative**. L'ADN polymérase ne travaille que dans un sens, en allongeant le brin neuf de son extrémité 5′ vers son extrémité 3′, et la réplication démarre en de nombreux points à la fois le long de chaque chromosome."),
                .callout(
                    title: "L'expérience de Meselson et Stahl (1958)",
                    text: "Des bactéries cultivées sur de l'azote lourd (¹⁵N) sont transférées sur de l'azote léger (¹⁴N). Après une division, tout leur ADN est de densité **intermédiaire** ; après deux, moitié intermédiaire, moitié léger. Seul le modèle semi-conservatif prédit exactement ce résultat.",
                    tone: .example
                ),
                .paragraph("Cette expérience est un modèle de démarche scientifique : trois hypothèses étaient possibles — conservative, semi-conservative, dispersive —, chacune prédisait un résultat différent, et une seule mesure a suffi à trancher. Retenez le raisonnement autant que la conclusion : c'est ce qu'on vous demandera d'appliquer à l'examen."),
                .keyFigure(value: "1 / 10⁹", label: "l'ordre de grandeur du taux d'erreur par nucléotide copié, une fois les systèmes de correction passés"),
                .paragraph("Une erreur sur un milliard, c'est à peu près une faute de frappe tous les mille livres recopiés. Ce taux extraordinaire est obtenu en deux temps : l'ADN polymérase relit ce qu'elle vient d'écrire et corrige ses propres erreurs, puis d'autres enzymes passent derrière elle pour réparer ce qui a échappé à cette relecture. Mais une erreur sur un milliard, sur six milliards de bases, c'est encore ==quelques erreurs à chaque division==."),
                .callout(
                    title: "Ne pas confondre",
                    text: "La réplication copie **l'ADN en ADN**, dans le noyau, avant une division. La transcription, qu'on verra au chapitre suivant, copie **un gène en ARN**, à tout moment de la vie de la cellule. Même principe de complémentarité, deux fonctions différentes.",
                    tone: .warning
                ),
                .list([
                    "Réplication : avant chaque division, pendant la phase S du cycle cellulaire",
                    "Semi-conservative : chaque molécule fille garde un brin de la molécule mère",
                    "Enzyme clé : l'ADN polymérase, qui assemble et relit",
                    "Fidélité : environ une erreur par milliard de nucléotides",
                ]),
                .paragraph("Ces erreurs résiduelles ne sont pas qu'un défaut. Ce sont elles, accumulées au fil des générations, qui produisent de nouveaux allèles, et donc la diversité sur laquelle agit l'évolution. Un système de copie parfait donnerait des espèces figées : c'est ==l'imperfection de la réplication== qui rend l'évolution possible."),
            ]),
            DemoChapter(title: "Du gène à la protéine", blocks: [
                .paragraph("L'ADN reste dans le noyau, mais les protéines sont fabriquées dans le cytoplasme. Il faut donc un intermédiaire, qui copie l'information et la transporte : c'est l'**ARN messager**. L'expression d'un gène se fait en deux étapes, la ==menthe|transcription== puis la ==bleu|traduction==."),
                .figure(.flow(title: "L'expression d'un gène", steps: ["ADN (le gène, dans le noyau)", "Transcription : ARN messager", "L'ARNm sort du noyau", "Traduction par les ribosomes", "Protéine"])),
                .paragraph("La **transcription** a lieu dans le noyau. L'ARN polymérase ouvre la double hélice au niveau d'un gène et fabrique une copie d'un seul des deux brins, le brin transcrit, par complémentarité. La molécule obtenue est un ARN : elle ressemble à l'ADN, avec trois différences."),
                .figure(.split(
                    title: "ADN et ARN",
                    left: DemoColumn(title: "ADN", items: ["Deux brins", "Sucre : désoxyribose", "Bases A, T, G, C", "Très long, dans le noyau", "Stable, conservé"]),
                    right: DemoColumn(title: "ARN messager", items: ["Un seul brin", "Sucre : ribose", "Bases A, U, G, C", "Court : un gène", "Éphémère, détruit après usage"])
                )),
                .paragraph("La différence la plus utile en exercice est celle des bases : dans l'ARN, **l'uracile (U) remplace la thymine**. Face à un A du brin transcrit, l'ARN polymérase place donc un U. La séquence de l'ARNm est ainsi identique à celle du brin non transcrit de l'ADN, dit brin codant, aux T près, qui y deviennent des U."),
                .heading("Le code génétique"),
                .paragraph("La **traduction** a lieu dans le cytoplasme, sur les ribosomes. L'ARNm y est lu par groupes de trois nucléotides, les **codons** ; chaque codon correspond à un acide aminé, et les acides aminés s'enchaînent pour former la protéine. La correspondance entre codons et acides aminés est le **code génétique**."),
                .formula("4^3 = 64 \\text{ codons} \\;\\; \\text{pour} \\;\\; 20 \\text{ acides aminés}", caption: "Quatre bases, trois positions : largement assez pour vingt acides aminés"),
                .paragraph("Il y a donc plus de codons que d'acides aminés : 61 codons désignent un acide aminé, et 3 sont des codons **stop** qui terminent la traduction. Plusieurs codons peuvent coder le même acide aminé — on dit que le code est **redondant** —, mais un codon ne code jamais qu'un seul acide aminé. La traduction commence toujours au codon AUG, qui code la méthionine."),
                .table(title: "Quelques codons de l'ARNm", headers: ["Codon", "Acide aminé"], rows: [
                    ["AUG", "Méthionine (codon initiateur)"],
                    ["GCA", "Alanine"],
                    ["UGG", "Tryptophane"],
                    ["GAG", "Acide glutamique"],
                    ["GUG", "Valine"],
                    ["UAA, UAG, UGA", "Stop"],
                ]),
                .paragraph("Le tableau montre déjà la redondance : GAG et GAA codent tous deux l'acide glutamique, et l'on verra au dernier chapitre qu'un seul changement de lettre — GAG devenu GUG — suffit à remplacer cet acide aminé par une valine. Pour traduire un ARN messager, on procède toujours dans le même ordre : repérer le codon AUG, découper en triplets, puis lire le tableau jusqu'au premier codon stop."),
                .callout(
                    title: "Exemple complet",
                    text: "Brin codant de l'ADN : 5′-ATG GCA TGG-3′. ARN messager : 5′-AUG GCA UGG-3′ (on remplace T par U). Protéine : **Met – Ala – Trp**. On lit toujours codon par codon, à partir du codon initiateur, sans chevauchement.",
                    tone: .example
                ),
                .paragraph("Le code génétique est ==universel== : à de rares exceptions près, le même codon désigne le même acide aminé chez une bactérie, un chêne et un être humain. C'est un argument fort en faveur d'une origine commune de tous les êtres vivants — et c'est ce qui permet de faire fabriquer de l'insuline humaine par des bactéries, en leur donnant simplement le gène."),
            ]),
            DemoChapter(title: "Mutations et hérédité", blocks: [
                .paragraph("Une **mutation** est une modification de la séquence de l'ADN. Elle peut être spontanée — une erreur de réplication non corrigée — ou provoquée par un **agent mutagène** : rayons UV, rayons X, certaines substances chimiques comme celles de la fumée de tabac. Toutes les mutations ne se valent pas, et leur effet dépend de ==l'endroit où elles tombent==."),
                .heading("Les types de mutations"),
                .table(title: "Mutations ponctuelles et conséquences", headers: ["Type", "Ce qui change", "Effet sur la protéine"], rows: [
                    ["Substitution silencieuse", "Une base, mais même acide aminé", "Aucun, grâce à la redondance du code"],
                    ["Substitution faux-sens", "Une base, un acide aminé différent", "Variable : nul à grave"],
                    ["Substitution non-sens", "Un codon devient un codon stop", "Protéine tronquée, souvent inactive"],
                    ["Insertion ou délétion", "Une base en plus ou en moins", "Décalage du cadre de lecture : protéine très altérée"],
                ]),
                .paragraph("La drépanocytose est l'exemple le plus étudié. Dans le gène de l'hémoglobine, le sixième codon passe de GAG à GTG : une seule base change, et l'acide glutamique est remplacé par une valine. Cette hémoglobine anormale se polymérise quand elle manque d'oxygène, et déforme les globules rouges en faucille."),
                .callout(
                    title: "Une mutation, deux effets",
                    text: "Les personnes qui portent deux allèles mutés sont malades ; celles qui n'en portent qu'un sont en bonne santé, et en plus **mieux protégées contre le paludisme**. C'est pourquoi l'allèle est fréquent en Afrique subsaharienne : là où le paludisme sévit, il avantage ses porteurs.",
                    tone: .insight
                ),
                .paragraph("Seules les mutations qui touchent les cellules reproductrices — les **mutations germinales** — se transmettent à la descendance. Une mutation dans une cellule de la peau, dite **somatique**, ne concerne que l'individu et les cellules issues de celle qui a muté : elle peut provoquer un cancer, mais pas une maladie héréditaire."),
                .heading("Les lois de Mendel"),
                .paragraph("En 1865, le moine Gregor Mendel publie les résultats de huit ans de croisements de pois. Il croise des lignées pures à graines rondes avec des lignées pures à graines ridées : toute la première génération (F1) a des graines rondes. Puis il croise ces hybrides entre eux : en deuxième génération (F2), le caractère ridé réapparaît, dans une proportion remarquablement stable."),
                .bars(title: "Les graines de Mendel en deuxième génération", unit: "graines", bars: [
                    DemoBar(label: "Rondes", value: 5474),
                    DemoBar(label: "Ridées", value: 1850),
                ]),
                .paragraph("Le rapport vaut $5474 / 1850 \\approx 2{,}96$, soit presque exactement **trois pour un**. Mendel l'explique par une hypothèse audacieuse pour l'époque : chaque individu possède deux « facteurs » pour un caractère — nous disons deux ==allèles== —, n'en transmet qu'un à chaque gamète, et l'allèle rond (R) est **dominant** sur l'allèle ridé (r), qui est **récessif**."),
                .table(title: "Échiquier de croisement : Rr × Rr", headers: ["", "Gamète R", "Gamète r"], rows: [
                    ["Gamète R", "RR (rond)", "Rr (rond)"],
                    ["Gamète r", "Rr (rond)", "rr (ridé)"],
                ]),
                .paragraph("Chaque case a une probabilité de un quart. On obtient les génotypes RR, Rr et rr dans les proportions 1/4, 1/2 et 1/4, et donc les phénotypes rond et ridé dans les proportions 3/4 et 1/4. Seuls les individus **homozygotes** rr expriment le caractère récessif ; les **hétérozygotes** Rr le portent sans le montrer."),
                .formula("P(rr) = \\frac{1}{2} \\times \\frac{1}{2} = \\frac{1}{4}", caption: "Chaque parent hétérozygote transmet r avec une probabilité 1/2, indépendamment de l'autre"),
                .paragraph("Le même raisonnement vaut pour les maladies humaines récessives, comme la **mucoviscidose** : deux parents porteurs sains, hétérozygotes, ont à chaque grossesse une probabilité de 1/4 d'avoir un enfant malade. « À chaque grossesse » est essentiel : ==le hasard n'a pas de mémoire==, et avoir eu un enfant malade ne protège pas le suivant."),
                .timeline(title: "Les grandes étapes de la génétique", events: [
                    DemoEvent(date: "1865", label: "Mendel publie ses lois de l'hérédité"),
                    DemoEvent(date: "1944", label: "Avery montre que l'ADN porte l'information héréditaire"),
                    DemoEvent(date: "1953", label: "Watson, Crick et Franklin : la double hélice"),
                    DemoEvent(date: "1966", label: "Le code génétique entièrement déchiffré"),
                    DemoEvent(date: "2003", label: "Séquence complète du génome humain"),
                    DemoEvent(date: "2012", label: "Charpentier et Doudna : l'outil CRISPR-Cas9"),
                ]),
                .paragraph("Cent cinquante ans séparent les pois de Mendel des ciseaux moléculaires qui permettent aujourd'hui de modifier un gène précis. Chaque étape a répondu à une question laissée ouverte par la précédente : ce qui est transmis, de quoi c'est fait, comment c'est copié, comment c'est lu — et maintenant, ==comment le corriger==."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Comment les bases de l'ADN s'apparient-elles entre les deux brins ?",
                back: "L'adénine avec la thymine (A–T, deux liaisons hydrogène) et la guanine avec la cytosine (G–C, trois liaisons hydrogène). Un brin détermine donc entièrement l'autre.",
                figure: .split(
                    title: "Complémentarité",
                    left: DemoColumn(title: "Brin 1", items: ["A", "G", "T", "C"]),
                    right: DemoColumn(title: "Brin 2", items: ["T", "C", "A", "G"])
                ),
                chapter: 0
            ),
            DemoCard(
                kind: .choice,
                front: "Quel est l'ARN messager transcrit à partir du brin codant 5′-ATG GCA TGG-3′ ?",
                back: "5′-AUG GCA UGG-3′ : l'ARNm a la séquence du brin codant, avec U à la place de T. Il se traduit en Met – Ala – Trp.",
                choices: ["5′-UAC CGU ACC-3′", "5′-AUG GCA UGG-3′", "5′-TAC CGT ACC-3′", "5′-ATG GCA TGG-3′"],
                answerIndex: 1,
                chapter: 2
            ),
            DemoCard(
                kind: .cloze,
                front: "La réplication de l'ADN est dite …, car chaque molécule fille conserve un brin de la molécule mère.",
                back: "semi-conservative",
                chapter: 1
            ),
            DemoCard(kind: .basic, front: "Quelle est la différence entre un gène et un allèle ?", back: "Un gène est un segment d'ADN, à un locus donné, qui code une protéine. Un allèle est l'une des versions de ce gène, qui diffère des autres par sa séquence.", chapter: 0),
            DemoCard(kind: .choice, front: "Combien existe-t-il de codons différents ?", back: "64 = 4³ : quatre bases possibles à chacune des trois positions. 61 codent un acide aminé, 3 sont des codons stop.", choices: ["20", "46", "61", "64"], answerIndex: 3, chapter: 2),
            DemoCard(kind: .cloze, front: "Dans l'ARN, la thymine est remplacée par l'… .", back: "uracile", chapter: 2),
            DemoCard(kind: .basic, front: "Que montre l'expérience de Meselson et Stahl ?", back: "Que la réplication est semi-conservative : après une division en milieu à ¹⁴N, tout l'ADN est de densité intermédiaire ; après deux, moitié intermédiaire, moitié léger.", hint: "Pensez aux densités après une puis deux divisions.", chapter: 1),
            DemoCard(kind: .choice, front: "Quelle mutation décale le cadre de lecture ?", back: "L'insertion ou la délétion d'une base : tous les codons situés après sont modifiés, et la protéine est très altérée.", choices: ["Une substitution silencieuse", "Une substitution faux-sens", "Une délétion d'une base", "Une substitution non-sens"], answerIndex: 2, chapter: 3),
            DemoCard(kind: .cloze, front: "Deux parents hétérozygotes Rr ont, à chaque naissance, une probabilité de … d'avoir un enfant rr.", back: "1/4", chapter: 3),
            DemoCard(kind: .basic, front: "Pourquoi l'allèle de la drépanocytose est-il fréquent là où sévit le paludisme ?", back: "Parce que les hétérozygotes, porteurs d'un seul allèle muté, sont en bonne santé et mieux protégés contre le paludisme : la sélection naturelle maintient l'allèle.", chapter: 3),
            DemoCard(kind: .cloze, front: "Selon les règles de Chargaff, dans un ADN double brin, le pourcentage de guanine est égal à celui de … .", back: "cytosine", chapter: 0),
            DemoCard(kind: .choice, front: "Où se déroule la traduction ?", back: "Dans le cytoplasme, sur les ribosomes, qui lisent l'ARN messager codon par codon.", choices: ["Dans le noyau", "Sur les ribosomes du cytoplasme", "Dans les mitochondries", "Sur la membrane plasmique"], answerIndex: 1, chapter: 2),
        ]
    )

    // MARK: Mathématiques : les probabilités

    private static let probabilityFR = OnboardingDemoCourse(
        id: "debug-probability",
        emoji: "🎲",
        subject: "Mathématiques",
        title: "Probabilités",
        summary: "Le vocabulaire des événements, les probabilités conditionnelles et les arbres, l'indépendance, puis les variables aléatoires, l'espérance et la loi binomiale.",
        accentIndex: 0,
        chapters: [
            DemoChapter(title: "Le langage des probabilités", blocks: [
                .paragraph("Les probabilités mesurent ==le degré de certitude== d'un événement dont on ne connaît pas l'issue à l'avance : un lancer de dé, un tirage, le résultat d'un test. Elles ne prédisent pas ce qui va arriver ; elles disent, avec précision, à quel point chaque issue est vraisemblable."),
                .heading("Expérience, univers, événement"),
                .paragraph("Une **expérience aléatoire** est une expérience dont on connaît tous les résultats possibles, sans pouvoir prévoir lequel se produira. Chaque résultat est une **issue** ; l'ensemble des issues est l'**univers**, noté $\\Omega$. Pour un dé à six faces, $\\Omega$ = {1, 2, 3, 4, 5, 6}."),
                .callout(
                    title: "Événement",
                    text: "Un **événement** est une partie de l'univers, c'est-à-dire un ensemble d'issues. « Obtenir un nombre pair » est l'événement $A$ = {2, 4, 6}. Il est réalisé si l'issue obtenue lui appartient.",
                    tone: .definition
                ),
                .paragraph("On combine les événements comme des ensembles. L'**intersection** $A \\cap B$ (« A et B ») est réalisée quand les deux le sont ; la **réunion** $A \\cup B$ (« A ou B ») quand au moins l'un des deux l'est ; le **contraire** $Ā$ quand $A$ ne l'est pas. Deux événements sont **incompatibles** s'ils ne peuvent pas se produire ensemble : $A \\cap B = \\emptyset$."),
                .heading("Calculer une probabilité"),
                .paragraph("Quand toutes les issues ont la même chance de se produire — on parle d'**équiprobabilité** —, la probabilité d'un événement est le nombre d'issues favorables divisé par le nombre d'issues possibles. C'est la formule de Laplace, et elle ne vaut ==que dans ce cas== : un dé truqué ou une roue inégale demandent une autre méthode."),
                .formula("P(A) = \\frac{\\text{nombre d'issues favorables}}{\\text{nombre d'issues possibles}}", caption: "En situation d'équiprobabilité seulement"),
                .paragraph("Lançons deux dés et regardons la somme. Il y a $6 \\times 6 = 36$ couples équiprobables, mais les sommes, elles, ne le sont pas : une seule façon d'obtenir 2 (1 et 1), six façons d'obtenir 7. Le graphique donne, pour chaque somme, le nombre de couples qui la produisent."),
                .bars(title: "Somme de deux dés : nombre de couples sur 36", unit: nil, bars: [
                    DemoBar(label: "2", value: 1),
                    DemoBar(label: "3", value: 2),
                    DemoBar(label: "4", value: 3),
                    DemoBar(label: "5", value: 4),
                    DemoBar(label: "6", value: 5),
                    DemoBar(label: "7", value: 6),
                    DemoBar(label: "8", value: 5),
                    DemoBar(label: "9", value: 4),
                    DemoBar(label: "10", value: 3),
                    DemoBar(label: "11", value: 2),
                    DemoBar(label: "12", value: 1),
                ]),
                .paragraph("On lit que $P(\\text{somme} = 7) = 6/36 = 1/6$, et $P(\\text{somme} = 2) = 1/36$. L'erreur classique est de raisonner sur les onze sommes possibles comme si elles étaient équiprobables, ce qui donnerait 1/11 à chacune. ==Il faut toujours compter sur des issues équiprobables==, ici les couples, et jamais sur des résultats qui ne le sont pas."),
                .table(title: "Les propriétés à connaître", headers: ["Propriété", "Formule"], rows: [
                    ["Bornes", "0 ≤ P(A) ≤ 1"],
                    ["Univers", "P(Ω) = 1"],
                    ["Contraire", "P(Ā) = 1 − P(A)"],
                    ["Réunion", "P(A ∪ B) = P(A) + P(B) − P(A ∩ B)"],
                    ["Incompatibles", "P(A ∪ B) = P(A) + P(B)"],
                ]),
                .paragraph("La formule de la réunion retire $P(A \\cap B)$ parce que les issues communes ont été comptées deux fois. Et le passage au contraire est souvent le raccourci le plus efficace : pour « au moins un six en quatre lancers », il est bien plus simple de calculer « aucun six », soit $(5/6)^4 \\approx 0{,}48$, puis de prendre le complément : $1 - 0{,}48 \\approx 0{,}52$."),
                .callout(
                    title: "Le réflexe « au moins un »",
                    text: "Dès qu'un énoncé dit « au moins un », pensez au contraire : « aucun ». C'est presque toujours un seul produit à calculer, au lieu d'une longue somme de cas.",
                    tone: .insight
                ),
            ]),
            DemoChapter(title: "Probabilités conditionnelles et arbres", blocks: [
                .paragraph("Une information nouvelle change les probabilités. Savoir qu'un test est positif change la probabilité d'être malade ; savoir que le dé est tombé sur un nombre pair change celle d'avoir fait un 2. La **probabilité conditionnelle** mesure la probabilité d'un événement ==quand on sait qu'un autre est réalisé==."),
                .callout(
                    title: "Probabilité conditionnelle",
                    text: "Si $P(A) \\neq 0$, la probabilité de $B$ sachant $A$ est $P(B | A) = \\frac{P(A \\cap B)}{P(A)}$, que les manuels notent aussi P_A(B). On restreint l'univers aux seules issues de $A$, et on regarde quelle part d'entre elles réalise aussi $B$.",
                    tone: .definition
                ),
                .paragraph("Exemple : on lance un dé, et on apprend que le résultat est pair. La probabilité que ce soit un 2 n'est plus 1/6, mais $\\frac{1/6}{1/2} = \\frac{1}{3}$ : il ne reste que trois issues possibles, 2, 4 et 6. La formule se retourne aussi, et c'est la forme qu'on utilise sur les arbres : $P(A \\cap B) = P(A) \\times P(B | A)$."),
                .heading("L'arbre pondéré"),
                .paragraph("Un **arbre pondéré** représente une expérience en plusieurs étapes. Chaque branche porte une probabilité ; les branches issues d'un même nœud ont une somme égale à 1 ; la probabilité d'un chemin est le produit des probabilités de ses branches. Et quand un événement est au bout de plusieurs chemins, on additionne."),
                .figure(.flow(title: "Lire un arbre pondéré", steps: ["Première étape : A ou Ā", "Deuxième étape : B ou B̄, sachant la première", "Un chemin : on multiplie les branches", "Plusieurs chemins vers B : on additionne"])),
                .paragraph("La dernière étape a un nom : la **formule des probabilités totales**. Si $A$ et $Ā$ partagent l'univers en deux, alors $B$ se réalise soit avec $A$, soit avec $Ā$, et ces deux cas sont incompatibles. On additionne donc les deux chemins qui mènent à $B$."),
                .formula("P(B) = P(A) \\times P(B | A) + P(Ā) \\times P(B | Ā)", caption: "La formule des probabilités totales, pour une partition en A et Ā"),
                .heading("Un test de dépistage"),
                .paragraph("Une maladie touche 1 % de la population. Un test la détecte chez 99 % des malades, mais il est aussi positif chez 2 % des personnes saines. Une personne est testée positive : quelle est la probabilité qu'elle soit malade ? L'intuition répond « 99 % ». Le calcul répond tout autre chose. Imaginons 10 000 personnes testées."),
                .table(title: "10 000 personnes testées", headers: ["", "Test positif", "Test négatif", "Total"], rows: [
                    ["Malades", "99", "1", "100"],
                    ["Saines", "198", "9 702", "9 900"],
                    ["Total", "297", "9 703", "10 000"],
                ]),
                .paragraph("Parmi les 297 positifs, seuls 99 sont malades. Avec l'arbre et les formules : $P(+) = 0{,}01 \\times 0{,}99 + 0{,}99 \\times 0{,}02 = 0{,}0297$, puis $P(M | +) = \\frac{0{,}0099}{0{,}0297} = \\frac{1}{3}$. Les faux positifs, pris sur une population saine cent fois plus nombreuse, ==noient les vrais positifs==."),
                .keyFigure(value: "33 %", label: "la probabilité d'être malade quand le test est positif, malgré un test fiable à 99 % chez les malades"),
                .paragraph("Le résultat dépend moins de la qualité du test que de la rareté de la maladie. Si elle touchait 10 % de la population, le même test donnerait $P(M | +) = \\frac{0{,}099}{0{,}099 + 0{,}018} \\approx 0{,}85$. Une probabilité conditionnelle se calcule toujours ==avec la probabilité de départ== : oublier la prévalence, c'est oublier la première branche de l'arbre."),
                .callout(
                    title: "Ne pas inverser",
                    text: "$P(+ | M)$ et $P(M | +)$ ne sont pas la même chose : la première vaut 0,99, la seconde environ 0,33. Confondre « la probabilité d'un test positif sachant qu'on est malade » et « la probabilité d'être malade sachant que le test est positif » est l'erreur la plus répandue, y compris chez les médecins.",
                    tone: .warning
                ),
                .paragraph("C'est pour cette raison qu'un test positif lors d'un dépistage de masse est toujours confirmé par un second examen, plus précis. Le calcul d'une probabilité « inversée » à partir de l'arbre porte le nom de **formule de Bayes**, du nom du pasteur anglais qui l'a énoncée au XVIIIe siècle."),
            ]),
            DemoChapter(title: "L'indépendance", blocks: [
                .paragraph("Deux événements sont indépendants quand savoir que l'un est réalisé ==ne change rien== à la probabilité de l'autre. Le résultat d'une pièce ne dépend pas de celui de la pièce d'avant ; la couleur des yeux ne dépend pas du jour de naissance."),
                .formula("A \\text{ et } B \\text{ indépendants} \\Leftrightarrow P(A \\cap B) = P(A) \\times P(B)", caption: "La définition, équivalente à P(B | A) = P(B) quand P(A) ≠ 0"),
                .paragraph("On vérifie l'indépendance par le calcul, jamais à l'intuition. Lançons un dé : soit $A$ = « pair » = {2, 4, 6} et $B$ = « au plus 2 » = {1, 2}. On a $P(A) = 1/2$, $P(B) = 1/3$, et $A \\cap B$ = {2}, donc $P(A \\cap B) = 1/6$. Comme $\\frac{1}{2} \\times \\frac{1}{3} = \\frac{1}{6}$, les deux événements sont indépendants — ce qui ne se voyait pas à l'œil nu."),
                .figure(.split(
                    title: "Deux notions à ne pas confondre",
                    left: DemoColumn(title: "Incompatibles", items: ["Ne peuvent pas arriver ensemble", "A ∩ B = ∅", "P(A ∩ B) = 0", "Notion ensembliste"]),
                    right: DemoColumn(title: "Indépendants", items: ["L'un n'informe pas sur l'autre", "P(A ∩ B) = P(A) × P(B)", "Se vérifie par le calcul", "Notion probabiliste"])
                )),
                .paragraph("Les deux notions sont même presque opposées : si $A$ et $B$ sont incompatibles et de probabilités non nulles, savoir que $A$ est réalisé dit avec certitude que $B$ ne l'est pas. Ils sont donc ==très dépendants==. Un tirage « pile » et un tirage « face » du même lancer sont incompatibles ; « pile » au premier lancer et « face » au second sont indépendants."),
                .heading("Répéter une expérience"),
                .paragraph("Quand on répète une expérience dans les mêmes conditions — lancer plusieurs fois une pièce, tirer avec remise —, les résultats successifs sont indépendants, et la probabilité d'une suite de résultats est le produit des probabilités de chacun. Obtenir trois fois « pile » avec une pièce équilibrée : $\\left(\\frac{1}{2}\\right)^3 = \\frac{1}{8}$."),
                .callout(
                    title: "Le sophisme du joueur",
                    text: "Après dix « rouge » d'affilée à la roulette, le « noir » n'est pas « dû » : les tirages sont indépendants, la roue n'a pas de mémoire, et la probabilité du noir au coup suivant est exactement la même qu'au premier coup.",
                    tone: .warning
                ),
                .paragraph("C'est pourtant ce qui, à long terme, donne raison à l'intuition des fréquences. La **loi des grands nombres**, démontrée par Jacques Bernoulli en 1713, affirme que sur un très grand nombre de répétitions indépendantes, la fréquence d'un événement se rapproche de sa probabilité. Non parce que les écarts se « rattrapent », mais parce qu'ils deviennent négligeables devant le nombre total d'essais."),
                .timeline(title: "Une brève histoire des probabilités", events: [
                    DemoEvent(date: "1654", label: "Pascal et Fermat résolvent le problème des partis"),
                    DemoEvent(date: "1713", label: "Jacques Bernoulli : la loi des grands nombres"),
                    DemoEvent(date: "1763", label: "Publication posthume de la formule de Bayes"),
                    DemoEvent(date: "1812", label: "Laplace, Théorie analytique des probabilités"),
                    DemoEvent(date: "1933", label: "Kolmogorov fonde les probabilités sur des axiomes"),
                ]),
                .paragraph("La discipline est née d'une question de joueurs : comment partager équitablement les mises d'une partie interrompue ? Trois siècles plus tard, elle sert à évaluer un médicament, à fixer une prime d'assurance, à transmettre un signal sans erreur. La méthode, elle, n'a pas changé : ==dénombrer, conditionner, multiplier, additionner==."),
            ]),
            DemoChapter(title: "Variables aléatoires et loi binomiale", blocks: [
                .paragraph("Souvent, ce qui intéresse n'est pas l'issue elle-même, mais un nombre qui en dépend : le gain d'un jeu, le nombre de bonnes réponses, le nombre de pièces défectueuses. Une **variable aléatoire** associe un nombre réel à chaque issue, et sa **loi** donne la probabilité de chacune de ses valeurs."),
                .heading("L'espérance"),
                .paragraph("Un jeu : on mise 2 €, on lance un dé, et on reçoit 10 € si l'on obtient un 6. Soit $X$ le gain net. Si le 6 sort, $X = 10 - 2 = 8$ ; sinon, $X = -2$. La loi de $X$ tient dans un tableau de deux colonnes."),
                .table(title: "Loi du gain net X", headers: ["Valeur de X", "−2 €", "8 €"], rows: [
                    ["Probabilité", "5/6", "1/6"],
                ]),
                .paragraph("L'**espérance** est la moyenne des valeurs pondérée par leurs probabilités : c'est le gain moyen par partie si l'on jouait un très grand nombre de fois. Ici $E(X) = -2 \\times \\frac{5}{6} + 8 \\times \\frac{1}{6} = \\frac{-10 + 8}{6} = -\\frac{1}{3}$. Le joueur perd en moyenne environ 33 centimes par partie : le jeu est ==défavorable==."),
                .formula("E(X) = \\sum_{i} x_i \\, P(X = x_i) \\;\\;\\;\\; V(X) = \\sum_{i} P(X = x_i)\\,(x_i - E(X))^2", caption: "L'espérance mesure le centre, la variance la dispersion autour de lui"),
                .paragraph("La **variance** mesure à quel point les valeurs s'écartent de l'espérance, et l'**écart-type** $\\sigma(X) = \\sqrt{V(X)}$ ramène cette mesure dans l'unité de $X$. Deux jeux de même espérance peuvent être très différents : l'un rapporte presque toujours la même petite somme, l'autre rien la plupart du temps et beaucoup rarement."),
                .heading("La loi binomiale"),
                .callout(
                    title: "Schéma de Bernoulli",
                    text: "On répète $n$ fois, de façon **indépendante**, une épreuve à deux issues : succès, de probabilité $p$, ou échec. Le nombre $X$ de succès suit la **loi binomiale** $B(n, p)$.",
                    tone: .definition
                ),
                .formula("P(X = k) = \\binom{n}{k}\\, p^k \\,(1-p)^{n-k}", caption: "Le coefficient binomial compte les chemins de l'arbre qui mènent à k succès"),
                .paragraph("La formule se lit sur l'arbre : chaque chemin avec $k$ succès et $n - k$ échecs a la probabilité $p^k (1-p)^{n-k}$, et le nombre de ces chemins est le coefficient binomial « $k$ parmi $n$ ». Exemple : un QCM de 10 questions à 4 choix, rempli entièrement au hasard. Le nombre de bonnes réponses suit $B(10\\,;\\,0{,}25)$, dont voici la loi."),
                .bars(title: "Loi de B(10 ; 0,25) : probabilité d'avoir k bonnes réponses", unit: "%", bars: [
                    DemoBar(label: "k = 0", value: 5.6),
                    DemoBar(label: "k = 1", value: 18.8),
                    DemoBar(label: "k = 2", value: 28.2),
                    DemoBar(label: "k = 3", value: 25.0),
                    DemoBar(label: "k = 4", value: 14.6),
                    DemoBar(label: "k = 5", value: 5.8),
                    DemoBar(label: "k = 6", value: 1.6),
                    DemoBar(label: "k = 7", value: 0.3),
                ]),
                .paragraph("La loi culmine autour de 2 ou 3 bonnes réponses, et s'effondre au-delà. Obtenir la moyenne, 5 sur 10, en répondant au hasard n'arrive qu'avec une probabilité d'environ ==7,8 %== ; ne rien avoir juste, $0{,}75^{10} \\approx 5{,}6\\,\\%$. Pour une loi binomiale, espérance et variance ont des formules directes."),
                .formula("E(X) = np \\;\\;\\;\\; V(X) = np(1-p)", caption: "Ici : E(X) = 10 × 0,25 = 2,5 et V(X) = 2,5 × 0,75 = 1,875"),
                .keyFigure(value: "2,5", label: "bonnes réponses en moyenne sur 10 questions à quatre choix, en répondant au hasard"),
                .paragraph("L'écart-type vaut $\\sqrt{1{,}875} \\approx 1{,}37$ : la plupart des candidats qui répondent au hasard obtiennent entre 1 et 4 bonnes réponses. C'est exactement ce que montrait le graphique, et c'est pourquoi certains QCM retirent des points pour chaque mauvaise réponse — de quoi ramener à zéro l'espérance du hasard."),
                .callout(
                    title: "Méthode : justifier une loi binomiale",
                    text: "Trois points à écrire, à chaque fois : 1. une épreuve à **deux issues** (succès de probabilité $p$) ; 2. répétée $n$ fois de façon **identique et indépendante** ; 3. $X$ compte le **nombre de succès**. Sans ces trois phrases, la réponse est incomplète.",
                    tone: .insight
                ),
                .paragraph("Le deuxième point est celui qu'on oublie : un tirage **sans remise** dans une petite urne n'est pas une répétition indépendante, et la loi binomiale ne s'applique pas. Vérifier les hypothèses avant d'appliquer la formule, c'est ==toute la différence== entre un calcul juste et un calcul qui a seulement l'air juste."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Comment calcule-t-on la probabilité d'un événement au bout de plusieurs chemins d'un arbre pondéré ?",
                back: "On multiplie les probabilités le long de chaque chemin, puis on additionne les résultats des chemins qui mènent à l'événement : c'est la formule des probabilités totales.",
                figure: .flow(title: "Lire un arbre", steps: ["Multiplier le long d'un chemin", "Additionner les chemins"]),
                chapter: 1
            ),
            DemoCard(
                kind: .choice,
                front: "On lance deux dés équilibrés. Quelle est la probabilité que la somme vaille 7 ?",
                back: "1/6 : six couples sur 36 donnent 7 — (1,6), (2,5), (3,4), (4,3), (5,2), (6,1).",
                choices: ["1/11", "1/12", "1/6", "7/36"],
                answerIndex: 2,
                chapter: 0
            ),
            DemoCard(
                kind: .cloze,
                front: "Deux événements A et B sont indépendants si et seulement si $P(A \\cap B) = $ … .",
                back: "$P(A) \\times P(B)$",
                chapter: 2
            ),
            DemoCard(kind: .basic, front: "Quelle est la formule de la probabilité de B sachant A ?", back: "$P(B | A) = \\frac{P(A \\cap B)}{P(A)}$, pour $P(A) \\neq 0$.", chapter: 1),
            DemoCard(kind: .choice, front: "Une maladie touche 1 % de la population ; un test est positif chez 99 % des malades et chez 2 % des personnes saines. Quelle est la probabilité d'être malade si le test est positif ?", back: "Environ 1/3 : $\\frac{0{,}01 \\times 0{,}99}{0{,}01 \\times 0{,}99 + 0{,}99 \\times 0{,}02} = \\frac{0{,}0099}{0{,}0297}$.", hint: "Imaginez 10 000 personnes testées.", choices: ["99 %", "98 %", "Environ 33 %", "1 %"], answerIndex: 2, chapter: 1),
            DemoCard(kind: .cloze, front: "La probabilité de l'événement contraire vaut $P(Ā) = $ … .", back: "$1 - P(A)$", chapter: 0),
            DemoCard(kind: .basic, front: "Quelle est la différence entre deux événements incompatibles et deux événements indépendants ?", back: "Incompatibles : ils ne peuvent pas se produire ensemble ($A \\cap B = \\emptyset$). Indépendants : la réalisation de l'un ne change pas la probabilité de l'autre ($P(A \\cap B) = P(A)P(B)$). Deux événements incompatibles de probabilités non nulles ne sont jamais indépendants.", chapter: 2),
            DemoCard(kind: .choice, front: "Quelle est l'espérance d'une variable aléatoire qui suit la loi binomiale $B(n, p)$ ?", back: "$E(X) = np$. Sa variance vaut $np(1-p)$.", choices: ["$p$", "$np$", "$np(1-p)$", "$n/p$"], answerIndex: 1, chapter: 3),
            DemoCard(kind: .basic, front: "Quelles conditions faut-il vérifier pour affirmer qu'une variable suit une loi binomiale ?", back: "Une épreuve à deux issues (succès de probabilité p), répétée n fois de façon identique et indépendante, et une variable X qui compte le nombre de succès.", chapter: 3),
            DemoCard(kind: .cloze, front: "Pour calculer la probabilité d'obtenir « au moins un » succès, on passe par l'événement contraire : « … ».", back: "aucun", chapter: 0),
            DemoCard(kind: .choice, front: "On mise 2 € et on reçoit 10 € si le dé donne 6. Quelle est l'espérance du gain net ?", back: "$-2 \\times \\frac{5}{6} + 8 \\times \\frac{1}{6} = -\\frac{1}{3}$, soit une perte moyenne d'environ 0,33 € par partie.", choices: ["$-\\frac{1}{3}$ €", "0 €", "$\\frac{1}{3}$ €", "$\\frac{5}{3}$ €"], answerIndex: 0, chapter: 3),
            DemoCard(kind: .cloze, front: "La loi des … énonce que la fréquence d'un événement se rapproche de sa probabilité quand le nombre de répétitions devient très grand.", back: "grands nombres", chapter: 2),
        ]
    )
}
#endif
