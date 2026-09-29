import Foundation

// MARK: - The four courses, in English

/// The demo courses, in English. High-school level: what a teacher would write on the
/// board, with exact definitions, mechanisms and examples.
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
                .paragraph("In 1945 the victors of the war no longer share anything. The United States and the USSR, allies against Nazi Germany, become ==the two superpowers== of a world splitting in two."),
                .callout(
                    title: "Cold War",
                    text: "A confrontation **without direct war** between the United States and the USSR, from 1947 to 1991, fought through economic pressure, propaganda, the arms race and proxy wars.",
                    tone: .definition
                ),
                .figure(.split(
                    title: "Two models",
                    left: DemoColumn(title: "Western bloc", items: ["United States", "Liberal democracy", "Market economy", "Marshall Plan (1947)", "NATO (1949)"]),
                    right: DemoColumn(title: "Eastern bloc", items: ["USSR", "Single party", "Planned economy", "Cominform (1947)", "Warsaw Pact (1955)"])
                )),
                .paragraph("In March 1947 President Truman promises to help any country threatened by communism: this is the ==bleu|Truman Doctrine==, or *containment*. The Marshall Plan, three months later, funds the reconstruction of Western Europe, and ties it to the American camp."),
                .timeline(title: "The first years", events: [
                    DemoEvent(date: "1947", label: "Truman Doctrine and Marshall Plan"),
                    DemoEvent(date: "1948", label: "Berlin Blockade"),
                    DemoEvent(date: "1949", label: "NATO founded, first Soviet bomb"),
                    DemoEvent(date: "1950", label: "Korean War begins"),
                ]),
                .callout(
                    title: "Remember",
                    text: "The Berlin Blockade (June 1948 to May 1949) is the first crisis: the USSR cuts the roads to West Berlin, the Allies answer with an ==airlift== lasting eleven months. Not a shot is fired, and yet everything is said.",
                    tone: .insight
                ),
                .paragraph("Each camp follows the same rule: never yield an inch, never fire at the other. This is **the balance of terror**, in place as soon as both sides have the bomb."),
            ]),
            DemoChapter(title: "Crises and the balance of terror (1953–1975)", blocks: [
                .paragraph("After Stalin's death (1953), Khrushchev's \"peaceful coexistence\" prevents neither crises nor the arms race. Each camp arms its allies and fights **by proxy**, from Korea to Vietnam."),
                .table(title: "The major crises", headers: ["Crisis", "Date", "What is at stake"], rows: [
                    ["Korean War", "1950–1953", "The 38th parallel, a Korea cut in two"],
                    ["Berlin Wall", "1961", "The East walls in its people to stop the flight westward"],
                    ["Cuban Missile Crisis", "1962", "Soviet missiles 150 km from Florida"],
                    ["Vietnam War", "1955–1975", "The United States gets bogged down, then withdraws"],
                ]),
                .keyFigure(value: "13 days", label: "the length of the Cuban Missile Crisis, in October 1962, before the missiles were withdrawn"),
                .paragraph("In October 1962 American planes photograph Soviet missile sites in Cuba. Kennedy imposes a naval blockade; Khrushchev eventually withdraws the missiles in exchange for a promise not to invade the island. ==Deterrence held==: the hottest moment of the whole Cold War."),
                .figure(.flow(title: "The logic of deterrence", steps: ["Both camps have the bomb", "To strike is to be struck", "Nobody strikes", "War is fought elsewhere"])),
                .callout(
                    title: "By proxy",
                    text: "Vietnam is the example: the United States backs the South, the USSR and China back the North. A real war, thousands of deaths, and never an American soldier facing a Soviet one.",
                    tone: .example
                ),
                .list([
                    "1957: Sputnik, the first satellite, opens the space race",
                    "1963: the red telephone links Washington and Moscow",
                    "1969: Apollo 11, America walks on the Moon",
                ]),
            ]),
            DemoChapter(title: "From détente to the fall of the Wall (1975–1991)", blocks: [
                .paragraph("The 1970s loosen the grip: SALT arms agreements (1972), the Helsinki conference (1975). But the ==rose|new Cold War== resumes in 1979, when the USSR invades Afghanistan and Reagan relaunches the arms race."),
                .paragraph("In 1985 Mikhail Gorbachev comes to power in an exhausted USSR. He launches **perestroika** (restructuring) and **glasnost** (openness), and stops propping up the communist regimes of Eastern Europe."),
                .timeline(title: "The end", events: [
                    DemoEvent(date: "1985", label: "Gorbachev comes to power"),
                    DemoEvent(date: "1987", label: "Washington Treaty: end of the Euromissiles"),
                    DemoEvent(date: "9 Nov 1989", label: "Fall of the Berlin Wall"),
                    DemoEvent(date: "1990", label: "German reunification"),
                    DemoEvent(date: "25 Dec 1991", label: "Dissolution of the USSR"),
                ]),
                .bars(title: "Military spending as a share of GDP, around 1985 (estimate)", unit: "%", bars: [
                    DemoBar(label: "United States", value: 6),
                    DemoBar(label: "USSR", value: 15),
                    DemoBar(label: "France", value: 4),
                ]),
                .callout(
                    title: "Why the Wall falls",
                    text: "Without Moscow's support, the Eastern regimes collapse one after another in 1989. On 9 November the GDR opens its borders: in one night, the symbol of division disappears.",
                    tone: .insight
                ),
                .paragraph("On 25 December 1991 the Soviet flag is lowered from the Kremlin. The Cold War ends ==without a battle==, through the exhaustion of one of the two camps."),
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
                .paragraph("A leaf is a factory: it takes light, water and carbon dioxide and turns them into ==sugar and oxygen==. This process is photosynthesis, and it feeds almost all life on Earth."),
                .callout(
                    title: "Photosynthesis",
                    text: "The synthesis of organic matter (glucose) by green plants, from mineral matter (CO₂ and water), using light energy.",
                    tone: .definition
                ),
                .formula("6\\,CO_2 + 6\\,H_2O \\rightarrow C_6H_{12}O_6 + 6\\,O_2", caption: "The overall equation, driven by light"),
                .paragraph("It all happens in the **chloroplasts**, green organelles of the leaf cells. Their colour comes from ==menthe|chlorophyll==, the pigment that absorbs red and blue light, and reflects green."),
                .figure(.flow(title: "From photon to sugar", steps: ["Chlorophyll absorbs light", "Water is split: O₂ released", "Energy is stored (ATP)", "CO₂ is fixed into glucose"])),
                .bars(title: "What chlorophyll absorbs, by colour", unit: "%", bars: [
                    DemoBar(label: "Blue", value: 90),
                    DemoBar(label: "Green", value: 15),
                    DemoBar(label: "Red", value: 80),
                ]),
                .callout(
                    title: "Why leaves are green",
                    text: "Because green is the colour chlorophyll **does not absorb**: it reflects it back to our eyes.",
                    tone: .insight
                ),
            ]),
            DemoChapter(title: "Making glucose", blocks: [
                .paragraph("Photosynthesis happens in two stages. The **light phase** needs light: it splits water, releases oxygen and stores energy. The **dark phase** does not: it uses that energy to fix CO₂ and build glucose."),
                .table(title: "The two phases", headers: ["", "Light phase", "Dark phase"], rows: [
                    ["Where", "Thylakoid membranes", "Chloroplast stroma"],
                    ["Light", "Essential", "Not directly"],
                    ["In", "Water, light", "CO₂, ATP"],
                    ["Out", "O₂, ATP", "Glucose"],
                ]),
                .figure(.cycle(title: "The Calvin cycle", nodes: ["CO₂ fixation", "Reduction with ATP", "Sugar formation", "Acceptor regeneration"])),
                .paragraph("The Calvin cycle turns in the stroma: on each turn, one CO₂ molecule is fixed onto an acceptor, reduced using ATP, and part of the product leaves the cycle to make ==glucose==. It takes **six turns** for one glucose molecule."),
                .keyFigure(value: "6 turns", label: "of the Calvin cycle to build a single glucose molecule"),
                .callout(
                    title: "Classic trap",
                    text: "The dark phase does not happen \"at night\": it runs during the day too, as soon as the light phase supplies energy. \"Dark\" means it does not use light directly.",
                    tone: .warning
                ),
            ]),
            DemoChapter(title: "Photosynthesis and the planet", blocks: [
                .paragraph("Every year, plants fix about ==120 billion tonnes of carbon==. Photosynthesis is the entry point of organic matter into food chains, and the source of all the oxygen we breathe."),
                .figure(.cycle(title: "The carbon cycle", nodes: ["CO₂ in the atmosphere", "Photosynthesis: fixed in plants", "Respiration, decomposition", "Back to the atmosphere"])),
                .paragraph("Three factors control its rate: light, CO₂ concentration and temperature. When one is lacking, raising the others changes nothing: that is the **limiting factor**."),
                .figure(.plot(title: "Light, up to a ceiling", caption: "More light speeds up photosynthesis, up to a plateau: beyond it, CO₂ or temperature is the limit.", kind: .saturation)),
                .list([
                    "Light: the more there is, the faster photosynthesis runs, until saturation",
                    "CO₂: at 0.04% of the air, often the limiting factor in full daylight",
                    "Temperature: an optimum around 25 to 30 °C, enzymes stop beyond it",
                ]),
                .callout(
                    title: "In a greenhouse",
                    text: "Growers sometimes enrich the air with CO₂: under strong light it is what holds growth back, and adding it makes tomatoes grow faster.",
                    tone: .example
                ),
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
        ]
    )

    // MARK: Maths: derivatives

    private static let derivativesEN = OnboardingDemoCourse(
        id: "maths-derivatives",
        emoji: "📐",
        subject: "Mathématiques",
        title: "Derivatives",
        summary: "The derivative at a point, the tangent, the standard derivatives and the calculation rules, then the sign of the derivative that gives a function's variations.",
        accentIndex: 0,
        chapters: [
            DemoChapter(title: "The derivative and the tangent", blocks: [
                .paragraph("Differentiating means measuring ==how fast a function changes==. On a curve, that speed can be seen: it is the slope of the tangent at the point you are looking at."),
                .callout(
                    title: "Derivative at a point",
                    text: "The derivative of $f$ at $a$, written $f'(a)$, is the limit of the rate of change between $a$ and $a+h$ as $h$ tends to 0.",
                    tone: .definition
                ),
                .formula("f'(a) = \\lim_{h \\to 0} \\frac{f(a+h) - f(a)}{h}", caption: "The rate of change, as h becomes infinitely small"),
                .figure(.plot(title: "The tangent at a point", caption: "The line that \"hugs\" the curve at $a$: its slope is $f'(a)$.", kind: .tangent)),
                .paragraph("The equation of the tangent at $a$ is $y = f'(a)(x - a) + f(a)$: a line through the point $(a, f(a))$ with slope $f'(a)$."),
                .callout(
                    title: "Example",
                    text: "For $f(x) = x^2$ at $a = 1$: $f'(1) = 2$, so the tangent is $y = 2(x - 1) + 1 = 2x - 1$.",
                    tone: .example
                ),
                .list([
                    "$f'(a) > 0$: the curve rises at $a$",
                    "$f'(a) < 0$: it falls",
                    "$f'(a) = 0$: horizontal tangent, often a peak or a trough",
                ]),
            ]),
            DemoChapter(title: "Computing a derivative", blocks: [
                .paragraph("You almost never compute a limit by hand: you learn **the standard derivatives**, and the rules that combine them."),
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
                .callout(
                    title: "The three rules",
                    text: "**Sum**: $(u+v)' = u' + v'$. **Product**: $(uv)' = u'v + uv'$. **Quotient**: $(u/v)' = (u'v - uv')/v^2$.",
                    tone: .insight
                ),
                .formula("(uv)' = u'v + uv'", caption: "The derivative of a product: each factor differentiated in turn, then added"),
                .paragraph("Example: $f(x) = 3x^2 - 5x + 2$. Differentiate term by term: $f'(x) = 6x - 5$. Constants vanish, ==powers drop by one==."),
                .callout(
                    title: "The mistake to avoid",
                    text: "$(uv)' \\neq u'v'$. The derivative of a product is **not** the product of the derivatives: $(x \\cdot x)' = 2x$, not $1 \\cdot 1$.",
                    tone: .warning
                ),
                .list([
                    "Spot the form: sum, product, quotient",
                    "Differentiate each piece with the table",
                    "Assemble with the right rule",
                    "Simplify, then check the sign",
                ], ordered: true),
            ]),
            DemoChapter(title: "Derivative and variations", blocks: [
                .paragraph("The sign of the derivative tells you ==which way the function goes==: positive, it rises; negative, it falls. This is the key to every table of variations."),
                .figure(.plot(title: "Sign of f′ and direction of f", caption: "Where $f'$ is positive, $f$ rises; where it vanishes while changing sign, $f$ reaches an extremum.", kind: .variation)),
                .paragraph("For $f(x) = x^3 - 3x$: $f'(x) = 3x^2 - 3 = 3(x-1)(x+1)$. It vanishes at $-1$ and $1$: a **local maximum** at $-1$ (value 2) and a **local minimum** at $1$ (value $-2$)."),
                .table(title: "Variations of f(x) = x³ − 3x", headers: ["Interval", "Sign of f′", "Direction of f"], rows: [
                    ["]−∞ ; −1[", "+", "increasing"],
                    ["]−1 ; 1[", "−", "decreasing"],
                    ["]1 ; +∞[", "+", "increasing"],
                ]),
                .callout(
                    title: "Method",
                    text: "1. Differentiate. 2. Study the sign of $f'$ (factorise!). 3. Deduce the variations. 4. Compute the values at the bounds and at the extrema.",
                    tone: .insight
                ),
                .keyFigure(value: "f′ = 0", label: "where the curve has a horizontal tangent: a peak, a trough, or a plateau"),
                .callout(
                    title: "Careful",
                    text: "$f'(a) = 0$ is not enough for an extremum: $x^3$ has a zero derivative at 0 and does not change direction. $f'$ must **change sign**.",
                    tone: .warning
                ),
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
        ]
    )

    // MARK: Physics: energy

    private static let energyEN = OnboardingDemoCourse(
        id: "physics-energy",
        emoji: "⚡️",
        subject: "Physique",
        title: "Energy",
        summary: "The forms of energy, its conservation from one form to another, then power and efficiency, with the formulas and orders of magnitude of the syllabus.",
        accentIndex: 6,
        chapters: [
            DemoChapter(title: "The forms of energy", blocks: [
                .paragraph("Energy cannot be seen, it **transforms**: a falling apple, the heat of an engine, the light of a lamp are the same quantity in different forms. It is measured in ==joules (J)==."),
                .table(title: "The usual forms", headers: ["Form", "Depends on", "Example"], rows: [
                    ["Kinetic", "mass and speed", "a moving car"],
                    ["Gravitational potential", "mass and height", "an apple in the tree"],
                    ["Thermal", "molecular agitation", "a hot pan"],
                    ["Electrical", "current", "a battery"],
                    ["Chemical", "bonds", "petrol, glucose"],
                ]),
                .formula("E_k = \\frac{1}{2} m v^2", caption: "Kinetic energy: m in kg, v in m/s, E in J"),
                .formula("E_p = m g h", caption: "Gravitational potential energy: g ≈ 9.8 N/kg, h in m"),
                .callout(
                    title: "Order of magnitude",
                    text: "A 1,000 kg car at 50 km/h (≈ 14 m/s) carries $E_k = \\frac{1}{2} \\times 1000 \\times 14^2 \\approx 98\\,000$ J, nearly 100 kJ. At 100 km/h, **four times more**.",
                    tone: .example
                ),
                .keyFigure(value: "× 4", label: "when speed doubles, kinetic energy quadruples: that is the square in the formula"),
                .callout(
                    title: "Unit",
                    text: "Energy is expressed in joules, never in watts. The watt measures **power**: energy per second.",
                    tone: .warning
                ),
            ]),
            DemoChapter(title: "Conservation and transfers", blocks: [
                .paragraph("==bleu|Energy is neither created nor destroyed==: it passes from one form to another, from one system to another. This is the conservation principle, and it holds for everything, from the atom to the galaxy."),
                .figure(.flow(title: "The energy chain of a fall", steps: ["Potential energy, at the top", "Becomes kinetic energy", "Impact: heat and sound", "Total unchanged"])),
                .paragraph("A ball dropped from 2 m loses potential energy and gains exactly as much kinetic energy, as long as friction is neglected. At the ground its speed is $v = \\sqrt{2gh} \\approx 6.3$ m/s."),
                .callout(
                    title: "Mechanical energy",
                    text: "The sum of kinetic and potential energy: $E_m = E_k + E_p$. Without friction, it is conserved.",
                    tone: .definition
                ),
                .formula("E_m = E_k + E_p = \\text{constant}", caption: "In the absence of friction"),
                .callout(
                    title: "What about friction?",
                    text: "It \"destroys\" nothing: the mechanical energy lost becomes thermal energy. The total is always conserved, it is just less useful.",
                    tone: .insight
                ),
                .list([
                    "Work: energy transferred by a force that moves something",
                    "Heat: transfer through a temperature difference",
                    "Radiation: transfer through light, like the Sun",
                ]),
            ]),
            DemoChapter(title: "Power and efficiency", blocks: [
                .paragraph("**Power** says how fast energy is transferred. A 2,000 W heater transfers 2,000 joules every second."),
                .formula("P = \\frac{E}{\\Delta t}", caption: "P in watts (W), E in joules, Δt in seconds"),
                .callout(
                    title: "The kilowatt-hour",
                    text: "1 kWh is 1,000 W for one hour: $1000 \\times 3600 = 3.6 \\times 10^6$ J. It is the unit on the electricity bill.",
                    tone: .example
                ),
                .paragraph("No converter is perfect: part of the energy received leaves as heat. The ==efficiency== compares what is useful to what is supplied."),
                .formula("\\eta = \\frac{E_{useful}}{E_{supplied}}", caption: "Always less than or equal to 1 (100%)"),
                .bars(title: "Efficiency of a few converters", unit: "%", bars: [
                    DemoBar(label: "Petrol engine", value: 35),
                    DemoBar(label: "LED bulb", value: 40),
                    DemoBar(label: "Electric motor", value: 90),
                    DemoBar(label: "Electric heater", value: 100),
                ]),
                .callout(
                    title: "100% efficiency?",
                    text: "An electric heater turns everything into heat, but heat is exactly what we want. For an engine, heat is a loss.",
                    tone: .warning
                ),
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
        ]
    )
}
