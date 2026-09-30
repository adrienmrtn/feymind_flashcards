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

    // MARK: Économie : l'offre et la demande

    private static let supplyDemandFR = OnboardingDemoCourse(
        id: "debug-supply-demand",
        emoji: "⚖️",
        subject: "Économie",
        title: "L'offre et la demande",
        summary: "Comment un marché fixe un prix : les courbes d'offre et de demande, l'équilibre, ce qui le déplace, l'élasticité, et ce que change l'intervention de l'État.",
        accentIndex: 5,
        chapters: [
            DemoChapter(title: "Le marché et la demande", blocks: [
                .paragraph("Pourquoi une fraise coûte-t-elle trois fois plus cher en mars qu'en juin ? Personne n'a décidé ce prix : il résulte de la rencontre de millions de décisions d'achat et de vente. Le modèle de l'offre et de la demande explique ==comment un marché fixe un prix== sans que personne ne le fixe."),
                .heading("Qu'est-ce qu'un marché ?"),
                .callout(
                    title: "Marché",
                    text: "Le lieu, physique ou non, où se rencontrent l'**offre** (ce que les vendeurs proposent) et la **demande** (ce que les acheteurs souhaitent acquérir) d'un bien ou d'un service, et où se forme son **prix**.",
                    tone: .definition
                ),
                .paragraph("Un marché n'est pas forcément un lieu : le marché du travail, le marché des changes ou le marché de l'immobilier n'ont pas de halle. Pour raisonner, les économistes partent d'un cas idéal, la **concurrence pure et parfaite**, où aucun acteur n'a assez de poids pour imposer son prix. Il repose sur cinq conditions."),
                .list([
                    "Atomicité : beaucoup d'acheteurs et de vendeurs, chacun trop petit pour influencer le prix",
                    "Homogénéité : tous les vendeurs proposent le même produit",
                    "Transparence : tout le monde connaît les prix et la qualité",
                    "Libre entrée : n'importe qui peut entrer sur le marché ou en sortir",
                    "Libre circulation des facteurs de production : travail et capital vont où ils rapportent le plus",
                ]),
                .paragraph("Aucun marché réel ne remplit parfaitement ces cinq conditions, et ce n'est pas le but : le modèle sert de ==point de comparaison==. Un marché de produits agricoles en gros s'en approche ; un marché dominé par trois opérateurs téléphoniques s'en éloigne, et c'est précisément ce qu'on mesure en le comparant au modèle."),
                .heading("La demande"),
                .paragraph("La **demande** est la quantité d'un bien que les acheteurs souhaitent acquérir à chaque prix possible. Elle obéit à une loi presque universelle : quand le prix monte, la quantité demandée baisse. Deux raisons à cela. L'**effet de substitution** : le bien devient plus cher que ses concurrents, on se reporte sur eux. L'**effet revenu** : à budget égal, on peut en acheter moins."),
                .formula("Q_d = 120 - 20\\,p", caption: "Une demande linéaire : quantité demandée (en milliers) en fonction du prix p (en euros)"),
                .paragraph("Cette fonction servira d'exemple tout au long du cours : imaginez le marché hebdomadaire d'un fromage dans une région, en milliers de pièces. À 1 €, les acheteurs en veulent 100 000 ; à 5 €, seulement 20 000. Chaque euro de plus fait renoncer 20 000 acheteurs. Représentée avec le prix en ordonnée, c'est une droite **décroissante** : la courbe de demande."),
                .callout(
                    title: "Le piège du vocabulaire",
                    text: "Quand le prix d'un bien change, on se **déplace le long** de sa courbe de demande : c'est la *quantité demandée* qui varie. Quand autre chose change — le revenu, les goûts, le prix d'un autre bien —, c'est **la courbe entière qui se déplace** : c'est la *demande* qui varie.",
                    tone: .warning
                ),
                .paragraph("Cette distinction est la source de la plupart des erreurs en exercice. « La demande baisse parce que le prix monte » est faux : c'est la quantité demandée qui baisse. La demande, elle, baisse quand les revenus diminuent, quand un produit concurrent devient moins cher, ou quand une étude révèle un danger pour la santé."),
                .timeline(title: "Les pères du modèle", events: [
                    DemoEvent(date: "1776", label: "Adam Smith, La Richesse des nations : la « main invisible »"),
                    DemoEvent(date: "1838", label: "Antoine-Augustin Cournot trace la première courbe de demande"),
                    DemoEvent(date: "1874", label: "Léon Walras, la théorie de l'équilibre général"),
                    DemoEvent(date: "1890", label: "Alfred Marshall croise l'offre et la demande"),
                ]),
                .paragraph("Marshall comparait l'offre et la demande aux deux lames d'une paire de ciseaux : se demander laquelle coupe le papier n'a pas de sens, et se demander si c'est l'offre ou la demande qui fixe le prix non plus. C'est ==leur rencontre== qui le détermine, et c'est l'objet du chapitre suivant."),
            ]),
            DemoChapter(title: "L'offre et l'équilibre", blocks: [
                .paragraph("Face aux acheteurs, les producteurs. L'**offre** est la quantité qu'ils sont prêts à vendre à chaque prix possible, et elle obéit à la loi inverse de la demande : plus le prix est élevé, plus ils veulent vendre. Un prix plus haut rend rentable de produire davantage, et attire de nouveaux producteurs."),
                .heading("La courbe d'offre"),
                .paragraph("Pourquoi faut-il un prix plus élevé pour produire plus ? Parce que produire chaque unité supplémentaire coûte de plus en plus cher à court terme : heures supplémentaires, machines poussées au-delà de leur régime, matières premières plus difficiles à obtenir. Le producteur n'accepte de produire une unité de plus que si le prix couvre ce **coût marginal** croissant."),
                .formula("Q_s = 20\\,p", caption: "L'offre du même marché : quantité offerte (en milliers) en fonction du prix p"),
                .paragraph("À court terme, l'offre finit même par buter sur un mur : la capacité de production. Une fromagerie ne peut pas produire plus que ce que ses cuves et son lait permettent, quel que soit le prix. La quantité offerte monte d'abord vite avec le prix, puis de moins en moins, jusqu'à un plafond."),
                .figure(.plot(title: "L'offre à court terme plafonne", caption: "En abscisse le prix, en ordonnée la quantité offerte : elle augmente avec le prix, puis bute sur la capacité de production.", kind: .saturation)),
                .paragraph("C'est pourquoi une hausse soudaine de la demande fait d'abord monter les prix plus que les quantités : les producteurs ne peuvent pas suivre tout de suite. À long terme, ils investissent, de nouveaux producteurs arrivent, et le plafond se relève. Dans notre exemple, on reste dans la zone où l'offre est une droite."),
                .heading("L'équilibre"),
                .paragraph("Mettons les deux côtés du marché face à face. Pour chaque prix, on compare la quantité que les acheteurs veulent et celle que les vendeurs proposent. Le tableau se lit ligne par ligne, et une seule ligne fait coïncider les deux."),
                .table(title: "Le marché du fromage, prix par prix", headers: ["Prix", "Demande (milliers)", "Offre (milliers)", "Situation"], rows: [
                    ["1 €", "100", "20", "Pénurie de 80"],
                    ["2 €", "80", "40", "Pénurie de 40"],
                    ["3 €", "60", "60", "Équilibre"],
                    ["4 €", "40", "80", "Excédent de 40"],
                    ["5 €", "20", "100", "Excédent de 80"],
                ]),
                .paragraph("Le **prix d'équilibre** est celui pour lequel la quantité offerte égale la quantité demandée. Graphiquement, c'est le point d'intersection des deux courbes ; algébriquement, c'est la solution d'une équation du premier degré."),
                .formula("120 - 20\\,p = 20\\,p \\;\\Rightarrow\\; p^* = 3 \\text{ €} \\;\\text{ et }\\; Q^* = 60", caption: "L'équilibre : l'offre égale la demande"),
                .paragraph("Au prix de 3 €, 60 000 fromages sont vendus chaque semaine, et chacun y trouve son compte : tous les acheteurs prêts à payer 3 € sont servis, tous les vendeurs prêts à vendre à 3 € ont écoulé leur production. Il n'y a ==ni file d'attente ni invendus==."),
                .keyFigure(value: "3 €", label: "le prix d'équilibre, le seul auquel 60 000 fromages trouvent à la fois un vendeur et un acheteur"),
                .paragraph("Ce prix n'est pas seulement un point sur un graphique : c'est celui vers lequel le marché revient tout seul. Si le prix est trop bas, les acheteurs se disputent une marchandise rare et le font monter ; s'il est trop haut, les vendeurs se retrouvent avec des invendus et le baissent. Le mécanisme se lit en quatre temps."),
                .figure(.flow(title: "Le retour à l'équilibre, depuis un prix trop bas", steps: ["Prix à 2 € : pénurie de 40 000", "Les acheteurs surenchérissent, le prix monte", "La quantité demandée baisse, l'offre augmente", "La pénurie se résorbe à 3 €"])),
                .paragraph("Le mécanisme est symétrique depuis un prix trop haut : à 4 €, les vendeurs ont 40 000 pièces d'invendus, ils baissent leurs prix pour les écouler, et le marché redescend vers 3 €. Dans les deux cas, ce sont les écarts entre offre et demande qui font bouger le prix, et c'est leur disparition qui l'arrête."),
                .callout(
                    title: "La main invisible",
                    text: "L'expression d'Adam Smith désigne ce mécanisme : chacun poursuit son intérêt — l'acheteur payer moins, le vendeur gagner plus —, et le prix s'ajuste jusqu'à coordonner leurs décisions, **sans qu'aucun planificateur n'intervienne**. Le prix est un signal : il dit aux producteurs quoi produire et aux consommateurs quoi économiser.",
                    tone: .insight
                ),
                .paragraph("Le mécanisme a une conséquence qui surprend : ==une pénurie est un symptôme de prix trop bas==, pas de production trop faible. C'est ce qu'on observe chaque fois qu'un prix est bloqué en dessous de l'équilibre, et c'est ce que le dernier chapitre étudiera."),
            ]),
            DemoChapter(title: "Quand l'équilibre se déplace", blocks: [
                .paragraph("L'équilibre ne dure que tant que rien ne change. Mais tout change : les revenus, les goûts, les coûts, la météo. Chaque fois, l'une des courbes se déplace, et le marché trouve ==un nouvel équilibre==, avec un autre prix et une autre quantité."),
                .figure(.split(
                    title: "Ce qui déplace les courbes",
                    left: DemoColumn(title: "La demande", items: ["Revenu des ménages", "Prix des biens substituables", "Prix des biens complémentaires", "Goûts, modes, informations", "Taille de la population"]),
                    right: DemoColumn(title: "L'offre", items: ["Coût des matières premières", "Salaires, énergie", "Progrès technique", "Nombre de producteurs", "Météo, taxes, subventions"])
                )),
                .paragraph("La méthode d'analyse est toujours la même, en trois questions : quelle courbe se déplace ? Dans quel sens ? Que deviennent le prix et la quantité d'équilibre ? Si la demande augmente, le prix et la quantité montent tous les deux. Si l'offre diminue, le prix monte mais la quantité baisse."),
                .callout(
                    title: "Un gel au Brésil",
                    text: "Le Brésil produit plus du tiers du café mondial. Quand un gel détruit une partie de la récolte, l'**offre** de café diminue : sa courbe se déplace vers la gauche. Au nouvel équilibre, le prix du café monte et la quantité échangée baisse — sans que la demande ait bougé.",
                    tone: .example
                ),
                .paragraph("Certains marchés ne retrouvent pas leur équilibre en douceur. Quand la production demande du temps — élever des porcs, planter des vergers —, les producteurs décident de ce qu'ils vendront demain en regardant le prix d'aujourd'hui. Un prix élevé les pousse tous à produire plus ; la production arrive en même temps, le prix s'effondre, et ils réduisent tous leur production. C'est le **cycle du porc**, décrit dès les années 1930."),
                .figure(.cycle(title: "Le cycle du porc", nodes: ["Prix élevé", "Les éleveurs produisent plus", "Surproduction : le prix chute", "Les éleveurs produisent moins"])),
                .paragraph("Ce cycle est une limite du modèle simple : il suppose que les quantités s'ajustent instantanément. Il explique aussi pourquoi les prix agricoles sont si instables, et pourquoi tant de pays ont mis en place des politiques pour les stabiliser, comme la **politique agricole commune** européenne à partir de 1962."),
                .heading("L'élasticité-prix"),
                .paragraph("Toutes les demandes ne réagissent pas de la même façon au prix. Une hausse de 10 % du prix de l'essence fait à peine baisser les achats à court terme : il faut bien aller travailler. La même hausse sur un voyage de loisir peut en faire renoncer beaucoup. L'**élasticité-prix** mesure cette sensibilité."),
                .formula("e = \\frac{\\Delta Q / Q}{\\Delta p / p}", caption: "La variation relative de la quantité demandée, divisée par la variation relative du prix : presque toujours négative"),
                .paragraph("Si le prix monte de 10 % et que la quantité baisse de 5 %, $e = -5 / 10 = -0{,}5$ : la demande est **inélastique**, car $|e| < 1$. Si la quantité baisse de 20 %, $e = -2$ : la demande est **élastique**, car $|e| > 1$. Et cela change tout pour le vendeur, parce que sa **recette** est le prix multiplié par la quantité vendue."),
                .bars(title: "Recette totale des vendeurs selon le prix (milliers d'euros)", unit: "k€", bars: [
                    DemoBar(label: "1 €", value: 100),
                    DemoBar(label: "2 €", value: 160),
                    DemoBar(label: "3 €", value: 180),
                    DemoBar(label: "4 €", value: 160),
                    DemoBar(label: "5 €", value: 100),
                ]),
                .paragraph("Le graphique montre la recette $R = p \\times Q_d$ sur notre marché. Elle monte jusqu'à 3 €, puis redescend. Ce n'est pas un hasard : le long d'une demande linéaire, l'élasticité change à chaque point, et la recette est maximale exactement ==là où l'élasticité vaut −1==."),
                .table(title: "L'élasticité le long de la demande Q = 120 − 20p", headers: ["Prix", "Quantité", "Élasticité", "Si le prix monte, la recette…"], rows: [
                    ["1 €", "100", "−0,2", "augmente"],
                    ["2 €", "80", "−0,5", "augmente"],
                    ["3 €", "60", "−1", "est maximale"],
                    ["4 €", "40", "−2", "diminue"],
                    ["5 €", "20", "−5", "diminue"],
                ]),
                .paragraph("La règle est générale : quand la demande est inélastique, une hausse de prix augmente la recette, car la quantité baisse proportionnellement moins que le prix n'augmente. C'est pourquoi l'État taxe volontiers le tabac et les carburants, dont la demande est peu élastique à court terme : la taxe rapporte, et les ventes ne s'effondrent pas."),
            ]),
            DemoChapter(title: "L'État et le marché", blocks: [
                .paragraph("Le prix d'équilibre n'est pas toujours jugé acceptable : trop élevé pour les locataires, trop bas pour les agriculteurs ou les salariés. L'État intervient alors, en fixant un prix, en taxant, en subventionnant. Le modèle permet de prévoir ==les effets de ces interventions==, y compris ceux qu'on ne souhaitait pas."),
                .heading("Prix plafond, prix plancher"),
                .callout(
                    title: "Prix plafond et prix plancher",
                    text: "Un **prix plafond** est un prix maximal fixé par l'État, en dessous de l'équilibre, pour protéger les acheteurs (encadrement des loyers). Un **prix plancher** est un prix minimal, au-dessus de l'équilibre, pour protéger les vendeurs (salaire minimum, prix garantis agricoles).",
                    tone: .definition
                ),
                .paragraph("Reprenons notre marché. Un plafond à 2 € rend le fromage moins cher pour ceux qui en trouvent, mais la demande monte à 80 000 et l'offre tombe à 40 000 : ==une pénurie de 40 000== s'installe, avec des files d'attente et un marché noir. Un plancher à 4 € garantit un bon prix aux producteurs, mais ils offrent 80 000 pièces quand les acheteurs n'en veulent que 40 000 : un excédent de 40 000, qu'il faut stocker, détruire ou exporter."),
                .table(title: "Les instruments de l'État", headers: ["Instrument", "Exemple", "Effet attendu", "Effet pervers possible"], rows: [
                    ["Prix plafond", "Encadrement des loyers", "Des prix plus bas", "Pénurie, logements retirés du marché"],
                    ["Prix plancher", "Salaire minimum", "Des revenus plus élevés", "Excédent d'offre : chômage si le plancher est trop haut"],
                    ["Taxe", "Taxe sur le tabac", "Moins de consommation, des recettes", "Contrebande"],
                    ["Subvention", "Bonus écologique", "Plus d'achats du bien aidé", "Coût pour les finances publiques"],
                ]),
                .paragraph("La dernière colonne n'est pas un réquisitoire : ces effets dépendent de l'écart entre le prix fixé et l'équilibre, et de l'élasticité des courbes. Un salaire minimum modéré peut avoir un effet très faible sur l'emploi ; un encadrement strict et durable des loyers réduit presque toujours l'offre de logements à louer. Le modèle ne dit pas s'il faut intervenir : il dit ==ce que coûte l'intervention==."),
                .heading("Qui paie une taxe ?"),
                .paragraph("L'État impose une taxe de 1 € par fromage, versée par les vendeurs. Pour vendre une pièce, un producteur exige désormais 1 € de plus qu'avant : s'il reçoit $p$ des acheteurs, il ne garde que $p - 1$. Son offre devient $Q_s = 20(p - 1)$, et l'équilibre se déplace."),
                .formula("120 - 20\\,p = 20\\,(p - 1) \\;\\Rightarrow\\; p = 3{,}5 \\text{ €} \\;\\text{ et }\\; Q = 50", caption: "Le nouvel équilibre, avec une taxe de 1 € par unité"),
                .paragraph("Les acheteurs paient maintenant 3,50 € au lieu de 3 € : ils supportent 50 centimes de la taxe. Les vendeurs reçoivent 3,50 € mais en reversent 1 € à l'État : il leur reste 2,50 € au lieu de 3 €, soit 50 centimes de perte. La taxe est partagée ==moitié-moitié==, parce que les deux courbes ont ici la même pente. L'État encaisse $1 \\times 50\\,000 = 50\\,000$ € par semaine."),
                .callout(
                    title: "Verser n'est pas payer",
                    text: "Le vendeur **verse** la taxe à l'État, mais c'est l'élasticité des courbes qui décide qui la **supporte**. Le côté du marché le moins élastique — celui qui ne peut pas se dérober — en paie la plus grande part. Pour le tabac, dont la demande est peu élastique, ce sont surtout les fumeurs.",
                    tone: .warning
                ),
                .paragraph("La taxe a aussi un coût caché. À l'équilibre, le **surplus du consommateur** — ce que les acheteurs étaient prêts à payer au-delà du prix — et le **surplus du producteur** — ce que les vendeurs reçoivent au-delà de leur coût — valaient chacun 90 000 €, soit 180 000 € au total. Après la taxe, ce total se répartit autrement, et une partie disparaît."),
                .bars(title: "Le surplus de 180 000 € après la taxe (milliers d'euros)", unit: "k€", bars: [
                    DemoBar(label: "Consommateurs", value: 62.5),
                    DemoBar(label: "Producteurs", value: 62.5),
                    DemoBar(label: "État (recette fiscale)", value: 50),
                    DemoBar(label: "Perte sèche", value: 5),
                ]),
                .paragraph("La **perte sèche** — 5 000 € par semaine — correspond aux 10 000 fromages qui ne sont plus échangés alors qu'un acheteur et un vendeur y auraient trouvé leur compte. Elle ne profite à personne. C'est le coût d'efficacité de la taxe, et il est d'autant plus grand que les courbes sont élastiques."),
                .list([
                    "Prix plafond sous l'équilibre : pénurie",
                    "Prix plancher au-dessus de l'équilibre : excédent",
                    "Taxe : prix payé en hausse, prix reçu en baisse, quantité en baisse, perte sèche",
                    "Partage de la taxe : le côté le moins élastique en supporte la plus grande part",
                ]),
                .paragraph("Ces quatre résultats valent pour n'importe quel marché, du pétrole au travail en passant par les logements. Ils ne disent pas qu'une intervention est bonne ou mauvaise — l'État peut vouloir réduire la consommation de tabac, ou garantir un revenu —, mais ils obligent à ==en chiffrer les effets==, ce qui est le premier travail de l'économiste."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Que se passe-t-il sur un marché quand le prix est inférieur au prix d'équilibre ?",
                back: "La quantité demandée dépasse la quantité offerte : il y a pénurie. Les acheteurs surenchérissent, le prix monte, la quantité demandée baisse et l'offre augmente jusqu'au retour à l'équilibre.",
                figure: .flow(title: "Retour à l'équilibre", steps: ["Prix trop bas", "Pénurie", "Le prix monte", "Équilibre"]),
                chapter: 1
            ),
            DemoCard(
                kind: .choice,
                front: "Un gel détruit une partie de la récolte de café. Que deviennent le prix et la quantité d'équilibre ?",
                back: "L'offre diminue (sa courbe se déplace vers la gauche) : le prix d'équilibre monte et la quantité échangée baisse.",
                choices: ["Le prix monte, la quantité monte", "Le prix monte, la quantité baisse", "Le prix baisse, la quantité baisse", "Rien ne change"],
                answerIndex: 1,
                chapter: 2
            ),
            DemoCard(
                kind: .cloze,
                front: "Quand le prix d'un bien augmente, on se déplace … sa courbe de demande : c'est la quantité demandée qui varie, pas la demande.",
                back: "le long de",
                chapter: 0
            ),
            DemoCard(kind: .basic, front: "Avec $Q_d = 120 - 20p$ et $Q_s = 20p$, quel est l'équilibre ?", back: "$120 - 20p = 20p$ donne $p^* = 3$ € et $Q^* = 60$ (milliers).", hint: "Égalisez l'offre et la demande.", chapter: 1),
            DemoCard(kind: .choice, front: "Le prix augmente de 10 % et la quantité demandée baisse de 5 %. Quelle est l'élasticité-prix de la demande ?", back: "$e = -5 / 10 = -0{,}5$ : la demande est inélastique, et une hausse de prix augmente la recette.", choices: ["−2", "−0,5", "0,5", "−5"], answerIndex: 1, chapter: 2),
            DemoCard(kind: .cloze, front: "Un prix plafond fixé en dessous du prix d'équilibre provoque une … .", back: "pénurie", chapter: 3),
            DemoCard(kind: .basic, front: "Quelles sont les cinq conditions de la concurrence pure et parfaite ?", back: "Atomicité, homogénéité du produit, transparence de l'information, libre entrée et sortie du marché, libre circulation des facteurs de production.", chapter: 0),
            DemoCard(kind: .choice, front: "Lequel de ces événements déplace la courbe de demande de voiture électrique vers la droite ?", back: "Une hausse du prix de l'essence : la voiture thermique, bien substituable, devient plus coûteuse à utiliser. Une baisse du prix de la voiture électrique elle-même ne déplace pas la courbe : on se déplace le long.", choices: ["Une baisse du prix des voitures électriques", "Une hausse du prix de l'essence", "Une hausse du coût des batteries", "Une baisse des revenus des ménages"], answerIndex: 1, chapter: 2),
            DemoCard(kind: .basic, front: "Qui supporte une taxe prélevée sur un marché ?", back: "Acheteurs et vendeurs se la partagent, quel que soit celui qui la verse. Le côté le moins élastique en supporte la plus grande part.", chapter: 3),
            DemoCard(kind: .cloze, front: "Le long d'une demande linéaire, la recette des vendeurs est maximale au point où l'élasticité-prix vaut … .", back: "−1", chapter: 2),
            DemoCard(kind: .choice, front: "Quel est l'effet d'un prix plancher fixé au-dessus de l'équilibre ?", back: "Un excédent d'offre : les vendeurs proposent plus que ce que les acheteurs veulent acheter à ce prix.", choices: ["Une pénurie", "Un excédent d'offre", "Aucun effet", "Une baisse du prix payé"], answerIndex: 1, chapter: 3),
            DemoCard(kind: .cloze, front: "La perte de surplus causée par une taxe, qui ne profite à personne, s'appelle la perte … .", back: "sèche", chapter: 3),
        ]
    )

    // MARK: Physique : les circuits électriques

    private static let circuitsFR = OnboardingDemoCourse(
        id: "debug-circuits",
        emoji: "🔌",
        subject: "Physique",
        title: "L'électricité : circuits",
        summary: "Le courant et la tension, la loi d'Ohm, les montages en série et en dérivation, puis la puissance, l'énergie et les règles de sécurité, avec des calculs faits pas à pas.",
        accentIndex: 2,
        chapters: [
            DemoChapter(title: "Courant et tension", blocks: [
                .paragraph("Quand on appuie sur un interrupteur, la lampe s'allume instantanément, et pourtant les électrons, dans les fils, avancent de moins d'un millimètre par seconde. Ce paradoxe dit l'essentiel : un circuit électrique est ==une boucle déjà pleine de charges==, que le générateur met en mouvement toutes à la fois."),
                .heading("Le courant électrique"),
                .paragraph("Un **courant électrique** est un déplacement d'ensemble de porteurs de charge. Dans les métaux, ce sont des **électrons libres**, qui se déplacent d'atome en atome ; dans les solutions, ce sont des ions. Son **intensité** $I$ mesure la quantité de charge qui traverse une section du fil chaque seconde. Elle s'exprime en **ampères** (A)."),
                .formula("I = \\frac{Q}{\\Delta t}", caption: "I en ampères (A), Q en coulombs (C), Δt en secondes (s)"),
                .paragraph("Un électron porte une charge de $1{,}6 \\times 10^{-19}$ C. Un courant de 1 A correspond donc au passage de $1 / (1{,}6 \\times 10^{-19}) \\approx 6{,}25 \\times 10^{18}$ électrons par seconde : plus de six milliards de milliards. C'est pourquoi on ne compte jamais les électrons un par un, mais les coulombs."),
                .callout(
                    title: "Sens conventionnel",
                    text: "Par convention, le courant circule **de la borne + vers la borne −** du générateur, à l'extérieur de celui-ci. Les électrons, chargés négativement, se déplacent **dans le sens inverse**. La convention date d'avant la découverte de l'électron, et on l'a gardée.",
                    tone: .warning
                ),
                .paragraph("Pour qu'un courant circule, il faut une **boucle fermée** : un générateur, des fils, au moins un récepteur, et aucune coupure. Ouvrir un interrupteur, c'est couper la boucle, et le courant s'arrête partout à la fois — avant comme après l'interrupteur."),
                .figure(.cycle(title: "Une boucle fermée", nodes: ["Borne + du générateur", "Fil de connexion", "Récepteur (lampe)", "Retour à la borne −"])),
                .paragraph("Dans une boucle simple, sans embranchement, l'intensité est ==la même en tout point== : le courant ne s'use pas en traversant la lampe. Ce qui se « consomme », c'est l'énergie que transportent les charges, pas les charges elles-mêmes. La lampe ne mange pas d'électrons, elle transforme de l'énergie électrique en lumière et en chaleur."),
                .heading("La tension"),
                .callout(
                    title: "Tension électrique",
                    text: "La **tension** $U$ entre deux points d'un circuit est la différence de leur potentiel électrique. Elle se mesure en **volts** (V). C'est elle qui met les charges en mouvement : sans tension, pas de courant.",
                    tone: .definition
                ),
                .paragraph("Une image aide à fixer les idées : dans un circuit d'eau, la pompe crée une différence de pression, et l'eau circule. Le générateur est la pompe, la tension est la différence de pression, l'intensité est le débit. Une pile de 1,5 V, une batterie de voiture de 12 V et une prise de courant de 230 V n'ont pas la même « pression »."),
                .table(title: "Mesurer dans un circuit", headers: ["Appareil", "Mesure", "Unité", "Branchement"], rows: [
                    ["Ampèremètre", "L'intensité", "Ampère (A)", "En série, dans la boucle"],
                    ["Voltmètre", "La tension", "Volt (V)", "En dérivation, aux bornes du dipôle"],
                    ["Ohmmètre", "La résistance", "Ohm (Ω)", "Aux bornes du dipôle, hors circuit"],
                ]),
                .paragraph("Le branchement découle de ce que l'appareil mesure. Un ampèremètre compte ce qui passe : il doit être traversé par le courant, donc placé **dans** la boucle. Un voltmètre compare deux points : il se branche **entre** eux. Brancher un ampèremètre en dérivation, c'est créer un court-circuit — et souvent griller son fusible."),
                .list([
                    "Loi des nœuds : la somme des intensités qui arrivent à un nœud égale la somme de celles qui en repartent",
                    "Loi des mailles : dans une boucle, la tension du générateur égale la somme des tensions aux bornes des récepteurs",
                    "Dans une boucle simple, l'intensité est la même partout",
                ]),
            ]),
            DemoChapter(title: "La loi d'Ohm", blocks: [
                .paragraph("Un fil de cuivre laisse passer le courant presque sans résistance ; un filament de tungstène le freine fortement. La **résistance** $R$ d'un dipôle mesure ==à quel point il s'oppose au passage du courant==. Elle s'exprime en ohms (Ω), du nom du physicien allemand Georg Ohm."),
                .heading("Une relation de proportionnalité"),
                .paragraph("Branchons un **conducteur ohmique** — une résistance, au sens du composant — sur un générateur réglable, et mesurons l'intensité pour plusieurs tensions. Les résultats, pour une résistance de 100 Ω, tombent sur une droite qui passe par l'origine."),
                .table(title: "Mesures aux bornes d'une résistance de 100 Ω", headers: ["Tension U (V)", "Intensité I (mA)", "U / I (Ω)"], rows: [
                    ["2", "20", "100"],
                    ["4", "40", "100"],
                    ["6", "60", "100"],
                    ["8", "80", "100"],
                    ["10", "100", "100"],
                ]),
                .paragraph("Le rapport $U / I$ est constant : c'est la résistance. Attention aux unités : 20 mA valent 0,020 A, et $2 / 0{,}020 = 100$ Ω. Cette proportionnalité entre la tension et l'intensité est la **loi d'Ohm**, la relation la plus utilisée de toute l'électricité."),
                .formula("U = R \\times I", caption: "U en volts (V), R en ohms (Ω), I en ampères (A)"),
                .paragraph("La formule se lit dans les trois sens : $U = RI$, $I = U / R$, $R = U / I$. Pour une tension donnée, plus la résistance est grande, plus l'intensité est faible. Exemple : une résistance de 470 Ω sous 12 V est traversée par $I = 12 / 470 \\approx 0{,}026$ A, soit environ 26 mA."),
                .heading("Tous les dipôles ne sont pas ohmiques"),
                .paragraph("La loi d'Ohm ne vaut que pour les conducteurs ohmiques. Une lampe à incandescence, par exemple, ne la respecte pas : quand la tension augmente, le filament chauffe, sa résistance augmente, et l'intensité croît de moins en moins vite. Sa **caractéristique** — la courbe de l'intensité en fonction de la tension — n'est pas une droite, mais une courbe qui s'infléchit."),
                .figure(.plot(title: "Caractéristique d'une lampe à incandescence", caption: "En abscisse la tension, en ordonnée l'intensité : plus le filament chauffe, plus sa résistance augmente, et plus l'intensité peine à suivre.", kind: .saturation)),
                .paragraph("Comparez avec la droite d'une résistance : pour la lampe, le rapport $U / I$ n'est pas constant, il augmente avec la tension. C'est la ==signature d'un dipôle non ohmique==. Les diodes en sont un autre exemple, encore plus marqué : elles laissent passer le courant dans un sens et presque pas dans l'autre."),
                .keyFigure(value: "× 10", label: "au moins : la résistance d'un filament de tungstène à 2 500 °C, comparée à sa résistance à froid"),
                .paragraph("C'est pourquoi une ampoule à incandescence grille le plus souvent à l'allumage : froide, sa résistance est faible, et un fort courant la traverse pendant une fraction de seconde avant que le filament ne chauffe. Un ohmmètre qui mesure une lampe éteinte donne donc une valeur très différente de sa résistance en fonctionnement."),
                .callout(
                    title: "Méthode",
                    text: "Pour appliquer la loi d'Ohm : 1. vérifier que le dipôle est ohmique ; 2. convertir en unités de base — volts, ampères, ohms (1 mA = 0,001 A, 1 kΩ = 1 000 Ω) ; 3. isoler la grandeur cherchée ; 4. donner le résultat avec son unité et un nombre raisonnable de chiffres.",
                    tone: .insight
                ),
                .paragraph("L'étape deux est celle qui fait perdre le plus de points : $12 / 470$ donne 0,026, et c'est un résultat en ampères. Écrire « 0,026 mA », c'est se tromper d'un facteur mille. Un ordre de grandeur de tête — ==quelques dizaines de milliampères pour quelques centaines d'ohms sous 12 V== — suffit à repérer l'erreur."),
            ]),
            DemoChapter(title: "Série et dérivation", blocks: [
                .paragraph("Dès qu'un circuit compte plus d'un récepteur, il faut savoir comment ils sont reliés. Il n'existe que deux façons élémentaires : **en série**, les uns à la suite des autres dans une même boucle ; **en dérivation**, sur des branches parallèles entre les deux mêmes points. Tout circuit, même complexe, se décompose en ces deux montages."),
                .figure(.split(
                    title: "Deux montages",
                    left: DemoColumn(title: "En série", items: ["Une seule boucle", "Même intensité partout", "Les tensions s'additionnent", "Les résistances s'additionnent", "Un élément grillé coupe tout"]),
                    right: DemoColumn(title: "En dérivation", items: ["Plusieurs branches", "Même tension aux bornes", "Les intensités s'additionnent", "Résistance équivalente plus petite", "Chaque branche est indépendante"])
                )),
                .paragraph("Chaque ligne du tableau découle des deux lois du premier chapitre. En série, il n'y a pas de nœud, donc l'intensité est la même partout ; la loi des mailles dit que les tensions s'ajoutent. En dérivation, les branches sont branchées entre les deux mêmes points, donc elles ont la même tension ; la loi des nœuds dit que les intensités s'ajoutent."),
                .heading("En série"),
                .formula("R_{eq} = R_1 + R_2", caption: "Deux résistances en série équivalent à une seule, égale à leur somme"),
                .callout(
                    title: "Exemple : deux résistances en série",
                    text: "Un générateur de 12 V alimente $R_1 = 100$ Ω et $R_2 = 200$ Ω en série. $R_{eq} = 300$ Ω, donc $I = 12 / 300 = 0{,}040$ A = 40 mA. Tensions : $U_1 = 100 \\times 0{,}040 = 4$ V et $U_2 = 200 \\times 0{,}040 = 8$ V. Vérification : $4 + 8 = 12$ V.",
                    tone: .example
                ),
                .paragraph("La tension se partage ==proportionnellement aux résistances== : la résistance deux fois plus grande prend une tension deux fois plus grande. Ce montage s'appelle un **diviseur de tension**, et il est partout en électronique pour obtenir une tension plus faible à partir d'une alimentation fixe."),
                .heading("En dérivation"),
                .formula("\\frac{1}{R_{eq}} = \\frac{1}{R_1} + \\frac{1}{R_2} \\;\\;\\Leftrightarrow\\;\\; R_{eq} = \\frac{R_1 R_2}{R_1 + R_2}", caption: "En dérivation, ce sont les inverses des résistances qui s'additionnent"),
                .paragraph("Branchons maintenant les mêmes résistances en dérivation sur le même générateur. Chacune reçoit les 12 V : $I_1 = 12 / 100 = 0{,}12$ A et $I_2 = 12 / 200 = 0{,}06$ A. Le générateur débite leur somme, $0{,}18$ A. La résistance équivalente vaut $\\frac{100 \\times 200}{300} \\approx 66{,}7$ Ω, et l'on vérifie que $12 / 66{,}7 \\approx 0{,}18$ A."),
                .table(title: "Les mêmes résistances, deux montages (générateur de 12 V)", headers: ["", "En série", "En dérivation"], rows: [
                    ["Résistance équivalente", "300 Ω", "≈ 66,7 Ω"],
                    ["Intensité débitée", "40 mA", "180 mA"],
                    ["Tension aux bornes de R₁", "4 V", "12 V"],
                    ["Tension aux bornes de R₂", "8 V", "12 V"],
                    ["Puissance totale", "0,48 W", "2,16 W"],
                ]),
                .paragraph("Le résultat est contre-intuitif : ajouter une résistance **en dérivation diminue** la résistance équivalente, parce qu'on offre au courant un chemin de plus. La résistance équivalente est toujours plus petite que la plus petite des résistances en parallèle — ici 66,7 Ω, moins que 100 Ω."),
                .callout(
                    title: "Pourquoi les prises sont en dérivation",
                    text: "Dans une maison, tous les appareils sont branchés en dérivation : chacun reçoit les 230 V, et on peut en éteindre un sans couper les autres. Mais chaque appareil ajouté augmente l'intensité totale dans le circuit : c'est ainsi qu'une multiprise surchargée fait **disjoncter**.",
                    tone: .warning
                ),
                .paragraph("Retenez la règle d'or : ==en série, l'intensité est commune ; en dérivation, c'est la tension==. Tout le reste — l'addition des tensions ou des intensités, le calcul des résistances équivalentes — s'en déduit, et c'est la première chose à identifier face à un schéma."),
            ]),
            DemoChapter(title: "Puissance, énergie et sécurité", blocks: [
                .paragraph("Un appareil électrique se choisit d'abord par sa **puissance** : 8 W pour une ampoule LED, 2 000 W pour une bouilloire. La puissance électrique reçue par un dipôle est le produit de la tension à ses bornes et de l'intensité qui le traverse. Elle mesure ==le débit d'énergie== qu'il reçoit."),
                .formula("P = U \\times I", caption: "P en watts (W), U en volts (V), I en ampères (A)"),
                .paragraph("Combinée à la loi d'Ohm, la formule prend deux autres formes pour un conducteur ohmique : $P = R I^2$ et $P = U^2 / R$. La première explique l'**effet Joule** : un conducteur traversé par un courant chauffe, d'autant plus que l'intensité est forte. C'est utile dans un radiateur ou un grille-pain, et c'est une perte partout ailleurs."),
                .table(title: "Puissance et intensité de quelques appareils sous 230 V", headers: ["Appareil", "Puissance", "Intensité (I = P / U)"], rows: [
                    ["Ampoule LED", "8 W", "≈ 0,035 A"],
                    ["Chargeur de téléphone", "20 W", "≈ 0,09 A"],
                    ["Téléviseur", "100 W", "≈ 0,43 A"],
                    ["Bouilloire", "2 000 W", "≈ 8,7 A"],
                    ["Four", "3 000 W", "≈ 13 A"],
                ]),
                .paragraph("Une prise standard est prévue pour 16 A, soit $230 \\times 16 \\approx 3\\,700$ W au maximum. Brancher une bouilloire et un four sur la même multiprise, c'est demander plus de 21 A : les fils chauffent par effet Joule, et c'est ainsi que commencent de nombreux incendies domestiques."),
                .heading("L'énergie consommée"),
                .formula("E = P \\times \\Delta t", caption: "E en joules si P est en watts et Δt en secondes ; en kWh si P est en kW et Δt en heures"),
                .callout(
                    title: "Combien coûte un thé ?",
                    text: "Une bouilloire de 2 000 W chauffe l'eau en 3 minutes : $E = 2 \\text{ kW} \\times 0{,}05 \\text{ h} = 0{,}1$ kWh. À environ 0,20 € le kWh, cela coûte **deux centimes**. En joules : $2000 \\times 180 = 360\\,000$ J.",
                    tone: .example
                ),
                .paragraph("Le kilowattheure est l'unité de la facture parce que le joule est bien trop petit à l'échelle d'un foyer : 1 kWh vaut $3{,}6 \\times 10^6$ J. Ce qui coûte cher, ce ne sont pas les appareils puissants utilisés quelques minutes, mais ceux qui fonctionnent longtemps : un radiateur de 1 500 W allumé dix heures consomme 15 kWh, cent cinquante fois plus que le thé."),
                .heading("L'électricité et le corps humain"),
                .paragraph("Le danger électrique tient à ==l'intensité qui traverse le corps==, pas directement à la tension. Mais c'est la tension qui la provoque : le corps humain a une résistance de l'ordre de 1 000 Ω entre les deux mains, peau humide. Sous 230 V, la loi d'Ohm donne $I = 230 / 1000 = 0{,}23$ A, soit 230 mA — une intensité mortelle."),
                .bars(title: "Effets d'un courant alternatif traversant le corps", unit: "mA", bars: [
                    DemoBar(label: "Seuil de perception", value: 0.5),
                    DemoBar(label: "Contraction : on ne peut plus lâcher", value: 10),
                    DemoBar(label: "Paralysie respiratoire", value: 30),
                    DemoBar(label: "Fibrillation cardiaque", value: 75),
                ]),
                .paragraph("Ces seuils expliquent le chiffre qu'on trouve sur tous les tableaux électriques : les **disjoncteurs différentiels 30 mA**. Ils comparent le courant qui part vers un appareil et celui qui en revient ; si la différence dépasse 30 mA, c'est qu'une partie du courant s'échappe — peut-être à travers quelqu'un —, et ils coupent en quelques centièmes de seconde."),
                .list([
                    "Fusible ou disjoncteur : coupe le circuit en cas de surintensité (court-circuit, surcharge), protège les installations",
                    "Disjoncteur différentiel 30 mA : coupe en cas de fuite de courant, protège les personnes",
                    "Prise de terre : évacue vers le sol le courant d'un appareil à carcasse métallique défectueux",
                    "Jamais d'appareil électrique près de l'eau : la peau mouillée divise la résistance du corps",
                ]),
                .paragraph("Ces protections sont l'aboutissement de deux siècles de maîtrise de l'électricité. Il a fallu d'abord la produire de façon continue, puis comprendre ses lois, puis la distribuer à grande échelle — et, à chaque étape, apprendre à s'en protéger."),
                .timeline(title: "Deux siècles d'électricité", events: [
                    DemoEvent(date: "1800", label: "Alessandro Volta invente la pile : le premier courant continu"),
                    DemoEvent(date: "1820", label: "Ørsted découvre qu'un courant dévie une boussole"),
                    DemoEvent(date: "1827", label: "Georg Ohm publie la loi qui porte son nom"),
                    DemoEvent(date: "1831", label: "Faraday découvre l'induction : on sait produire du courant"),
                    DemoEvent(date: "1879", label: "Lampe à incandescence durable de Swan et Edison"),
                    DemoEvent(date: "1882", label: "Première centrale électrique publique, à New York"),
                ]),
                .paragraph("L'unité d'intensité porte le nom d'Ampère, celle de tension celui de Volta, celle de résistance celui d'Ohm : trois des lettres que vous écrivez à chaque exercice sont ==un hommage aux pionniers== de cette histoire. Et chacune de leurs découvertes se résume aujourd'hui en une formule de quelques caractères."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Comment se comportent l'intensité et la tension dans un montage en série, et dans un montage en dérivation ?",
                back: "En série, l'intensité est la même partout et les tensions s'additionnent. En dérivation, la tension est la même aux bornes de chaque branche et les intensités s'additionnent.",
                figure: .split(
                    title: "Deux montages",
                    left: DemoColumn(title: "Série", items: ["I commune", "U s'additionnent"]),
                    right: DemoColumn(title: "Dérivation", items: ["U commune", "I s'additionnent"])
                ),
                chapter: 2
            ),
            DemoCard(
                kind: .choice,
                front: "Une résistance de 470 Ω est soumise à une tension de 12 V. Quelle intensité la traverse ?",
                back: "$I = U / R = 12 / 470 \\approx 0{,}026$ A, soit environ 26 mA.",
                choices: ["≈ 26 mA", "≈ 39 A", "≈ 5,6 A", "≈ 0,26 mA"],
                answerIndex: 0,
                chapter: 1
            ),
            DemoCard(
                kind: .cloze,
                front: "Un voltmètre se branche en … aux bornes du dipôle dont on veut mesurer la tension.",
                back: "dérivation",
                chapter: 0
            ),
            DemoCard(kind: .basic, front: "Énoncez la loi d'Ohm.", back: "Pour un conducteur ohmique, la tension à ses bornes est proportionnelle à l'intensité qui le traverse : $U = R \\times I$, avec U en volts, R en ohms, I en ampères.", chapter: 1),
            DemoCard(kind: .choice, front: "Deux résistances de 100 Ω et 200 Ω sont montées en série sur un générateur de 12 V. Quelle est la tension aux bornes de la résistance de 200 Ω ?", back: "$I = 12 / 300 = 0{,}04$ A, donc $U_2 = 200 \\times 0{,}04 = 8$ V.", hint: "Calculez d'abord l'intensité commune.", choices: ["4 V", "6 V", "8 V", "12 V"], answerIndex: 2, chapter: 2),
            DemoCard(kind: .cloze, front: "Par convention, le courant circule de la borne … vers la borne − du générateur, à l'extérieur de celui-ci.", back: "+", chapter: 0),
            DemoCard(kind: .basic, front: "Pourquoi ajouter une résistance en dérivation diminue-t-il la résistance équivalente ?", back: "Parce qu'on offre au courant un chemin supplémentaire : les intensités des branches s'additionnent, le générateur débite davantage sous la même tension, donc $R_{eq} = U / I$ diminue.", chapter: 2),
            DemoCard(kind: .choice, front: "Quelle énergie consomme une bouilloire de 2 000 W en fonctionnant 3 minutes ?", back: "$E = P \\times \\Delta t = 2 \\text{ kW} \\times 0{,}05 \\text{ h} = 0{,}1$ kWh, soit 360 000 J.", choices: ["6 kWh", "0,1 kWh", "6 000 J", "0,6 kWh"], answerIndex: 1, chapter: 3),
            DemoCard(kind: .cloze, front: "La puissance électrique reçue par un dipôle vaut $P = U \\times$ … .", back: "$I$", chapter: 3),
            DemoCard(kind: .basic, front: "Que protège un disjoncteur différentiel 30 mA, et comment ?", back: "Les personnes : il compare le courant qui part vers un appareil et celui qui en revient, et coupe si la différence dépasse 30 mA, signe d'une fuite de courant, peut-être à travers un corps.", chapter: 3),
            DemoCard(kind: .choice, front: "À partir de quelle intensité environ un courant traversant le corps peut-il provoquer une paralysie respiratoire ?", back: "Environ 30 mA, d'où le calibre des disjoncteurs différentiels domestiques.", choices: ["0,5 mA", "30 mA", "1 A", "10 A"], answerIndex: 1, chapter: 3),
            DemoCard(kind: .cloze, front: "Un électron porte une charge de $1{,}6 \\times 10^{-19}$ … .", back: "coulomb", chapter: 0),
        ]
    )

    // MARK: SVT : la cellule et la mitose

    private static let mitosisFR = OnboardingDemoCourse(
        id: "debug-mitosis",
        emoji: "🔬",
        subject: "SVT",
        title: "La cellule et la mitose",
        summary: "La cellule et ses organites, le cycle cellulaire, les phases de la mitose, la méiose qui fabrique les gamètes, et le cancer, quand la division échappe à tout contrôle.",
        accentIndex: 3,
        chapters: [
            DemoChapter(title: "La cellule, unité du vivant", blocks: [
                .paragraph("Tout être vivant est fait de cellules : une seule pour une bactérie, environ ==30 000 milliards== pour un être humain. Et toute cellule naît d'une autre cellule, par division. Ces deux phrases forment la **théorie cellulaire**, l'un des piliers de la biologie."),
                .heading("Une découverte en deux siècles"),
                .paragraph("Il a fallu inventer le microscope pour voir les cellules, puis deux siècles d'observations pour comprendre qu'elles étaient le point commun de tous les êtres vivants. La frise résume ce long chemin, qui s'achève quand on observe enfin une cellule en train de se diviser."),
                .timeline(title: "La théorie cellulaire", events: [
                    DemoEvent(date: "1665", label: "Robert Hooke observe des « cellules » dans le liège"),
                    DemoEvent(date: "1674", label: "Van Leeuwenhoek découvre des êtres vivants microscopiques"),
                    DemoEvent(date: "1838–1839", label: "Schleiden et Schwann : plantes et animaux sont faits de cellules"),
                    DemoEvent(date: "1855", label: "Virchow : toute cellule provient d'une cellule"),
                    DemoEvent(date: "1882", label: "Flemming décrit et nomme la mitose"),
                ]),
                .paragraph("La phrase de Virchow, *omnis cellula e cellula*, a une conséquence vertigineuse : chacune de vos cellules descend, par une chaîne ininterrompue de divisions, de la toute première cellule vivante. La division cellulaire n'est pas un détail du fonctionnement du vivant, c'est ==ce qui le fait durer==."),
                .callout(
                    title: "Cellule",
                    text: "La plus petite unité structurale et fonctionnelle du vivant : un espace délimité par une **membrane plasmique**, contenant un **cytoplasme** et une information génétique sous forme d'**ADN**, capable de se nourrir, de produire de l'énergie et de se reproduire.",
                    tone: .definition
                ),
                .paragraph("Il existe deux grands types de cellules. Les **procaryotes** — les bactéries — n'ont pas de noyau : leur ADN flotte dans le cytoplasme. Les **eucaryotes** — animaux, végétaux, champignons, protistes — ont un noyau qui enferme l'ADN, et des compartiments spécialisés, les **organites**."),
                .heading("Les organites"),
                .table(title: "Les principaux organites d'une cellule eucaryote", headers: ["Organite", "Rôle"], rows: [
                    ["Noyau", "Contient l'ADN, siège de la réplication et de la transcription"],
                    ["Mitochondrie", "Respiration cellulaire : produit l'ATP"],
                    ["Ribosome", "Traduction : fabrique les protéines"],
                    ["Réticulum endoplasmique", "Synthèse et transport des protéines et des lipides"],
                    ["Appareil de Golgi", "Modifie, trie et expédie les protéines"],
                    ["Chloroplaste", "Photosynthèse, chez les végétaux seulement"],
                ]),
                .paragraph("La cellule végétale possède en plus une **paroi** rigide de cellulose autour de sa membrane, une grande **vacuole** remplie d'eau qui la maintient gonflée, et des chloroplastes. La cellule animale n'a ni paroi ni chloroplaste, mais des **centrosomes**, qui joueront un rôle central pendant la division."),
                .keyFigure(value: "10 à 100 µm", label: "la taille typique d'une cellule eucaryote, environ dix fois celle d'une bactérie : invisible à l'œil nu"),
                .paragraph("Cette taille n'est pas un hasard. Une cellule échange tout — nourriture, oxygène, déchets — à travers sa membrane, et quand son volume augmente, sa surface augmente moins vite. Au-delà d'une certaine taille, ==la membrane ne suffit plus== à nourrir l'intérieur : la cellule doit se diviser ou mourir."),
            ]),
            DemoChapter(title: "Le cycle cellulaire", blocks: [
                .paragraph("Une cellule qui se divise passe par une succession d'étapes qui se répètent à chaque génération : c'est le **cycle cellulaire**. Il comprend une longue **interphase**, pendant laquelle la cellule grandit et copie son ADN, et une courte **mitose**, pendant laquelle elle se divise en deux."),
                .figure(.cycle(title: "Le cycle cellulaire", nodes: ["G1 : croissance", "S : réplication de l'ADN", "G2 : préparation", "M : mitose et cytocinèse"])),
                .paragraph("La phase **G1** (de l'anglais *gap*, intervalle) est celle où la cellule grandit et fonctionne normalement. En phase **S** (synthèse), elle réplique tout son ADN. En phase **G2**, elle vérifie la copie et prépare la division. La phase **M** est la mitose elle-même, suivie de la **cytocinèse**, qui partage le cytoplasme."),
                .bars(title: "Durée des phases pour une cellule humaine en culture", unit: "h", bars: [
                    DemoBar(label: "G1", value: 11),
                    DemoBar(label: "S", value: 8),
                    DemoBar(label: "G2", value: 4),
                    DemoBar(label: "M", value: 1),
                ]),
                .paragraph("Sur un cycle de 24 heures environ, la mitose n'occupe qu'une heure. C'est pourquoi, sur une lame de microscope, l'immense majorité des cellules sont en interphase : la proportion de cellules observées dans chaque phase ==reflète la durée de cette phase==. Beaucoup de cellules, comme les neurones, quittent même le cycle pour une phase de repos, dite G0, et ne se divisent plus."),
                .heading("Chromosomes et chromatides"),
                .callout(
                    title: "Chromosome et chromatide",
                    text: "Un **chromosome** est une molécule d'ADN associée à des protéines. Après la phase S, chaque chromosome est formé de **deux chromatides sœurs**, deux copies identiques reliées par un **centromère**. Il reste **un seul** chromosome, mais à deux chromatides.",
                    tone: .definition
                ),
                .paragraph("La quantité d'ADN d'une cellule suit donc le cycle. Appelons $Q$ la quantité d'ADN d'une cellule en G1. Pendant la phase S, elle double progressivement pour atteindre $2Q$. À la fin de la mitose, chaque cellule fille repart avec $Q$. La courbe de la quantité d'ADN en fonction du temps a la forme d'un escalier qui monte en S et redescend d'un coup à la division."),
                .formula("Q \\;\\to\\; 2Q \\;\\to\\; Q", caption: "La quantité d'ADN par cellule : doublée pendant la phase S, partagée à la mitose"),
                .paragraph("Le nombre de chromosomes, lui, ne change pas pendant la phase S : une cellule humaine a 46 chromosomes en G1, et toujours 46 en G2 — mais à deux chromatides chacun. On le note ==2n = 46== : $n$ est le nombre de chromosomes d'un jeu, 23 chez l'humain, et les cellules du corps en ont deux jeux, l'un maternel, l'autre paternel."),
                .callout(
                    title: "L'erreur classique",
                    text: "Croire que la réplication double le nombre de chromosomes. Elle double **la quantité d'ADN**, pas le nombre de chromosomes : 46 chromosomes à une chromatide deviennent 46 chromosomes à deux chromatides. Le nombre ne double qu'un instant, en anaphase, quand les chromatides se séparent.",
                    tone: .warning
                ),
                .list([
                    "G1 : croissance, chromosomes à une chromatide, quantité d'ADN Q",
                    "S : réplication, la quantité d'ADN passe de Q à 2Q",
                    "G2 : chromosomes à deux chromatides, vérification de la copie",
                    "M : mitose, chaque cellule fille reçoit Q",
                ]),
                .paragraph("Le passage d'une phase à l'autre n'est pas automatique : il est contrôlé par des **points de contrôle**, où la cellule vérifie que tout est en ordre avant de continuer — que l'ADN est intact avant la phase S, qu'il est entièrement copié avant la mitose. Leur découverte a valu le prix Nobel 2001 à Hartwell, Hunt et Nurse, et c'est leur défaillance qui ouvre la porte au cancer."),
            ]),
            DemoChapter(title: "Les phases de la mitose", blocks: [
                .paragraph("La mitose est la division d'une cellule en ==deux cellules filles génétiquement identiques== à la cellule mère. Son enjeu est simple à énoncer et redoutable à réaliser : répartir exactement une copie de chacun des 46 chromosomes dans chacune des deux cellules, sans en perdre ni en doubler aucun."),
                .figure(.flow(title: "Les étapes de la mitose", steps: ["Prophase : les chromosomes se condensent", "Métaphase : ils s'alignent à l'équateur", "Anaphase : les chromatides sœurs se séparent", "Télophase : deux noyaux se reforment", "Cytocinèse : deux cellules filles"])),
                .paragraph("Chaque phase a ses marqueurs visibles au microscope, et c'est ce qu'on vous demandera de reconnaître sur une photographie. Le tableau les rassemble ; la métaphase est la plus facile à identifier, avec ses chromosomes alignés comme une rangée de soldats au milieu de la cellule."),
                .table(title: "Ce qu'on voit à chaque phase", headers: ["Phase", "Ce qui se passe"], rows: [
                    ["Prophase", "Les chromosomes se condensent et deviennent visibles ; l'enveloppe du noyau disparaît ; le fuseau de division se forme"],
                    ["Métaphase", "Les chromosomes, à deux chromatides, s'alignent sur la plaque équatoriale, accrochés au fuseau par leur centromère"],
                    ["Anaphase", "Les chromatides sœurs se séparent et migrent vers les pôles opposés : chaque pôle reçoit 46 chromosomes à une chromatide"],
                    ["Télophase", "Les chromosomes se décondensent ; une enveloppe nucléaire se reforme autour de chaque lot"],
                ]),
                .paragraph("Le **fuseau de division** est la machine qui rend tout cela possible : un réseau de fibres de protéines, les microtubules, tendues entre les deux pôles de la cellule. Elles s'accrochent aux centromères, alignent les chromosomes, puis raccourcissent pour tirer les chromatides vers les pôles. Un point de contrôle bloque l'anaphase tant qu'un seul chromosome n'est pas correctement accroché."),
                .callout(
                    title: "Le bilan de la mitose",
                    text: "Une cellule mère à 2n = 46 chromosomes donne **deux cellules filles à 2n = 46 chromosomes**, portant exactement la même information génétique. La mitose est une **reproduction conforme** : c'est elle qui permet la croissance, le renouvellement des tissus et la cicatrisation.",
                    tone: .insight
                ),
                .paragraph("La cytocinèse diffère selon le type de cellule. La cellule animale s'étrangle en son milieu, comme un ballon qu'on pince, grâce à un anneau de protéines contractiles. La cellule végétale, prisonnière de sa paroi rigide, ne peut pas s'étrangler : elle construit une nouvelle paroi au milieu, de l'intérieur vers l'extérieur."),
                .figure(.split(
                    title: "Deux façons de se diviser",
                    left: DemoColumn(title: "Cellule animale", items: ["Centrosomes aux pôles", "Anneau contractile", "Étranglement du cytoplasme"]),
                    right: DemoColumn(title: "Cellule végétale", items: ["Pas de centrosome", "Paroi rigide", "Nouvelle paroi construite au centre"])
                )),
                .paragraph("Chaque division double le nombre de cellules. Partant d'une cellule, on en a 2 après une division, 4 après deux, 8 après trois : la croissance est **exponentielle**. Après $k$ divisions, une population de $N_0$ cellules en compte $N_0 \\times 2^k$."),
                .formula("N = N_0 \\times 2^k", caption: "Le nombre de cellules après k divisions successives, si toutes se divisent"),
                .paragraph("Dix divisions donnent déjà $2^{10} = 1\\,024$ cellules ; quarante-cinq divisions, environ 35 000 milliards — l'ordre de grandeur d'un corps humain. En réalité, les cellules d'un organisme ne se divisent pas toutes, et beaucoup meurent : la croissance d'un tissu sain est un ==équilibre entre divisions et morts cellulaires==, que l'organisme règle en permanence."),
            ]),
            DemoChapter(title: "Méiose, mitose et cancer", blocks: [
                .paragraph("La mitose fabrique des copies conformes. Mais pour la reproduction sexuée, il faut autre chose : des cellules qui n'ont qu'un seul jeu de chromosomes, pour qu'à la fécondation, l'ovule et le spermatozoïde reconstituent une cellule à deux jeux. C'est le rôle de la **méiose**, qui a lieu uniquement dans les gonades."),
                .table(title: "Mitose et méiose face à face", headers: ["", "Mitose", "Méiose"], rows: [
                    ["Où", "Presque toutes les cellules du corps", "Les cellules reproductrices des gonades"],
                    ["Divisions", "Une", "Deux successives"],
                    ["Cellules obtenues", "2", "4"],
                    ["Chromosomes", "2n = 46, comme la mère", "n = 23, moitié moins"],
                    ["Information génétique", "Identique à la cellule mère", "Différente d'une cellule à l'autre"],
                    ["Rôle", "Croissance, renouvellement", "Fabrication des gamètes"],
                ]),
                .paragraph("La première division de méiose sépare les chromosomes **homologues** — le chromosome d'origine maternelle et celui d'origine paternelle de chaque paire — ; elle divise par deux le nombre de chromosomes. La seconde sépare les chromatides sœurs, comme une mitose. Au passage, la méiose ==brasse l'information génétique== de deux façons."),
                .formula("2^{23} \\approx 8{,}4 \\times 10^{6}", caption: "Le nombre de combinaisons de chromosomes possibles dans un gamète humain, par le seul brassage interchromosomique"),
                .paragraph("Le **brassage interchromosomique** vient de ce que chaque paire se sépare indépendamment des autres : pour chacune des 23 paires, le gamète reçoit l'homologue maternel ou le paternel, d'où $2^{23}$, plus de huit millions de combinaisons. Le **brassage intrachromosomique**, par des échanges de morceaux entre homologues appelés *crossing-over*, multiplie encore ce nombre. Deux frères et sœurs, hors vrais jumeaux, ne reçoivent jamais la même combinaison."),
                .heading("Quand la division échappe au contrôle"),
                .paragraph("Dans un organisme sain, chaque cellule ne se divise que lorsqu'elle en reçoit le signal, et s'arrête lorsqu'on le lui demande. Deux familles de gènes règlent ce contrôle. Les **proto-oncogènes** fonctionnent comme un accélérateur : ils poussent la cellule à se diviser. Les **gènes suppresseurs de tumeurs** fonctionnent comme un frein : ils arrêtent le cycle en cas de problème."),
                .callout(
                    title: "Cancer",
                    text: "Une maladie due à la **prolifération incontrôlée** de cellules qui ont accumulé des mutations : un accélérateur bloqué (un proto-oncogène devenu **oncogène**) et des freins cassés (des gènes suppresseurs inactivés). Les cellules forment une tumeur, puis peuvent envahir les tissus voisins et essaimer à distance : ce sont les **métastases**.",
                    tone: .definition
                ),
                .paragraph("Le plus célèbre des freins est la protéine **p53**, surnommée « la gardienne du génome » : quand l'ADN est endommagé, elle bloque le cycle le temps de la réparation, ou déclenche le suicide de la cellule si les dégâts sont trop graves. Le gène qui la code est muté dans environ la moitié des cancers humains. Il faut en général ==plusieurs mutations successives==, accumulées sur des années, pour qu'une cellule devienne cancéreuse — ce qui explique que le risque augmente avec l'âge."),
                .keyFigure(value: "≈ 30", label: "doublements pour qu'une seule cellule devienne une tumeur d'un centimètre, soit environ un milliard de cellules (2³⁰ ≈ 1,07 × 10⁹)"),
                .paragraph("Une tumeur n'est donc détectable qu'après une longue histoire silencieuse : trente doublements pour atteindre un centimètre, alors que dix de plus suffiraient à la multiplier par mille. C'est tout l'enjeu du **dépistage** : repérer la tumeur le plus tôt possible sur cette courbe exponentielle, quand elle est encore petite et localisée."),
                .callout(
                    title: "Pourquoi la chimiothérapie fait perdre les cheveux",
                    text: "La plupart des chimiothérapies visent les cellules **qui se divisent**, en bloquant la réplication de l'ADN ou le fuseau de division. Elles touchent donc aussi les cellules saines qui se divisent vite : racines des cheveux, muqueuse de l'intestin, moelle osseuse. Les effets secondaires sont la conséquence directe de la cible.",
                    tone: .warning
                ),
                .list([
                    "Tabac : la première cause évitable de cancer en France",
                    "Alcool, surpoids, sédentarité : des facteurs de risque majeurs",
                    "Rayons UV : les coups de soleil, surtout dans l'enfance, favorisent les mélanomes",
                    "Certains virus : le papillomavirus, contre lequel il existe un vaccin",
                ]),
                .paragraph("Tous ces facteurs agissent de la même façon : ils augmentent le nombre de mutations dans les cellules qui se divisent. Comprendre la mitose, c'est donc comprendre à la fois ==comment le corps se construit et se répare==, et comment, parfois, cette même machine se dérègle."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Quelles sont les phases du cycle cellulaire ?",
                back: "L'interphase, formée de G1 (croissance), S (réplication de l'ADN) et G2 (préparation), puis la phase M : la mitose, suivie de la cytocinèse.",
                figure: .cycle(title: "Le cycle cellulaire", nodes: ["G1", "S", "G2", "M"]),
                chapter: 1
            ),
            DemoCard(
                kind: .choice,
                front: "Pendant quelle phase de la mitose les chromatides sœurs se séparent-elles ?",
                back: "L'anaphase : les chromatides sœurs migrent vers les pôles opposés, et chaque pôle reçoit un chromosome à une chromatide de chaque sorte.",
                choices: ["Prophase", "Métaphase", "Anaphase", "Télophase"],
                answerIndex: 2,
                chapter: 2
            ),
            DemoCard(
                kind: .cloze,
                front: "L'ADN d'une cellule est répliqué pendant la phase … de l'interphase.",
                back: "S",
                chapter: 1
            ),
            DemoCard(kind: .basic, front: "Quelle est la différence entre un procaryote et un eucaryote ?", back: "Un procaryote (une bactérie) n'a pas de noyau : son ADN est dans le cytoplasme. Un eucaryote a un noyau qui enferme son ADN, et des organites.", chapter: 0),
            DemoCard(kind: .choice, front: "Quel organite produit l'essentiel de l'ATP de la cellule ?", back: "La mitochondrie, siège de la respiration cellulaire.", choices: ["Le noyau", "La mitochondrie", "Le ribosome", "L'appareil de Golgi"], answerIndex: 1, chapter: 0),
            DemoCard(kind: .cloze, front: "Après la phase S, chaque chromosome est formé de deux … sœurs reliées par un centromère.", back: "chromatides", chapter: 1),
            DemoCard(kind: .basic, front: "Que devient le nombre de chromosomes et la quantité d'ADN au cours du cycle cellulaire ?", back: "La quantité d'ADN double en phase S (de Q à 2Q) et revient à Q à la division. Le nombre de chromosomes reste 46 : ils passent d'une à deux chromatides.", hint: "Distinguez la quantité d'ADN et le nombre de chromosomes.", chapter: 1),
            DemoCard(kind: .choice, front: "Combien de cellules, et à combien de chromosomes, la méiose produit-elle à partir d'une cellule humaine ?", back: "Quatre cellules à n = 23 chromosomes, génétiquement différentes les unes des autres.", choices: ["2 cellules à 46 chromosomes", "2 cellules à 23 chromosomes", "4 cellules à 23 chromosomes", "4 cellules à 46 chromosomes"], answerIndex: 2, chapter: 3),
            DemoCard(kind: .cloze, front: "Pendant la …, les chromosomes s'alignent sur la plaque équatoriale.", back: "métaphase", chapter: 2),
            DemoCard(kind: .basic, front: "Qu'est-ce qu'un cancer, à l'échelle de la cellule ?", back: "La prolifération incontrôlée de cellules qui ont accumulé des mutations : des proto-oncogènes devenus oncogènes (accélérateur bloqué) et des gènes suppresseurs de tumeurs inactivés (freins cassés).", chapter: 3),
            DemoCard(kind: .choice, front: "Combien de combinaisons de chromosomes un gamète humain peut-il recevoir par le seul brassage interchromosomique ?", back: "$2^{23}$, soit environ 8,4 millions : chacune des 23 paires se sépare indépendamment des autres.", choices: ["23", "46", "$2^{23}$, environ 8,4 millions", "$23^2$, soit 529"], answerIndex: 2, chapter: 3),
            DemoCard(kind: .cloze, front: "La mitose produit deux cellules filles génétiquement … à la cellule mère.", back: "identiques", chapter: 2),
        ]
    )
}
#endif
