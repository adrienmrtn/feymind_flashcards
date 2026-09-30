import Foundation

#if DEBUG
// MARK: - The six debug courses, in English

/// Six complete, pre-written courses, **reserved for debug builds**: enough to fill
/// the library in one gesture to test the sheets, the outline, the cards and review
/// without generating anything. They follow the same rule as the demo courses — four
/// chapters, text between every rich object, no object touching another — and the
/// same standard: high school or early university, accurate facts, correct figures
/// and checked calculations.
///
/// The identifiers are stable across languages; the subjects are the canonical names
/// from `SubjectCatalog`.
extension DebugCourseCatalog {
    static let english: [OnboardingDemoCourse] = [
        revolutionEN, geneticsEN, probabilityEN, supplyDemandEN, circuitsEN, mitosisEN,
    ]

    // MARK: History: the French Revolution

    private static let revolutionEN = OnboardingDemoCourse(
        id: "debug-revolution",
        emoji: "🇫🇷",
        subject: "Histoire",
        title: "The French Revolution (1789–1799)",
        summary: "Ten years that took France from absolute monarchy to the Republic: the crisis of 1789, the constitutional monarchy, the Terror, then the Directory up to Bonaparte's coup d'état.",
        accentIndex: 1,
        chapters: [
            DemoChapter(title: "The crisis of the Ancien Régime (1787–1789)", blocks: [
                .paragraph("In 1789, France is the most populous kingdom in Europe: about ==28 million inhabitants==, ruled by a king who holds his power from God and shares it with no one. In ten years, this centuries-old regime collapses. To understand how, we must start from what would later be called the **Ancien Régime**."),
                .heading("A society of orders"),
                .paragraph("Society is divided into three orders, unequal in law. The **clergy** prays, the **nobility** fights, the **Third Estate** works: at least, that is what the theory says. The first two orders enjoy **privileges** — special rights, such as exemption from the taille, the main direct tax, or the right to collect dues from the peasants."),
                .callout(
                    title: "Privilege",
                    text: "Literally a “private law”: a right or exemption granted to a group or a person, and not to everyone. Under the Ancien Régime, inequality before the law and before taxation is **the rule**, not the exception.",
                    tone: .definition
                ),
                .paragraph("The Third Estate includes everyone who is neither a priest nor a noble, that is, almost everyone: the peasants, who form the vast majority, the craftsmen and workers of the towns, but also a rich and educated **bourgeoisie** — merchants, lawyers, bankers — who resent more and more being excluded from the honours reserved for birth."),
                .bars(title: "Share of the three orders in the population (around 1789)", unit: "%", bars: [
                    DemoBar(label: "Clergy", value: 0.5),
                    DemoBar(label: "Nobility", value: 1.5),
                    DemoBar(label: "Third Estate", value: 98),
                ]),
                .paragraph("The chart shows the heart of the problem: two percent of the population hold most of the privileges, a large share of the land and almost all the high offices. In January 1789, the Abbé Sieyès sums up the situation in a famous pamphlet: “What is the Third Estate? Everything. What has it been until now? Nothing. What does it ask? To be something.”"),
                .heading("Three crises at once"),
                .paragraph("The Revolution is born from the meeting of three crises. First, a **financial crisis**: wars, and above all support for American independence, have deepened the debt, whose repayment absorbs nearly ==half of state spending==. Successive ministers propose making the privileged pay; the privileged refuse."),
                .paragraph("Next, an **economic crisis**: the 1788 harvest, ravaged by hail, is catastrophic, and the price of bread soars. On 14 July 1789, it reaches its highest level of the century in Paris. Finally, a **crisis of ideas**: the Enlightenment philosophers — Montesquieu and the separation of powers, Rousseau and popular sovereignty, Voltaire and tolerance — have taught the elites to judge power in the name of reason."),
                .figure(.flow(title: "From crisis to Revolution", steps: ["Debt and looming bankruptcy", "The privileged refuse the tax", "The king summons the Estates-General", "The Third demands voting by head", "The Third proclaims itself the National Assembly"])),
                .paragraph("Cornered, Louis XVI summons the **Estates-General**, an assembly of the three orders that had not met since 1614. Throughout the kingdom, people draw up **cahiers de doléances** (lists of grievances) to tell the king what is wrong: nearly sixty thousand of them, calling above all for equality in taxation and an end to abuses, but almost never for the end of the monarchy."),
                .callout(
                    title: "Voting by order",
                    text: "At the Estates-General, each order votes separately and has **one vote**: the clergy and the nobility, united, always beat the Third by two votes to one. The Third has won the right to have as many deputies as the other two orders combined — but the vote must be **by head** for that number to count.",
                    tone: .insight
                ),
                .paragraph("Everything hinges on this question of procedure. On 17 June 1789, with no agreement in sight, the deputies of the Third proclaim themselves the ==bleu|National Assembly==: they no longer represent an order, but the entire nation. On 20 June, finding their hall locked, they gather in the Tennis Court and swear not to separate until they have given France a constitution. Sovereignty has just changed sides."),
            ]),
            DemoChapter(title: "1789: the end of absolutism", blocks: [
                .paragraph("The summer of 1789 undoes in a few weeks what centuries had built. The deputies' revolution at Versailles is relayed by ==the revolution of the Parisians==, then by that of the countryside: it is this combination that makes it irreversible."),
                .timeline(title: "Summer and autumn 1789", events: [
                    DemoEvent(date: "5 May", label: "Opening of the Estates-General at Versailles"),
                    DemoEvent(date: "20 June", label: "Tennis Court Oath"),
                    DemoEvent(date: "14 July", label: "Storming of the Bastille"),
                    DemoEvent(date: "4 August", label: "Abolition of privileges"),
                    DemoEvent(date: "26 August", label: "Declaration of the Rights of Man and of the Citizen"),
                    DemoEvent(date: "5–6 October", label: "The king is brought back from Versailles to Paris"),
                ]),
                .paragraph("In early July, the king masses troops around Paris and dismisses Necker, the popular minister. Parisians see this as preparation for a show of force against the Assembly. On 14 July, looking for gunpowder for the muskets seized at the Invalides, the crowd attacks the **Bastille**, a royal fortress and state prison. It holds only seven prisoners, but its fall is a symbol: the people have made the king give way."),
                .heading("The night of 4 August"),
                .paragraph("In the countryside, a rumour of an aristocratic plot sets off the **Great Fear**: armed peasants attack châteaux and burn the registers listing seigneurial dues. To restore calm, the Assembly votes, on the night of 4 August, the ==abolition of privileges==: the end of feudal rights, of the tithe, of the sale of offices, and equality of all before taxation and public employment."),
                .callout(
                    title: "Declaration of the Rights of Man and of the Citizen",
                    text: "Adopted on 26 August 1789, it sets out the principles of the new regime in seventeen articles. Article 1: “Men are born and remain free and equal in rights.” Article 3: sovereignty resides in **the nation**. Article 16: no constitution without the separation of powers.",
                    tone: .definition
                ),
                .paragraph("The Declaration is a universal text — it speaks of man, not of the Frenchman — and that is why it had such influence outside France. But it also has its blind spots: it says nothing about women, and does not challenge slavery in the colonies. In 1791, Olympe de Gouges answers it with a *Declaration of the Rights of Woman and of the Female Citizen*."),
                .figure(.split(
                    title: "Two sources of power",
                    left: DemoColumn(title: "Ancien Régime", items: ["Divine-right monarchy", "Society of orders", "Privileges", "The king makes the law", "Subjects"]),
                    right: DemoColumn(title: "Principles of 1789", items: ["National sovereignty", "Equality in rights", "One law for all", "Separation of powers", "Citizens"])
                )),
                .paragraph("The side-by-side sums up what changed in 1789: power no longer comes from God but from the nation, and the law is no longer the will of one man but ==the expression of the general will==. The king remains in place, but he is now only the first official of a state whose sovereignty he no longer owns."),
                .heading("The constitutional monarchy"),
                .paragraph("From 1789 to 1791, the Constituent Assembly remakes France. It creates the **départements** (1790), nationalises Church property to repay the debt, and imposes on the clergy a **Civil Constitution** that turns priests into elected officials. The Constitution of 1791 establishes a constitutional monarchy: the king keeps executive power and a suspensive veto; a Legislative Assembly votes the laws."),
                .callout(
                    title: "Census suffrage",
                    text: "In 1791, only **active citizens** vote: men over 25 who pay a tax at least equal to three days' wages, about 4.3 million French people. The others are “passive” citizens: equal in rights, but not in political rights.",
                    tone: .warning
                ),
                .paragraph("This compromise rests on the king's good faith, and the king has none. On the night of 20 to 21 June 1791, Louis XVI flees with his family towards the eastern border; he is recognised and arrested at **Varennes**. The bond of trust is broken: for some Parisians, a king who flees his nation can no longer represent it."),
            ]),
            DemoChapter(title: "The Republic and the Terror (1792–1794)", blocks: [
                .paragraph("In April 1792, France declares war on Austria. The revolutionaries hope to export liberty; the king secretly hopes for defeat, which would restore him. The war will ==radicalise the Revolution==: defeats, real or suspected betrayals, internal uprisings, and the conviction that victory must be won at any cost."),
                .heading("The fall of the monarchy"),
                .paragraph("On 10 August 1792, the Parisian sans-culottes and the fédérés from the provinces storm the Tuileries Palace. The king is suspended, then imprisoned. A new assembly, the **Convention**, is elected for the first time by **universal male suffrage**. On 20 September, the French army stops the Prussians at Valmy; on the 21st, the Convention abolishes the monarchy. The Republic is born."),
                .keyFigure(value: "21 Jan. 1793", label: "Louis XVI, tried by the Convention and found guilty of treason, is guillotined on the Place de la Révolution"),
                .paragraph("The king's execution makes France an enemy of every monarchy in Europe: England, Spain and the Dutch Republic join the coalition. To raise soldiers, the Convention decrees a levy of 300,000 men, and the West erupts: this is the start of the **War in the Vendée**, which will leave about two hundred thousand dead on both sides."),
                .figure(.split(
                    title: "Two camps in the Convention",
                    left: DemoColumn(title: "Girondins", items: ["Brissot, Vergniaud", "Support from the provinces", "Distrust of Paris", "Economic liberalism", "Rejection of emergency measures"]),
                    right: DemoColumn(title: "Montagnards", items: ["Robespierre, Danton, Marat", "Support from the sans-culottes", "Strong central power", "Price controls", "Emergency measures"])
                )),
                .paragraph("Between the two groups, the **Plain** — the majority of deputies — tips the votes. Under pressure from the sans-culottes, who surround the Convention on 2 June 1793, the Girondin leaders are arrested. The Montagnards now govern alone, through the **Committee of Public Safety**, in which Robespierre becomes the dominant figure."),
                .heading("The Terror"),
                .callout(
                    title: "The Terror",
                    text: "The emergency government of 1793–1794, which suspends liberties to save a Republic threatened by foreign war and civil war. Its instruments: the **Law of Suspects** (September 1793), the Revolutionary Tribunal, the representatives on mission, and the guillotine.",
                    tone: .definition
                ),
                .paragraph("The Terror is also an economic and social policy: the **General Maximum** caps the price of basic necessities, the **levée en masse** mobilises all men aged 18 to 25, and the Convention abolishes slavery in the colonies on 4 February 1794. It imposes a republican calendar that starts time from 22 September 1792, Year I of liberty."),
                .paragraph("The human toll is heavy. About ==rose|17,000 death sentences== are handed down by the courts, not counting summary executions and the massacres of the civil war. Contrary to a common belief, the victims are not mainly nobles: most are ordinary people, suspected of revolt, fraud or lukewarmness."),
                .bars(title: "Those sentenced to death in the Terror, by social origin", unit: "%", bars: [
                    DemoBar(label: "Workers, craftsmen", value: 31),
                    DemoBar(label: "Peasants", value: 28),
                    DemoBar(label: "Bourgeoisie", value: 25),
                    DemoBar(label: "Nobility", value: 8.5),
                    DemoBar(label: "Clergy", value: 6.5),
                ]),
                .paragraph("These figures, compiled by the historian Donald Greer in 1935, show that the Terror strikes first where the Republic feels threatened — the Vendée, Lyon, Marseille, Toulon — and therefore where most people live. In spring 1794, military victories make the emergency harder to justify; yet the law of 22 Prairial (June 1794) speeds up the trials even further: this is the **Great Terror**."),
                .callout(
                    title: "9 Thermidor",
                    text: "On 27 July 1794 (9 Thermidor Year II), deputies fearing for their own heads have Robespierre and his associates arrested. They are guillotined the next day. The Terror ends, not because its opponents defeated it from outside, but because ==its own actors== turned against it.",
                    tone: .insight
                ),
            ]),
            DemoChapter(title: "From the Directory to Bonaparte (1795–1799), and what remains", blocks: [
                .paragraph("After Thermidor, the moderate republicans want to ==bring the Revolution to an end==: neither the return of the king, nor the return of the Terror. The Constitution of Year III (1795) is designed to prevent both the dictatorship of one man and that of an assembly."),
                .heading("A fragile regime"),
                .paragraph("Executive power is entrusted to five **Directors**, legislative power to two councils — the Five Hundred, who propose the laws, and the Elders, who vote them. Suffrage becomes census-based again. The regime is caught in a vice between the royalists, who win the 1797 elections, and the neo-Jacobins, who win those of 1798: each time, the Directory cancels the result by force, and leans more and more on the army."),
                .table(title: "The regimes of the decade", headers: ["Regime", "Dates", "Who governs", "Suffrage"], rows: [
                    ["Absolute monarchy", "until 1789", "The king alone", "None"],
                    ["Constitutional monarchy", "1791–1792", "The king and the Legislative Assembly", "Census-based"],
                    ["Republic: the Convention", "1792–1795", "The Convention, the Committee of Public Safety", "Universal male"],
                    ["Republic: the Directory", "1795–1799", "Five Directors, two councils", "Census-based"],
                    ["Consulate", "from 1799", "Bonaparte, First Consul", "Plebiscites"],
                ]),
                .paragraph("The table reads like a curve: power widens until 1793, then narrows. And at each stage, suffrage follows the same movement. The Revolution laid down the principle of national sovereignty, but it never stopped arguing over ==who has the right to speak in the nation's name==."),
                .paragraph("Meanwhile, a young general rises. Napoleon Bonaparte crushed a royalist uprising in Paris in 1795, conquered Italy in 1796–1797, then led the Egyptian expedition. Back in France, crowned with his victories, he allies with Sieyès, now a Director, who is looking for “a sword” to revise the Constitution."),
                .callout(
                    title: "The coup of 18 Brumaire",
                    text: "On 9 November 1799 (18 Brumaire Year VIII), Bonaparte and Sieyès overthrow the Directory; the next day, grenadiers disperse the Five Hundred. The Consulate that follows concentrates power in the hands of the First Consul. This day is traditionally taken as **the end of the Revolution**.",
                    tone: .example
                ),
                .heading("What remains of the Revolution"),
                .paragraph("Bonaparte keeps much of the legacy: the Civil Code of 1804 enshrines equality before the law, property and the end of feudalism. He erases other parts: he restores slavery in 1802, and replaces the sovereignty of assemblies with his own. The revolutionary legacy thus reads in two columns: principles won for good, and struggles that will last throughout the nineteenth century."),
                .list([
                    "Lasting gains: end of privileges and of the society of orders, equality before the law and taxation, départements, the metric system, secular civil registration",
                    "Principles laid down: national sovereignty, the rights of man, separation of powers",
                    "Unfinished struggles: universal suffrage (1848), final abolition of slavery (1848), women's right to vote (1944)",
                ]),
                .paragraph("The dates in the last line show that it took a century and a half to keep all the promises of 1789. It is this gap between ==the principles proclaimed and their application== that makes the Revolution a founding moment: it gave later generations the words with which to demand what it had not itself granted."),
                .figure(.flow(title: "The dynamics of the decade", steps: ["1789: the nation takes sovereignty", "1791: compromise with the king", "1792: war and the Republic", "1793–1794: the Terror", "1795–1799: stabilisation, then the army"])),
                .paragraph("This diagram is the backbone of an essay on the period. Each stage responds to the failure of the previous one: the 1791 compromise fails because of the king, the moderate Republic because of the war, the Terror because of its excesses, and the Directory for lack of legitimacy. Explaining ==why each stage leads to the next== is understanding the Revolution rather than reciting it."),
                .callout(
                    title: "The classic mistake",
                    text: "Writing that the Revolution abolished the monarchy in 1789. In 1789, it abolished **absolutism** and privileges; the constitutional monarchy lasted until 10 August 1792, and the Republic was not proclaimed until September 1792.",
                    tone: .warning
                ),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "What are the three orders of Ancien Régime society?",
                back: "The clergy and the nobility, the privileged orders (about 2% of the population), and the Third Estate (about 98%), which pays most of the taxes.",
                figure: .split(
                    title: "A society of orders",
                    left: DemoColumn(title: "Privileged", items: ["Clergy", "Nobility"]),
                    right: DemoColumn(title: "Non-privileged", items: ["Third Estate"])
                ),
                chapter: 0
            ),
            DemoCard(
                kind: .choice,
                front: "What does the Assembly vote on the night of 4 August 1789?",
                back: "The abolition of privileges: the end of feudal rights, the tithe and the sale of offices, and equality in taxation.",
                choices: ["The Declaration of the Rights of Man", "The abolition of privileges", "The abolition of the monarchy", "The Civil Constitution of the Clergy"],
                answerIndex: 1,
                chapter: 1
            ),
            DemoCard(
                kind: .cloze,
                front: "Louis XVI is arrested at … in June 1791, while fleeing towards the eastern border.",
                back: "Varennes",
                chapter: 1
            ),
            DemoCard(kind: .basic, front: "Why is the question of voting by order or by head decisive in 1789?", back: "By order, the clergy and the nobility always win two votes to one. By head, the Third Estate, which has as many deputies as the other two orders combined, can win a majority with a few allies.", hint: "Count the votes in each case.", chapter: 0),
            DemoCard(kind: .cloze, front: "On 17 June 1789, the deputies of the Third Estate proclaim themselves the … .", back: "National Assembly", chapter: 0),
            DemoCard(kind: .choice, front: "When is the Republic proclaimed in France?", back: "In September 1792: the Convention abolishes the monarchy on 21 September, the day after Valmy.", choices: ["July 1789", "June 1791", "September 1792", "July 1794"], answerIndex: 2, chapter: 2),
            DemoCard(kind: .basic, front: "What is the Terror?", back: "The emergency government of 1793–1794 that suspends liberties to save the Republic at war: the Law of Suspects, the Revolutionary Tribunal, about 17,000 death sentences. It ends with Robespierre's fall on 9 Thermidor Year II (27 July 1794).", chapter: 2),
            DemoCard(kind: .cloze, front: "Article 1 of the 1789 Declaration states: “Men are born and remain free and … in rights.”", back: "equal", chapter: 1),
            DemoCard(kind: .choice, front: "Which social group accounts for the most death sentences during the Terror?", back: "Ordinary people: workers, craftsmen and peasants make up nearly six out of ten of those condemned; nobles, about 8%.", choices: ["The nobility", "The clergy", "Workers, craftsmen and peasants", "Army officers"], answerIndex: 2, chapter: 2),
            DemoCard(kind: .basic, front: "What is census suffrage?", back: "A right to vote reserved for those who pay a certain amount of tax (the cens). In 1791, only “active” citizens, about 4.3 million men, vote.", chapter: 1),
            DemoCard(kind: .cloze, front: "The coup of 18 … Year VIII (9 November 1799) brings Bonaparte to power.", back: "Brumaire", chapter: 3),
            DemoCard(kind: .choice, front: "How many Directors hold executive power under the Directory?", back: "Five, alongside two councils: the Five Hundred and the Elders.", choices: ["One", "Three", "Five", "Seven"], answerIndex: 2, chapter: 3),
        ]
    )

    // MARK: Biology: genetics and DNA

    private static let geneticsEN = OnboardingDemoCourse(
        id: "debug-genetics",
        emoji: "🧬",
        subject: "SVT",
        title: "Genetics and DNA",
        summary: "The DNA molecule, its replication, the path from gene to protein, the mutations that create diversity, and Mendel's laws that describe how it is passed on.",
        accentIndex: 4,
        chapters: [
            DemoChapter(title: "The DNA molecule", blocks: [
                .paragraph("Every cell in your body contains, in its nucleus, about ==two metres of DNA== folded into a few micrometres. This molecule carries the information needed to build and run a living being, and it passes it on from a cell to its daughters, from a parent to their children."),
                .heading("A double helix"),
                .paragraph("DNA — deoxyribonucleic acid — is a long chain of **nucleotides**. Each nucleotide is made of three parts: a phosphate group, a sugar, deoxyribose, and a **nitrogenous base**. There are four bases: adenine (A), thymine (T), guanine (G) and cytosine (C). It is the order of these bases along the molecule that makes up the genetic information."),
                .callout(
                    title: "Base complementarity",
                    text: "The two strands of DNA are joined by their bases, always paired the same way: **A with T** (two hydrogen bonds), **G with C** (three hydrogen bonds). Knowing one strand therefore means knowing the other.",
                    tone: .definition
                ),
                .paragraph("This rule had been spotted before the structure was understood: in 1950, Erwin Chargaff showed that in the DNA of every species, there is as much adenine as thymine, and as much guanine as cytosine. The proportions of A and G, on the other hand, vary from one species to another."),
                .formula("A = T \\;\\;\\;\\; G = C \\;\\;\\;\\; A + G = T + C", caption: "Chargaff's rules, as base proportions: a consequence of pairing"),
                .paragraph("In 1953, James Watson and Francis Crick proposed the **double helix** model, drawing on the X-ray diffraction images obtained by Rosalind Franklin. The two strands wind around each other like a twisted ladder: the uprights are the sugar-phosphate chains, the rungs are the base pairs. The two strands are ==antiparallel==: they run in opposite directions."),
                .heading("Genes, chromosomes, genome"),
                .paragraph("In a human cell, DNA is divided into **46 chromosomes**, 23 inherited from the mother and 23 from the father. A **gene** is a segment of DNA that carries the information to make a protein; it occupies a precise place on a chromosome, its **locus**. The whole of an organism's DNA is its **genome**: in humans, about 3.2 billion base pairs per set of chromosomes."),
                .bars(title: "Number of protein-coding genes (orders of magnitude)", unit: "thousands", bars: [
                    DemoBar(label: "Bacterium E. coli", value: 4.3),
                    DemoBar(label: "Yeast", value: 6),
                    DemoBar(label: "Fruit fly", value: 14),
                    DemoBar(label: "Worm C. elegans", value: 20),
                    DemoBar(label: "Human", value: 20),
                ]),
                .paragraph("The chart holds a surprise: a one-millimetre worm has roughly as many genes as we do. An organism's complexity therefore does not come from the number of its genes, but from ==the way they are used== — when, where and how much. In humans, protein-coding genes in fact take up only about 1.5% of the genome."),
                .table(title: "The basic vocabulary", headers: ["Word", "Definition"], rows: [
                    ["Gene", "A segment of DNA that codes for a protein"],
                    ["Allele", "A version of a gene, differing in its sequence"],
                    ["Locus", "The location of a gene on a chromosome"],
                    ["Genotype", "The alleles an individual carries"],
                    ["Phenotype", "The observable traits that result"],
                ]),
                .paragraph("These five words come up throughout the rest of the course, and each refers to a different level: the molecule, its variant, its place, what an individual carries, and what we see of them. A phenotype depends on the genotype, but also on the environment: two identical twins have the same genotype, not necessarily the same height."),
            ]),
            DemoChapter(title: "DNA replication", blocks: [
                .paragraph("Before each division, a cell must copy its 3.2 billion base pairs — twice, since it has two sets — to give a complete copy to each of its daughters. This copying is called **replication**, and it is ==almost perfectly== faithful."),
                .heading("A semi-conservative mechanism"),
                .paragraph("The principle follows directly from complementarity. The two strands of the double helix separate, like a zip being opened; each strand then serves as a **template** for building a new strand, by placing opposite each base its complementary base. The result is two molecules identical to the original molecule."),
                .figure(.flow(title: "The steps of replication", steps: ["Helicase opens the double helix", "Each strand serves as a template", "DNA polymerase adds the complementary nucleotides", "Two identical molecules, each with one old strand and one new strand"])),
                .paragraph("Each daughter molecule therefore contains one strand inherited from the parent molecule and one newly synthesised strand: replication is said to be **semi-conservative**. DNA polymerase works in one direction only, extending the new strand from its 5′ end towards its 3′ end, and replication starts at many points at once along each chromosome."),
                .callout(
                    title: "The Meselson–Stahl experiment (1958)",
                    text: "Bacteria grown on heavy nitrogen (¹⁵N) are transferred to light nitrogen (¹⁴N). After one division, all their DNA is of **intermediate** density; after two, half intermediate, half light. Only the semi-conservative model predicts exactly this result.",
                    tone: .example
                ),
                .paragraph("This experiment is a model of scientific method: three hypotheses were possible — conservative, semi-conservative, dispersive —, each predicted a different result, and a single measurement was enough to decide. Remember the reasoning as much as the conclusion: that is what you will be asked to apply in the exam."),
                .keyFigure(value: "1 / 10⁹", label: "the order of magnitude of the error rate per nucleotide copied, once the correction systems have done their work"),
                .paragraph("One error in a billion is roughly one typo for every thousand books copied out. This extraordinary rate is achieved in two stages: DNA polymerase proofreads what it has just written and corrects its own errors, then other enzymes follow behind to repair what escaped that proofreading. But one error in a billion, over six billion bases, still means ==a few errors at every division==."),
                .callout(
                    title: "Don't confuse",
                    text: "Replication copies **DNA into DNA**, in the nucleus, before a division. Transcription, which we will see in the next chapter, copies **a gene into RNA**, at any point in the cell's life. Same principle of complementarity, two different functions.",
                    tone: .warning
                ),
                .list([
                    "Replication: before each division, during the S phase of the cell cycle",
                    "Semi-conservative: each daughter molecule keeps one strand of the parent molecule",
                    "Key enzyme: DNA polymerase, which assembles and proofreads",
                    "Fidelity: about one error per billion nucleotides",
                ]),
                .paragraph("These residual errors are not just a flaw. It is they, accumulated over generations, that produce new alleles, and therefore the diversity on which evolution acts. A perfect copying system would give frozen species: it is ==the imperfection of replication== that makes evolution possible."),
            ]),
            DemoChapter(title: "From gene to protein", blocks: [
                .paragraph("DNA stays in the nucleus, but proteins are made in the cytoplasm. An intermediary is therefore needed to copy the information and carry it: this is **messenger RNA**. A gene is expressed in two steps, ==menthe|transcription== then ==bleu|translation==."),
                .figure(.flow(title: "Gene expression", steps: ["DNA (the gene, in the nucleus)", "Transcription: messenger RNA", "The mRNA leaves the nucleus", "Translation by the ribosomes", "Protein"])),
                .paragraph("**Transcription** takes place in the nucleus. RNA polymerase opens the double helix at a gene and makes a copy of only one of the two strands, the template strand, by complementarity. The resulting molecule is an RNA: it resembles DNA, with three differences."),
                .figure(.split(
                    title: "DNA and RNA",
                    left: DemoColumn(title: "DNA", items: ["Two strands", "Sugar: deoxyribose", "Bases A, T, G, C", "Very long, in the nucleus", "Stable, preserved"]),
                    right: DemoColumn(title: "Messenger RNA", items: ["A single strand", "Sugar: ribose", "Bases A, U, G, C", "Short: one gene", "Short-lived, destroyed after use"])
                )),
                .paragraph("The most useful difference in exercises is the bases: in RNA, **uracil (U) replaces thymine**. Opposite an A on the template strand, RNA polymerase therefore places a U. The mRNA sequence is thus identical to that of the non-template strand of DNA, called the coding strand, except that its Ts become Us."),
                .heading("The genetic code"),
                .paragraph("**Translation** takes place in the cytoplasm, on the ribosomes. There the mRNA is read in groups of three nucleotides, the **codons**; each codon corresponds to an amino acid, and the amino acids are linked together to form the protein. The correspondence between codons and amino acids is the **genetic code**."),
                .formula("4^3 = 64 \\text{ codons} \\;\\; \\text{for} \\;\\; 20 \\text{ amino acids}", caption: "Four bases, three positions: more than enough for twenty amino acids"),
                .paragraph("There are therefore more codons than amino acids: 61 codons specify an amino acid, and 3 are **stop** codons that end translation. Several codons can code for the same amino acid — the code is said to be **redundant** —, but a codon never codes for more than one amino acid. Translation always begins at the AUG codon, which codes for methionine."),
                .table(title: "Some mRNA codons", headers: ["Codon", "Amino acid"], rows: [
                    ["AUG", "Methionine (start codon)"],
                    ["GCA", "Alanine"],
                    ["UGG", "Tryptophan"],
                    ["GAG", "Glutamic acid"],
                    ["GUG", "Valine"],
                    ["UAA, UAG, UGA", "Stop"],
                ]),
                .paragraph("The table already shows the redundancy: GAG and GAA both code for glutamic acid, and we will see in the last chapter that a single letter change — GAG becoming GUG — is enough to replace this amino acid with a valine. To translate a messenger RNA, always proceed in the same order: find the AUG codon, split into triplets, then read the table until the first stop codon."),
                .callout(
                    title: "Complete example",
                    text: "DNA coding strand: 5′-ATG GCA TGG-3′. Messenger RNA: 5′-AUG GCA UGG-3′ (replace T with U). Protein: **Met – Ala – Trp**. Always read codon by codon, starting from the start codon, with no overlap.",
                    tone: .example
                ),
                .paragraph("The genetic code is ==universal==: with rare exceptions, the same codon specifies the same amino acid in a bacterium, an oak tree and a human being. This is a strong argument for a common origin of all living things — and it is what makes it possible to have bacteria produce human insulin, simply by giving them the gene."),
            ]),
            DemoChapter(title: "Mutations and heredity", blocks: [
                .paragraph("A **mutation** is a change in the DNA sequence. It can be spontaneous — an uncorrected replication error — or caused by a **mutagen**: UV rays, X-rays, certain chemicals such as those in tobacco smoke. Not all mutations are equal, and their effect depends on ==where they occur==."),
                .heading("Types of mutations"),
                .table(title: "Point mutations and their consequences", headers: ["Type", "What changes", "Effect on the protein"], rows: [
                    ["Silent substitution", "One base, but the same amino acid", "None, thanks to the redundancy of the code"],
                    ["Missense substitution", "One base, a different amino acid", "Variable: none to severe"],
                    ["Nonsense substitution", "A codon becomes a stop codon", "Truncated protein, often inactive"],
                    ["Insertion or deletion", "One base more or less", "Frameshift: protein badly altered"],
                ]),
                .paragraph("Sickle cell disease is the most studied example. In the haemoglobin gene, the sixth codon changes from GAG to GTG: a single base changes, and glutamic acid is replaced by valine. This abnormal haemoglobin polymerises when short of oxygen, and deforms red blood cells into a sickle shape."),
                .callout(
                    title: "One mutation, two effects",
                    text: "People who carry two mutated alleles are ill; those who carry only one are healthy, and are also **better protected against malaria**. That is why the allele is common in sub-Saharan Africa: where malaria is rife, it gives its carriers an advantage.",
                    tone: .insight
                ),
                .paragraph("Only mutations affecting the reproductive cells — **germline mutations** — are passed on to offspring. A mutation in a skin cell, called **somatic**, concerns only the individual and the cells descended from the one that mutated: it can cause cancer, but not an inherited disease."),
                .heading("Mendel's laws"),
                .paragraph("In 1865, the monk Gregor Mendel published the results of eight years of crossing peas. He crossed pure lines with round seeds with pure lines with wrinkled seeds: the whole first generation (F1) had round seeds. Then he crossed these hybrids with each other: in the second generation (F2), the wrinkled trait reappeared, in a remarkably stable proportion."),
                .bars(title: "Mendel's seeds in the second generation", unit: "seeds", bars: [
                    DemoBar(label: "Round", value: 5474),
                    DemoBar(label: "Wrinkled", value: 1850),
                ]),
                .paragraph("The ratio is $5474 / 1850 \\approx 2.96$, almost exactly **three to one**. Mendel explained it with a hypothesis that was bold for its time: each individual has two “factors” for a trait — we say two ==alleles== —, passes only one to each gamete, and the round allele (R) is **dominant** over the wrinkled allele (r), which is **recessive**."),
                .table(title: "Punnett square: Rr × Rr", headers: ["", "Gamete R", "Gamete r"], rows: [
                    ["Gamete R", "RR (round)", "Rr (round)"],
                    ["Gamete r", "Rr (round)", "rr (wrinkled)"],
                ]),
                .paragraph("Each square has a probability of one quarter. We get the genotypes RR, Rr and rr in proportions 1/4, 1/2 and 1/4, and therefore the round and wrinkled phenotypes in proportions 3/4 and 1/4. Only **homozygous** rr individuals express the recessive trait; **heterozygous** Rr individuals carry it without showing it."),
                .formula("P(rr) = \\frac{1}{2} \\times \\frac{1}{2} = \\frac{1}{4}", caption: "Each heterozygous parent passes on r with probability 1/2, independently of the other"),
                .paragraph("The same reasoning applies to recessive human diseases, such as **cystic fibrosis**: two healthy carrier parents, both heterozygous, have at each pregnancy a probability of 1/4 of having an affected child. “At each pregnancy” is essential: ==chance has no memory==, and having had one affected child does not protect the next."),
                .timeline(title: "Key milestones in genetics", events: [
                    DemoEvent(date: "1865", label: "Mendel publishes his laws of heredity"),
                    DemoEvent(date: "1944", label: "Avery shows that DNA carries hereditary information"),
                    DemoEvent(date: "1953", label: "Watson, Crick and Franklin: the double helix"),
                    DemoEvent(date: "1966", label: "The genetic code fully deciphered"),
                    DemoEvent(date: "2003", label: "Complete sequence of the human genome"),
                    DemoEvent(date: "2012", label: "Charpentier and Doudna: the CRISPR-Cas9 tool"),
                ]),
                .paragraph("A hundred and fifty years separate Mendel's peas from the molecular scissors that now make it possible to edit a specific gene. Each step answered a question left open by the previous one: what is passed on, what it is made of, how it is copied, how it is read — and now, ==how to correct it==."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "How do the bases of DNA pair up between the two strands?",
                back: "Adenine with thymine (A–T, two hydrogen bonds) and guanine with cytosine (G–C, three hydrogen bonds). One strand therefore entirely determines the other.",
                figure: .split(
                    title: "Complementarity",
                    left: DemoColumn(title: "Strand 1", items: ["A", "G", "T", "C"]),
                    right: DemoColumn(title: "Strand 2", items: ["T", "C", "A", "G"])
                ),
                chapter: 0
            ),
            DemoCard(
                kind: .choice,
                front: "What messenger RNA is transcribed from the coding strand 5′-ATG GCA TGG-3′?",
                back: "5′-AUG GCA UGG-3′: the mRNA has the sequence of the coding strand, with U in place of T. It is translated into Met – Ala – Trp.",
                choices: ["5′-UAC CGU ACC-3′", "5′-AUG GCA UGG-3′", "5′-TAC CGT ACC-3′", "5′-ATG GCA TGG-3′"],
                answerIndex: 1,
                chapter: 2
            ),
            DemoCard(
                kind: .cloze,
                front: "DNA replication is called …, because each daughter molecule keeps one strand of the parent molecule.",
                back: "semi-conservative",
                chapter: 1
            ),
            DemoCard(kind: .basic, front: "What is the difference between a gene and an allele?", back: "A gene is a segment of DNA, at a given locus, that codes for a protein. An allele is one of the versions of that gene, differing from the others in its sequence.", chapter: 0),
            DemoCard(kind: .choice, front: "How many different codons are there?", back: "64 = 4³: four possible bases at each of the three positions. 61 code for an amino acid, 3 are stop codons.", choices: ["20", "46", "61", "64"], answerIndex: 3, chapter: 2),
            DemoCard(kind: .cloze, front: "In RNA, thymine is replaced by … .", back: "uracil", chapter: 2),
            DemoCard(kind: .basic, front: "What does the Meselson–Stahl experiment show?", back: "That replication is semi-conservative: after one division in a ¹⁴N medium, all the DNA is of intermediate density; after two, half intermediate, half light.", hint: "Think about the densities after one and then two divisions.", chapter: 1),
            DemoCard(kind: .choice, front: "Which mutation shifts the reading frame?", back: "The insertion or deletion of a base: all the codons after it are changed, and the protein is badly altered.", choices: ["A silent substitution", "A missense substitution", "A deletion of one base", "A nonsense substitution"], answerIndex: 2, chapter: 3),
            DemoCard(kind: .cloze, front: "Two heterozygous Rr parents have, at each birth, a probability of … of having an rr child.", back: "1/4", chapter: 3),
            DemoCard(kind: .basic, front: "Why is the sickle cell allele common where malaria is rife?", back: "Because heterozygotes, who carry a single mutated allele, are healthy and better protected against malaria: natural selection maintains the allele.", chapter: 3),
            DemoCard(kind: .cloze, front: "According to Chargaff's rules, in double-stranded DNA, the percentage of guanine equals that of … .", back: "cytosine", chapter: 0),
            DemoCard(kind: .choice, front: "Where does translation take place?", back: "In the cytoplasm, on the ribosomes, which read the messenger RNA codon by codon.", choices: ["In the nucleus", "On the ribosomes of the cytoplasm", "In the mitochondria", "On the plasma membrane"], answerIndex: 1, chapter: 2),
        ]
    )

    // MARK: Mathematics: probability

    private static let probabilityEN = OnboardingDemoCourse(
        id: "debug-probability",
        emoji: "🎲",
        subject: "Mathématiques",
        title: "Probability",
        summary: "The vocabulary of events, conditional probability and trees, independence, then random variables, expectation and the binomial distribution.",
        accentIndex: 0,
        chapters: [
            DemoChapter(title: "The language of probability", blocks: [
                .paragraph("Probability measures ==the degree of certainty== of an event whose outcome is not known in advance: a roll of a die, a draw, the result of a test. It does not predict what will happen; it says, precisely, how likely each outcome is."),
                .heading("Experiment, sample space, event"),
                .paragraph("A **random experiment** is one whose possible results are all known, without being able to predict which one will occur. Each result is an **outcome**; the set of outcomes is the **sample space**, written $\\Omega$. For a six-sided die, $\\Omega$ = {1, 2, 3, 4, 5, 6}."),
                .callout(
                    title: "Event",
                    text: "An **event** is a subset of the sample space, that is, a set of outcomes. “Rolling an even number” is the event $A$ = {2, 4, 6}. It occurs if the outcome obtained belongs to it.",
                    tone: .definition
                ),
                .paragraph("Events are combined like sets. The **intersection** $A \\cap B$ (“A and B”) occurs when both do; the **union** $A \\cup B$ (“A or B”) when at least one of them does; the **complement** $Ā$ when $A$ does not. Two events are **mutually exclusive** if they cannot occur together: $A \\cap B = \\emptyset$."),
                .heading("Calculating a probability"),
                .paragraph("When all outcomes are equally likely — we speak of **equiprobability** —, the probability of an event is the number of favourable outcomes divided by the number of possible outcomes. This is Laplace's formula, and it holds ==only in that case==: a loaded die or an uneven wheel calls for another method."),
                .formula("P(A) = \\frac{\\text{number of favourable outcomes}}{\\text{number of possible outcomes}}", caption: "Only when outcomes are equally likely"),
                .paragraph("Let's roll two dice and look at the sum. There are $6 \\times 6 = 36$ equally likely pairs, but the sums are not: only one way to get 2 (1 and 1), six ways to get 7. The chart gives, for each sum, the number of pairs that produce it."),
                .bars(title: "Sum of two dice: number of pairs out of 36", unit: nil, bars: [
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
                .paragraph("We read that $P(\\text{sum} = 7) = 6/36 = 1/6$, and $P(\\text{sum} = 2) = 1/36$. The classic mistake is to reason on the eleven possible sums as if they were equally likely, which would give 1/11 to each. ==Always count equally likely outcomes==, here the pairs, and never results that are not."),
                .table(title: "Properties to know", headers: ["Property", "Formula"], rows: [
                    ["Bounds", "0 ≤ P(A) ≤ 1"],
                    ["Sample space", "P(Ω) = 1"],
                    ["Complement", "P(Ā) = 1 − P(A)"],
                    ["Union", "P(A ∪ B) = P(A) + P(B) − P(A ∩ B)"],
                    ["Mutually exclusive", "P(A ∪ B) = P(A) + P(B)"],
                ]),
                .paragraph("The union formula subtracts $P(A \\cap B)$ because the shared outcomes were counted twice. And switching to the complement is often the most efficient shortcut: for “at least one six in four rolls”, it is much simpler to calculate “no six”, that is $(5/6)^4 \\approx 0.48$, then take the complement: $1 - 0.48 \\approx 0.52$."),
                .callout(
                    title: "The “at least one” reflex",
                    text: "Whenever a problem says “at least one”, think of the complement: “none”. It is almost always a single product to calculate, instead of a long sum of cases.",
                    tone: .insight
                ),
            ]),
            DemoChapter(title: "Conditional probability and trees", blocks: [
                .paragraph("New information changes probabilities. Knowing that a test is positive changes the probability of being ill; knowing that the die landed on an even number changes the probability of having rolled a 2. **Conditional probability** measures the probability of an event ==given that another has occurred==."),
                .callout(
                    title: "Conditional probability",
                    text: "If $P(A) \\neq 0$, the probability of $B$ given $A$ is $P(B | A) = \\frac{P(A \\cap B)}{P(A)}$, which textbooks also write P_A(B). We restrict the sample space to the outcomes of $A$ alone, and look at what share of them also make $B$ occur.",
                    tone: .definition
                ),
                .paragraph("Example: we roll a die and learn that the result is even. The probability that it is a 2 is no longer 1/6, but $\\frac{1/6}{1/2} = \\frac{1}{3}$: only three possible outcomes remain, 2, 4 and 6. The formula can also be turned around, and this is the form used on trees: $P(A \\cap B) = P(A) \\times P(B | A)$."),
                .heading("The probability tree"),
                .paragraph("A **probability tree** represents an experiment in several stages. Each branch carries a probability; the branches leaving the same node add up to 1; the probability of a path is the product of the probabilities of its branches. And when an event lies at the end of several paths, we add them."),
                .figure(.flow(title: "Reading a probability tree", steps: ["First stage: A or Ā", "Second stage: B or B̄, given the first", "One path: multiply the branches", "Several paths to B: add them up"])),
                .paragraph("The last step has a name: the **law of total probability**. If $A$ and $Ā$ split the sample space in two, then $B$ occurs either with $A$ or with $Ā$, and these two cases are mutually exclusive. We therefore add the two paths leading to $B$."),
                .formula("P(B) = P(A) \\times P(B | A) + P(Ā) \\times P(B | Ā)", caption: "The law of total probability, for a partition into A and Ā"),
                .heading("A screening test"),
                .paragraph("A disease affects 1% of the population. A test detects it in 99% of those who are ill, but it is also positive in 2% of healthy people. A person tests positive: what is the probability that they are ill? Intuition says “99%”. The calculation says something else entirely. Imagine 10,000 people tested."),
                .table(title: "10,000 people tested", headers: ["", "Positive test", "Negative test", "Total"], rows: [
                    ["Ill", "99", "1", "100"],
                    ["Healthy", "198", "9,702", "9,900"],
                    ["Total", "297", "9,703", "10,000"],
                ]),
                .paragraph("Of the 297 positives, only 99 are ill. With the tree and the formulas: $P(+) = 0.01 \\times 0.99 + 0.99 \\times 0.02 = 0.0297$, then $P(M | +) = \\frac{0.0099}{0.0297} = \\frac{1}{3}$. The false positives, drawn from a healthy population a hundred times larger, ==drown out the true positives==."),
                .keyFigure(value: "33%", label: "the probability of being ill when the test is positive, despite a test that is 99% reliable in those who are ill"),
                .paragraph("The result depends less on the quality of the test than on the rarity of the disease. If it affected 10% of the population, the same test would give $P(M | +) = \\frac{0.099}{0.099 + 0.018} \\approx 0.85$. A conditional probability is always calculated ==with the starting probability==: forgetting the prevalence means forgetting the first branch of the tree."),
                .callout(
                    title: "Don't reverse them",
                    text: "$P(+ | M)$ and $P(M | +)$ are not the same thing: the first is 0.99, the second about 0.33. Confusing “the probability of a positive test given that one is ill” with “the probability of being ill given that the test is positive” is the most widespread mistake, including among doctors.",
                    tone: .warning
                ),
                .paragraph("This is why a positive result in mass screening is always confirmed by a second, more precise test. Calculating a “reversed” probability from the tree is called **Bayes' formula**, after the English minister who stated it in the eighteenth century."),
            ]),
            DemoChapter(title: "Independence", blocks: [
                .paragraph("Two events are independent when knowing that one has occurred ==changes nothing== about the probability of the other. The result of a coin toss does not depend on the previous toss; eye colour does not depend on the day of birth."),
                .formula("A \\text{ and } B \\text{ independent} \\Leftrightarrow P(A \\cap B) = P(A) \\times P(B)", caption: "The definition, equivalent to P(B | A) = P(B) when P(A) ≠ 0"),
                .paragraph("Independence is checked by calculation, never by intuition. Let's roll a die: let $A$ = “even” = {2, 4, 6} and $B$ = “at most 2” = {1, 2}. We have $P(A) = 1/2$, $P(B) = 1/3$, and $A \\cap B$ = {2}, so $P(A \\cap B) = 1/6$. Since $\\frac{1}{2} \\times \\frac{1}{3} = \\frac{1}{6}$, the two events are independent — which was not obvious to the naked eye."),
                .figure(.split(
                    title: "Two notions not to confuse",
                    left: DemoColumn(title: "Mutually exclusive", items: ["Cannot happen together", "A ∩ B = ∅", "P(A ∩ B) = 0", "A set-theory notion"]),
                    right: DemoColumn(title: "Independent", items: ["One tells nothing about the other", "P(A ∩ B) = P(A) × P(B)", "Checked by calculation", "A probability notion"])
                )),
                .paragraph("The two notions are in fact almost opposites: if $A$ and $B$ are mutually exclusive with non-zero probabilities, knowing that $A$ has occurred tells us for certain that $B$ has not. They are therefore ==highly dependent==. “Heads” and “tails” on the same toss are mutually exclusive; “heads” on the first toss and “tails” on the second are independent."),
                .heading("Repeating an experiment"),
                .paragraph("When an experiment is repeated under the same conditions — tossing a coin several times, drawing with replacement —, the successive results are independent, and the probability of a sequence of results is the product of the probabilities of each. Getting “heads” three times with a fair coin: $\\left(\\frac{1}{2}\\right)^3 = \\frac{1}{8}$."),
                .callout(
                    title: "The gambler's fallacy",
                    text: "After ten “reds” in a row at roulette, “black” is not “due”: the spins are independent, the wheel has no memory, and the probability of black on the next spin is exactly the same as on the first.",
                    tone: .warning
                ),
                .paragraph("Yet this is what, in the long run, vindicates our intuition about frequencies. The **law of large numbers**, proved by Jacob Bernoulli in 1713, states that over a very large number of independent repetitions, the frequency of an event approaches its probability. Not because deviations “catch up”, but because they become negligible compared with the total number of trials."),
                .timeline(title: "A brief history of probability", events: [
                    DemoEvent(date: "1654", label: "Pascal and Fermat solve the problem of points"),
                    DemoEvent(date: "1713", label: "Jacob Bernoulli: the law of large numbers"),
                    DemoEvent(date: "1763", label: "Posthumous publication of Bayes' formula"),
                    DemoEvent(date: "1812", label: "Laplace, Analytical Theory of Probability"),
                    DemoEvent(date: "1933", label: "Kolmogorov founds probability on axioms"),
                ]),
                .paragraph("The discipline was born from a gamblers' question: how to share fairly the stakes of an interrupted game? Three centuries later, it is used to evaluate a medicine, set an insurance premium, transmit a signal without error. The method has not changed: ==count, condition, multiply, add==."),
            ]),
            DemoChapter(title: "Random variables and the binomial distribution", blocks: [
                .paragraph("Often, what matters is not the outcome itself, but a number that depends on it: the winnings of a game, the number of correct answers, the number of defective parts. A **random variable** assigns a real number to each outcome, and its **distribution** gives the probability of each of its values."),
                .heading("Expectation"),
                .paragraph("A game: you bet €2, roll a die, and receive €10 if you get a 6. Let $X$ be the net gain. If the 6 comes up, $X = 10 - 2 = 8$; otherwise, $X = -2$. The distribution of $X$ fits in a two-column table."),
                .table(title: "Distribution of the net gain X", headers: ["Value of X", "−€2", "€8"], rows: [
                    ["Probability", "5/6", "1/6"],
                ]),
                .paragraph("The **expectation** is the average of the values weighted by their probabilities: it is the average gain per game if you played a very large number of times. Here $E(X) = -2 \\times \\frac{5}{6} + 8 \\times \\frac{1}{6} = \\frac{-10 + 8}{6} = -\\frac{1}{3}$. The player loses on average about 33 cents per game: the game is ==unfavourable==."),
                .formula("E(X) = \\sum_{i} x_i \\, P(X = x_i) \\;\\;\\;\\; V(X) = \\sum_{i} P(X = x_i)\\,(x_i - E(X))^2", caption: "Expectation measures the centre, variance the spread around it"),
                .paragraph("The **variance** measures how far the values stray from the expectation, and the **standard deviation** $\\sigma(X) = \\sqrt{V(X)}$ brings that measure back into the unit of $X$. Two games with the same expectation can be very different: one almost always pays the same small sum, the other nothing most of the time and a lot on rare occasions."),
                .heading("The binomial distribution"),
                .callout(
                    title: "Bernoulli scheme",
                    text: "A trial with two outcomes — success, with probability $p$, or failure — is repeated $n$ times, **independently**. The number $X$ of successes follows the **binomial distribution** $B(n, p)$.",
                    tone: .definition
                ),
                .formula("P(X = k) = \\binom{n}{k}\\, p^k \\,(1-p)^{n-k}", caption: "The binomial coefficient counts the paths in the tree that lead to k successes"),
                .paragraph("The formula can be read off the tree: each path with $k$ successes and $n - k$ failures has probability $p^k (1-p)^{n-k}$, and the number of these paths is the binomial coefficient “$n$ choose $k$”. Example: a multiple-choice test of 10 questions with 4 options, filled in entirely at random. The number of correct answers follows $B(10\\,;\\,0.25)$, whose distribution is shown here."),
                .bars(title: "Distribution of B(10, 0.25): probability of k correct answers", unit: "%", bars: [
                    DemoBar(label: "k = 0", value: 5.6),
                    DemoBar(label: "k = 1", value: 18.8),
                    DemoBar(label: "k = 2", value: 28.2),
                    DemoBar(label: "k = 3", value: 25.0),
                    DemoBar(label: "k = 4", value: 14.6),
                    DemoBar(label: "k = 5", value: 5.8),
                    DemoBar(label: "k = 6", value: 1.6),
                    DemoBar(label: "k = 7", value: 0.3),
                ]),
                .paragraph("The distribution peaks around 2 or 3 correct answers, and collapses beyond that. Getting a pass mark, 5 out of 10, by answering at random happens with a probability of only about ==7.8%==; getting nothing right, $0.75^{10} \\approx 5.6\\,\\%$. For a binomial distribution, expectation and variance have direct formulas."),
                .formula("E(X) = np \\;\\;\\;\\; V(X) = np(1-p)", caption: "Here: E(X) = 10 × 0.25 = 2.5 and V(X) = 2.5 × 0.75 = 1.875"),
                .keyFigure(value: "2.5", label: "correct answers on average out of 10 four-option questions, answering at random"),
                .paragraph("The standard deviation is $\\sqrt{1.875} \\approx 1.37$: most candidates who answer at random get between 1 and 4 correct answers. That is exactly what the chart showed, and it is why some multiple-choice tests deduct points for each wrong answer — enough to bring the expected score from guessing down to zero."),
                .callout(
                    title: "Method: justifying a binomial distribution",
                    text: "Three points to write down, every time: 1. a trial with **two outcomes** (success with probability $p$); 2. repeated $n$ times in an **identical and independent** way; 3. $X$ counts the **number of successes**. Without these three sentences, the answer is incomplete.",
                    tone: .insight
                ),
                .paragraph("The second point is the one people forget: drawing **without replacement** from a small urn is not an independent repetition, and the binomial distribution does not apply. Checking the assumptions before applying the formula makes ==all the difference== between a correct calculation and one that only looks correct."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "How do you calculate the probability of an event at the end of several paths in a probability tree?",
                back: "Multiply the probabilities along each path, then add the results of the paths that lead to the event: this is the law of total probability.",
                figure: .flow(title: "Reading a tree", steps: ["Multiply along a path", "Add the paths"]),
                chapter: 1
            ),
            DemoCard(
                kind: .choice,
                front: "Two fair dice are rolled. What is the probability that the sum is 7?",
                back: "1/6: six pairs out of 36 give 7 — (1,6), (2,5), (3,4), (4,3), (5,2), (6,1).",
                choices: ["1/11", "1/12", "1/6", "7/36"],
                answerIndex: 2,
                chapter: 0
            ),
            DemoCard(
                kind: .cloze,
                front: "Two events A and B are independent if and only if $P(A \\cap B) = $ … .",
                back: "$P(A) \\times P(B)$",
                chapter: 2
            ),
            DemoCard(kind: .basic, front: "What is the formula for the probability of B given A?", back: "$P(B | A) = \\frac{P(A \\cap B)}{P(A)}$, for $P(A) \\neq 0$.", chapter: 1),
            DemoCard(kind: .choice, front: "A disease affects 1% of the population; a test is positive in 99% of those who are ill and in 2% of healthy people. What is the probability of being ill if the test is positive?", back: "About 1/3: $\\frac{0.01 \\times 0.99}{0.01 \\times 0.99 + 0.99 \\times 0.02} = \\frac{0.0099}{0.0297}$.", hint: "Imagine 10,000 people tested.", choices: ["99%", "98%", "About 33%", "1%"], answerIndex: 2, chapter: 1),
            DemoCard(kind: .cloze, front: "The probability of the complementary event is $P(Ā) = $ … .", back: "$1 - P(A)$", chapter: 0),
            DemoCard(kind: .basic, front: "What is the difference between two mutually exclusive events and two independent events?", back: "Mutually exclusive: they cannot occur together ($A \\cap B = \\emptyset$). Independent: one occurring does not change the probability of the other ($P(A \\cap B) = P(A)P(B)$). Two mutually exclusive events with non-zero probabilities are never independent.", chapter: 2),
            DemoCard(kind: .choice, front: "What is the expectation of a random variable following the binomial distribution $B(n, p)$?", back: "$E(X) = np$. Its variance is $np(1-p)$.", choices: ["$p$", "$np$", "$np(1-p)$", "$n/p$"], answerIndex: 1, chapter: 3),
            DemoCard(kind: .basic, front: "What conditions must be checked to state that a variable follows a binomial distribution?", back: "A trial with two outcomes (success with probability p), repeated n times in an identical and independent way, and a variable X that counts the number of successes.", chapter: 3),
            DemoCard(kind: .cloze, front: "To calculate the probability of getting “at least one” success, go through the complementary event: “…”.", back: "none", chapter: 0),
            DemoCard(kind: .choice, front: "You bet €2 and receive €10 if the die shows 6. What is the expected net gain?", back: "$-2 \\times \\frac{5}{6} + 8 \\times \\frac{1}{6} = -\\frac{1}{3}$, an average loss of about €0.33 per game.", choices: ["$-\\frac{1}{3}$ €", "0 €", "$\\frac{1}{3}$ €", "$\\frac{5}{3}$ €"], answerIndex: 0, chapter: 3),
            DemoCard(kind: .cloze, front: "The law of … states that the frequency of an event approaches its probability as the number of repetitions becomes very large.", back: "large numbers", chapter: 2),
        ]
    )

    // MARK: Economics: supply and demand

    private static let supplyDemandEN = OnboardingDemoCourse(
        id: "debug-supply-demand",
        emoji: "⚖️",
        subject: "Économie",
        title: "Supply and demand",
        summary: "How a market sets a price: supply and demand curves, equilibrium, what shifts it, elasticity, and what state intervention changes.",
        accentIndex: 5,
        chapters: [
            DemoChapter(title: "The market and demand", blocks: [
                .paragraph("Why does a strawberry cost three times as much in March as in June? Nobody decided that price: it results from millions of buying and selling decisions meeting. The supply and demand model explains ==how a market sets a price== without anyone setting it."),
                .heading("What is a market?"),
                .callout(
                    title: "Market",
                    text: "The place, physical or not, where the **supply** (what sellers offer) and the **demand** (what buyers wish to acquire) of a good or service meet, and where its **price** is formed.",
                    tone: .definition
                ),
                .paragraph("A market is not necessarily a place: the labour market, the foreign exchange market or the property market have no market hall. To reason, economists start from an ideal case, **perfect competition**, where no player has enough weight to impose its price. It rests on five conditions."),
                .list([
                    "Atomicity: many buyers and sellers, each too small to influence the price",
                    "Homogeneity: all sellers offer the same product",
                    "Transparency: everyone knows the prices and the quality",
                    "Free entry: anyone can enter or leave the market",
                    "Free movement of factors of production: labour and capital go where they earn the most",
                ]),
                .paragraph("No real market perfectly meets these five conditions, and that is not the point: the model serves as a ==benchmark==. A wholesale market for farm produce comes close; a market dominated by three phone operators falls far short, and that is precisely what we measure by comparing it with the model."),
                .heading("Demand"),
                .paragraph("**Demand** is the quantity of a good that buyers wish to acquire at each possible price. It obeys an almost universal law: when the price rises, the quantity demanded falls. There are two reasons for this. The **substitution effect**: the good becomes more expensive than its competitors, so people switch to them. The **income effect**: with the same budget, you can buy less of it."),
                .formula("Q_d = 120 - 20\\,p", caption: "A linear demand: quantity demanded (in thousands) as a function of the price p (in euros)"),
                .paragraph("This function will serve as an example throughout the course: imagine the weekly market for a cheese in one region, in thousands of units. At €1, buyers want 100,000; at €5, only 20,000. Each extra euro makes 20,000 buyers give up. Plotted with the price on the vertical axis, it is a **downward-sloping** straight line: the demand curve."),
                .callout(
                    title: "The vocabulary trap",
                    text: "When the price of a good changes, we **move along** its demand curve: it is the *quantity demanded* that varies. When something else changes — income, tastes, the price of another good —, **the whole curve shifts**: it is *demand* that varies.",
                    tone: .warning
                ),
                .paragraph("This distinction is the source of most mistakes in exercises. “Demand falls because the price rises” is wrong: it is the quantity demanded that falls. Demand itself falls when incomes decrease, when a competing product becomes cheaper, or when a study reveals a health risk."),
                .timeline(title: "The fathers of the model", events: [
                    DemoEvent(date: "1776", label: "Adam Smith, The Wealth of Nations: the “invisible hand”"),
                    DemoEvent(date: "1838", label: "Antoine-Augustin Cournot draws the first demand curve"),
                    DemoEvent(date: "1874", label: "Léon Walras, general equilibrium theory"),
                    DemoEvent(date: "1890", label: "Alfred Marshall crosses supply and demand"),
                ]),
                .paragraph("Marshall compared supply and demand to the two blades of a pair of scissors: asking which one cuts the paper makes no sense, and neither does asking whether supply or demand sets the price. It is ==their meeting== that determines it, and that is the subject of the next chapter."),
            ]),
            DemoChapter(title: "Supply and equilibrium", blocks: [
                .paragraph("Facing the buyers are the producers. **Supply** is the quantity they are willing to sell at each possible price, and it obeys the opposite law to demand: the higher the price, the more they want to sell. A higher price makes it profitable to produce more, and attracts new producers."),
                .heading("The supply curve"),
                .paragraph("Why does it take a higher price to produce more? Because producing each additional unit costs more and more in the short run: overtime, machines pushed beyond their normal pace, raw materials that are harder to obtain. A producer agrees to produce one more unit only if the price covers this rising **marginal cost**."),
                .formula("Q_s = 20\\,p", caption: "Supply in the same market: quantity supplied (in thousands) as a function of the price p"),
                .paragraph("In the short run, supply even ends up hitting a wall: production capacity. A cheese dairy cannot produce more than its vats and its milk allow, whatever the price. The quantity supplied first rises quickly with the price, then less and less, up to a ceiling."),
                .figure(.plot(title: "Short-run supply levels off", caption: "Price on the horizontal axis, quantity supplied on the vertical axis: it rises with the price, then hits production capacity.", kind: .saturation)),
                .paragraph("That is why a sudden rise in demand first pushes up prices more than quantities: producers cannot keep up right away. In the long run, they invest, new producers arrive, and the ceiling rises. In our example, we stay in the zone where supply is a straight line."),
                .heading("Equilibrium"),
                .paragraph("Let's put the two sides of the market face to face. For each price, we compare the quantity buyers want with the quantity sellers offer. The table reads row by row, and only one row makes the two match."),
                .table(title: "The cheese market, price by price", headers: ["Price", "Demand (thousands)", "Supply (thousands)", "Situation"], rows: [
                    ["€1", "100", "20", "Shortage of 80"],
                    ["€2", "80", "40", "Shortage of 40"],
                    ["€3", "60", "60", "Equilibrium"],
                    ["€4", "40", "80", "Surplus of 40"],
                    ["€5", "20", "100", "Surplus of 80"],
                ]),
                .paragraph("The **equilibrium price** is the one at which the quantity supplied equals the quantity demanded. Graphically, it is the point where the two curves intersect; algebraically, it is the solution of a linear equation."),
                .formula("120 - 20\\,p = 20\\,p \\;\\Rightarrow\\; p^* = 3 \\text{ €} \\;\\text{ and }\\; Q^* = 60", caption: "Equilibrium: supply equals demand"),
                .paragraph("At a price of €3, 60,000 cheeses are sold each week, and everyone is satisfied: all the buyers willing to pay €3 are served, all the sellers willing to sell at €3 have sold their output. There is ==neither a queue nor unsold stock==."),
                .keyFigure(value: "€3", label: "the equilibrium price, the only one at which 60,000 cheeses find both a seller and a buyer"),
                .paragraph("This price is not just a point on a graph: it is the one the market returns to on its own. If the price is too low, buyers compete for scarce goods and bid it up; if it is too high, sellers are left with unsold stock and lower it. The mechanism unfolds in four stages."),
                .figure(.flow(title: "Returning to equilibrium from a price that is too low", steps: ["Price at €2: shortage of 40,000", "Buyers outbid each other, the price rises", "Quantity demanded falls, supply increases", "The shortage disappears at €3"])),
                .paragraph("The mechanism is symmetrical from a price that is too high: at €4, sellers have 40,000 unsold units, they lower their prices to shift them, and the market comes back down towards €3. In both cases, it is the gaps between supply and demand that move the price, and their disappearance that stops it."),
                .callout(
                    title: "The invisible hand",
                    text: "Adam Smith's phrase refers to this mechanism: each person pursues their own interest — the buyer to pay less, the seller to earn more —, and the price adjusts until it coordinates their decisions, **without any planner stepping in**. The price is a signal: it tells producers what to produce and consumers what to save on.",
                    tone: .insight
                ),
                .paragraph("The mechanism has a surprising consequence: ==a shortage is a symptom of a price that is too low==, not of production that is too weak. This is what we see whenever a price is held below equilibrium, and it is what the last chapter will study."),
            ]),
            DemoChapter(title: "When the equilibrium shifts", blocks: [
                .paragraph("Equilibrium lasts only as long as nothing changes. But everything changes: incomes, tastes, costs, the weather. Each time, one of the curves shifts, and the market finds ==a new equilibrium==, with a different price and a different quantity."),
                .figure(.split(
                    title: "What shifts the curves",
                    left: DemoColumn(title: "Demand", items: ["Household income", "Price of substitute goods", "Price of complementary goods", "Tastes, fashions, information", "Size of the population"]),
                    right: DemoColumn(title: "Supply", items: ["Cost of raw materials", "Wages, energy", "Technical progress", "Number of producers", "Weather, taxes, subsidies"])
                )),
                .paragraph("The method of analysis is always the same, in three questions: which curve shifts? In which direction? What happens to the equilibrium price and quantity? If demand increases, the price and the quantity both rise. If supply decreases, the price rises but the quantity falls."),
                .callout(
                    title: "A frost in Brazil",
                    text: "Brazil produces more than a third of the world's coffee. When a frost destroys part of the harvest, the **supply** of coffee decreases: its curve shifts to the left. At the new equilibrium, the price of coffee rises and the quantity traded falls — without demand having moved.",
                    tone: .example
                ),
                .paragraph("Some markets do not return smoothly to equilibrium. When production takes time — raising pigs, planting orchards —, producers decide what they will sell tomorrow by looking at today's price. A high price pushes them all to produce more; the output arrives at the same time, the price collapses, and they all cut back production. This is the **pork cycle**, described as early as the 1930s."),
                .figure(.cycle(title: "The pork cycle", nodes: ["High price", "Farmers produce more", "Overproduction: the price falls", "Farmers produce less"])),
                .paragraph("This cycle is a limit of the simple model: it assumes that quantities adjust instantly. It also explains why farm prices are so unstable, and why so many countries have introduced policies to stabilise them, such as the European **Common Agricultural Policy** from 1962."),
                .heading("Price elasticity"),
                .paragraph("Not all demand reacts to price in the same way. A 10% rise in the price of petrol barely reduces purchases in the short run: people still have to get to work. The same rise on a holiday trip can make many give it up. **Price elasticity** measures this sensitivity."),
                .formula("e = \\frac{\\Delta Q / Q}{\\Delta p / p}", caption: "The relative change in quantity demanded, divided by the relative change in price: almost always negative"),
                .paragraph("If the price rises by 10% and the quantity falls by 5%, $e = -5 / 10 = -0.5$: demand is **inelastic**, since $|e| < 1$. If the quantity falls by 20%, $e = -2$: demand is **elastic**, since $|e| > 1$. And this changes everything for the seller, because their **revenue** is the price multiplied by the quantity sold."),
                .bars(title: "Sellers' total revenue by price (thousands of euros)", unit: "k€", bars: [
                    DemoBar(label: "€1", value: 100),
                    DemoBar(label: "€2", value: 160),
                    DemoBar(label: "€3", value: 180),
                    DemoBar(label: "€4", value: 160),
                    DemoBar(label: "€5", value: 100),
                ]),
                .paragraph("The chart shows the revenue $R = p \\times Q_d$ in our market. It rises up to €3, then falls again. This is no coincidence: along a linear demand curve, elasticity changes at every point, and revenue is highest exactly ==where elasticity equals −1==."),
                .table(title: "Elasticity along the demand curve Q = 120 − 20p", headers: ["Price", "Quantity", "Elasticity", "If the price rises, revenue…"], rows: [
                    ["€1", "100", "−0.2", "increases"],
                    ["€2", "80", "−0.5", "increases"],
                    ["€3", "60", "−1", "is at its maximum"],
                    ["€4", "40", "−2", "decreases"],
                    ["€5", "20", "−5", "decreases"],
                ]),
                .paragraph("The rule is general: when demand is inelastic, a price rise increases revenue, because the quantity falls proportionally less than the price rises. That is why the state readily taxes tobacco and motor fuels, whose demand is not very elastic in the short run: the tax brings in money, and sales do not collapse."),
            ]),
            DemoChapter(title: "The state and the market", blocks: [
                .paragraph("The equilibrium price is not always considered acceptable: too high for tenants, too low for farmers or employees. The state then steps in, by setting a price, taxing, or subsidising. The model makes it possible to predict ==the effects of these interventions==, including the unwanted ones."),
                .heading("Price ceiling, price floor"),
                .callout(
                    title: "Price ceiling and price floor",
                    text: "A **price ceiling** is a maximum price set by the state, below equilibrium, to protect buyers (rent control). A **price floor** is a minimum price, above equilibrium, to protect sellers (minimum wage, guaranteed farm prices).",
                    tone: .definition
                ),
                .paragraph("Back to our market. A ceiling at €2 makes cheese cheaper for those who can find it, but demand rises to 80,000 and supply falls to 40,000: ==a shortage of 40,000== sets in, with queues and a black market. A floor at €4 guarantees producers a good price, but they supply 80,000 units when buyers want only 40,000: a surplus of 40,000, which has to be stored, destroyed or exported."),
                .table(title: "The state's instruments", headers: ["Instrument", "Example", "Intended effect", "Possible side effect"], rows: [
                    ["Price ceiling", "Rent control", "Lower prices", "Shortage, homes withdrawn from the market"],
                    ["Price floor", "Minimum wage", "Higher incomes", "Excess supply: unemployment if the floor is too high"],
                    ["Tax", "Tobacco tax", "Less consumption, revenue", "Smuggling"],
                    ["Subsidy", "Green car bonus", "More purchases of the subsidised good", "Cost to public finances"],
                ]),
                .paragraph("The last column is not an indictment: these effects depend on the gap between the set price and equilibrium, and on the elasticity of the curves. A moderate minimum wage can have a very small effect on employment; strict, long-lasting rent control almost always reduces the supply of homes to rent. The model does not say whether to intervene: it says ==what intervention costs==."),
                .heading("Who pays a tax?"),
                .paragraph("The state imposes a tax of €1 per cheese, paid by the sellers. To sell a unit, a producer now demands €1 more than before: if they receive $p$ from buyers, they keep only $p - 1$. Their supply becomes $Q_s = 20(p - 1)$, and the equilibrium shifts."),
                .formula("120 - 20\\,p = 20\\,(p - 1) \\;\\Rightarrow\\; p = 3.5 \\text{ €} \\;\\text{ and }\\; Q = 50", caption: "The new equilibrium, with a tax of €1 per unit"),
                .paragraph("Buyers now pay €3.50 instead of €3: they bear 50 cents of the tax. Sellers receive €3.50 but hand €1 over to the state: they are left with €2.50 instead of €3, a loss of 50 cents. The tax is shared ==half and half==, because here the two curves have the same slope. The state collects $1 \\times 50\\,000 = 50\\,000$ € per week."),
                .callout(
                    title: "Remitting is not paying",
                    text: "The seller **remits** the tax to the state, but it is the elasticity of the curves that decides who **bears** it. The least elastic side of the market — the one that cannot get away — pays the larger share. For tobacco, whose demand is not very elastic, it is mainly smokers.",
                    tone: .warning
                ),
                .paragraph("The tax also has a hidden cost. At equilibrium, **consumer surplus** — what buyers were willing to pay above the price — and **producer surplus** — what sellers receive above their cost — were each worth €90,000, or €180,000 in total. After the tax, this total is divided differently, and part of it disappears."),
                .bars(title: "The €180,000 surplus after the tax (thousands of euros)", unit: "k€", bars: [
                    DemoBar(label: "Consumers", value: 62.5),
                    DemoBar(label: "Producers", value: 62.5),
                    DemoBar(label: "State (tax revenue)", value: 50),
                    DemoBar(label: "Deadweight loss", value: 5),
                ]),
                .paragraph("The **deadweight loss** — €5,000 per week — corresponds to the 10,000 cheeses no longer traded even though a buyer and a seller would both have benefited. It benefits no one. It is the efficiency cost of the tax, and it is all the larger when the curves are elastic."),
                .list([
                    "Price ceiling below equilibrium: shortage",
                    "Price floor above equilibrium: surplus",
                    "Tax: price paid rises, price received falls, quantity falls, deadweight loss",
                    "Sharing the tax: the least elastic side bears the larger share",
                ]),
                .paragraph("These four results hold for any market, from oil to labour to housing. They do not say whether an intervention is good or bad — the state may want to reduce tobacco consumption, or guarantee an income —, but they force us to ==put figures on its effects==, which is the economist's first job."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "What happens in a market when the price is below the equilibrium price?",
                back: "The quantity demanded exceeds the quantity supplied: there is a shortage. Buyers outbid each other, the price rises, the quantity demanded falls and supply increases until equilibrium is restored.",
                figure: .flow(title: "Return to equilibrium", steps: ["Price too low", "Shortage", "The price rises", "Equilibrium"]),
                chapter: 1
            ),
            DemoCard(
                kind: .choice,
                front: "A frost destroys part of the coffee harvest. What happens to the equilibrium price and quantity?",
                back: "Supply decreases (its curve shifts to the left): the equilibrium price rises and the quantity traded falls.",
                choices: ["Price rises, quantity rises", "Price rises, quantity falls", "Price falls, quantity falls", "Nothing changes"],
                answerIndex: 1,
                chapter: 2
            ),
            DemoCard(
                kind: .cloze,
                front: "When the price of a good rises, we move … its demand curve: it is the quantity demanded that varies, not demand.",
                back: "along",
                chapter: 0
            ),
            DemoCard(kind: .basic, front: "With $Q_d = 120 - 20p$ and $Q_s = 20p$, what is the equilibrium?", back: "$120 - 20p = 20p$ gives $p^* = 3$ € and $Q^* = 60$ (thousands).", hint: "Set supply equal to demand.", chapter: 1),
            DemoCard(kind: .choice, front: "The price rises by 10% and the quantity demanded falls by 5%. What is the price elasticity of demand?", back: "$e = -5 / 10 = -0.5$: demand is inelastic, and a price rise increases revenue.", choices: ["−2", "−0.5", "0.5", "−5"], answerIndex: 1, chapter: 2),
            DemoCard(kind: .cloze, front: "A price ceiling set below the equilibrium price causes a … .", back: "shortage", chapter: 3),
            DemoCard(kind: .basic, front: "What are the five conditions of perfect competition?", back: "Atomicity, product homogeneity, transparency of information, free entry to and exit from the market, free movement of factors of production.", chapter: 0),
            DemoCard(kind: .choice, front: "Which of these events shifts the demand curve for electric cars to the right?", back: "A rise in the price of petrol: the petrol car, a substitute good, becomes more expensive to use. A fall in the price of electric cars themselves does not shift the curve: we move along it.", choices: ["A fall in the price of electric cars", "A rise in the price of petrol", "A rise in the cost of batteries", "A fall in household incomes"], answerIndex: 1, chapter: 2),
            DemoCard(kind: .basic, front: "Who bears a tax levied on a market?", back: "Buyers and sellers share it, whichever of them remits it. The least elastic side bears the larger share.", chapter: 3),
            DemoCard(kind: .cloze, front: "Along a linear demand curve, sellers' revenue is highest at the point where the price elasticity equals … .", back: "−1", chapter: 2),
            DemoCard(kind: .choice, front: "What is the effect of a price floor set above equilibrium?", back: "Excess supply: sellers offer more than buyers want to buy at that price.", choices: ["A shortage", "Excess supply", "No effect", "A fall in the price paid"], answerIndex: 1, chapter: 3),
            DemoCard(kind: .cloze, front: "The loss of surplus caused by a tax, which benefits no one, is called … loss.", back: "deadweight", chapter: 3),
        ]
    )

    // MARK: Physics: electric circuits

    private static let circuitsEN = OnboardingDemoCourse(
        id: "debug-circuits",
        emoji: "🔌",
        subject: "Physique",
        title: "Electricity: circuits",
        summary: "Current and voltage, Ohm's law, series and parallel circuits, then power, energy and safety rules, with calculations worked step by step.",
        accentIndex: 2,
        chapters: [
            DemoChapter(title: "Current and voltage", blocks: [
                .paragraph("When you press a switch, the lamp lights up instantly, and yet the electrons in the wires move forward by less than a millimetre per second. This paradox says it all: an electric circuit is ==a loop already full of charges==, which the generator sets moving all at once."),
                .heading("Electric current"),
                .paragraph("An **electric current** is a collective movement of charge carriers. In metals, these are **free electrons**, which move from atom to atom; in solutions, they are ions. Its **current** $I$ measures the amount of charge passing through a cross-section of the wire each second. It is expressed in **amperes** (A)."),
                .formula("I = \\frac{Q}{\\Delta t}", caption: "I in amperes (A), Q in coulombs (C), Δt in seconds (s)"),
                .paragraph("An electron carries a charge of $1.6 \\times 10^{-19}$ C. A current of 1 A therefore corresponds to $1 / (1.6 \\times 10^{-19}) \\approx 6.25 \\times 10^{18}$ electrons passing per second: more than six billion billion. That is why we never count electrons one by one, but coulombs."),
                .callout(
                    title: "Conventional direction",
                    text: "By convention, current flows **from the + terminal to the − terminal** of the generator, outside it. Electrons, which are negatively charged, move **in the opposite direction**. The convention dates from before the electron was discovered, and it has been kept.",
                    tone: .warning
                ),
                .paragraph("For a current to flow, there must be a **closed loop**: a generator, wires, at least one load, and no break. Opening a switch breaks the loop, and the current stops everywhere at once — before the switch as well as after it."),
                .figure(.cycle(title: "A closed loop", nodes: ["+ terminal of the generator", "Connecting wire", "Load (lamp)", "Back to the − terminal"])),
                .paragraph("In a simple loop, with no branches, the current is ==the same at every point==: it is not used up by passing through the lamp. What is “consumed” is the energy carried by the charges, not the charges themselves. The lamp does not eat electrons; it converts electrical energy into light and heat."),
                .heading("Voltage"),
                .callout(
                    title: "Voltage",
                    text: "The **voltage** $U$ between two points of a circuit is the difference in their electric potential. It is measured in **volts** (V). It is what sets the charges moving: no voltage, no current.",
                    tone: .definition
                ),
                .paragraph("An analogy helps: in a water circuit, the pump creates a pressure difference, and the water flows. The generator is the pump, the voltage is the pressure difference, the current is the flow rate. A 1.5 V battery, a 12 V car battery and a 230 V wall socket do not have the same “pressure”."),
                .table(title: "Measuring in a circuit", headers: ["Instrument", "Measures", "Unit", "Connection"], rows: [
                    ["Ammeter", "Current", "Ampere (A)", "In series, in the loop"],
                    ["Voltmeter", "Voltage", "Volt (V)", "In parallel, across the component"],
                    ["Ohmmeter", "Resistance", "Ohm (Ω)", "Across the component, out of the circuit"],
                ]),
                .paragraph("The connection follows from what the instrument measures. An ammeter counts what passes through: the current must flow through it, so it is placed **in** the loop. A voltmeter compares two points: it is connected **between** them. Connecting an ammeter in parallel creates a short circuit — and often blows its fuse."),
                .list([
                    "Junction rule: the sum of the currents entering a junction equals the sum of those leaving it",
                    "Loop rule: in a loop, the generator voltage equals the sum of the voltages across the loads",
                    "In a simple loop, the current is the same everywhere",
                ]),
            ]),
            DemoChapter(title: "Ohm's law", blocks: [
                .paragraph("A copper wire lets current through with almost no resistance; a tungsten filament slows it down strongly. The **resistance** $R$ of a component measures ==how much it opposes the flow of current==. It is expressed in ohms (Ω), after the German physicist Georg Ohm."),
                .heading("A proportional relationship"),
                .paragraph("Let's connect an **ohmic conductor** — a resistor, in the component sense — to an adjustable generator, and measure the current for several voltages. The results, for a 100 Ω resistor, fall on a straight line through the origin."),
                .table(title: "Measurements across a 100 Ω resistor", headers: ["Voltage U (V)", "Current I (mA)", "U / I (Ω)"], rows: [
                    ["2", "20", "100"],
                    ["4", "40", "100"],
                    ["6", "60", "100"],
                    ["8", "80", "100"],
                    ["10", "100", "100"],
                ]),
                .paragraph("The ratio $U / I$ is constant: it is the resistance. Watch the units: 20 mA is 0.020 A, and $2 / 0.020 = 100$ Ω. This proportionality between voltage and current is **Ohm's law**, the most widely used relationship in all of electricity."),
                .formula("U = R \\times I", caption: "U in volts (V), R in ohms (Ω), I in amperes (A)"),
                .paragraph("The formula can be read three ways: $U = RI$, $I = U / R$, $R = U / I$. For a given voltage, the greater the resistance, the smaller the current. Example: a 470 Ω resistor at 12 V carries $I = 12 / 470 \\approx 0.026$ A, about 26 mA."),
                .heading("Not all components are ohmic"),
                .paragraph("Ohm's law holds only for ohmic conductors. An incandescent lamp, for example, does not obey it: as the voltage increases, the filament heats up, its resistance increases, and the current grows more and more slowly. Its **characteristic** — the curve of current against voltage — is not a straight line, but a curve that bends."),
                .figure(.plot(title: "Characteristic of an incandescent lamp", caption: "Voltage on the horizontal axis, current on the vertical axis: the hotter the filament gets, the higher its resistance, and the more the current struggles to keep up.", kind: .saturation)),
                .paragraph("Compare with a resistor's straight line: for the lamp, the ratio $U / I$ is not constant, it increases with the voltage. This is the ==signature of a non-ohmic component==. Diodes are another, even more marked example: they let current through in one direction and almost not at all in the other."),
                .keyFigure(value: "× 10", label: "at least: the resistance of a tungsten filament at 2,500 °C, compared with its resistance when cold"),
                .paragraph("That is why an incandescent bulb most often burns out when switched on: when cold, its resistance is low, and a large current flows through it for a fraction of a second before the filament heats up. An ohmmeter measuring a switched-off lamp therefore gives a value very different from its resistance in operation."),
                .callout(
                    title: "Method",
                    text: "To apply Ohm's law: 1. check that the component is ohmic; 2. convert to base units — volts, amperes, ohms (1 mA = 0.001 A, 1 kΩ = 1,000 Ω); 3. isolate the quantity you are looking for; 4. give the result with its unit and a sensible number of digits.",
                    tone: .insight
                ),
                .paragraph("Step two is the one that loses the most marks: $12 / 470$ gives 0.026, and that is a result in amperes. Writing “0.026 mA” is off by a factor of a thousand. A mental order of magnitude — ==a few tens of milliamperes for a few hundred ohms at 12 V== — is enough to spot the error."),
            ]),
            DemoChapter(title: "Series and parallel", blocks: [
                .paragraph("As soon as a circuit has more than one load, you need to know how they are connected. There are only two basic ways: **in series**, one after the other in the same loop; **in parallel**, on separate branches between the same two points. Any circuit, however complex, breaks down into these two arrangements."),
                .figure(.split(
                    title: "Two arrangements",
                    left: DemoColumn(title: "In series", items: ["A single loop", "Same current everywhere", "Voltages add up", "Resistances add up", "One blown element cuts everything"]),
                    right: DemoColumn(title: "In parallel", items: ["Several branches", "Same voltage across each", "Currents add up", "Smaller equivalent resistance", "Each branch is independent"])
                )),
                .paragraph("Each line of the table follows from the two rules of the first chapter. In series, there is no junction, so the current is the same everywhere; the loop rule says the voltages add up. In parallel, the branches are connected between the same two points, so they have the same voltage; the junction rule says the currents add up."),
                .heading("In series"),
                .formula("R_{eq} = R_1 + R_2", caption: "Two resistors in series are equivalent to a single one, equal to their sum"),
                .callout(
                    title: "Example: two resistors in series",
                    text: "A 12 V generator powers $R_1 = 100$ Ω and $R_2 = 200$ Ω in series. $R_{eq} = 300$ Ω, so $I = 12 / 300 = 0.040$ A = 40 mA. Voltages: $U_1 = 100 \\times 0.040 = 4$ V and $U_2 = 200 \\times 0.040 = 8$ V. Check: $4 + 8 = 12$ V.",
                    tone: .example
                ),
                .paragraph("The voltage is shared ==in proportion to the resistances==: the resistor that is twice as large takes twice the voltage. This arrangement is called a **voltage divider**, and it is everywhere in electronics for obtaining a lower voltage from a fixed supply."),
                .heading("In parallel"),
                .formula("\\frac{1}{R_{eq}} = \\frac{1}{R_1} + \\frac{1}{R_2} \\;\\;\\Leftrightarrow\\;\\; R_{eq} = \\frac{R_1 R_2}{R_1 + R_2}", caption: "In parallel, it is the reciprocals of the resistances that add up"),
                .paragraph("Now let's connect the same resistors in parallel to the same generator. Each receives the full 12 V: $I_1 = 12 / 100 = 0.12$ A and $I_2 = 12 / 200 = 0.06$ A. The generator delivers their sum, $0.18$ A. The equivalent resistance is $\\frac{100 \\times 200}{300} \\approx 66.7$ Ω, and we can check that $12 / 66.7 \\approx 0.18$ A."),
                .table(title: "The same resistors, two arrangements (12 V generator)", headers: ["", "In series", "In parallel"], rows: [
                    ["Equivalent resistance", "300 Ω", "≈ 66.7 Ω"],
                    ["Current delivered", "40 mA", "180 mA"],
                    ["Voltage across R₁", "4 V", "12 V"],
                    ["Voltage across R₂", "8 V", "12 V"],
                    ["Total power", "0.48 W", "2.16 W"],
                ]),
                .paragraph("The result is counter-intuitive: adding a resistor **in parallel decreases** the equivalent resistance, because it gives the current one more path. The equivalent resistance is always smaller than the smallest of the resistances in parallel — here 66.7 Ω, less than 100 Ω."),
                .callout(
                    title: "Why sockets are wired in parallel",
                    text: "In a home, all appliances are connected in parallel: each receives the full 230 V, and you can switch one off without cutting the others. But each appliance added increases the total current in the circuit: that is how an overloaded power strip makes the breaker **trip**.",
                    tone: .warning
                ),
                .paragraph("Remember the golden rule: ==in series, the current is shared; in parallel, the voltage is==. Everything else — adding voltages or currents, calculating equivalent resistances — follows from it, and it is the first thing to identify when facing a circuit diagram."),
            ]),
            DemoChapter(title: "Power, energy and safety", blocks: [
                .paragraph("An electrical appliance is chosen first by its **power**: 8 W for an LED bulb, 2,000 W for a kettle. The electrical power received by a component is the product of the voltage across it and the current flowing through it. It measures ==the rate of energy== it receives."),
                .formula("P = U \\times I", caption: "P in watts (W), U in volts (V), I in amperes (A)"),
                .paragraph("Combined with Ohm's law, the formula takes two other forms for an ohmic conductor: $P = R I^2$ and $P = U^2 / R$. The first explains the **Joule effect**: a conductor carrying a current heats up, all the more so as the current is strong. It is useful in a heater or a toaster, and a loss everywhere else."),
                .table(title: "Power and current of some appliances at 230 V", headers: ["Appliance", "Power", "Current (I = P / U)"], rows: [
                    ["LED bulb", "8 W", "≈ 0.035 A"],
                    ["Phone charger", "20 W", "≈ 0.09 A"],
                    ["Television", "100 W", "≈ 0.43 A"],
                    ["Kettle", "2,000 W", "≈ 8.7 A"],
                    ["Oven", "3,000 W", "≈ 13 A"],
                ]),
                .paragraph("A standard socket is rated for 16 A, that is $230 \\times 16 \\approx 3\\,700$ W at most. Plugging a kettle and an oven into the same power strip means drawing more than 21 A: the wires heat up through the Joule effect, and this is how many house fires start."),
                .heading("Energy consumed"),
                .formula("E = P \\times \\Delta t", caption: "E in joules if P is in watts and Δt in seconds; in kWh if P is in kW and Δt in hours"),
                .callout(
                    title: "How much does a cup of tea cost?",
                    text: "A 2,000 W kettle heats the water in 3 minutes: $E = 2 \\text{ kW} \\times 0.05 \\text{ h} = 0.1$ kWh. At about €0.20 per kWh, that costs **two cents**. In joules: $2000 \\times 180 = 360\\,000$ J.",
                    tone: .example
                ),
                .paragraph("The kilowatt-hour is the unit on the bill because the joule is far too small at the scale of a household: 1 kWh is $3.6 \\times 10^6$ J. What costs a lot is not the powerful appliances used for a few minutes, but those that run for a long time: a 1,500 W heater left on for ten hours consumes 15 kWh, a hundred and fifty times more than the tea."),
                .heading("Electricity and the human body"),
                .paragraph("The electrical danger lies in ==the current flowing through the body==, not directly in the voltage. But it is the voltage that drives it: the human body has a resistance of around 1,000 Ω between the two hands, with damp skin. At 230 V, Ohm's law gives $I = 230 / 1000 = 0.23$ A, or 230 mA — a lethal current."),
                .bars(title: "Effects of an alternating current passing through the body", unit: "mA", bars: [
                    DemoBar(label: "Perception threshold", value: 0.5),
                    DemoBar(label: "Muscle contraction: you can no longer let go", value: 10),
                    DemoBar(label: "Respiratory paralysis", value: 30),
                    DemoBar(label: "Cardiac fibrillation", value: 75),
                ]),
                .paragraph("These thresholds explain the figure found on every electrical panel: **30 mA residual-current devices**. They compare the current going out to an appliance with the current coming back from it; if the difference exceeds 30 mA, some of the current is escaping — perhaps through someone —, and they cut the power within a few hundredths of a second."),
                .list([
                    "Fuse or circuit breaker: cuts the circuit in case of overcurrent (short circuit, overload), protects the installation",
                    "30 mA residual-current device: cuts the power in case of current leakage, protects people",
                    "Earth connection: carries the current from a faulty metal-cased appliance safely to the ground",
                    "Never use an electrical appliance near water: wet skin divides the body's resistance",
                ]),
                .paragraph("These protections are the result of two centuries of mastering electricity. First it had to be produced continuously, then its laws understood, then distributed on a large scale — and, at each stage, people had to learn to protect themselves from it."),
                .timeline(title: "Two centuries of electricity", events: [
                    DemoEvent(date: "1800", label: "Alessandro Volta invents the battery: the first direct current"),
                    DemoEvent(date: "1820", label: "Ørsted discovers that a current deflects a compass"),
                    DemoEvent(date: "1827", label: "Georg Ohm publishes the law that bears his name"),
                    DemoEvent(date: "1831", label: "Faraday discovers induction: we now know how to produce current"),
                    DemoEvent(date: "1879", label: "Swan and Edison's long-lasting incandescent lamp"),
                    DemoEvent(date: "1882", label: "First public power station, in New York"),
                ]),
                .paragraph("The unit of current is named after Ampère, the unit of voltage after Volta, the unit of resistance after Ohm: three of the letters you write in every exercise are ==a tribute to the pioneers== of this story. And each of their discoveries now fits into a formula of just a few characters."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "How do current and voltage behave in a series circuit, and in a parallel circuit?",
                back: "In series, the current is the same everywhere and the voltages add up. In parallel, the voltage is the same across each branch and the currents add up.",
                figure: .split(
                    title: "Two arrangements",
                    left: DemoColumn(title: "Series", items: ["I shared", "U values add up"]),
                    right: DemoColumn(title: "Parallel", items: ["U shared", "I values add up"])
                ),
                chapter: 2
            ),
            DemoCard(
                kind: .choice,
                front: "A 470 Ω resistor is subjected to a voltage of 12 V. What current flows through it?",
                back: "$I = U / R = 12 / 470 \\approx 0.026$ A, about 26 mA.",
                choices: ["≈ 26 mA", "≈ 39 A", "≈ 5.6 A", "≈ 0.26 mA"],
                answerIndex: 0,
                chapter: 1
            ),
            DemoCard(
                kind: .cloze,
                front: "A voltmeter is connected in … across the component whose voltage you want to measure.",
                back: "parallel",
                chapter: 0
            ),
            DemoCard(kind: .basic, front: "State Ohm's law.", back: "For an ohmic conductor, the voltage across it is proportional to the current flowing through it: $U = R \\times I$, with U in volts, R in ohms, I in amperes.", chapter: 1),
            DemoCard(kind: .choice, front: "Two resistors of 100 Ω and 200 Ω are connected in series to a 12 V generator. What is the voltage across the 200 Ω resistor?", back: "$I = 12 / 300 = 0.04$ A, so $U_2 = 200 \\times 0.04 = 8$ V.", hint: "First calculate the shared current.", choices: ["4 V", "6 V", "8 V", "12 V"], answerIndex: 2, chapter: 2),
            DemoCard(kind: .cloze, front: "By convention, current flows from the … terminal to the − terminal of the generator, outside it.", back: "+", chapter: 0),
            DemoCard(kind: .basic, front: "Why does adding a resistor in parallel decrease the equivalent resistance?", back: "Because it gives the current an extra path: the branch currents add up, the generator delivers more at the same voltage, so $R_{eq} = U / I$ decreases.", chapter: 2),
            DemoCard(kind: .choice, front: "How much energy does a 2,000 W kettle consume running for 3 minutes?", back: "$E = P \\times \\Delta t = 2 \\text{ kW} \\times 0.05 \\text{ h} = 0.1$ kWh, or 360,000 J.", choices: ["6 kWh", "0.1 kWh", "6,000 J", "0.6 kWh"], answerIndex: 1, chapter: 3),
            DemoCard(kind: .cloze, front: "The electrical power received by a component is $P = U \\times$ … .", back: "$I$", chapter: 3),
            DemoCard(kind: .basic, front: "What does a 30 mA residual-current device protect, and how?", back: "People: it compares the current going out to an appliance with the current coming back, and cuts the power if the difference exceeds 30 mA, a sign of current leakage, perhaps through a body.", chapter: 3),
            DemoCard(kind: .choice, front: "From roughly what current can a current passing through the body cause respiratory paralysis?", back: "About 30 mA, hence the rating of household residual-current devices.", choices: ["0.5 mA", "30 mA", "1 A", "10 A"], answerIndex: 1, chapter: 3),
            DemoCard(kind: .cloze, front: "An electron carries a charge of $1.6 \\times 10^{-19}$ … .", back: "coulombs", chapter: 0),
        ]
    )

    // MARK: Biology: the cell and mitosis

    private static let mitosisEN = OnboardingDemoCourse(
        id: "debug-mitosis",
        emoji: "🔬",
        subject: "SVT",
        title: "The cell and mitosis",
        summary: "The cell and its organelles, the cell cycle, the phases of mitosis, meiosis which makes gametes, and cancer, when division escapes all control.",
        accentIndex: 3,
        chapters: [
            DemoChapter(title: "The cell, the unit of life", blocks: [
                .paragraph("Every living being is made of cells: just one for a bacterium, about ==30 trillion== for a human being. And every cell is born from another cell, by division. These two sentences form **cell theory**, one of the pillars of biology."),
                .heading("A discovery over two centuries"),
                .paragraph("The microscope had to be invented to see cells, then two centuries of observation were needed to understand that they were the common feature of all living beings. The timeline sums up this long journey, which ends when a cell is finally observed in the act of dividing."),
                .timeline(title: "Cell theory", events: [
                    DemoEvent(date: "1665", label: "Robert Hooke observes “cells” in cork"),
                    DemoEvent(date: "1674", label: "Van Leeuwenhoek discovers microscopic living beings"),
                    DemoEvent(date: "1838–1839", label: "Schleiden and Schwann: plants and animals are made of cells"),
                    DemoEvent(date: "1855", label: "Virchow: every cell comes from a cell"),
                    DemoEvent(date: "1882", label: "Flemming describes and names mitosis"),
                ]),
                .paragraph("Virchow's phrase, *omnis cellula e cellula*, has a dizzying consequence: each of your cells descends, through an unbroken chain of divisions, from the very first living cell. Cell division is not a detail of how life works; it is ==what makes it last==."),
                .callout(
                    title: "Cell",
                    text: "The smallest structural and functional unit of life: a space bounded by a **plasma membrane**, containing **cytoplasm** and genetic information in the form of **DNA**, able to feed, produce energy and reproduce.",
                    tone: .definition
                ),
                .paragraph("There are two main types of cells. **Prokaryotes** — bacteria — have no nucleus: their DNA floats in the cytoplasm. **Eukaryotes** — animals, plants, fungi, protists — have a nucleus that encloses the DNA, and specialised compartments, the **organelles**."),
                .heading("The organelles"),
                .table(title: "The main organelles of a eukaryotic cell", headers: ["Organelle", "Role"], rows: [
                    ["Nucleus", "Contains the DNA, site of replication and transcription"],
                    ["Mitochondrion", "Cellular respiration: produces ATP"],
                    ["Ribosome", "Translation: makes proteins"],
                    ["Endoplasmic reticulum", "Synthesis and transport of proteins and lipids"],
                    ["Golgi apparatus", "Modifies, sorts and ships proteins"],
                    ["Chloroplast", "Photosynthesis, in plants only"],
                ]),
                .paragraph("The plant cell also has a rigid cellulose **cell wall** around its membrane, a large water-filled **vacuole** that keeps it swollen, and chloroplasts. The animal cell has neither a wall nor chloroplasts, but it has **centrosomes**, which will play a central role during division."),
                .keyFigure(value: "10 to 100 µm", label: "the typical size of a eukaryotic cell, about ten times that of a bacterium: invisible to the naked eye"),
                .paragraph("This size is no accident. A cell exchanges everything — food, oxygen, waste — across its membrane, and when its volume increases, its surface area increases more slowly. Beyond a certain size, ==the membrane is no longer enough== to feed the interior: the cell must divide or die."),
            ]),
            DemoChapter(title: "The cell cycle", blocks: [
                .paragraph("A dividing cell goes through a succession of stages that repeat at each generation: this is the **cell cycle**. It includes a long **interphase**, during which the cell grows and copies its DNA, and a short **mitosis**, during which it divides in two."),
                .figure(.cycle(title: "The cell cycle", nodes: ["G1: growth", "S: DNA replication", "G2: preparation", "M: mitosis and cytokinesis"])),
                .paragraph("The **G1** phase (G for *gap*) is when the cell grows and functions normally. In the **S** phase (synthesis), it replicates all its DNA. In the **G2** phase, it checks the copy and prepares for division. The **M** phase is mitosis itself, followed by **cytokinesis**, which splits the cytoplasm."),
                .bars(title: "Length of the phases for a human cell in culture", unit: "h", bars: [
                    DemoBar(label: "G1", value: 11),
                    DemoBar(label: "S", value: 8),
                    DemoBar(label: "G2", value: 4),
                    DemoBar(label: "M", value: 1),
                ]),
                .paragraph("Out of a cycle of about 24 hours, mitosis takes up only one hour. That is why, on a microscope slide, the vast majority of cells are in interphase: the proportion of cells seen in each phase ==reflects the length of that phase==. Many cells, such as neurons, even leave the cycle for a resting phase, called G0, and no longer divide."),
                .heading("Chromosomes and chromatids"),
                .callout(
                    title: "Chromosome and chromatid",
                    text: "A **chromosome** is a DNA molecule associated with proteins. After the S phase, each chromosome is made of **two sister chromatids**, two identical copies joined by a **centromere**. It is still **a single** chromosome, but with two chromatids.",
                    tone: .definition
                ),
                .paragraph("The amount of DNA in a cell therefore follows the cycle. Let $Q$ be the amount of DNA in a cell in G1. During the S phase, it gradually doubles to reach $2Q$. At the end of mitosis, each daughter cell starts again with $Q$. The curve of the amount of DNA over time looks like a staircase that climbs during S and drops all at once at division."),
                .formula("Q \\;\\to\\; 2Q \\;\\to\\; Q", caption: "The amount of DNA per cell: doubled during the S phase, shared out at mitosis"),
                .paragraph("The number of chromosomes, however, does not change during the S phase: a human cell has 46 chromosomes in G1, and still 46 in G2 — but with two chromatids each. We write ==2n = 46==: $n$ is the number of chromosomes in one set, 23 in humans, and body cells have two sets, one maternal, the other paternal."),
                .callout(
                    title: "The classic mistake",
                    text: "Believing that replication doubles the number of chromosomes. It doubles **the amount of DNA**, not the number of chromosomes: 46 single-chromatid chromosomes become 46 two-chromatid chromosomes. The number only doubles for an instant, in anaphase, when the chromatids separate.",
                    tone: .warning
                ),
                .list([
                    "G1: growth, single-chromatid chromosomes, amount of DNA Q",
                    "S: replication, the amount of DNA goes from Q to 2Q",
                    "G2: two-chromatid chromosomes, checking of the copy",
                    "M: mitosis, each daughter cell receives Q",
                ]),
                .paragraph("Moving from one phase to the next is not automatic: it is governed by **checkpoints**, where the cell checks that everything is in order before continuing — that the DNA is intact before the S phase, that it is fully copied before mitosis. Their discovery earned Hartwell, Hunt and Nurse the 2001 Nobel Prize, and it is their failure that opens the door to cancer."),
            ]),
            DemoChapter(title: "The phases of mitosis", blocks: [
                .paragraph("Mitosis is the division of a cell into ==two daughter cells genetically identical== to the mother cell. Its challenge is simple to state and formidable to achieve: distribute exactly one copy of each of the 46 chromosomes to each of the two cells, without losing or duplicating any."),
                .figure(.flow(title: "The stages of mitosis", steps: ["Prophase: the chromosomes condense", "Metaphase: they line up at the equator", "Anaphase: the sister chromatids separate", "Telophase: two nuclei re-form", "Cytokinesis: two daughter cells"])),
                .paragraph("Each phase has its markers visible under the microscope, and that is what you will be asked to recognise on a photograph. The table brings them together; metaphase is the easiest to identify, with its chromosomes lined up like a row of soldiers in the middle of the cell."),
                .table(title: "What you see in each phase", headers: ["Phase", "What happens"], rows: [
                    ["Prophase", "The chromosomes condense and become visible; the nuclear envelope disappears; the spindle forms"],
                    ["Metaphase", "The two-chromatid chromosomes line up on the equatorial plate, attached to the spindle by their centromere"],
                    ["Anaphase", "The sister chromatids separate and move to opposite poles: each pole receives 46 single-chromatid chromosomes"],
                    ["Telophase", "The chromosomes decondense; a nuclear envelope re-forms around each set"],
                ]),
                .paragraph("The **spindle** is the machine that makes all this possible: a network of protein fibres, the microtubules, stretched between the two poles of the cell. They attach to the centromeres, line up the chromosomes, then shorten to pull the chromatids towards the poles. A checkpoint blocks anaphase as long as even one chromosome is not correctly attached."),
                .callout(
                    title: "The outcome of mitosis",
                    text: "A mother cell with 2n = 46 chromosomes gives **two daughter cells with 2n = 46 chromosomes**, carrying exactly the same genetic information. Mitosis is **faithful reproduction**: it is what enables growth, tissue renewal and wound healing.",
                    tone: .insight
                ),
                .paragraph("Cytokinesis differs by cell type. The animal cell pinches in at its middle, like a balloon being squeezed, thanks to a ring of contractile proteins. The plant cell, trapped in its rigid wall, cannot pinch in: it builds a new wall in the middle, from the inside out."),
                .figure(.split(
                    title: "Two ways of dividing",
                    left: DemoColumn(title: "Animal cell", items: ["Centrosomes at the poles", "Contractile ring", "Pinching of the cytoplasm"]),
                    right: DemoColumn(title: "Plant cell", items: ["No centrosome", "Rigid wall", "New wall built in the centre"])
                )),
                .paragraph("Each division doubles the number of cells. Starting from one cell, there are 2 after one division, 4 after two, 8 after three: growth is **exponential**. After $k$ divisions, a population of $N_0$ cells numbers $N_0 \\times 2^k$."),
                .formula("N = N_0 \\times 2^k", caption: "The number of cells after k successive divisions, if all of them divide"),
                .paragraph("Ten divisions already give $2^{10} = 1\\,024$ cells; forty-five divisions, about 35 trillion — the order of magnitude of a human body. In reality, the cells of an organism do not all divide, and many die: the growth of healthy tissue is a ==balance between cell division and cell death==, which the organism constantly regulates."),
            ]),
            DemoChapter(title: "Meiosis, mitosis and cancer", blocks: [
                .paragraph("Mitosis makes faithful copies. But sexual reproduction needs something else: cells with only one set of chromosomes, so that at fertilisation, the egg and the sperm rebuild a cell with two sets. That is the role of **meiosis**, which takes place only in the gonads."),
                .table(title: "Mitosis and meiosis side by side", headers: ["", "Mitosis", "Meiosis"], rows: [
                    ["Where", "Almost all body cells", "The reproductive cells of the gonads"],
                    ["Divisions", "One", "Two in succession"],
                    ["Cells produced", "2", "4"],
                    ["Chromosomes", "2n = 46, like the mother cell", "n = 23, half as many"],
                    ["Genetic information", "Identical to the mother cell", "Different from one cell to another"],
                    ["Role", "Growth, renewal", "Making gametes"],
                ]),
                .paragraph("The first meiotic division separates the **homologous** chromosomes — the maternal and the paternal chromosome of each pair —; it halves the number of chromosomes. The second separates the sister chromatids, like a mitosis. Along the way, meiosis ==shuffles the genetic information== in two ways."),
                .formula("2^{23} \\approx 8.4 \\times 10^{6}", caption: "The number of possible chromosome combinations in a human gamete, from independent assortment alone"),
                .paragraph("**Independent assortment** comes from the fact that each pair separates independently of the others: for each of the 23 pairs, the gamete receives the maternal or the paternal homologue, hence $2^{23}$, more than eight million combinations. **Crossing over**, through exchanges of segments between homologues, multiplies this number even further. Two siblings, other than identical twins, never receive the same combination."),
                .heading("When division escapes control"),
                .paragraph("In a healthy organism, each cell divides only when it receives the signal to do so, and stops when told to. Two families of genes govern this control. **Proto-oncogenes** work like an accelerator: they push the cell to divide. **Tumour suppressor genes** work like a brake: they stop the cycle when there is a problem."),
                .callout(
                    title: "Cancer",
                    text: "A disease caused by the **uncontrolled proliferation** of cells that have accumulated mutations: a stuck accelerator (a proto-oncogene turned into an **oncogene**) and broken brakes (inactivated suppressor genes). The cells form a tumour, then can invade neighbouring tissues and spread to distant sites: these are **metastases**.",
                    tone: .definition
                ),
                .paragraph("The most famous of the brakes is the protein **p53**, nicknamed “the guardian of the genome”: when DNA is damaged, it halts the cycle long enough for repair, or triggers the cell's suicide if the damage is too severe. The gene that codes for it is mutated in about half of human cancers. It generally takes ==several successive mutations==, accumulated over years, for a cell to become cancerous — which explains why the risk increases with age."),
                .keyFigure(value: "≈ 30", label: "doublings for a single cell to become a one-centimetre tumour, about a billion cells (2³⁰ ≈ 1.07 × 10⁹)"),
                .paragraph("A tumour is therefore only detectable after a long, silent history: thirty doublings to reach one centimetre, whereas ten more would be enough to multiply it by a thousand. That is the whole point of **screening**: spotting the tumour as early as possible on this exponential curve, while it is still small and localised."),
                .callout(
                    title: "Why chemotherapy makes hair fall out",
                    text: "Most chemotherapies target cells **that are dividing**, by blocking DNA replication or the spindle. They therefore also hit healthy cells that divide quickly: hair roots, the lining of the gut, bone marrow. The side effects are a direct consequence of the target.",
                    tone: .warning
                ),
                .list([
                    "Tobacco: the leading preventable cause of cancer in France",
                    "Alcohol, excess weight, physical inactivity: major risk factors",
                    "UV rays: sunburn, especially in childhood, promotes melanoma",
                    "Certain viruses: the papillomavirus, for which there is a vaccine",
                ]),
                .paragraph("All these factors act in the same way: they increase the number of mutations in dividing cells. Understanding mitosis therefore means understanding both ==how the body builds and repairs itself==, and how, sometimes, that same machinery goes wrong."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "What are the phases of the cell cycle?",
                back: "Interphase, made up of G1 (growth), S (DNA replication) and G2 (preparation), then the M phase: mitosis, followed by cytokinesis.",
                figure: .cycle(title: "The cell cycle", nodes: ["G1", "S", "G2", "M"]),
                chapter: 1
            ),
            DemoCard(
                kind: .choice,
                front: "During which phase of mitosis do the sister chromatids separate?",
                back: "Anaphase: the sister chromatids move to opposite poles, and each pole receives one single-chromatid chromosome of each kind.",
                choices: ["Prophase", "Metaphase", "Anaphase", "Telophase"],
                answerIndex: 2,
                chapter: 2
            ),
            DemoCard(
                kind: .cloze,
                front: "A cell's DNA is replicated during the … phase of interphase.",
                back: "S",
                chapter: 1
            ),
            DemoCard(kind: .basic, front: "What is the difference between a prokaryote and a eukaryote?", back: "A prokaryote (a bacterium) has no nucleus: its DNA is in the cytoplasm. A eukaryote has a nucleus that encloses its DNA, and organelles.", chapter: 0),
            DemoCard(kind: .choice, front: "Which organelle produces most of the cell's ATP?", back: "The mitochondrion, the site of cellular respiration.", choices: ["The nucleus", "The mitochondrion", "The ribosome", "The Golgi apparatus"], answerIndex: 1, chapter: 0),
            DemoCard(kind: .cloze, front: "After the S phase, each chromosome is made of two sister … joined by a centromere.", back: "chromatids", chapter: 1),
            DemoCard(kind: .basic, front: "What happens to the number of chromosomes and the amount of DNA during the cell cycle?", back: "The amount of DNA doubles in the S phase (from Q to 2Q) and returns to Q at division. The number of chromosomes stays at 46: they go from one to two chromatids.", hint: "Distinguish the amount of DNA from the number of chromosomes.", chapter: 1),
            DemoCard(kind: .choice, front: "How many cells, and with how many chromosomes, does meiosis produce from a human cell?", back: "Four cells with n = 23 chromosomes, genetically different from one another.", choices: ["2 cells with 46 chromosomes", "2 cells with 23 chromosomes", "4 cells with 23 chromosomes", "4 cells with 46 chromosomes"], answerIndex: 2, chapter: 3),
            DemoCard(kind: .cloze, front: "During …, the chromosomes line up on the equatorial plate.", back: "metaphase", chapter: 2),
            DemoCard(kind: .basic, front: "What is cancer, at the level of the cell?", back: "The uncontrolled proliferation of cells that have accumulated mutations: proto-oncogenes turned into oncogenes (a stuck accelerator) and inactivated tumour suppressor genes (broken brakes).", chapter: 3),
            DemoCard(kind: .choice, front: "How many chromosome combinations can a human gamete receive from independent assortment alone?", back: "$2^{23}$, about 8.4 million: each of the 23 pairs separates independently of the others.", choices: ["23", "46", "$2^{23}$, about 8.4 million", "$23^2$, that is 529"], answerIndex: 2, chapter: 3),
            DemoCard(kind: .cloze, front: "Mitosis produces two daughter cells that are genetically … to the mother cell.", back: "identical", chapter: 2),
        ]
    )
}
#endif
