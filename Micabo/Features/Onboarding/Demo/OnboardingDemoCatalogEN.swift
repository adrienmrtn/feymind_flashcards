import Foundation

// MARK: - The four courses, in English

/// The demo courses, in English. High-school level: what a teacher would write on the
/// board, with exact definitions, mechanisms and examples.
///
/// **Four chapters per course, and text between every object.** A diagram, a table or a
/// chart only reads with the sentence that brings it in and the one that draws something
/// out of it: two objects in a row with no paragraph between them read as a gallery, not
/// as a study sheet. The rule here is that no rich object touches another.
///
/// Subjects keep the catalogue's canonical (French) names so they land in the right
/// filters; `SubjectDisplay` translates them on screen.
extension OnboardingDemoCatalog {
    static let english: [OnboardingDemoCourse] = [
        coldWarEN, photosynthesisEN, derivativesEN, energyEN,
    ]

    // MARK: History: the Cold War

    private static let coldWarEN = OnboardingDemoCourse(
        id: "history-cold-war",
        emoji: "🏛️",
        subject: "Histoire",
        title: "The Cold War (1947–1991)",
        summary: "Two blocs, two models, and never a direct war: forty-four years of tension, crises and détente, until the Wall came down.",
        accentIndex: 3,
        chapters: [
            DemoChapter(title: "Two blocs face to face (1947–1953)", blocks: [
                .paragraph("In 1945 the victors of the war no longer share anything. The United States and the USSR, allies against Nazi Germany, become ==the two superpowers== of a world splitting in two. Everything that follows — forty-four years of tension — makes sense from that break."),
                .heading("A world cut in two"),
                .paragraph("The Yalta (February 1945) and Potsdam (July 1945) conferences were meant to organise the peace. They organise the partition instead: Eastern Europe, liberated by the Red Army, stays under Soviet control; Western Europe, liberated by the Anglo-Americans, enters Washington's orbit. As early as March 1946, Churchill speaks of an **iron curtain** fallen across the continent."),
                .callout(
                    title: "Cold War",
                    text: "A confrontation **without direct war** between the United States and the USSR, from 1947 to 1991, fought through economic pressure, propaganda, the arms race and proxy wars.",
                    tone: .definition
                ),
                .paragraph("The word “cold” says the essential: the two giants never fight each other. They clash everywhere else, and by every other means. What divides them is not only a rivalry of power, it is ==two ways of organising a society==, incompatible with one another."),
                .figure(.split(
                    title: "Two models",
                    left: DemoColumn(title: "Western bloc", items: ["United States", "Liberal democracy", "Market economy", "Marshall Plan (1947)", "NATO (1949)"]),
                    right: DemoColumn(title: "Eastern bloc", items: ["USSR", "Single party", "Planned economy", "Cominform (1947)", "Warsaw Pact (1955)"])
                )),
                .paragraph("In the West, free elections, several parties, an independent press, and an economy where companies are private and prices are free. In the East, a single party, the Communist Party, which controls the state, the press and the economy: the plan, decided in Moscow, sets what is produced and at what price. Each camp presents itself as the free world, and describes the other as a threat."),
                .heading("Containment"),
                .paragraph("In March 1947 President Truman promises to help any country threatened by communism: this is the ==bleu|Truman Doctrine==, or *containment* — hold communism where it is, without trying to overthrow it where it rules. The Marshall Plan, three months later, funds the reconstruction of Western Europe with 13 billion dollars, and ties it to the American camp. The USSR answers by forbidding its satellites to accept it, and creates the Cominform to coordinate the communist parties."),
                .timeline(title: "The first years", events: [
                    DemoEvent(date: "1947", label: "Truman Doctrine and Marshall Plan"),
                    DemoEvent(date: "1948", label: "Berlin Blockade"),
                    DemoEvent(date: "1949", label: "NATO founded, first Soviet bomb"),
                    DemoEvent(date: "1950", label: "Korean War begins"),
                ]),
                .paragraph("Berlin is the first trial of strength. The city, deep inside the Soviet zone, is itself divided into four sectors. When the Western powers create a common currency for their zones, in June 1948, Stalin cuts every road and railway to West Berlin: two million inhabitants find themselves under siege."),
                .callout(
                    title: "Remember",
                    text: "The Berlin Blockade (June 1948 to May 1949) is the first crisis: the USSR cuts the roads to West Berlin, the Allies answer with an ==airlift== lasting eleven months — a plane every two minutes. Not a shot is fired, and yet everything is said.",
                    tone: .insight
                ),
                .paragraph("The blockade fails, and it sets the rules of the game for forty years: each camp tests the other, but neither crosses the line that would lead to war. In 1949 the USSR explodes its first atomic bomb, four years after Hiroshima. Both camps now hold the ultimate weapon, and **the balance of terror** settles in."),
                .list([
                    "Iron curtain: the border cutting Europe in two, from the Baltic to the Adriatic",
                    "Containment: the American strategy, hold without attacking",
                    "Satellite: an Eastern European country ruled by a communist party aligned with Moscow",
                ]),
                .paragraph("The Korean War, in June 1950, shows what a conflict becomes in this frame: the communist North invades the South, the Americans intervene under the UN flag, China sends its “volunteers”. Three years of fighting, two million dead, and a border back exactly where it was. Each camp follows the same rule: never yield an inch, never fire at the other superpower."),
            ]),
            DemoChapter(title: "Crises and the balance of terror (1953–1975)", blocks: [
                .paragraph("After Stalin's death (1953), Khrushchev proposes “peaceful coexistence”: the two systems can live side by side, and the economy will say which one is better. But coexistence prevents neither crises nor the arms race. Each camp arms its allies and fights **by proxy**, from Korea to Vietnam."),
                .paragraph("Coexistence has its limits, and Budapest shows them as early as 1956: when Hungary tries to leave the Warsaw Pact, Soviet tanks crush the uprising in a few days. The West protests, and does not move. Each side stays master at home: that is the unwritten rule of the Cold War."),
                .table(title: "The major crises", headers: ["Crisis", "Date", "What is at stake"], rows: [
                    ["Korean War", "1950–1953", "The 38th parallel, a Korea cut in two"],
                    ["Berlin Wall", "1961", "The East walls in its people to stop the flight westward"],
                    ["Cuban Missile Crisis", "1962", "Soviet missiles 150 km from Florida"],
                    ["Vietnam War", "1955–1975", "The United States gets bogged down, then withdraws"],
                ]),
                .heading("Berlin, again"),
                .paragraph("Between 1949 and 1961, nearly three million East Germans cross to the West, most of them through Berlin, where taking the underground is enough. The GDR is emptying of its doctors, its engineers, its young people. In the night of 12 to 13 August 1961, it closes the border: barbed wire first, then a concrete wall, watchtowers, a death strip. ==The Wall== becomes the symbol of the whole Cold War, and of what each camp is worth in the other's eyes."),
                .keyFigure(value: "13 days", label: "the length of the Cuban Missile Crisis, in October 1962, before the missiles were withdrawn"),
                .paragraph("In October 1962 American spy planes photograph Soviet missile sites in Cuba, a hundred and fifty kilometres from Florida. Kennedy imposes a naval blockade of the island and demands their removal; for thirteen days the world holds its breath. Khrushchev eventually withdraws the missiles in exchange for a promise not to invade Cuba — and the quiet removal of American missiles from Turkey. ==Deterrence held==: the hottest moment of the whole Cold War."),
                .figure(.flow(title: "The logic of deterrence", steps: ["Both camps have the bomb", "To strike is to be struck", "Nobody strikes", "War is fought elsewhere"])),
                .paragraph("This logic has a name: **mutual assured destruction**. Neither camp can destroy the other without being destroyed in return, so neither strikes first. The bomb, paradoxically, becomes a guarantee of peace between the two giants — and that is precisely why the war moves elsewhere, to the allies, where it can stay conventional."),
                .callout(
                    title: "By proxy",
                    text: "Vietnam is the example: the United States backs the South, the USSR and China back the North. A real war, millions of deaths, and never an American soldier facing a Soviet one.",
                    tone: .example
                ),
                .paragraph("The United States commits to Vietnam from 1965: more than five hundred thousand soldiers in 1968, massive bombing, and a public opinion that turns when the images reach television. They withdraw in 1973; Saigon falls in 1975. It is the first war America loses, and it loses it ==without ever facing the USSR==."),
                .heading("The race everywhere"),
                .paragraph("The confrontation is also played out in the sky, in laboratories and in stadiums. Every satellite, every medal, every record is presented as proof that one system is better than the other. The space race is its shop window: the USSR takes the lead, America catches up by giving itself ten years."),
                .list([
                    "1957: Sputnik, the first satellite, opens the space race",
                    "1961: Gagarin, first man in space",
                    "1963: the red telephone links Washington and Moscow, the lesson of Cuba",
                    "1969: Apollo 11, America walks on the Moon",
                ]),
                .paragraph("The red telephone, installed after Cuba, sums up the period: two adversaries who do not trust each other, but who know that a misunderstanding could blow everything up. They talk so as not to fight. It is from this caution that the détente of the 1970s is born."),
            ]),
            DemoChapter(title: "From détente to the fall of the Wall (1975–1991)", blocks: [
                .paragraph("The 1970s loosen the grip. Both camps have understood that they will not win, and that the arms race costs a fortune: they negotiate. But the ==rose|new Cold War== resumes in 1979, when the USSR invades Afghanistan and Reagan relaunches the arms race."),
                .heading("Détente"),
                .paragraph("The SALT agreements (1972) limit the number of nuclear missiles for the first time. The Helsinki conference (1975) recognises the borders inherited from the war — what Moscow wanted — in exchange for a commitment on human rights, which Eastern dissidents will brandish for fifteen years. Nixon travels to Beijing and Moscow; trade resumes; the two Germanies recognise each other."),
                .paragraph("The respite is short. In December 1979 the Red Army enters Afghanistan to prop up a tottering communist regime: ten years of war, a million dead, and the USSR bogged down in its own Vietnam. The United States boycotts the Moscow Games, arms the Afghan resistance, and Ronald Reagan, elected in 1980, calls the USSR an “evil empire”. His space shield project, SDI, launches a technological race Moscow can no longer follow."),
                .paragraph("In 1985 Mikhail Gorbachev comes to power in an exhausted USSR: shop shelves are empty, industry is outdated, the army swallows an enormous share of the wealth. He launches **perestroika** (restructuring of the economy) and **glasnost** (openness in public life), negotiates disarmament with Reagan, and stops propping up the communist regimes of Eastern Europe: each will now be responsible for its own fate."),
                .timeline(title: "The end", events: [
                    DemoEvent(date: "1985", label: "Gorbachev comes to power"),
                    DemoEvent(date: "1987", label: "Washington Treaty: end of the Euromissiles"),
                    DemoEvent(date: "9 Nov 1989", label: "Fall of the Berlin Wall"),
                    DemoEvent(date: "1990", label: "German reunification"),
                    DemoEvent(date: "25 Dec 1991", label: "Dissolution of the USSR"),
                ]),
                .paragraph("The year 1989 sweeps everything away. In Poland, the Solidarność union wins free elections in June. In Hungary, the government opens its border with Austria in September: East Germans pour through it by the thousands. In the GDR, the Monday demonstrations in Leipzig gather hundreds of thousands of people, and the regime, without Moscow's support, can no longer shoot."),
                .heading("Why the USSR lost"),
                .paragraph("The Cold War was fought on the economy as much as on weapons. The USSR devoted to its army a share of its wealth the United States never needed to reach, with an economy half the size. Every extra missile was one hospital or one factory fewer, and the population knew it."),
                .bars(title: "Military spending as a share of GDP, around 1985 (estimate)", unit: "%", bars: [
                    DemoBar(label: "United States", value: 6),
                    DemoBar(label: "USSR", value: 15),
                    DemoBar(label: "France", value: 4),
                ]),
                .paragraph("The chart reads at a glance: for a comparable military effort, the USSR sacrifices more than twice what the United States devotes to it. It is this exhaustion Gorbachev tries to stop — and it is by loosening the grip that he frees the forces that will dissolve the system."),
                .callout(
                    title: "Why the Wall falls",
                    text: "Without Moscow's support, the Eastern regimes collapse one after another in 1989. On 9 November a GDR spokesman announces, by mistake, that the borders are open “immediately”: in one night, tens of thousands of Berliners cross, and the symbol of division disappears.",
                    tone: .insight
                ),
                .paragraph("Germany reunifies in October 1990, under NATO's protection — something Moscow would have refused five years earlier. Inside the USSR, the republics demand their independence; a failed coup in August 1991 finishes discrediting the party. On 25 December 1991 the Soviet flag is lowered from the Kremlin. The Cold War ends ==without a battle==, through the exhaustion of one of the two camps."),
            ]),
            DemoChapter(title: "Making sense of the Cold War", blocks: [
                .paragraph("Forty-four years, dozens of crises, hundreds of dates: the Cold War is not memorised date by date, it is understood through its mechanisms. This chapter gathers ==the vocabulary, the logic and the method== for writing about it in an exam."),
                .heading("The vocabulary"),
                .paragraph("Each word below names a precise mechanism, and using one in place of another is an error of understanding, not of vocabulary. “Détente” is not “peace”, “containment” is not “attack”, “satellite” is not “ally”."),
                .table(title: "Words to know", headers: ["Word", "What it means"], rows: [
                    ["Iron curtain", "The closed border cutting Europe in two"],
                    ["Containment", "Holding communism without attacking it where it rules"],
                    ["Deterrence", "Not striking because you would be struck back"],
                    ["Proxy war", "A war fought by allies, not by the two giants"],
                    ["Détente", "The easing of tensions, in the 1970s"],
                    ["Satellite", "An Eastern country ruled by a party aligned with Moscow"],
                ]),
                .paragraph("These words describe one cycle, repeated from 1947 to 1991. Tension rises, a crisis breaks out, the two camps negotiate because neither wants war, tension falls — then a new crisis starts somewhere else. Berlin, Cuba, Vietnam, Afghanistan: it is always the same loop."),
                .figure(.cycle(title: "The cycle of crises", nodes: ["Tension rises", "A crisis breaks out", "They negotiate", "Tension falls"])),
                .paragraph("Understanding this cycle means being able to explain any crisis without having learnt it by heart: who tests whom, how far, and why it stops short of war. The answer is almost always the same — **nuclear deterrence** — and it is what sets the Cold War apart from every rivalry before it."),
                .heading("In the exam"),
                .callout(
                    title: "Method",
                    text: "For an essay: 1. A plan in three parts — the formation of the blocs, crises and coexistence, détente and the end. 2. One date and one precise example per idea. 3. A conclusion that answers the question: why “cold”, and why it ends without a war.",
                    tone: .insight
                ),
                .paragraph("For a document analysis, the first question to ask is the point of view: who is speaking, from which camp, at which moment of the cycle? A Soviet poster from 1950 and a Kennedy speech from 1963 do not say the same thing, and it is precisely their difference you are expected to explain."),
                .callout(
                    title: "The classic mistake",
                    text: "Writing that the United States and the USSR went to war with each other. They **never** fought directly: that is the very definition of the Cold War, and it is what deterrence explains.",
                    tone: .warning
                ),
                .list([
                    "1947: Truman Doctrine, Marshall Plan — the blocs form",
                    "1949: NATO, Soviet bomb — the balance of terror begins",
                    "1961: the Wall — division becomes concrete",
                    "1962: Cuba — deterrence holds",
                    "1975: Helsinki — détente",
                    "1989: the Wall falls — the end",
                    "1991: the USSR disappears",
                ]),
                .paragraph("Seven dates are enough to hold the whole period, provided you know what each one opens or closes. Learn them with their mechanism, not only with their event: that link is what makes the difference between reciting a timeline and ==explaining an era==."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "What are the two blocs of the Cold War, and who leads them?",
                back: "The Western bloc, led by the United States (liberal democracy, market economy), and the Eastern bloc, led by the USSR (single party, planned economy).",
                figure: .split(
                    title: "Two models",
                    left: DemoColumn(title: "West", items: ["United States", "NATO"]),
                    right: DemoColumn(title: "East", items: ["USSR", "Warsaw Pact"])
                ),
                chapter: 0
            ),
            DemoCard(
                kind: .choice,
                front: "Which crisis brought the world to the brink of nuclear war in 1962?",
                back: "The Cuban Missile Crisis: Soviet missiles installed in Cuba, thirteen days of standoff, then a withdrawal in exchange for a promise not to invade the island.",
                choices: ["The Berlin Blockade", "The Cuban Missile Crisis", "The Korean War", "The invasion of Afghanistan"],
                answerIndex: 1,
                chapter: 1
            ),
            DemoCard(
                kind: .cloze,
                front: "The Berlin Wall falls on 9 November …, two years before the dissolution of the USSR.",
                back: "1989",
                chapter: 2
            ),
            DemoCard(kind: .basic, front: "What is the Truman Doctrine?", back: "The United States' commitment, in March 1947, to help any country threatened by communism: the policy of containment.", chapter: 0),
            DemoCard(kind: .cloze, front: "The … Plan (1947) funds the reconstruction of Western Europe.", back: "Marshall", chapter: 0),
            DemoCard(kind: .choice, front: "Who launched perestroika and glasnost?", back: "Mikhail Gorbachev, in power from 1985, tried to reform the USSR from within.", choices: ["Stalin", "Khrushchev", "Gorbachev", "Brezhnev"], answerIndex: 2, chapter: 2),
            DemoCard(kind: .basic, front: "Why did the United States and the USSR never fight each other directly?", back: "Because of nuclear deterrence: since each camp could destroy the other, striking first would mean being struck back. War is therefore fought by proxy, through the allies.", chapter: 3),
            DemoCard(kind: .cloze, front: "The easing of tensions between the two blocs in the 1970s is called … .", back: "détente", chapter: 3),
        ]
    )

    // MARK: Biology: photosynthesis

    private static let photosynthesisEN = OnboardingDemoCourse(
        id: "biology-photosynthesis",
        emoji: "🌿",
        subject: "SVT",
        title: "Photosynthesis",
        summary: "How a leaf makes sugar out of light, water and carbon dioxide, and why almost all life depends on it.",
        accentIndex: 4,
        chapters: [
            DemoChapter(title: "Capturing light", blocks: [
                .paragraph("A leaf is a factory: it takes light, water and carbon dioxide and turns them into ==sugar and oxygen==. This process is photosynthesis, and it feeds almost all life on Earth — including us, who eat plants or the animals that eat them."),
                .heading("A leaf, up close"),
                .paragraph("The leaf is built for this job. It is flat and thin, to offer as much surface as possible to the light. Its underside is pierced by thousands of **stomata**, tiny pores that open during the day to let the CO₂ of the air in and oxygen out. Between the two faces, cells packed with chloroplasts; and veins that bring water up from the roots and carry the sugar away."),
                .callout(
                    title: "Photosynthesis",
                    text: "The synthesis of organic matter (glucose) by green plants, from mineral matter (CO₂ and water), using light energy.",
                    tone: .definition
                ),
                .paragraph("The definition fits in one equation. Six molecules of carbon dioxide and six molecules of water give one molecule of glucose and six molecules of oxygen. Nothing is created: the carbon atoms of the sugar come from the CO₂ in the air, the oxygen released comes from the water. It is ==the energy of light== that makes the assembly possible."),
                .formula("6\\,CO_2 + 6\\,H_2O \\rightarrow C_6H_{12}O_6 + 6\\,O_2", caption: "The overall equation, driven by light"),
                .paragraph("It all happens in the **chloroplasts**, green organelles found by the dozen in every cell of the leaf's parenchyma. Their colour comes from ==menthe|chlorophyll==, the pigment that absorbs red and blue light, and reflects green. It is the only place in the cell where light is captured: no chloroplast, no photosynthesis."),
                .heading("From photon to sugar"),
                .paragraph("What happens inside can be summed up in four steps, which follow one another in a fraction of a second. Light strikes the chlorophyll; the energy received is used to split water molecules, which releases oxygen; that energy is stored in a form the cell knows how to use, ATP; and ATP is finally used to fix CO₂ into glucose."),
                .figure(.flow(title: "From photon to sugar", steps: ["Chlorophyll absorbs light", "Water is split: O₂ released", "Energy is stored (ATP)", "CO₂ is fixed into glucose"])),
                .paragraph("Not all colours of light are equal for the leaf. The white light of the Sun is a mixture; chlorophyll mostly captures the two ends of the spectrum — blue and red — and lets the middle through. This is measured by lighting a chlorophyll solution one colour at a time, and looking at what gets through."),
                .bars(title: "What chlorophyll absorbs, by colour", unit: "%", bars: [
                    DemoBar(label: "Blue", value: 90),
                    DemoBar(label: "Green", value: 15),
                    DemoBar(label: "Red", value: 80),
                ]),
                .paragraph("The chart reads at a glance: nine blue photons out of ten are captured, eight red ones out of ten, and barely one green out of six. Green is not entirely lost — a few secondary pigments, the carotenoids, take some of it — but most of it goes back where it came from."),
                .callout(
                    title: "Why leaves are green",
                    text: "Because green is the colour chlorophyll **does not absorb**: it reflects it back to our eyes. A leaf is green for the same reason a red cloth is red — it is the colour it rejects.",
                    tone: .insight
                ),
                .paragraph("A simple experiment shows it: a plant grown under green light grows poorly, a plant under red or blue light grows well. That is why modern greenhouses light their crops in pink, a mix of red and blue — not one photon is wasted on green the plant would not use."),
                .paragraph("You can also check that the leaf really makes sugar. A leaf exposed to light, bleached and then dipped in iodine solution turns blue-black: it contains starch, the form in which the plant stores its glucose. A leaf kept in the dark stays yellow: ==no light, no sugar==."),
            ]),
            DemoChapter(title: "Making glucose", blocks: [
                .paragraph("Photosynthesis happens in two stages, in two places inside the chloroplast. The **light phase** needs light: it splits water, releases oxygen and stores energy. The **dark phase** does not need it directly: it uses that energy to fix CO₂ and build glucose. The first produces the fuel, the second spends it."),
                .heading("The light phase"),
                .paragraph("It takes place in the **thylakoids**, membrane sacs stacked inside the chloroplast, where chlorophyll is anchored. When a photon strikes a chlorophyll molecule, it knocks out an electron, and that electron is replaced by splitting a water molecule: this is the **photolysis of water**. The oxygen from the water is released as O₂ — the one we breathe — and the electron's energy is used to make ATP, the energy currency of every living cell."),
                .table(title: "The two phases", headers: ["", "Light phase", "Dark phase"], rows: [
                    ["Where", "Thylakoid membranes", "Chloroplast stroma"],
                    ["Light", "Essential", "Not directly"],
                    ["In", "Water, light", "CO₂, ATP"],
                    ["Out", "O₂, ATP", "Glucose"],
                ]),
                .paragraph("The table reads by columns: what comes out of the light phase — ATP — is exactly what the dark phase needs. The two phases are therefore linked: the second stops as soon as the first stops supplying it, which happens a few minutes after sunset."),
                .heading("The Calvin cycle"),
                .paragraph("The dark phase takes place in the **stroma**, the fluid bathing the thylakoids. It bears the name of the chemist who described it in 1950 by tracing radioactive carbon: Melvin Calvin. It is a cycle, that is a sequence of reactions that returns to its starting point, having made sugar along the way."),
                .figure(.cycle(title: "The Calvin cycle", nodes: ["CO₂ fixation", "Reduction with ATP", "Sugar formation", "Acceptor regeneration"])),
                .paragraph("On each turn, one CO₂ molecule is fixed onto a host molecule, the acceptor, by an enzyme called RuBisCO — the most abundant protein on the planet. The compound obtained is reduced using the ATP from the light phase, and part of the product leaves the cycle to make ==glucose==, while the rest regenerates the acceptor for the next turn. It takes **six turns** for one glucose molecule: one per carbon atom."),
                .keyFigure(value: "6 turns", label: "of the Calvin cycle to build a single glucose molecule"),
                .paragraph("The glucose made does not stay glucose for long. The plant assembles it into **starch** to store it in the leaf or in a tuber — that is the starch of the potato —, into **sucrose** to carry it through the sap down to the roots and out to the fruit, or into **cellulose** to build its walls. The wood of a tree is sugar stacked up over decades."),
                .callout(
                    title: "Classic trap",
                    text: "The dark phase does not happen “at night”: it runs during the day too, as soon as the light phase supplies energy. “Dark” means it does not use light directly — not that it waits for darkness.",
                    tone: .warning
                ),
                .list([
                    "Light phase: thylakoids, light, water split, O₂ released, ATP produced",
                    "Dark phase: stroma, Calvin cycle, CO₂ fixed, glucose made",
                    "Six turns of the cycle per glucose molecule, one per carbon atom",
                ]),
                .paragraph("Remember the thread rather than the names: light becomes chemical energy, chemical energy becomes sugar, and sugar becomes everything else in the plant. Each step has its place and its fuel, and ==none works without the previous one==."),
            ]),
            DemoChapter(title: "Photosynthesis and the planet", blocks: [
                .paragraph("Every year, plants fix about ==120 billion tonnes of carbon==. Photosynthesis is the entry point of organic matter into food chains, and the source of all the oxygen we breathe. At the scale of the planet, it is the process that drives the carbon cycle."),
                .heading("The carbon cycle"),
                .paragraph("Carbon circulates between the air, living things and the soil, and photosynthesis is one of the cycle's two engines. It takes CO₂ out of the atmosphere and locks it into the matter of plants. Respiration and decomposition go the other way: they burn that matter and return the CO₂ to the air. As long as the two balance, the amount of CO₂ in the atmosphere stays stable."),
                .figure(.cycle(title: "The carbon cycle", nodes: ["CO₂ in the atmosphere", "Photosynthesis: fixed in plants", "Respiration, decomposition", "Back to the atmosphere"])),
                .paragraph("Plants are the **primary producers**: they make the organic matter everything else lives on. A herbivore eats the plant, a carnivore eats the herbivore, and at each step the carbon passes from one organism to the next. Without photosynthesis, the chain has no first link."),
                .heading("What controls it"),
                .paragraph("Three factors control the rate of photosynthesis: light, CO₂ concentration and temperature. When one is lacking, raising the others changes nothing: that is the **limiting factor**, the one that sets the pace of everything else, like the slowest station on an assembly line."),
                .figure(.plot(title: "Light, up to a ceiling", caption: "More light speeds up photosynthesis, up to a plateau: beyond it, CO₂ or temperature is the limit.", kind: .saturation)),
                .paragraph("The curve reads in two parts. At first it rises: every extra photon is used, light is the limiting factor. Then it flattens: the plant receives more light than it can use, and it is the available CO₂ — or the speed of the enzymes, which depends on temperature — that holds the pace back. Adding light on the plateau changes nothing any more."),
                .list([
                    "Light: the more there is, the faster photosynthesis runs, until saturation",
                    "CO₂: at 0.04% of the air, often the limiting factor in full daylight",
                    "Temperature: an optimum around 25 to 30 °C, enzymes stop beyond it",
                ]),
                .callout(
                    title: "In a greenhouse",
                    text: "Growers sometimes enrich the air with CO₂, up to three times its natural concentration: under strong light it is what holds growth back, and adding it makes tomatoes grow faster.",
                    tone: .example
                ),
                .paragraph("The same reasoning explains why plants grow little in winter, even in fine weather: the light is there, but temperature holds the enzymes back. And why a houseplant wastes away far from the window: the temperature is fine, but light is lacking. ==Identifying the limiting factor== means knowing what to change."),
                .heading("The lungs of the planet"),
                .paragraph("Forests are often called the lungs of the Earth. That is half true: forests do fix carbon, but nearly half of the world's photosynthesis happens in the oceans, through **phytoplankton** — microscopic algae in suspension. A litre of seawater holds millions of them, and it is to them that we owe every second breath."),
                .keyFigure(value: "≈ 50%", label: "of the oxygen produced each year on Earth comes from the phytoplankton of the oceans"),
                .paragraph("That is also why photosynthesis sits at the heart of the climate question. For two centuries we have been returning to the air, by burning coal and oil, carbon that photosynthesis locked underground millions of years ago. Plants and oceans reabsorb part of it, but not all: the balance of the cycle is broken, and CO₂ accumulates."),
            ]),
            DemoChapter(title: "Photosynthesis and respiration", blocks: [
                .paragraph("Photosynthesis makes sugar; **respiration** burns it. The two processes are ==the reverse of each other==, and a plant does both — including in broad daylight. Confusing the two is the most common mistake on this topic, and this chapter exists so that it does not happen to you."),
                .heading("The reverse path"),
                .paragraph("Cellular respiration takes glucose and oxygen, and releases CO₂, water and above all energy, in the form of ATP. This is what each of our cells does, all the time, and it is also what every plant cell does: a plant needs energy to grow, to move its sap, to open its stomata — and it draws that energy from its own sugar."),
                .formula("C_6H_{12}O_6 + 6\\,O_2 \\rightarrow 6\\,CO_2 + 6\\,H_2O + \\text{energy}", caption: "Respiration: the photosynthesis equation, read backwards"),
                .paragraph("The two equations are symmetrical, but they happen neither in the same place nor at the same pace. Photosynthesis is in the chloroplasts, and only in the light; respiration is in the **mitochondria**, and all the time. The table puts the two face to face."),
                .table(title: "Face to face", headers: ["", "Photosynthesis", "Respiration"], rows: [
                    ["Where", "Chloroplasts", "Mitochondria"],
                    ["When", "In the light", "Day and night"],
                    ["Uses", "CO₂, water, light", "Glucose, O₂"],
                    ["Produces", "Glucose, O₂", "CO₂, water, ATP"],
                    ["Who", "Plants, algae", "All living things"],
                ]),
                .paragraph("During the day, a plant does both at once, but photosynthesis wins by far: it fixes much more CO₂ than respiration releases, and the balance is a gain of matter. At night, only respiration goes on: the plant uses up a little of its sugar and releases a little CO₂. Over twenty-four hours, the balance stays strongly positive — that is what makes the plant grow."),
                .callout(
                    title: "Classic trap",
                    text: "“Plants respire at night and photosynthesise during the day.” Wrong: they respire **all the time**. During the day, photosynthesis simply masks respiration, because it is much more intense.",
                    tone: .warning
                ),
                .heading("Where the energy comes from"),
                .paragraph("Put end to end, the two processes tell the journey of energy through the living world. It arrives from the Sun; photosynthesis stores it in the bonds of glucose; respiration releases it as ATP; and ATP pays for all the work of the cell. Every calorie you spend was, one day, a photon caught by a leaf."),
                .figure(.flow(title: "The journey of energy", steps: ["Sunlight", "Glucose (photosynthesis)", "ATP (respiration)", "Work of the cell"])),
                .paragraph("This journey splits living things into two families. **Autotrophs** — plants, algae, some bacteria — make their own organic matter from mineral matter: they need only light, water and CO₂. **Heterotrophs** — animals, fungi, us — cannot: they must eat organic matter already made, directly or not, by an autotroph."),
                .callout(
                    title: "Autotroph, heterotroph",
                    text: "An **autotrophic** organism produces its organic matter from mineral matter; a **heterotrophic** organism must take it from other living things. Every food chain starts with an autotroph.",
                    tone: .definition
                ),
                .list([
                    "Photosynthesis: makes glucose, in the light, in the chloroplasts",
                    "Respiration: burns glucose, all the time, in the mitochondria",
                    "By day photosynthesis wins; by night only respiration goes on",
                    "Autotrophs at the head of the chain, heterotrophs behind",
                ]),
                .paragraph("This last point is the key to the whole chapter, and to many others: life on Earth runs on solar energy, ==converted once==, by photosynthesis, then passed from mouth to mouth along the food chains. Everything else — breathing, running, thinking — is a way of spending that energy."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "What are the reactants and products of photosynthesis?",
                back: "Reactants: carbon dioxide (CO₂) and water (H₂O), with light energy. Products: glucose (C₆H₁₂O₆) and oxygen (O₂).",
                figure: .flow(title: "From photon to sugar", steps: ["Light", "Water split, O₂", "ATP", "Glucose"]),
                chapter: 0
            ),
            DemoCard(
                kind: .choice,
                front: "Where does the light phase of photosynthesis take place?",
                back: "In the thylakoid membranes, inside the chloroplast. The stroma hosts the Calvin cycle.",
                choices: ["In the stroma", "In the thylakoid membranes", "In the nucleus", "In the mitochondria"],
                answerIndex: 1,
                chapter: 1
            ),
            DemoCard(
                kind: .cloze,
                front: "Chlorophyll mostly absorbs blue and red, and reflects …, hence the colour of leaves.",
                back: "green",
                chapter: 0
            ),
            DemoCard(kind: .basic, front: "What is a limiting factor?", back: "The factor (light, CO₂ or temperature) whose shortage holds photosynthesis back: while it is lacking, raising the others changes nothing.", chapter: 2),
            DemoCard(kind: .cloze, front: "It takes … turns of the Calvin cycle to build one glucose molecule.", back: "six", chapter: 1),
            DemoCard(kind: .choice, front: "Which gas does photosynthesis release?", back: "Oxygen (O₂), from the splitting of water molecules during the light phase.", choices: ["Carbon dioxide", "Oxygen", "Nitrogen", "Hydrogen"], answerIndex: 1, chapter: 0),
            DemoCard(kind: .basic, front: "What is the difference between photosynthesis and respiration?", back: "Photosynthesis makes glucose from CO₂ and water, in the light, in the chloroplasts. Respiration burns that glucose with oxygen to release energy (ATP), all the time, in the mitochondria.", chapter: 3),
            DemoCard(kind: .cloze, front: "An organism that makes its own organic matter from mineral matter is called … .", back: "autotrophic", chapter: 3),
        ]
    )

    // MARK: Maths: derivatives

    private static let derivativesEN = OnboardingDemoCourse(
        id: "maths-derivatives",
        emoji: "📐",
        subject: "Mathématiques",
        title: "Derivatives",
        summary: "The derivative at a point, the tangent, the standard derivatives and the calculation rules, the sign of the derivative that gives the variations, and optimisation problems.",
        accentIndex: 0,
        chapters: [
            DemoChapter(title: "The derivative and the tangent", blocks: [
                .paragraph("Differentiating means measuring ==how fast a function changes==. On a curve, that speed can be seen: it is the slope of the tangent at the point you are looking at. The whole chapter fits in that idea, and the rest is only calculation."),
                .heading("The rate of change"),
                .paragraph("Before instantaneous speed comes average speed. Between two points with abscissas $a$ and $a+h$, the function has changed by $f(a+h) - f(a)$ while $x$ changed by $h$. The ratio of the two is the **rate of change**: it is the slope of the line joining the two points of the curve, the secant."),
                .formula("\\frac{f(a+h) - f(a)}{h}", caption: "The rate of change of f between a and a + h: the slope of the secant"),
                .paragraph("This rate depends on $h$: the closer the two points, the more the secant looks like the curve itself around $a$. The idea of the derivative is to let $h$ tend to zero — to bring the two points together until they merge — and to look at what the slope tends to."),
                .callout(
                    title: "Derivative at a point",
                    text: "The derivative of $f$ at $a$, written $f'(a)$, is the limit of the rate of change between $a$ and $a+h$ as $h$ tends to 0. When that limit exists, $f$ is said to be **differentiable** at $a$.",
                    tone: .definition
                ),
                .formula("f'(a) = \\lim_{h \\to 0} \\frac{f(a+h) - f(a)}{h}", caption: "The rate of change, as h becomes infinitely small"),
                .paragraph("Geometrically, when the two points meet, the secant becomes ==the tangent==: the line that touches the curve at $a$ while following its direction. The derivative is its slope. A steep positive slope says the curve rises fast; a zero slope, that the curve is horizontal there."),
                .figure(.plot(title: "The tangent at a point", caption: "The line that “hugs” the curve at $a$: its slope is $f'(a)$.", kind: .tangent)),
                .paragraph("Knowing the slope and one point is enough to write the line. The equation of the tangent at $a$ is $y = f'(a)(x - a) + f(a)$: a line through the point $(a, f(a))$ with slope $f'(a)$. It is a formula to know by heart, because it comes up in almost every test."),
                .callout(
                    title: "Example",
                    text: "For $f(x) = x^2$ at $a = 1$: the rate of change is $\\frac{(1+h)^2 - 1}{h} = 2 + h$, which tends to $2$. So $f'(1) = 2$, and the tangent is $y = 2(x - 1) + 1 = 2x - 1$.",
                    tone: .example
                ),
                .paragraph("The sign of the derivative reads directly on the curve, and it is what the whole of chapter three will be about. A tangent rising from left to right has a positive slope; a falling tangent, a negative slope; a horizontal tangent, a zero slope — and that is often where something happens."),
                .list([
                    "$f'(a) > 0$: the curve rises at $a$",
                    "$f'(a) < 0$: it falls",
                    "$f'(a) = 0$: horizontal tangent, often a peak or a trough",
                ]),
                .heading("Why it matters"),
                .paragraph("The derivative is not only a classroom object: it is everywhere something varies. Speed is the derivative of position with respect to time; acceleration, the derivative of speed. In economics, marginal cost is the derivative of total cost. When a physicist or an economist asks “at what rate?”, they are asking for a derivative."),
                .paragraph("That is also why the notion was invented twice, in the seventeenth century, by Newton to describe the motion of planets and by Leibniz for the geometry of curves. Two problems, one idea: ==look at what happens infinitely close to a point==."),
            ]),
            DemoChapter(title: "Computing a derivative", blocks: [
                .paragraph("You almost never compute a limit by hand: you learn **the standard derivatives**, and the rules that combine them. With a table of eight lines and three rules, you can differentiate any function in the syllabus — and it is an exercise that must become a reflex."),
                .heading("The standard derivatives"),
                .paragraph("Every line of the table can be proved with the definition from the previous chapter, and it is worth having done it at least once for $x^2$. But in practice, you know them by heart. The most important line is the one for $x^n$: the power comes down as a factor, and the exponent loses one."),
                .table(title: "Standard derivatives", headers: ["f(x)", "f′(x)"], rows: [
                    ["k (constant)", "0"],
                    ["x", "1"],
                    ["x²", "2x"],
                    ["xⁿ", "n · xⁿ⁻¹"],
                    ["1/x", "−1/x²"],
                    ["√x", "1/(2√x)"],
                    ["eˣ", "eˣ"],
                    ["ln x", "1/x"],
                ]),
                .paragraph("Two lines deserve a remark. The derivative of a constant is zero: a function that does not change has zero speed, which makes sense. And the derivative of $e^x$ is $e^x$ itself: it is ==the only function== that is its own derivative, and that is exactly why the exponential is everywhere in physics — it describes everything that grows at a rate proportional to its size."),
                .heading("The rules"),
                .callout(
                    title: "The three rules",
                    text: "**Sum**: $(u+v)' = u' + v'$. **Product**: $(uv)' = u'v + uv'$. **Quotient**: $(u/v)' = (u'v - uv')/v^2$. And for a constant $k$: $(ku)' = ku'$.",
                    tone: .insight
                ),
                .paragraph("The sum rule is the most natural: differentiate term by term. Example: $f(x) = 3x^2 - 5x + 2$ gives $f'(x) = 6x - 5$. Constants vanish, ==powers drop by one==, coefficients stay as factors. A polynomial is differentiated this way in one line."),
                .formula("(uv)' = u'v + uv'", caption: "The derivative of a product: each factor differentiated in turn, then added"),
                .paragraph("The product rule needs a little more care. For $f(x) = x^2 e^x$, set $u = x^2$ and $v = e^x$, so $u' = 2x$ and $v' = e^x$: $f'(x) = 2x\\,e^x + x^2 e^x = (2x + x^2)\\,e^x$. Differentiate the first while keeping the second, then the other way round, and add. Factorising at the end is not a nicety: it is what will let you study the sign."),
                .callout(
                    title: "The mistake to avoid",
                    text: "$(uv)' \\neq u'v'$. The derivative of a product is **not** the product of the derivatives: $(x \\cdot x)' = 2x$, not $1 \\cdot 1$. The same goes for the quotient.",
                    tone: .warning
                ),
                .paragraph("The quotient follows the same logic, with a minus sign and a square in the denominator. For $f(x) = \\frac{x}{x+1}$: $u = x$, $v = x + 1$, so $f'(x) = \\frac{1 \\cdot (x+1) - x \\cdot 1}{(x+1)^2} = \\frac{1}{(x+1)^2}$. The numerator often simplifies a lot — when it does not, check the calculation."),
                .heading("A function inside another"),
                .paragraph("There remains the case where one function is nested inside another: $(2x+1)^3$, $\\sqrt{x^2+1}$, $e^{-x}$. Differentiate the outside while keeping the inside, then multiply by the derivative of the inside. For a power, that gives the formula below; for the exponential, $(e^{u})' = u'\\,e^{u}$."),
                .formula("(u^n)' = n\\,u'\\,u^{n-1}", caption: "Differentiating a power of a function: the outside, times the derivative of the inside"),
                .paragraph("Example: $f(x) = (2x+1)^3$. The inside is $u = 2x+1$, with derivative $u' = 2$; so $f'(x) = 3 \\cdot 2 \\cdot (2x+1)^2 = 6(2x+1)^2$. Forgetting the factor $u'$ is the most frequent mistake in the whole chapter: the derivative of the inside ==is never left out==."),
                .list([
                    "Spot the form: sum, product, quotient, or nested function",
                    "Differentiate each piece with the table",
                    "Assemble with the right rule",
                    "Simplify and factorise, then check the sign",
                ], ordered: true),
                .paragraph("These four steps are the same routine for every function. With practice they happen in your head; without, they happen on scrap paper. Either way, the last one — factorising — is the one that prepares the next chapter."),
            ]),
            DemoChapter(title: "Derivative and variations", blocks: [
                .paragraph("The sign of the derivative tells you ==which way the function goes==: positive, it rises; negative, it falls. This is the key to every table of variations, and the reason you learnt to differentiate."),
                .heading("The theorem"),
                .paragraph("If $f'$ is positive on an interval, $f$ is increasing on that interval; if $f'$ is negative, $f$ is decreasing; if $f'$ is zero on the whole interval, $f$ is constant. The intuition is the one from chapter one: a positive slope everywhere is a curve that rises everywhere."),
                .figure(.plot(title: "Sign of f′ and direction of f", caption: "Where $f'$ is positive, $f$ rises; where it vanishes while changing sign, $f$ reaches an extremum.", kind: .variation)),
                .paragraph("The chart shows the two curves one under the other. As long as $f'$ is above the axis, $f$ climbs; the moment $f'$ crosses the axis going down, $f$ reaches a peak and comes back down. The point where $f'$ vanishes **while changing sign** is a **local extremum**: a maximum if $f'$ goes from positive to negative, a minimum the other way round."),
                .heading("A complete example"),
                .paragraph("For $f(x) = x^3 - 3x$: $f'(x) = 3x^2 - 3 = 3(x-1)(x+1)$. The derivative vanishes at $-1$ and $1$. A sign table for a product of two factors gives: positive before $-1$, negative between $-1$ and $1$, positive after $1$. We deduce a **local maximum** at $-1$, where $f(-1) = 2$, and a **local minimum** at $1$, where $f(1) = -2$."),
                .table(title: "Variations of f(x) = x³ − 3x", headers: ["Interval", "Sign of f′", "Direction of f"], rows: [
                    ["]−∞ ; −1[", "+", "increasing"],
                    ["]−1 ; 1[", "−", "decreasing"],
                    ["]1 ; +∞[", "+", "increasing"],
                ]),
                .paragraph("The table is the expected answer to “study the variations of $f$”: the intervals on top, the sign of the derivative in the middle, the arrows at the bottom, with the values of $f$ at the points where it changes direction. It is a standard object, and it must be laid out in exactly that order."),
                .callout(
                    title: "Method",
                    text: "1. Differentiate. 2. Study the sign of $f'$ (factorise!). 3. Deduce the variations. 4. Compute the values at the bounds and at the extrema. 5. Draw up the table.",
                    tone: .insight
                ),
                .paragraph("Step two is where it goes wrong. The sign of a derivative cannot be read off $6x - 5$ or $3x^2 - 3$ as they stand: you must ==solve $f'(x) = 0$== and then draw a sign table, or factorise to read the sign of each factor. An unfactorised derivative is a derivative you know nothing about."),
                .keyFigure(value: "f′ = 0", label: "where the curve has a horizontal tangent: a peak, a trough, or a plateau"),
                .paragraph("A horizontal tangent is therefore a signal, not a proof: it says the function stops rising or falling for an instant, but not whether it sets off again the other way. The sign table decides, and it alone."),
                .callout(
                    title: "Careful",
                    text: "$f'(a) = 0$ is not enough for an extremum: $x^3$ has a zero derivative at 0 and does not change direction — it is a plateau. $f'$ must **change sign** at $a$.",
                    tone: .warning
                ),
                .heading("Reading a curve"),
                .paragraph("The link works the other way too: from the curve of $f$ you can guess the sign of $f'$, and from the curve of $f'$, the variations of $f$. It is a classic exercise: you are given the graph of the derivative, and asked where the function is increasing. The answer is: where the curve of $f'$ is above the horizontal axis."),
                .list([
                    "Curve of $f$ rising ⇔ $f'$ positive",
                    "Peak or trough of $f$ ⇔ $f'$ vanishes while changing sign",
                    "Curve of $f'$ above the axis ⇔ $f$ increasing",
                ]),
                .paragraph("This cross-reading is what separates a student who applies a recipe from one who understands: the derivative is not one more calculation, it is ==the curve seen differently==. And it is what makes the next chapter possible, where we look for the best point of a curve we have not drawn."),
            ]),
            DemoChapter(title: "Solving an optimisation problem", blocks: [
                .paragraph("Optimising means finding ==the largest or the smallest value== a quantity can take: the maximum area of an enclosure, the minimum cost of a box, the highest profit. These are the problems where the derivative does something concrete, and the ones that earn the most marks."),
                .heading("An enclosure against a wall"),
                .paragraph("You have 40 metres of fencing to enclose a rectangular pen against a wall: the wall makes one side, the fencing the other three. Which dimensions give the largest area? Call $x$ the width, perpendicular to the wall. The two widths take $2x$ metres of fencing; $40 - 2x$ remain for the length. The area is the product of the two."),
                .formula("A(x) = x\\,(40 - 2x) = 40x - 2x^2", caption: "The area of the pen, for x between 0 and 20"),
                .paragraph("The problem has become a study of a function: we look for the maximum of $A$ on $[0 ; 20]$ — beyond 20, the length would be negative. Differentiate: $A'(x) = 40 - 4x$, which vanishes for $x = 10$, positive before, negative after. The table of variations gives the answer."),
                .table(title: "Variations of A(x) = 40x − 2x²", headers: ["x", "Sign of A′", "Direction of A"], rows: [
                    ["[0 ; 10[", "+", "increasing, from 0 to 200"],
                    ["x = 10", "0", "maximum: A(10) = 200"],
                    ["]10 ; 20]", "−", "decreasing, from 200 to 0"],
                ]),
                .paragraph("The maximum area is $200$ m², for a width of $10$ m and a length of $20$ m. Note that it is not a square: because the wall replaces one side, the best rectangle is twice as long as it is wide. Without the derivative, we could have tried values at random; with it, we have ==the certainty== that this is the best."),
                .callout(
                    title: "Method",
                    text: "1. Choose the variable, and the interval where it makes sense. 2. Express the quantity to optimise as a function of that single variable. 3. Differentiate, study the sign, draw up the table. 4. Read off the extremum, and **answer the question asked** — with the unit.",
                    tone: .insight
                ),
                .heading("A second example"),
                .paragraph("A company makes $x$ hundred items a day, at a total cost $C(x) = x^2 + 4x + 16$ (in hundreds of euros), for $x$ between 1 and 10. The average cost per hundred items is $M(x) = C(x)/x = x + 4 + 16/x$. For which output is this average cost lowest?"),
                .formula("M'(x) = 1 - \\frac{16}{x^2} = \\frac{x^2 - 16}{x^2} = \\frac{(x-4)(x+4)}{x^2}", caption: "The derivative, factorised to read its sign"),
                .paragraph("On $[1 ; 10]$, the denominator and $x + 4$ are positive: the sign of $M'$ is that of $x - 4$, negative before 4, positive after. The average cost falls until $x = 4$, then rises again: the minimum is at $x = 4$, and equals $M(4) = 4 + 4 + 4 = 12$, that is 1,200 euros per hundred. Making four hundred items a day is **the most economical rate**."),
                .figure(.flow(title: "The approach", steps: ["One variable", "One function", "Its derivative", "Its table", "The answer"])),
                .paragraph("The two examples follow exactly the same path, and it is always the same: the difficulty of an optimisation problem is almost never in the derivative, it is in the **setting up** — finding the right variable and writing the quantity as a function of it. Once the function is laid down, the rest is chapter three."),
                .callout(
                    title: "The traps",
                    text: "Forgetting the interval (a negative length does not exist); differentiating the wrong quantity (the total cost instead of the average cost); stopping at $x = 10$ without saying the area is $200$ m². The examiner expects **the answer to the question**, not only the table.",
                    tone: .warning
                ),
                .list([
                    "Pen, box, cylinder: one free dimension, a constraint of length or volume",
                    "Cost, profit, revenue: a quantity produced, an economic function",
                    "Journey, speed, time: a position or an instant to choose",
                ]),
                .paragraph("These three families cover almost every exam question. Each time, the hidden question is the same: ==for which value of $x$ does the derivative vanish while changing sign?== When you can recognise it under any disguise, the chapter is yours."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "What does the derivative $f'(a)$ represent geometrically?",
                back: "The slope of the tangent to the curve of $f$ at the point with abscissa $a$.",
                figure: .plot(title: "The tangent at a", caption: "", kind: .tangent),
                chapter: 0
            ),
            DemoCard(
                kind: .choice,
                front: "What is the derivative of $f(x) = 3x^2 - 5x + 2$?",
                back: "$f'(x) = 6x - 5$: the power drops by one, the $x$ term becomes its slope, the constant disappears.",
                choices: ["$6x - 5$", "$3x - 5$", "$6x + 2$", "$x^2 - 5$"],
                answerIndex: 0,
                chapter: 1
            ),
            DemoCard(
                kind: .cloze,
                front: "On an interval where $f'$ is …, the function $f$ is increasing.",
                back: "positive",
                chapter: 2
            ),
            DemoCard(kind: .basic, front: "What is the formula for the derivative of a product?", back: "$(uv)' = u'v + uv'$: differentiate each factor in turn and add.", chapter: 1),
            DemoCard(kind: .cloze, front: "The derivative of $e^x$ is … .", back: "$e^x$", chapter: 1),
            DemoCard(kind: .choice, front: "At which points does $f(x) = x^3 - 3x$ have a local extremum?", back: "At $x = -1$ (maximum, value 2) and $x = 1$ (minimum, value $-2$): where $f'(x) = 3(x-1)(x+1)$ vanishes while changing sign.", choices: ["$x = 0$", "$x = -1$ and $x = 1$", "$x = 3$", "None"], answerIndex: 1, chapter: 2),
            DemoCard(kind: .basic, front: "How do you find the maximum of a quantity in an optimisation problem?", back: "Express the quantity as a function of a single variable on the interval where it makes sense, differentiate, study the sign of the derivative, and read the maximum in the table of variations where the derivative vanishes going from positive to negative.", chapter: 3),
            DemoCard(kind: .cloze, front: "With 40 m of fencing against a wall, the area of the pen is largest for a width of … m.", back: "10", chapter: 3),
        ]
    )

    // MARK: Physics: energy

    private static let energyEN = OnboardingDemoCourse(
        id: "physics-energy",
        emoji: "⚡️",
        subject: "Physique",
        title: "Energy",
        summary: "The forms of energy, its conservation from one form to another, power and efficiency, then energy chains, with the formulas and orders of magnitude of the syllabus.",
        accentIndex: 6,
        chapters: [
            DemoChapter(title: "The forms of energy", blocks: [
                .paragraph("Energy cannot be seen, it **transforms**: a falling apple, the heat of an engine, the light of a lamp are the same quantity in different forms. It is measured in ==joules (J)==, and one joule is roughly the energy needed to lift an apple one metre."),
                .heading("One quantity, several forms"),
                .paragraph("Physicists took two centuries to understand that heat, motion, light and electricity were one and the same thing in different clothes. What links them is that each can be converted into another — an engine turns heat into motion, a dynamo turns motion into electricity — and that the total amount never changes. The table below lists the forms in the syllabus."),
                .table(title: "The usual forms", headers: ["Form", "Depends on", "Example"], rows: [
                    ["Kinetic", "mass and speed", "a moving car"],
                    ["Gravitational potential", "mass and height", "an apple in the tree"],
                    ["Thermal", "molecular agitation", "a hot pan"],
                    ["Electrical", "current", "a battery"],
                    ["Chemical", "bonds", "petrol, glucose"],
                ]),
                .paragraph("Two of these forms have a formula to know by heart. **Kinetic energy** is that of a moving body: it grows with mass, and with the square of speed. Doubling the mass doubles it; doubling the speed quadruples it. That square is what makes high-speed accidents so severe."),
                .formula("E_k = \\frac{1}{2} m v^2", caption: "Kinetic energy: m in kg, v in m/s, E in J"),
                .paragraph("**Gravitational potential energy** is that of a body at a height: energy “in reserve”, which will become motion if you let go. It is proportional to mass and to height, and to the strength of gravity $g$, about $9.8$ N/kg on Earth — and six times less on the Moon."),
                .formula("E_p = m g h", caption: "Gravitational potential energy: g ≈ 9.8 N/kg, h in m"),
                .callout(
                    title: "Order of magnitude",
                    text: "A 1,000 kg car at 50 km/h (≈ 14 m/s) carries $E_k = \\frac{1}{2} \\times 1000 \\times 14^2 \\approx 98\\,000$ J, nearly 100 kJ. At 100 km/h, **four times more**: 400 kJ, the energy it would take to hoist it forty metres up.",
                    tone: .example
                ),
                .paragraph("This example shows the trap of units: speed must be in metres per second, not kilometres per hour, or the result is off by a factor of thirteen. To convert, divide km/h by 3.6. It is ==the first thing to check== in any kinetic energy calculation."),
                .keyFigure(value: "× 4", label: "when speed doubles, kinetic energy quadruples: that is the square in the formula"),
                .heading("Units"),
                .paragraph("The joule is small at the scale of everyday life, and its multiples are used: the kilojoule (1 kJ = 1,000 J) for food, the megajoule for fuels, the kilowatt-hour for electricity. A gram of sugar releases about 17 kJ; a litre of petrol, 35 MJ; a chocolate bar, 1,000 kJ — enough to hoist a car to the top of the Eiffel Tower, if we could convert without loss."),
                .callout(
                    title: "Unit",
                    text: "Energy is expressed in joules, never in watts. The watt measures **power**: energy per second. Confusing the two is confusing a litre with a litre per minute.",
                    tone: .warning
                ),
                .list([
                    "1 kJ = 1,000 J: the energy of a food is given in kJ on the packet",
                    "1 kWh = 3,600,000 J: the unit on the electricity bill",
                    "1 calorie ≈ 4.18 J: the old unit, still on labels",
                ]),
                .paragraph("Remember the logic rather than the figures: energy is always a quantity, like a volume, and it converts from one form to another without ever disappearing. It is this principle, the most important in all of physics, that the next chapter states."),
            ]),
            DemoChapter(title: "Conservation and transfers", blocks: [
                .paragraph("==bleu|Energy is neither created nor destroyed==: it passes from one form to another, from one system to another. This is the conservation principle, and it holds for everything, from the atom to the galaxy. No experiment, ever, has caught it out."),
                .heading("A fall"),
                .paragraph("Take a ball held two metres above the ground. It has potential energy, and no kinetic energy. Let it go: as it falls, its height decreases and its speed increases — potential energy becomes kinetic energy, in exactly the same proportions. At the ground, everything is kinetic; on impact, everything becomes heat and sound."),
                .figure(.flow(title: "The energy chain of a fall", steps: ["Potential energy, at the top", "Becomes kinetic energy", "Impact: heat and sound", "Total unchanged"])),
                .paragraph("This reasoning lets you calculate without knowing the forces. A ball dropped from 2 m loses potential energy and gains exactly as much kinetic energy, as long as friction is neglected: $mgh = \\frac{1}{2}mv^2$, so the mass cancels and the speed at the ground is $v = \\sqrt{2gh}$."),
                .formula("v = \\sqrt{2 g h} \\approx \\sqrt{2 \\times 9.8 \\times 2} \\approx 6.3 \\text{ m/s}", caption: "The speed at the ground, without friction: the same for a marble and for a bowling ball"),
                .paragraph("The result does not depend on the mass: a marble and a bowling ball dropped from the same height arrive at the same speed. Galileo observed it from the top of the tower of Pisa; conservation of energy explains it in one line. That is ==the strength of this principle==: it gives answers where the equations of motion would be painful."),
                .callout(
                    title: "Mechanical energy",
                    text: "The sum of kinetic and potential energy: $E_m = E_k + E_p$. Without friction, it is conserved: what one loses, the other gains.",
                    tone: .definition
                ),
                .formula("E_m = E_k + E_p = \\text{constant}", caption: "In the absence of friction"),
                .paragraph("The pendulum is the perfect example. At the top of its swing it stops for an instant: everything is potential. At the bottom it moves fastest: everything is kinetic. In between, energy passes endlessly from one form to the other, and the pendulum climbs back exactly to the height it started from — if it were not for the air."),
                .heading("What about friction?"),
                .paragraph("In real life, the pendulum eventually stops, the ball bounces lower, the car stops when the engine is cut. Mechanical energy decreases. It has not disappeared: friction has converted it into **thermal energy**, in the air, in the ground, in the brakes — which heat up, sometimes a lot."),
                .callout(
                    title: "What friction does",
                    text: "It “destroys” nothing: the mechanical energy lost becomes thermal energy. The total is always conserved, it is just **less useful** — diffuse heat no longer makes anything move.",
                    tone: .insight
                ),
                .paragraph("This loss of usefulness is a deep idea. Energy is conserved, but it **degrades**: every conversion leaves a little of it as lukewarm heat that can no longer be recovered. That is why perpetual motion is impossible, and why an engine must be fed continuously."),
                .list([
                    "Work: energy transferred by a force that moves something — pushing, lifting, braking",
                    "Heat: transfer through a temperature difference — a pan on the stove",
                    "Radiation: transfer through light — the Sun warming your skin",
                ]),
                .paragraph("These three modes are the only ways energy passes from one system to another. Drawing up an **energy balance** means choosing a system, listing what comes in and what goes out through these three routes, and checking that the account adds up: ==what comes in minus what goes out is what stays==."),
            ]),
            DemoChapter(title: "Power and efficiency", blocks: [
                .paragraph("**Power** says how fast energy is transferred. A 2,000 W heater transfers 2,000 joules every second. Two devices can use the same energy, one in a minute and the other in an hour: the first is sixty times more powerful."),
                .heading("Power"),
                .formula("P = \\frac{E}{\\Delta t}", caption: "P in watts (W), E in joules, Δt in seconds"),
                .paragraph("The formula reads both ways. Knowing the power and the duration, you get the energy back: $E = P \\times \\Delta t$. A 2,000 W oven switched on for an hour uses $2000 \\times 3600 = 7.2 \\times 10^6$ J, that is 7.2 MJ. The orders of magnitude in the table are worth remembering."),
                .table(title: "A few powers", headers: ["What", "Power"], rows: [
                    ["A human at rest", "≈ 100 W"],
                    ["A cyclist at full effort", "≈ 300 W"],
                    ["An oven", "2,000 W"],
                    ["A car", "≈ 100 kW"],
                    ["A wind turbine", "≈ 3 MW"],
                    ["A nuclear reactor", "≈ 1,000 MW"],
                ]),
                .paragraph("A human at rest gives off roughly the power of an old-fashioned light bulb: that is why a full room warms up quickly. And a nuclear reactor produces ten million times more — enough to supply a million homes. Power is ==the flow rate of energy==, as the flow of a tap is that of water."),
                .callout(
                    title: "The kilowatt-hour",
                    text: "1 kWh is 1,000 W for one hour: $1000 \\times 3600 = 3.6 \\times 10^6$ J. It is the unit on the electricity bill, and it costs about twenty cents.",
                    tone: .example
                ),
                .paragraph("The kilowatt-hour is an energy, not a power — the “hour” is there to remind you: a power multiplied by a time. A French household uses about 4,700 kWh of electricity a year, a little over 500 W on average, day and night. A 2,000 W radiator left on for an eight-hour night uses 16 of them by itself."),
                .heading("Efficiency"),
                .paragraph("No converter is perfect: part of the energy received leaves as heat, and has served no purpose. The ==efficiency== compares what is useful to what is supplied. A petrol engine receives the chemical energy of the fuel and returns only a third of it as motion: the rest heats the engine, the exhaust, and the air around."),
                .formula("\\eta = \\frac{E_{useful}}{E_{supplied}}", caption: "Always less than or equal to 1 (100%)"),
                .paragraph("Efficiency is often given as a percentage, and it multiplies along a chain: if a power station has an efficiency of 35% and the grid 90%, the efficiency of the whole is $0.35 \\times 0.9 \\approx 0.32$. Every extra link loses something, which is why we try to have as few as possible."),
                .bars(title: "Efficiency of a few converters", unit: "%", bars: [
                    DemoBar(label: "Petrol engine", value: 35),
                    DemoBar(label: "LED bulb", value: 40),
                    DemoBar(label: "Electric motor", value: 90),
                    DemoBar(label: "Electric heater", value: 100),
                ]),
                .paragraph("The chart explains a good part of the energy transition. An electric motor turns nine tenths of what it receives into motion, a petrol engine one third: for the same energy at the start, the electric car goes almost three times as far. An incandescent bulb, for its part, had an efficiency of 5% — it was a heater that gave off a little light."),
                .callout(
                    title: "100% efficiency?",
                    text: "An electric heater turns everything into heat, but heat is exactly what we want: its efficiency is 100%. For an engine, the same heat is a loss. **Useful** depends on what you ask the device to do.",
                    tone: .warning
                ),
                .list([
                    "Power: energy per second, in watts",
                    "Energy: power times duration — in joules, or in kWh on the bill",
                    "Efficiency: useful over supplied, never more than 1, and it multiplies along a chain",
                ]),
                .paragraph("These three notions let you read any spec sheet and check any promise. A device that claimed more useful energy than it receives would break the first principle; an efficiency above one ==does not exist==, whatever the advertising says."),
            ]),
            DemoChapter(title: "Energy chains", blocks: [
                .paragraph("An **energy chain** is the diagram that tells the journey of energy: where it comes from, which converters it passes through, in what form it comes out, and what is lost on the way. It is ==the tool of the energy balance==, and it is almost always what you are asked to draw in an exam."),
                .heading("Reading a chain"),
                .paragraph("The diagram reads from left to right. At both ends, **reservoirs**: where the energy is stored at the start, where it ends up. Between them, **converters**: the devices that make it change form. Each arrow carries one form of energy, and each converter lets out an arrow of heat — the losses. A hydroelectric power station is the most readable example."),
                .figure(.flow(title: "A hydroelectric power station", steps: ["Stored water: potential", "Fall: kinetic", "Turbine: mechanical", "Alternator: electrical", "Grid"])),
                .paragraph("The water in the dam has potential energy, because of its height. Falling through the pipes, it converts it into kinetic energy. The turbine turns this moving water into rotation; the alternator turns the rotation into current; the lines carry the current away. At each step a little heat escapes — but very little: a hydro plant has an efficiency close to 90%, the best of all."),
                .paragraph("The same logic describes any system, including a human body. A cyclist converts the chemical energy of food into mechanical energy in the muscles, with an efficiency of about 25%: three quarters leave as heat, and that is why you sweat."),
                .figure(.flow(title: "A cyclist", steps: ["Food: chemical", "Muscles: mechanical", "Wheels: kinetic", "Friction: heat"])),
                .heading("Converters"),
                .paragraph("A converter is defined by what it receives and what it returns. The table gathers those in the syllabus; for each, the last column says in what form the unused part leaves. Notice that it is **always heat**: it is the final form of all degraded energy."),
                .table(title: "A few converters", headers: ["Converter", "Receives", "Returns", "Loses"], rows: [
                    ["Electric motor", "Electrical", "Mechanical", "Heat"],
                    ["Solar panel", "Radiation", "Electrical", "Heat"],
                    ["Battery", "Chemical", "Electrical", "Heat"],
                    ["LED lamp", "Electrical", "Light", "Heat"],
                    ["Petrol engine", "Chemical", "Mechanical", "Heat, gases"],
                ]),
                .paragraph("Drawing the chain of a device already means understanding how it works — and often why it gets hot. A computer receives electrical energy and, in the end, returns nothing but heat: the computation itself stores nothing. A warm phone charger is a converter losing a few percent on the way."),
                .callout(
                    title: "The toaster",
                    text: "It receives 1,000 W of electrical energy and returns 1,000 W of heat: efficiency 100%. But if the electricity comes from a 35% thermal power station, nearly 3,000 W of gas had to be burnt to toast the bread. **The whole chain** counts, not only the last link.",
                    tone: .example
                ),
                .heading("Where electricity comes from"),
                .paragraph("Following the chain all the way back leads to the **sources** of energy: what we burn, what we let fall, what we capture. Some renew themselves on a human timescale — sun, wind, water, biomass —, others run out — coal, oil, gas, uranium. The chart shows where electricity comes from in France, where nuclear has dominated since the 1980s."),
                .bars(title: "Where France's electricity comes from (orders of magnitude)", unit: "%", bars: [
                    DemoBar(label: "Nuclear", value: 65),
                    DemoBar(label: "Hydro", value: 12),
                    DemoBar(label: "Wind", value: 10),
                    DemoBar(label: "Solar", value: 5),
                    DemoBar(label: "Gas, coal", value: 8),
                ]),
                .paragraph("These shares change from one year to the next — a dry winter empties the dams, a windy year swells wind power — but the order remains: two thirds nuclear, a quarter renewable, and a fossil share used mostly for peaks in demand. Elsewhere in Europe, gas and coal weigh far more, and electricity there emits several times more CO₂."),
                .callout(
                    title: "Renewable, not free",
                    text: "A renewable source replenishes itself, but capturing it has a cost: materials, land, losses along the chain. And “renewable” does not mean “without effect”: a dam drowns a valley, a wind turbine needs copper. **No chain is without loss, and no source is without consequence.**",
                    tone: .warning
                ),
                .list([
                    "Reservoirs at both ends, converters between them, one form of energy per arrow",
                    "Each converter loses heat: efficiency measures it",
                    "Efficiencies multiply along the chain",
                    "The source, at the very start, decides what the energy costs — and what it emits",
                ]),
                .paragraph("With these four rules, you can draw and comment on any chain: that of a phone, a train, a power station. It is the chapter that links physics to what you read in the news, and ==the most useful== of the four for understanding the world around you."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "What happens to the potential energy of a falling ball?",
                back: "It converts into kinetic energy during the fall (speed increases), then into thermal and sound energy on impact. The total is conserved.",
                figure: .flow(title: "Energy chain", steps: ["Potential", "Kinetic", "Heat and sound"]),
                chapter: 1
            ),
            DemoCard(
                kind: .choice,
                front: "If a car's speed doubles, its kinetic energy is…",
                back: "Quadrupled: $E_k = \\frac{1}{2} m v^2$ depends on the square of the speed.",
                choices: ["doubled", "quadrupled", "unchanged", "halved"],
                answerIndex: 1,
                chapter: 0
            ),
            DemoCard(
                kind: .cloze,
                front: "Power is the energy transferred per unit of …: it is expressed in watts.",
                back: "time",
                chapter: 2
            ),
            DemoCard(kind: .basic, front: "What is the formula for gravitational potential energy?", back: "$E_p = m g h$, with m in kg, g ≈ 9.8 N/kg and h in metres.", chapter: 0),
            DemoCard(kind: .cloze, front: "Efficiency is the ratio of … energy to supplied energy.", back: "useful", chapter: 2),
            DemoCard(kind: .choice, front: "What is the unit of energy?", back: "The joule (J). The watt measures power, that is energy per second.", choices: ["The watt", "The joule", "The newton", "The volt"], answerIndex: 1, chapter: 0),
            DemoCard(kind: .basic, front: "What is an energy chain?", back: "The diagram that follows energy from one reservoir to another, through converters: one form of energy per arrow, and at each converter an arrow of losses, as heat.", chapter: 3),
            DemoCard(kind: .cloze, front: "In a hydroelectric power station, the … energy of the stored water becomes kinetic energy in the fall.", back: "potential", chapter: 3),
        ]
    )
}
