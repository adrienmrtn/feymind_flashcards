import Foundation

// MARK: - The four courses, in Spanish

/// The demo courses, in Spanish (Spain). High-school level: what a teacher would write on
/// the board, with exact definitions, mechanisms and examples.
///
/// **Four chapters per course, and text between every object.** A diagram, a table or a
/// chart only reads with the sentence that brings it in and the one that draws something
/// out of it: two objects in a row with no paragraph between them read as a gallery, not
/// as a study sheet. The rule here is that no rich object touches another.
///
/// Subjects keep the catalogue's canonical (French) names so they land in the right
/// filters; `SubjectDisplay` translates them on screen.
extension OnboardingDemoCatalog {
    static let spanish: [OnboardingDemoCourse] = [
        coldWarES, photosynthesisES, derivativesES, energyES,
    ]

    // MARK: History: the Cold War

    private static let coldWarES = OnboardingDemoCourse(
        id: "history-cold-war",
        emoji: "🏛️",
        subject: "Histoire",
        title: "La Guerra Fría (1947–1991)",
        summary: "Dos bloques, dos modelos y nunca una guerra directa: cuarenta y cuatro años de tensión, crisis y distensión, hasta la caída del Muro.",
        accentIndex: 3,
        chapters: [
            DemoChapter(title: "Dos bloques frente a frente (1947–1953)", blocks: [
                .paragraph("En 1945 los vencedores de la guerra ya no comparten nada. Estados Unidos y la URSS, aliados contra la Alemania nazi, se convierten en ==las dos superpotencias== de un mundo que se parte en dos. Todo lo que sigue —cuarenta y cuatro años de tensión— se entiende a partir de esa ruptura."),
                .heading("Un mundo partido en dos"),
                .paragraph("Las conferencias de Yalta (febrero de 1945) y Potsdam (julio de 1945) debían organizar la paz. Lo que organizan, en realidad, es el reparto: Europa del Este, liberada por el Ejército Rojo, queda bajo control soviético; Europa occidental, liberada por los angloamericanos, entra en la órbita de Washington. Ya en marzo de 1946, Churchill habla de un **telón de acero** caído sobre el continente."),
                .callout(
                    title: "Guerra Fría",
                    text: "Enfrentamiento **sin guerra directa** entre Estados Unidos y la URSS, de 1947 a 1991, librado mediante la presión económica, la propaganda, la carrera armamentística y las guerras indirectas.",
                    tone: .definition
                ),
                .paragraph("La palabra «fría» dice lo esencial: los dos gigantes nunca se enfrentan entre sí. Chocan en todas partes, y por todos los demás medios. Lo que los separa no es solo una rivalidad de poder, sino ==dos maneras de organizar una sociedad==, incompatibles entre sí."),
                .figure(.split(
                    title: "Dos modelos",
                    left: DemoColumn(title: "Bloque occidental", items: ["Estados Unidos", "Democracia liberal", "Economía de mercado", "Plan Marshall (1947)", "OTAN (1949)"]),
                    right: DemoColumn(title: "Bloque del Este", items: ["URSS", "Partido único", "Economía planificada", "Kominform (1947)", "Pacto de Varsovia (1955)"])
                )),
                .paragraph("En el Oeste, elecciones libres, varios partidos, una prensa independiente y una economía en la que las empresas son privadas y los precios, libres. En el Este, un partido único, el Partido Comunista, que controla el Estado, la prensa y la economía: el plan, decidido en Moscú, fija qué se produce y a qué precio. Cada bando se presenta como el mundo libre y describe al otro como una amenaza."),
                .heading("La contención"),
                .paragraph("En marzo de 1947 el presidente Truman promete ayudar a cualquier país amenazado por el comunismo: es la ==bleu|doctrina Truman==, o *contención*: frenar el comunismo donde está, sin intentar derribarlo allí donde gobierna. El Plan Marshall, tres meses después, financia la reconstrucción de Europa occidental con 13 000 millones de dólares y la vincula al bando estadounidense. La URSS responde prohibiendo a sus satélites aceptarlo y crea la Kominform para coordinar a los partidos comunistas."),
                .timeline(title: "Los primeros años", events: [
                    DemoEvent(date: "1947", label: "Doctrina Truman y Plan Marshall"),
                    DemoEvent(date: "1948", label: "Bloqueo de Berlín"),
                    DemoEvent(date: "1949", label: "Fundación de la OTAN, primera bomba soviética"),
                    DemoEvent(date: "1950", label: "Comienza la guerra de Corea"),
                ]),
                .paragraph("Berlín es el primer pulso. La ciudad, en plena zona soviética, está a su vez dividida en cuatro sectores. Cuando las potencias occidentales crean una moneda común para sus zonas, en junio de 1948, Stalin corta todas las carreteras y vías férreas hacia Berlín Oeste: dos millones de habitantes se encuentran sitiados."),
                .callout(
                    title: "Para recordar",
                    text: "El bloqueo de Berlín (de junio de 1948 a mayo de 1949) es la primera crisis: la URSS corta las carreteras hacia Berlín Oeste y los aliados responden con un ==puente aéreo== que dura once meses: un avión cada dos minutos. No se dispara ni un tiro, y sin embargo todo queda dicho.",
                    tone: .insight
                ),
                .paragraph("El bloqueo fracasa y fija las reglas del juego durante cuarenta años: cada bando pone a prueba al otro, pero ninguno cruza la línea que llevaría a la guerra. En 1949 la URSS hace estallar su primera bomba atómica, cuatro años después de Hiroshima. Ambos bandos poseen ya el arma definitiva, y se instala **el equilibrio del terror**."),
                .list([
                    "Telón de acero: la frontera que parte Europa en dos, del Báltico al Adriático",
                    "Contención: la estrategia estadounidense, frenar sin atacar",
                    "Satélite: país de Europa del Este gobernado por un partido comunista alineado con Moscú",
                ]),
                .paragraph("La guerra de Corea, en junio de 1950, muestra en qué se convierte un conflicto en este marco: el Norte comunista invade el Sur, los estadounidenses intervienen bajo bandera de la ONU y China envía sus «voluntarios». Tres años de combates, dos millones de muertos y una frontera que vuelve exactamente a donde estaba. Cada bando sigue la misma regla: no ceder ni un palmo, no disparar nunca contra la otra superpotencia."),
            ]),
            DemoChapter(title: "Crisis y equilibrio del terror (1953–1975)", blocks: [
                .paragraph("Tras la muerte de Stalin (1953), Jruschov propone la «coexistencia pacífica»: los dos sistemas pueden convivir, y la economía dirá cuál es mejor. Pero la coexistencia no impide ni las crisis ni la carrera armamentística. Cada bando arma a sus aliados y combate **por persona interpuesta**, de Corea a Vietnam."),
                .paragraph("La coexistencia tiene sus límites, y Budapest los muestra ya en 1956: cuando Hungría intenta salir del Pacto de Varsovia, los tanques soviéticos aplastan la insurrección en pocos días. Occidente protesta, y no se mueve. Cada uno sigue siendo dueño en su casa: esa es la regla no escrita de la Guerra Fría."),
                .table(title: "Las grandes crisis", headers: ["Crisis", "Fecha", "Qué está en juego"], rows: [
                    ["Guerra de Corea", "1950–1953", "El paralelo 38, una Corea partida en dos"],
                    ["Muro de Berlín", "1961", "El Este encierra a su población para frenar la huida hacia el Oeste"],
                    ["Crisis de los misiles de Cuba", "1962", "Misiles soviéticos a 150 km de Florida"],
                    ["Guerra de Vietnam", "1955–1975", "Estados Unidos se empantana y luego se retira"],
                ]),
                .heading("Berlín, otra vez"),
                .paragraph("Entre 1949 y 1961, casi tres millones de alemanes del Este pasan al Oeste, la mayoría por Berlín, donde basta con coger el metro. La RDA se vacía de sus médicos, sus ingenieros, sus jóvenes. En la noche del 12 al 13 de agosto de 1961, cierra la frontera: primero alambre de espino, luego un muro de hormigón, torres de vigilancia, una franja de la muerte. ==El Muro== se convierte en el símbolo de toda la Guerra Fría, y de lo que vale cada bando a ojos del otro."),
                .keyFigure(value: "13 días", label: "la duración de la crisis de los misiles de Cuba, en octubre de 1962, antes de la retirada de los misiles"),
                .paragraph("En octubre de 1962 aviones espía estadounidenses fotografían bases de misiles soviéticos en Cuba, a ciento cincuenta kilómetros de Florida. Kennedy impone un bloqueo naval a la isla y exige su retirada; durante trece días el mundo contiene la respiración. Jruschov acaba retirando los misiles a cambio de la promesa de no invadir Cuba, y de la retirada discreta de los misiles estadounidenses de Turquía. ==La disuasión funcionó==: el momento más caliente de toda la Guerra Fría."),
                .figure(.flow(title: "La lógica de la disuasión", steps: ["Ambos bandos tienen la bomba", "Atacar es ser atacado", "Nadie ataca", "La guerra se libra en otra parte"])),
                .paragraph("Esta lógica tiene nombre: **destrucción mutua asegurada**. Ningún bando puede destruir al otro sin ser destruido a su vez, así que ninguno ataca primero. La bomba, paradójicamente, se convierte en una garantía de paz entre los dos gigantes, y precisamente por eso la guerra se desplaza a otra parte, a los aliados, donde puede seguir siendo convencional."),
                .callout(
                    title: "Por persona interpuesta",
                    text: "Vietnam es el ejemplo: Estados Unidos apoya al Sur, la URSS y China apoyan al Norte. Una guerra real, millones de muertos, y nunca un soldado estadounidense frente a uno soviético.",
                    tone: .example
                ),
                .paragraph("Estados Unidos se implica en Vietnam a partir de 1965: más de quinientos mil soldados en 1968, bombardeos masivos y una opinión pública que da la vuelta cuando las imágenes llegan a la televisión. Se retiran en 1973; Saigón cae en 1975. Es la primera guerra que pierde Estados Unidos, y la pierde ==sin enfrentarse nunca a la URSS==."),
                .heading("La carrera en todos los frentes"),
                .paragraph("El enfrentamiento se libra también en el cielo, en los laboratorios y en los estadios. Cada satélite, cada medalla, cada récord se presenta como la prueba de que un sistema es mejor que el otro. La carrera espacial es su escaparate: la URSS toma la delantera, y Estados Unidos la alcanza dándose diez años."),
                .list([
                    "1957: el Sputnik, primer satélite, abre la carrera espacial",
                    "1961: Gagarin, primer hombre en el espacio",
                    "1963: el teléfono rojo une Washington y Moscú, la lección de Cuba",
                    "1969: Apolo 11, Estados Unidos pisa la Luna",
                ]),
                .paragraph("El teléfono rojo, instalado después de Cuba, resume el periodo: dos adversarios que no se fían el uno del otro, pero que saben que un malentendido podría hacerlo saltar todo por los aires. Hablan para no pelear. De esa prudencia nace la distensión de los años setenta."),
            ]),
            DemoChapter(title: "De la distensión a la caída del Muro (1975–1991)", blocks: [
                .paragraph("Los años setenta aflojan la presión. Ambos bandos han comprendido que no ganarán, y que la carrera armamentística cuesta una fortuna: negocian. Pero la ==rose|nueva Guerra Fría== se reanuda en 1979, cuando la URSS invade Afganistán y Reagan relanza la carrera armamentística."),
                .heading("La distensión"),
                .paragraph("Los acuerdos SALT (1972) limitan por primera vez el número de misiles nucleares. La conferencia de Helsinki (1975) reconoce las fronteras heredadas de la guerra —lo que quería Moscú— a cambio de un compromiso sobre los derechos humanos, que los disidentes del Este esgrimirán durante quince años. Nixon viaja a Pekín y a Moscú; el comercio se reanuda; las dos Alemanias se reconocen mutuamente."),
                .paragraph("La tregua es breve. En diciembre de 1979 el Ejército Rojo entra en Afganistán para sostener un régimen comunista que se tambalea: diez años de guerra, un millón de muertos y una URSS empantanada en su propio Vietnam. Estados Unidos boicotea los Juegos de Moscú, arma a la resistencia afgana, y Ronald Reagan, elegido en 1980, llama a la URSS «imperio del mal». Su proyecto de escudo espacial, la IDE, lanza una carrera tecnológica que Moscú ya no puede seguir."),
                .paragraph("En 1985 Mijaíl Gorbachov llega al poder en una URSS agotada: las estanterías de las tiendas están vacías, la industria está anticuada y el ejército se traga una parte enorme de la riqueza. Lanza la **perestroika** (reestructuración de la economía) y la **glásnost** (transparencia en la vida pública), negocia el desarme con Reagan y deja de sostener a los regímenes comunistas de Europa del Este: cada uno será en adelante responsable de su propio destino."),
                .timeline(title: "El final", events: [
                    DemoEvent(date: "1985", label: "Gorbachov llega al poder"),
                    DemoEvent(date: "1987", label: "Tratado de Washington: fin de los euromisiles"),
                    DemoEvent(date: "9 nov. 1989", label: "Caída del Muro de Berlín"),
                    DemoEvent(date: "1990", label: "Reunificación alemana"),
                    DemoEvent(date: "25 dic. 1991", label: "Disolución de la URSS"),
                ]),
                .paragraph("El año 1989 lo barre todo. En Polonia, el sindicato Solidarność gana unas elecciones libres en junio. En Hungría, el gobierno abre su frontera con Austria en septiembre: los alemanes del Este la cruzan por miles. En la RDA, las manifestaciones de los lunes en Leipzig reúnen a cientos de miles de personas, y el régimen, sin el apoyo de Moscú, ya no puede disparar."),
                .heading("Por qué perdió la URSS"),
                .paragraph("La Guerra Fría se libró tanto en la economía como en las armas. La URSS dedicaba a su ejército una parte de su riqueza que Estados Unidos nunca necesitó alcanzar, con una economía de la mitad de tamaño. Cada misil de más era un hospital o una fábrica de menos, y la población lo sabía."),
                .bars(title: "Gasto militar en porcentaje del PIB, hacia 1985 (estimación)", unit: "%", bars: [
                    DemoBar(label: "Estados Unidos", value: 6),
                    DemoBar(label: "URSS", value: 15),
                    DemoBar(label: "Francia", value: 4),
                ]),
                .paragraph("El gráfico se lee de un vistazo: para un esfuerzo militar comparable, la URSS sacrifica más del doble de lo que le dedica Estados Unidos. Es ese agotamiento lo que Gorbachov intenta detener, y es al aflojar la presión cuando libera las fuerzas que disolverán el sistema."),
                .callout(
                    title: "Por qué cae el Muro",
                    text: "Sin el apoyo de Moscú, los regímenes del Este se derrumban uno tras otro en 1989. El 9 de noviembre un portavoz de la RDA anuncia, por error, que las fronteras se abren «de inmediato»: en una sola noche, decenas de miles de berlineses las cruzan, y el símbolo de la división desaparece.",
                    tone: .insight
                ),
                .paragraph("Alemania se reunifica en octubre de 1990, bajo la protección de la OTAN, algo que Moscú habría rechazado cinco años antes. Dentro de la URSS, las repúblicas reclaman su independencia; un golpe de Estado fallido en agosto de 1991 acaba de desacreditar al partido. El 25 de diciembre de 1991 se arría la bandera soviética del Kremlin. La Guerra Fría termina ==sin una batalla==, por el agotamiento de uno de los dos bandos."),
            ]),
            DemoChapter(title: "Comprender la Guerra Fría", blocks: [
                .paragraph("Cuarenta y cuatro años, decenas de crisis, cientos de fechas: la Guerra Fría no se memoriza fecha a fecha, se comprende a través de sus mecanismos. Este capítulo reúne ==el vocabulario, la lógica y el método== para redactar sobre ella en un examen."),
                .heading("El vocabulario"),
                .paragraph("Cada palabra de abajo nombra un mecanismo preciso, y usar una en lugar de otra es un error de comprensión, no de vocabulario. «Distensión» no es «paz», «contención» no es «ataque», «satélite» no es «aliado»."),
                .table(title: "Palabras que hay que saber", headers: ["Palabra", "Qué significa"], rows: [
                    ["Telón de acero", "La frontera cerrada que parte Europa en dos"],
                    ["Contención", "Frenar el comunismo sin atacarlo donde gobierna"],
                    ["Disuasión", "No atacar porque te atacarían a su vez"],
                    ["Guerra indirecta", "Una guerra librada por los aliados, no por los dos gigantes"],
                    ["Distensión", "La relajación de las tensiones, en los años setenta"],
                    ["Satélite", "Un país del Este gobernado por un partido alineado con Moscú"],
                ]),
                .paragraph("Estas palabras describen un mismo ciclo, repetido de 1947 a 1991. La tensión sube, estalla una crisis, los dos bandos negocian porque ninguno quiere la guerra, la tensión baja… y una nueva crisis empieza en otra parte. Berlín, Cuba, Vietnam, Afganistán: siempre es el mismo bucle."),
                .figure(.cycle(title: "El ciclo de las crisis", nodes: ["La tensión sube", "Estalla una crisis", "Se negocia", "La tensión baja"])),
                .paragraph("Comprender este ciclo es ser capaz de explicar cualquier crisis sin habérsela aprendido de memoria: quién pone a prueba a quién, hasta dónde y por qué se detiene antes de la guerra. La respuesta es casi siempre la misma —**la disuasión nuclear**— y es lo que distingue la Guerra Fría de todas las rivalidades anteriores."),
                .heading("En el examen"),
                .callout(
                    title: "Método",
                    text: "Para una redacción: 1. Un plan en tres partes: la formación de los bloques, crisis y coexistencia, distensión y final. 2. Una fecha y un ejemplo preciso por idea. 3. Una conclusión que responda a la pregunta: por qué «fría» y por qué termina sin guerra.",
                    tone: .insight
                ),
                .paragraph("Para un comentario de documento, la primera pregunta que hay que hacerse es el punto de vista: ¿quién habla, desde qué bando, en qué momento del ciclo? Un cartel soviético de 1950 y un discurso de Kennedy de 1963 no dicen lo mismo, y es precisamente su diferencia lo que se espera que expliques."),
                .callout(
                    title: "El error clásico",
                    text: "Escribir que Estados Unidos y la URSS se hicieron la guerra. **Nunca** combatieron directamente: esa es la definición misma de la Guerra Fría, y es lo que explica la disuasión.",
                    tone: .warning
                ),
                .list([
                    "1947: doctrina Truman, Plan Marshall: se forman los bloques",
                    "1949: OTAN, bomba soviética: empieza el equilibrio del terror",
                    "1961: el Muro: la división se vuelve de hormigón",
                    "1962: Cuba: la disuasión resiste",
                    "1975: Helsinki: la distensión",
                    "1989: cae el Muro: el final",
                    "1991: la URSS desaparece",
                ]),
                .paragraph("Siete fechas bastan para dominar todo el periodo, siempre que sepas lo que cada una abre o cierra. Apréndelas con su mecanismo, no solo con su acontecimiento: ese vínculo es lo que marca la diferencia entre recitar una cronología y ==explicar una época==."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "¿Cuáles son los dos bloques de la Guerra Fría y quién los lidera?",
                back: "El bloque occidental, liderado por Estados Unidos (democracia liberal, economía de mercado), y el bloque del Este, liderado por la URSS (partido único, economía planificada).",
                figure: .split(
                    title: "Dos modelos",
                    left: DemoColumn(title: "Oeste", items: ["Estados Unidos", "OTAN"]),
                    right: DemoColumn(title: "Este", items: ["URSS", "Pacto de Varsovia"])
                ),
                chapter: 0
            ),
            DemoCard(
                kind: .choice,
                front: "¿Qué crisis llevó al mundo al borde de la guerra nuclear en 1962?",
                back: "La crisis de los misiles de Cuba: misiles soviéticos instalados en Cuba, trece días de pulso y después una retirada a cambio de la promesa de no invadir la isla.",
                choices: ["El bloqueo de Berlín", "La crisis de los misiles de Cuba", "La guerra de Corea", "La invasión de Afganistán"],
                answerIndex: 1,
                chapter: 1
            ),
            DemoCard(
                kind: .cloze,
                front: "El Muro de Berlín cae el 9 de noviembre de …, dos años antes de la disolución de la URSS.",
                back: "1989",
                chapter: 2
            ),
            DemoCard(kind: .basic, front: "¿Qué es la doctrina Truman?", back: "El compromiso de Estados Unidos, en marzo de 1947, de ayudar a cualquier país amenazado por el comunismo: la política de contención.", chapter: 0),
            DemoCard(kind: .cloze, front: "El Plan … (1947) financia la reconstrucción de Europa occidental.", back: "Marshall", chapter: 0),
            DemoCard(kind: .choice, front: "¿Quién lanzó la perestroika y la glásnost?", back: "Mijaíl Gorbachov, en el poder desde 1985, intentó reformar la URSS desde dentro.", choices: ["Stalin", "Jruschov", "Gorbachov", "Brézhnev"], answerIndex: 2, chapter: 2),
            DemoCard(kind: .basic, front: "¿Por qué Estados Unidos y la URSS nunca combatieron directamente?", back: "Por la disuasión nuclear: como cada bando podía destruir al otro, atacar primero significaba ser atacado a su vez. Por eso la guerra se libra por persona interpuesta, a través de los aliados.", chapter: 3),
            DemoCard(kind: .cloze, front: "La relajación de las tensiones entre los dos bloques en los años setenta se llama … .", back: "distensión", chapter: 3),
        ]
    )

    // MARK: Biology: photosynthesis

    private static let photosynthesisES = OnboardingDemoCourse(
        id: "biology-photosynthesis",
        emoji: "🌿",
        subject: "SVT",
        title: "La fotosíntesis",
        summary: "Cómo una hoja fabrica azúcar a partir de luz, agua y dióxido de carbono, y por qué casi toda la vida depende de ello.",
        accentIndex: 4,
        chapters: [
            DemoChapter(title: "Captar la luz", blocks: [
                .paragraph("Una hoja es una fábrica: toma luz, agua y dióxido de carbono y los transforma en ==azúcar y oxígeno==. Este proceso es la fotosíntesis, y alimenta a casi toda la vida en la Tierra, incluidos nosotros, que comemos plantas o animales que se las comen."),
                .heading("Una hoja, de cerca"),
                .paragraph("La hoja está hecha para este trabajo. Es plana y fina, para ofrecer a la luz la mayor superficie posible. Su envés está perforado por miles de **estomas**, diminutos poros que se abren durante el día para dejar entrar el CO₂ del aire y salir el oxígeno. Entre las dos caras, células repletas de cloroplastos; y nervios que suben el agua desde las raíces y se llevan el azúcar."),
                .callout(
                    title: "Fotosíntesis",
                    text: "La síntesis de materia orgánica (glucosa) por las plantas verdes, a partir de materia mineral (CO₂ y agua), utilizando la energía de la luz.",
                    tone: .definition
                ),
                .paragraph("La definición cabe en una ecuación. Seis moléculas de dióxido de carbono y seis moléculas de agua dan una molécula de glucosa y seis moléculas de oxígeno. Nada se crea: los átomos de carbono del azúcar proceden del CO₂ del aire, y el oxígeno liberado procede del agua. Es ==la energía de la luz== la que hace posible el ensamblaje."),
                .formula("6\\,CO_2 + 6\\,H_2O \\rightarrow C_6H_{12}O_6 + 6\\,O_2", caption: "La ecuación global, impulsada por la luz"),
                .paragraph("Todo ocurre en los **cloroplastos**, orgánulos verdes presentes por decenas en cada célula del parénquima de la hoja. Su color se debe a la ==menthe|clorofila==, el pigmento que absorbe la luz roja y azul, y refleja la verde. Es el único lugar de la célula donde se capta la luz: sin cloroplasto, no hay fotosíntesis."),
                .heading("Del fotón al azúcar"),
                .paragraph("Lo que ocurre dentro se puede resumir en cuatro pasos, que se suceden en una fracción de segundo. La luz incide en la clorofila; la energía recibida sirve para romper moléculas de agua, lo que libera oxígeno; esa energía se almacena en una forma que la célula sabe usar, el ATP; y el ATP se emplea por último para fijar el CO₂ en forma de glucosa."),
                .figure(.flow(title: "Del fotón al azúcar", steps: ["La clorofila absorbe la luz", "Se rompe el agua: se libera O₂", "Se almacena la energía (ATP)", "El CO₂ se fija en glucosa"])),
                .paragraph("No todos los colores de la luz valen lo mismo para la hoja. La luz blanca del Sol es una mezcla; la clorofila capta sobre todo los dos extremos del espectro —el azul y el rojo— y deja pasar el centro. Se mide iluminando una disolución de clorofila con un color cada vez y observando lo que la atraviesa."),
                .bars(title: "Lo que absorbe la clorofila, por color", unit: "%", bars: [
                    DemoBar(label: "Azul", value: 90),
                    DemoBar(label: "Verde", value: 15),
                    DemoBar(label: "Rojo", value: 80),
                ]),
                .paragraph("El gráfico se lee de un vistazo: se captan nueve fotones azules de cada diez, ocho rojos de cada diez, y apenas uno verde de cada seis. El verde no se pierde del todo —algunos pigmentos secundarios, los carotenoides, aprovechan una parte—, pero la mayor parte vuelve por donde ha venido."),
                .callout(
                    title: "Por qué las hojas son verdes",
                    text: "Porque el verde es el color que la clorofila **no absorbe**: lo refleja hacia nuestros ojos. Una hoja es verde por la misma razón por la que un trapo rojo es rojo: es el color que rechaza.",
                    tone: .insight
                ),
                .paragraph("Un experimento sencillo lo demuestra: una planta cultivada bajo luz verde crece mal, y una planta bajo luz roja o azul crece bien. Por eso los invernaderos modernos iluminan sus cultivos de rosa, una mezcla de rojo y azul: no se desperdicia ni un fotón en un verde que la planta no utilizaría."),
                .paragraph("También se puede comprobar que la hoja fabrica azúcar de verdad. Una hoja expuesta a la luz, decolorada y sumergida después en agua yodada se vuelve negro azulada: contiene almidón, la forma en que la planta almacena su glucosa. Una hoja mantenida a oscuras se queda amarilla: ==sin luz, no hay azúcar==."),
            ]),
            DemoChapter(title: "Fabricar glucosa", blocks: [
                .paragraph("La fotosíntesis se desarrolla en dos etapas, en dos lugares del cloroplasto. La **fase luminosa** necesita luz: rompe el agua, libera oxígeno y almacena energía. La **fase oscura** no la necesita directamente: usa esa energía para fijar el CO₂ y construir glucosa. La primera produce el combustible, la segunda lo gasta."),
                .heading("La fase luminosa"),
                .paragraph("Tiene lugar en los **tilacoides**, sacos membranosos apilados dentro del cloroplasto, donde está anclada la clorofila. Cuando un fotón incide en una molécula de clorofila, le arranca un electrón, y ese electrón se repone rompiendo una molécula de agua: es la **fotólisis del agua**. El oxígeno del agua se libera en forma de O₂ —el que respiramos— y la energía del electrón sirve para fabricar ATP, la moneda energética de toda célula viva."),
                .table(title: "Las dos fases", headers: ["", "Fase luminosa", "Fase oscura"], rows: [
                    ["Dónde", "Membranas de los tilacoides", "Estroma del cloroplasto"],
                    ["Luz", "Imprescindible", "No directamente"],
                    ["Entra", "Agua, luz", "CO₂, ATP"],
                    ["Sale", "O₂, ATP", "Glucosa"],
                ]),
                .paragraph("La tabla se lee por columnas: lo que sale de la fase luminosa —el ATP— es exactamente lo que necesita la fase oscura. Las dos fases están, por tanto, unidas: la segunda se detiene en cuanto la primera deja de abastecerla, lo que ocurre unos minutos después de la puesta de sol."),
                .heading("El ciclo de Calvin"),
                .paragraph("La fase oscura tiene lugar en el **estroma**, el líquido que baña los tilacoides. Lleva el nombre del químico que la describió en 1950 siguiendo el rastro de carbono radiactivo: Melvin Calvin. Es un ciclo, es decir, una secuencia de reacciones que vuelve a su punto de partida tras haber fabricado azúcar por el camino."),
                .figure(.cycle(title: "El ciclo de Calvin", nodes: ["Fijación del CO₂", "Reducción con ATP", "Formación de azúcar", "Regeneración del aceptor"])),
                .paragraph("En cada vuelta, una molécula de CO₂ se fija sobre una molécula de acogida, el aceptor, gracias a una enzima llamada RuBisCO, la proteína más abundante del planeta. El compuesto obtenido se reduce con el ATP de la fase luminosa, y una parte del producto sale del ciclo para fabricar ==glucosa==, mientras que el resto regenera el aceptor para la vuelta siguiente. Hacen falta **seis vueltas** para una molécula de glucosa: una por átomo de carbono."),
                .keyFigure(value: "6 vueltas", label: "del ciclo de Calvin para construir una sola molécula de glucosa"),
                .paragraph("La glucosa fabricada no sigue siendo glucosa mucho tiempo. La planta la ensambla en **almidón** para almacenarla en la hoja o en un tubérculo —es el almidón de la patata—, en **sacarosa** para transportarla por la savia hasta las raíces y los frutos, o en **celulosa** para construir sus paredes. La madera de un árbol es azúcar acumulado durante décadas."),
                .callout(
                    title: "Trampa clásica",
                    text: "La fase oscura no ocurre «de noche»: funciona también de día, en cuanto la fase luminosa le suministra energía. «Oscura» significa que no usa la luz directamente, no que espere a la oscuridad.",
                    tone: .warning
                ),
                .list([
                    "Fase luminosa: tilacoides, luz, rotura del agua, liberación de O₂, producción de ATP",
                    "Fase oscura: estroma, ciclo de Calvin, fijación del CO₂, fabricación de glucosa",
                    "Seis vueltas del ciclo por molécula de glucosa, una por átomo de carbono",
                ]),
                .paragraph("Retén el hilo más que los nombres: la luz se convierte en energía química, la energía química en azúcar, y el azúcar en todo lo demás de la planta. Cada paso tiene su lugar y su combustible, y ==ninguno funciona sin el anterior==."),
            ]),
            DemoChapter(title: "La fotosíntesis y el planeta", blocks: [
                .paragraph("Cada año, las plantas fijan unos ==120 000 millones de toneladas de carbono==. La fotosíntesis es la puerta de entrada de la materia orgánica en las cadenas alimentarias, y la fuente de todo el oxígeno que respiramos. A escala del planeta, es el proceso que mueve el ciclo del carbono."),
                .heading("El ciclo del carbono"),
                .paragraph("El carbono circula entre el aire, los seres vivos y el suelo, y la fotosíntesis es uno de los dos motores del ciclo. Retira CO₂ de la atmósfera y lo encierra en la materia de las plantas. La respiración y la descomposición van en sentido contrario: queman esa materia y devuelven el CO₂ al aire. Mientras ambos se equilibran, la cantidad de CO₂ en la atmósfera se mantiene estable."),
                .figure(.cycle(title: "El ciclo del carbono", nodes: ["CO₂ en la atmósfera", "Fotosíntesis: fijado en las plantas", "Respiración, descomposición", "De vuelta a la atmósfera"])),
                .paragraph("Las plantas son los **productores primarios**: fabrican la materia orgánica de la que vive todo lo demás. Un herbívoro se come la planta, un carnívoro se come al herbívoro, y en cada paso el carbono pasa de un organismo al siguiente. Sin fotosíntesis, la cadena no tiene primer eslabón."),
                .heading("Qué la controla"),
                .paragraph("Tres factores controlan la velocidad de la fotosíntesis: la luz, la concentración de CO₂ y la temperatura. Cuando uno escasea, aumentar los demás no cambia nada: es el **factor limitante**, el que marca el ritmo de todo lo demás, como el puesto más lento de una cadena de montaje."),
                .figure(.plot(title: "La luz, hasta un techo", caption: "Más luz acelera la fotosíntesis, hasta una meseta: a partir de ahí, el límite es el CO₂ o la temperatura.", kind: .saturation)),
                .paragraph("La curva se lee en dos partes. Al principio sube: cada fotón de más se aprovecha, la luz es el factor limitante. Después se aplana: la planta recibe más luz de la que puede usar, y es el CO₂ disponible —o la velocidad de las enzimas, que depende de la temperatura— lo que frena el ritmo. Añadir luz en la meseta ya no cambia nada."),
                .list([
                    "Luz: cuanta más hay, más rápido va la fotosíntesis, hasta la saturación",
                    "CO₂: con un 0,04 % del aire, suele ser el factor limitante a plena luz del día",
                    "Temperatura: un óptimo en torno a 25–30 °C; por encima, las enzimas se detienen",
                ]),
                .callout(
                    title: "En un invernadero",
                    text: "Los agricultores a veces enriquecen el aire con CO₂, hasta tres veces su concentración natural: con luz intensa es lo que frena el crecimiento, y añadirlo hace que los tomates crezcan más rápido.",
                    tone: .example
                ),
                .paragraph("El mismo razonamiento explica por qué las plantas crecen poco en invierno, incluso con buen tiempo: la luz está ahí, pero la temperatura frena las enzimas. Y por qué una planta de interior languidece lejos de la ventana: la temperatura es buena, pero falta luz. ==Identificar el factor limitante== es saber qué hay que cambiar."),
                .heading("Los pulmones del planeta"),
                .paragraph("A menudo se dice que los bosques son los pulmones de la Tierra. Es verdad a medias: los bosques sí fijan carbono, pero casi la mitad de la fotosíntesis mundial ocurre en los océanos, gracias al **fitoplancton**, algas microscópicas en suspensión. Un litro de agua de mar contiene millones, y a ellas les debemos una de cada dos respiraciones."),
                .keyFigure(value: "≈ 50 %", label: "del oxígeno producido cada año en la Tierra procede del fitoplancton de los océanos"),
                .paragraph("Por eso la fotosíntesis también está en el centro de la cuestión climática. Desde hace dos siglos devolvemos al aire, al quemar carbón y petróleo, carbono que la fotosíntesis encerró bajo tierra hace millones de años. Las plantas y los océanos reabsorben una parte, pero no todo: el equilibrio del ciclo se ha roto, y el CO₂ se acumula."),
            ]),
            DemoChapter(title: "Fotosíntesis y respiración", blocks: [
                .paragraph("La fotosíntesis fabrica azúcar; la **respiración** lo quema. Los dos procesos son ==el inverso el uno del otro==, y una planta hace ambos, incluso a plena luz del día. Confundirlos es el error más frecuente en este tema, y este capítulo existe para que no te pase."),
                .heading("El camino inverso"),
                .paragraph("La respiración celular toma glucosa y oxígeno, y libera CO₂, agua y, sobre todo, energía, en forma de ATP. Es lo que hace cada una de nuestras células, todo el tiempo, y es también lo que hace cada célula vegetal: una planta necesita energía para crecer, para mover su savia, para abrir sus estomas, y saca esa energía de su propio azúcar."),
                .formula("C_6H_{12}O_6 + 6\\,O_2 \\rightarrow 6\\,CO_2 + 6\\,H_2O + \\text{energía}", caption: "La respiración: la ecuación de la fotosíntesis, leída al revés"),
                .paragraph("Las dos ecuaciones son simétricas, pero no ocurren ni en el mismo lugar ni al mismo ritmo. La fotosíntesis está en los cloroplastos, y solo con luz; la respiración está en las **mitocondrias**, y todo el tiempo. La tabla las pone frente a frente."),
                .table(title: "Frente a frente", headers: ["", "Fotosíntesis", "Respiración"], rows: [
                    ["Dónde", "Cloroplastos", "Mitocondrias"],
                    ["Cuándo", "Con luz", "De día y de noche"],
                    ["Usa", "CO₂, agua, luz", "Glucosa, O₂"],
                    ["Produce", "Glucosa, O₂", "CO₂, agua, ATP"],
                    ["Quién", "Plantas, algas", "Todos los seres vivos"],
                ]),
                .paragraph("Durante el día, una planta hace las dos cosas a la vez, pero la fotosíntesis gana con mucho: fija mucho más CO₂ del que libera la respiración, y el balance es una ganancia de materia. De noche, solo continúa la respiración: la planta gasta un poco de su azúcar y libera un poco de CO₂. En veinticuatro horas, el balance sigue siendo claramente positivo: eso es lo que hace crecer a la planta."),
                .callout(
                    title: "Trampa clásica",
                    text: "«Las plantas respiran de noche y hacen la fotosíntesis de día». Falso: respiran **todo el tiempo**. Durante el día, la fotosíntesis simplemente enmascara la respiración, porque es mucho más intensa.",
                    tone: .warning
                ),
                .heading("De dónde viene la energía"),
                .paragraph("Puestos uno detrás del otro, los dos procesos cuentan el viaje de la energía a través del mundo vivo. Llega del Sol; la fotosíntesis la almacena en los enlaces de la glucosa; la respiración la libera en forma de ATP; y el ATP paga todo el trabajo de la célula. Cada caloría que gastas fue, un día, un fotón captado por una hoja."),
                .figure(.flow(title: "El viaje de la energía", steps: ["Luz solar", "Glucosa (fotosíntesis)", "ATP (respiración)", "Trabajo de la célula"])),
                .paragraph("Este viaje divide a los seres vivos en dos familias. Los **autótrofos** —plantas, algas, algunas bacterias— fabrican su propia materia orgánica a partir de materia mineral: solo necesitan luz, agua y CO₂. Los **heterótrofos** —animales, hongos, nosotros— no pueden: tienen que comer materia orgánica ya fabricada, directa o indirectamente, por un autótrofo."),
                .callout(
                    title: "Autótrofo, heterótrofo",
                    text: "Un organismo **autótrofo** produce su materia orgánica a partir de materia mineral; un organismo **heterótrofo** tiene que tomarla de otros seres vivos. Toda cadena alimentaria empieza por un autótrofo.",
                    tone: .definition
                ),
                .list([
                    "Fotosíntesis: fabrica glucosa, con luz, en los cloroplastos",
                    "Respiración: quema glucosa, todo el tiempo, en las mitocondrias",
                    "De día gana la fotosíntesis; de noche solo continúa la respiración",
                    "Autótrofos a la cabeza de la cadena, heterótrofos detrás",
                ]),
                .paragraph("Este último punto es la clave de todo el capítulo, y de muchos otros: la vida en la Tierra funciona con energía solar, ==convertida una sola vez== por la fotosíntesis y transmitida después de boca en boca a lo largo de las cadenas alimentarias. Todo lo demás —respirar, correr, pensar— es una manera de gastar esa energía."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "¿Cuáles son los reactivos y los productos de la fotosíntesis?",
                back: "Reactivos: dióxido de carbono (CO₂) y agua (H₂O), con la energía de la luz. Productos: glucosa (C₆H₁₂O₆) y oxígeno (O₂).",
                figure: .flow(title: "Del fotón al azúcar", steps: ["Luz", "Rotura del agua, O₂", "ATP", "Glucosa"]),
                chapter: 0
            ),
            DemoCard(
                kind: .choice,
                front: "¿Dónde tiene lugar la fase luminosa de la fotosíntesis?",
                back: "En las membranas de los tilacoides, dentro del cloroplasto. El estroma alberga el ciclo de Calvin.",
                choices: ["En el estroma", "En las membranas de los tilacoides", "En el núcleo", "En las mitocondrias"],
                answerIndex: 1,
                chapter: 1
            ),
            DemoCard(
                kind: .cloze,
                front: "La clorofila absorbe sobre todo el azul y el rojo, y refleja el …, de ahí el color de las hojas.",
                back: "verde",
                chapter: 0
            ),
            DemoCard(kind: .basic, front: "¿Qué es un factor limitante?", back: "El factor (luz, CO₂ o temperatura) cuya escasez frena la fotosíntesis: mientras falte, aumentar los demás no cambia nada.", chapter: 2),
            DemoCard(kind: .cloze, front: "Hacen falta … vueltas del ciclo de Calvin para construir una molécula de glucosa.", back: "seis", chapter: 1),
            DemoCard(kind: .choice, front: "¿Qué gas libera la fotosíntesis?", back: "El oxígeno (O₂), procedente de la rotura de las moléculas de agua durante la fase luminosa.", choices: ["Dióxido de carbono", "Oxígeno", "Nitrógeno", "Hidrógeno"], answerIndex: 1, chapter: 0),
            DemoCard(kind: .basic, front: "¿Qué diferencia hay entre la fotosíntesis y la respiración?", back: "La fotosíntesis fabrica glucosa a partir de CO₂ y agua, con luz, en los cloroplastos. La respiración quema esa glucosa con oxígeno para liberar energía (ATP), todo el tiempo, en las mitocondrias.", chapter: 3),
            DemoCard(kind: .cloze, front: "Un organismo que fabrica su propia materia orgánica a partir de materia mineral se llama … .", back: "autótrofo", chapter: 3),
        ]
    )

    // MARK: Maths: derivatives

    private static let derivativesES = OnboardingDemoCourse(
        id: "maths-derivatives",
        emoji: "📐",
        subject: "Mathématiques",
        title: "Las derivadas",
        summary: "La derivada en un punto, la tangente, las derivadas usuales y las reglas de cálculo, el signo de la derivada que da la monotonía, y los problemas de optimización.",
        accentIndex: 0,
        chapters: [
            DemoChapter(title: "La derivada y la tangente", blocks: [
                .paragraph("Derivar es medir ==lo rápido que cambia una función==. En una curva, esa rapidez se ve: es la pendiente de la tangente en el punto que se mira. Todo el capítulo cabe en esa idea, y el resto no es más que cálculo."),
                .heading("La tasa de variación"),
                .paragraph("Antes de la velocidad instantánea viene la velocidad media. Entre dos puntos de abscisas $a$ y $a+h$, la función ha variado $f(a+h) - f(a)$ mientras $x$ variaba $h$. El cociente de ambos es la **tasa de variación**: es la pendiente de la recta que une los dos puntos de la curva, la secante."),
                .formula("\\frac{f(a+h) - f(a)}{h}", caption: "La tasa de variación de f entre a y a + h: la pendiente de la secante"),
                .paragraph("Esta tasa depende de $h$: cuanto más cerca están los dos puntos, más se parece la secante a la propia curva en torno a $a$. La idea de la derivada es hacer tender $h$ a cero —acercar los dos puntos hasta que se confundan— y mirar hacia qué tiende la pendiente."),
                .callout(
                    title: "Derivada en un punto",
                    text: "La derivada de $f$ en $a$, que se escribe $f'(a)$, es el límite de la tasa de variación entre $a$ y $a+h$ cuando $h$ tiende a 0. Cuando ese límite existe, se dice que $f$ es **derivable** en $a$.",
                    tone: .definition
                ),
                .formula("f'(a) = \\lim_{h \\to 0} \\frac{f(a+h) - f(a)}{h}", caption: "La tasa de variación, cuando h se hace infinitamente pequeño"),
                .paragraph("Geométricamente, cuando los dos puntos se juntan, la secante se convierte en ==la tangente==: la recta que toca la curva en $a$ siguiendo su dirección. La derivada es su pendiente. Una pendiente positiva y pronunciada dice que la curva sube deprisa; una pendiente nula, que ahí la curva es horizontal."),
                .figure(.plot(title: "La tangente en un punto", caption: "La recta que «abraza» la curva en $a$: su pendiente es $f'(a)$.", kind: .tangent)),
                .paragraph("Conocer la pendiente y un punto basta para escribir la recta. La ecuación de la tangente en $a$ es $y = f'(a)(x - a) + f(a)$: una recta que pasa por el punto $(a, f(a))$ con pendiente $f'(a)$. Es una fórmula que hay que saberse de memoria, porque aparece en casi todos los exámenes."),
                .callout(
                    title: "Ejemplo",
                    text: "Para $f(x) = x^2$ en $a = 1$: la tasa de variación es $\\frac{(1+h)^2 - 1}{h} = 2 + h$, que tiende a $2$. Así que $f'(1) = 2$, y la tangente es $y = 2(x - 1) + 1 = 2x - 1$.",
                    tone: .example
                ),
                .paragraph("El signo de la derivada se lee directamente en la curva, y de eso tratará todo el capítulo tres. Una tangente que sube de izquierda a derecha tiene pendiente positiva; una tangente que baja, pendiente negativa; una tangente horizontal, pendiente nula, y ahí es a menudo donde pasa algo."),
                .list([
                    "$f'(a) > 0$: la curva sube en $a$",
                    "$f'(a) < 0$: baja",
                    "$f'(a) = 0$: tangente horizontal, a menudo una cima o un valle",
                ]),
                .heading("Por qué importa"),
                .paragraph("La derivada no es solo un objeto de clase: está en todas partes donde algo varía. La velocidad es la derivada de la posición respecto del tiempo; la aceleración, la derivada de la velocidad. En economía, el coste marginal es la derivada del coste total. Cuando un físico o un economista pregunta «¿a qué ritmo?», está pidiendo una derivada."),
                .paragraph("Por eso también la noción se inventó dos veces, en el siglo XVII: Newton, para describir el movimiento de los planetas, y Leibniz, para la geometría de las curvas. Dos problemas, una sola idea: ==mirar lo que pasa infinitamente cerca de un punto==."),
            ]),
            DemoChapter(title: "Calcular una derivada", blocks: [
                .paragraph("Casi nunca se calcula un límite a mano: se aprenden **las derivadas usuales** y las reglas que las combinan. Con una tabla de ocho líneas y tres reglas, se puede derivar cualquier función del temario, y es un ejercicio que tiene que convertirse en un acto reflejo."),
                .heading("Las derivadas usuales"),
                .paragraph("Cada línea de la tabla se puede demostrar con la definición del capítulo anterior, y vale la pena haberlo hecho al menos una vez con $x^2$. Pero en la práctica, se saben de memoria. La línea más importante es la de $x^n$: la potencia baja como factor y el exponente pierde uno."),
                .table(title: "Derivadas usuales", headers: ["f(x)", "f′(x)"], rows: [
                    ["k (constante)", "0"],
                    ["x", "1"],
                    ["x²", "2x"],
                    ["xⁿ", "n · xⁿ⁻¹"],
                    ["1/x", "−1/x²"],
                    ["√x", "1/(2√x)"],
                    ["eˣ", "eˣ"],
                    ["ln x", "1/x"],
                ]),
                .paragraph("Dos líneas merecen un comentario. La derivada de una constante es cero: una función que no cambia tiene velocidad nula, lo cual tiene sentido. Y la derivada de $e^x$ es la propia $e^x$: es ==la única función== que es su propia derivada, y precisamente por eso la exponencial está en todas partes en física: describe todo lo que crece a un ritmo proporcional a su tamaño."),
                .heading("Las reglas"),
                .callout(
                    title: "Las tres reglas",
                    text: "**Suma**: $(u+v)' = u' + v'$. **Producto**: $(uv)' = u'v + uv'$. **Cociente**: $(u/v)' = (u'v - uv')/v^2$. Y para una constante $k$: $(ku)' = ku'$.",
                    tone: .insight
                ),
                .paragraph("La regla de la suma es la más natural: se deriva término a término. Ejemplo: $f(x) = 3x^2 - 5x + 2$ da $f'(x) = 6x - 5$. Las constantes desaparecen, ==las potencias bajan un grado== y los coeficientes se quedan como factores. Un polinomio se deriva así en una línea."),
                .formula("(uv)' = u'v + uv'", caption: "La derivada de un producto: se deriva cada factor por turnos y se suma"),
                .paragraph("La regla del producto requiere un poco más de cuidado. Para $f(x) = x^2 e^x$, se toma $u = x^2$ y $v = e^x$, así que $u' = 2x$ y $v' = e^x$: $f'(x) = 2x\\,e^x + x^2 e^x = (2x + x^2)\\,e^x$. Se deriva el primero dejando el segundo, luego al revés, y se suma. Factorizar al final no es un detalle estético: es lo que permitirá estudiar el signo."),
                .callout(
                    title: "El error que hay que evitar",
                    text: "$(uv)' \\neq u'v'$. La derivada de un producto **no** es el producto de las derivadas: $(x \\cdot x)' = 2x$, no $1 \\cdot 1$. Lo mismo vale para el cociente.",
                    tone: .warning
                ),
                .paragraph("El cociente sigue la misma lógica, con un signo menos y un cuadrado en el denominador. Para $f(x) = \\frac{x}{x+1}$: $u = x$, $v = x + 1$, así que $f'(x) = \\frac{1 \\cdot (x+1) - x \\cdot 1}{(x+1)^2} = \\frac{1}{(x+1)^2}$. El numerador a menudo se simplifica mucho; cuando no lo hace, revisa el cálculo."),
                .heading("Una función dentro de otra"),
                .paragraph("Queda el caso en que una función está anidada dentro de otra: $(2x+1)^3$, $\\sqrt{x^2+1}$, $e^{-x}$. Se deriva la de fuera dejando la de dentro, y luego se multiplica por la derivada de la de dentro. Para una potencia, eso da la fórmula de abajo; para la exponencial, $(e^{u})' = u'\\,e^{u}$."),
                .formula("(u^n)' = n\\,u'\\,u^{n-1}", caption: "Derivar una potencia de una función: la de fuera, por la derivada de la de dentro"),
                .paragraph("Ejemplo: $f(x) = (2x+1)^3$. La de dentro es $u = 2x+1$, de derivada $u' = 2$; así que $f'(x) = 3 \\cdot 2 \\cdot (2x+1)^2 = 6(2x+1)^2$. Olvidar el factor $u'$ es el error más frecuente de todo el capítulo: la derivada de la de dentro ==nunca se deja fuera==."),
                .list([
                    "Identificar la forma: suma, producto, cociente o función anidada",
                    "Derivar cada pieza con la tabla",
                    "Ensamblar con la regla adecuada",
                    "Simplificar y factorizar, y después estudiar el signo",
                ], ordered: true),
                .paragraph("Estos cuatro pasos son la misma rutina para cualquier función. Con práctica, se hacen de cabeza; sin ella, en papel de borrador. En cualquier caso, el último —factorizar— es el que prepara el capítulo siguiente."),
            ]),
            DemoChapter(title: "Derivada y monotonía", blocks: [
                .paragraph("El signo de la derivada dice ==hacia dónde va la función==: positivo, sube; negativo, baja. Es la clave de toda tabla de variación, y la razón por la que has aprendido a derivar."),
                .heading("El teorema"),
                .paragraph("Si $f'$ es positiva en un intervalo, $f$ es creciente en ese intervalo; si $f'$ es negativa, $f$ es decreciente; si $f'$ es nula en todo el intervalo, $f$ es constante. La intuición es la del capítulo uno: una pendiente positiva en todas partes es una curva que sube en todas partes."),
                .figure(.plot(title: "Signo de f′ y sentido de f", caption: "Donde $f'$ es positiva, $f$ sube; donde se anula cambiando de signo, $f$ alcanza un extremo.", kind: .variation)),
                .paragraph("El gráfico muestra las dos curvas una debajo de la otra. Mientras $f'$ está por encima del eje, $f$ sube; en el momento en que $f'$ cruza el eje hacia abajo, $f$ alcanza una cima y vuelve a bajar. El punto donde $f'$ se anula **cambiando de signo** es un **extremo local**: un máximo si $f'$ pasa de positiva a negativa, un mínimo en el caso contrario."),
                .heading("Un ejemplo completo"),
                .paragraph("Para $f(x) = x^3 - 3x$: $f'(x) = 3x^2 - 3 = 3(x-1)(x+1)$. La derivada se anula en $-1$ y en $1$. Una tabla de signos para un producto de dos factores da: positiva antes de $-1$, negativa entre $-1$ y $1$, positiva después de $1$. Se deduce un **máximo local** en $-1$, donde $f(-1) = 2$, y un **mínimo local** en $1$, donde $f(1) = -2$."),
                .table(title: "Variación de f(x) = x³ − 3x", headers: ["Intervalo", "Signo de f′", "Sentido de f"], rows: [
                    ["]−∞ ; −1[", "+", "creciente"],
                    ["]−1 ; 1[", "−", "decreciente"],
                    ["]1 ; +∞[", "+", "creciente"],
                ]),
                .paragraph("La tabla es la respuesta esperada a «estudia la monotonía de $f$»: los intervalos arriba, el signo de la derivada en medio, las flechas abajo, con los valores de $f$ en los puntos donde cambia de sentido. Es un objeto estándar, y hay que presentarlo exactamente en ese orden."),
                .callout(
                    title: "Método",
                    text: "1. Derivar. 2. Estudiar el signo de $f'$ (¡factorizar!). 3. Deducir la monotonía. 4. Calcular los valores en los extremos del intervalo y en los extremos locales. 5. Construir la tabla.",
                    tone: .insight
                ),
                .paragraph("El paso dos es donde las cosas se tuercen. El signo de una derivada no se lee en $6x - 5$ o $3x^2 - 3$ tal cual: hay que ==resolver $f'(x) = 0$== y luego hacer una tabla de signos, o factorizar para leer el signo de cada factor. Una derivada sin factorizar es una derivada de la que no sabes nada."),
                .keyFigure(value: "f′ = 0", label: "donde la curva tiene tangente horizontal: una cima, un valle o una meseta"),
                .paragraph("Una tangente horizontal es, por tanto, una señal, no una prueba: dice que la función deja de subir o de bajar por un instante, pero no si vuelve a arrancar en sentido contrario. Decide la tabla de signos, y solo ella."),
                .callout(
                    title: "Cuidado",
                    text: "$f'(a) = 0$ no basta para tener un extremo: $x^3$ tiene derivada nula en 0 y no cambia de sentido; es una meseta. $f'$ tiene que **cambiar de signo** en $a$.",
                    tone: .warning
                ),
                .heading("Leer una curva"),
                .paragraph("El vínculo funciona también al revés: a partir de la curva de $f$ se puede adivinar el signo de $f'$, y a partir de la curva de $f'$, la monotonía de $f$. Es un ejercicio clásico: te dan la gráfica de la derivada y te preguntan dónde es creciente la función. La respuesta es: donde la curva de $f'$ está por encima del eje horizontal."),
                .list([
                    "Curva de $f$ que sube ⇔ $f'$ positiva",
                    "Cima o valle de $f$ ⇔ $f'$ se anula cambiando de signo",
                    "Curva de $f'$ por encima del eje ⇔ $f$ creciente",
                ]),
                .paragraph("Esta lectura cruzada es lo que separa a un alumno que aplica una receta de uno que comprende: la derivada no es un cálculo más, es ==la curva vista de otra manera==. Y es lo que hace posible el capítulo siguiente, donde buscamos el mejor punto de una curva que no hemos dibujado."),
            ]),
            DemoChapter(title: "Resolver un problema de optimización", blocks: [
                .paragraph("Optimizar es encontrar ==el mayor o el menor valor== que puede tomar una magnitud: el área máxima de un cercado, el coste mínimo de una caja, el mayor beneficio. Son los problemas en los que la derivada hace algo concreto, y los que más puntos dan."),
                .heading("Un cercado contra un muro"),
                .paragraph("Tienes 40 metros de valla para cercar un corral rectangular contra un muro: el muro forma un lado y la valla, los otros tres. ¿Qué dimensiones dan el área máxima? Llamemos $x$ al ancho, perpendicular al muro. Los dos anchos se llevan $2x$ metros de valla; quedan $40 - 2x$ para el largo. El área es el producto de ambos."),
                .formula("A(x) = x\\,(40 - 2x) = 40x - 2x^2", caption: "El área del corral, para x entre 0 y 20"),
                .paragraph("El problema se ha convertido en el estudio de una función: buscamos el máximo de $A$ en $[0 ; 20]$; más allá de 20, el largo sería negativo. Derivamos: $A'(x) = 40 - 4x$, que se anula para $x = 10$, positiva antes y negativa después. La tabla de variación da la respuesta."),
                .table(title: "Variación de A(x) = 40x − 2x²", headers: ["x", "Signo de A′", "Sentido de A"], rows: [
                    ["[0 ; 10[", "+", "creciente, de 0 a 200"],
                    ["x = 10", "0", "máximo: A(10) = 200"],
                    ["]10 ; 20]", "−", "decreciente, de 200 a 0"],
                ]),
                .paragraph("El área máxima es de $200$ m², para un ancho de $10$ m y un largo de $20$ m. Fíjate en que no es un cuadrado: como el muro sustituye a un lado, el mejor rectángulo es el doble de largo que de ancho. Sin la derivada, podríamos haber probado valores al azar; con ella, tenemos ==la certeza== de que es el mejor."),
                .callout(
                    title: "Método",
                    text: "1. Elegir la variable y el intervalo en el que tiene sentido. 2. Expresar la magnitud que se quiere optimizar en función de esa única variable. 3. Derivar, estudiar el signo, construir la tabla. 4. Leer el extremo y **responder a la pregunta planteada**, con la unidad.",
                    tone: .insight
                ),
                .heading("Un segundo ejemplo"),
                .paragraph("Una empresa fabrica $x$ centenares de piezas al día, con un coste total $C(x) = x^2 + 4x + 16$ (en centenares de euros), para $x$ entre 1 y 10. El coste medio por centenar de piezas es $M(x) = C(x)/x = x + 4 + 16/x$. ¿Para qué producción es mínimo este coste medio?"),
                .formula("M'(x) = 1 - \\frac{16}{x^2} = \\frac{x^2 - 16}{x^2} = \\frac{(x-4)(x+4)}{x^2}", caption: "La derivada, factorizada para leer su signo"),
                .paragraph("En $[1 ; 10]$, el denominador y $x + 4$ son positivos: el signo de $M'$ es el de $x - 4$, negativo antes de 4 y positivo después. El coste medio baja hasta $x = 4$ y luego vuelve a subir: el mínimo está en $x = 4$ y vale $M(4) = 4 + 4 + 4 = 12$, es decir, 1200 euros por centenar. Fabricar cuatrocientas piezas al día es **el ritmo más económico**."),
                .figure(.flow(title: "El procedimiento", steps: ["Una variable", "Una función", "Su derivada", "Su tabla", "La respuesta"])),
                .paragraph("Los dos ejemplos siguen exactamente el mismo camino, y siempre es el mismo: la dificultad de un problema de optimización casi nunca está en la derivada, sino en el **planteamiento**: encontrar la variable adecuada y escribir la magnitud en función de ella. Una vez planteada la función, el resto es el capítulo tres."),
                .callout(
                    title: "Las trampas",
                    text: "Olvidar el intervalo (una longitud negativa no existe); derivar la magnitud equivocada (el coste total en lugar del coste medio); quedarse en $x = 10$ sin decir que el área es $200$ m². El examinador espera **la respuesta a la pregunta**, no solo la tabla.",
                    tone: .warning
                ),
                .list([
                    "Corral, caja, cilindro: una dimensión libre, una restricción de longitud o de volumen",
                    "Coste, beneficio, ingresos: una cantidad producida, una función económica",
                    "Trayecto, velocidad, tiempo: una posición o un instante que elegir",
                ]),
                .paragraph("Estas tres familias cubren casi todas las preguntas de examen. Cada vez, la pregunta oculta es la misma: ==¿para qué valor de $x$ se anula la derivada cambiando de signo?== Cuando sepas reconocerla bajo cualquier disfraz, el capítulo es tuyo."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "¿Qué representa geométricamente la derivada $f'(a)$?",
                back: "La pendiente de la tangente a la curva de $f$ en el punto de abscisa $a$.",
                figure: .plot(title: "La tangente en a", caption: "", kind: .tangent),
                chapter: 0
            ),
            DemoCard(
                kind: .choice,
                front: "¿Cuál es la derivada de $f(x) = 3x^2 - 5x + 2$?",
                back: "$f'(x) = 6x - 5$: la potencia baja un grado, el término en $x$ se convierte en su pendiente y la constante desaparece.",
                choices: ["$6x - 5$", "$3x - 5$", "$6x + 2$", "$x^2 - 5$"],
                answerIndex: 0,
                chapter: 1
            ),
            DemoCard(
                kind: .cloze,
                front: "En un intervalo en el que $f'$ es …, la función $f$ es creciente.",
                back: "positiva",
                chapter: 2
            ),
            DemoCard(kind: .basic, front: "¿Cuál es la fórmula de la derivada de un producto?", back: "$(uv)' = u'v + uv'$: se deriva cada factor por turnos y se suma.", chapter: 1),
            DemoCard(kind: .cloze, front: "La derivada de $e^x$ es … .", back: "$e^x$", chapter: 1),
            DemoCard(kind: .choice, front: "¿En qué puntos tiene $f(x) = x^3 - 3x$ un extremo local?", back: "En $x = -1$ (máximo, de valor 2) y en $x = 1$ (mínimo, de valor $-2$): donde $f'(x) = 3(x-1)(x+1)$ se anula cambiando de signo.", choices: ["$x = 0$", "$x = -1$ y $x = 1$", "$x = 3$", "Ninguno"], answerIndex: 1, chapter: 2),
            DemoCard(kind: .basic, front: "¿Cómo se encuentra el máximo de una magnitud en un problema de optimización?", back: "Se expresa la magnitud en función de una sola variable en el intervalo donde tiene sentido, se deriva, se estudia el signo de la derivada y se lee el máximo en la tabla de variación, donde la derivada se anula pasando de positiva a negativa.", chapter: 3),
            DemoCard(kind: .cloze, front: "Con 40 m de valla contra un muro, el área del corral es máxima para un ancho de … m.", back: "10", chapter: 3),
        ]
    )

    // MARK: Physics: energy

    private static let energyES = OnboardingDemoCourse(
        id: "physics-energy",
        emoji: "⚡️",
        subject: "Physique",
        title: "La energía",
        summary: "Las formas de energía, su conservación de una forma a otra, la potencia y el rendimiento, y después las cadenas energéticas, con las fórmulas y los órdenes de magnitud del temario.",
        accentIndex: 6,
        chapters: [
            DemoChapter(title: "Las formas de energía", blocks: [
                .paragraph("La energía no se ve, se **transforma**: una manzana que cae, el calor de un motor, la luz de una lámpara son la misma magnitud en formas distintas. Se mide en ==julios (J)==, y un julio es aproximadamente la energía necesaria para levantar una manzana un metro."),
                .heading("Una magnitud, varias formas"),
                .paragraph("Los físicos tardaron dos siglos en comprender que el calor, el movimiento, la luz y la electricidad eran una misma cosa con distintos ropajes. Lo que las une es que cada una puede convertirse en otra —un motor transforma calor en movimiento, una dinamo transforma movimiento en electricidad— y que la cantidad total nunca cambia. La tabla de abajo recoge las formas del temario."),
                .table(title: "Las formas habituales", headers: ["Forma", "Depende de", "Ejemplo"], rows: [
                    ["Cinética", "la masa y la velocidad", "un coche en marcha"],
                    ["Potencial gravitatoria", "la masa y la altura", "una manzana en el árbol"],
                    ["Térmica", "la agitación molecular", "una sartén caliente"],
                    ["Eléctrica", "la corriente", "una pila"],
                    ["Química", "los enlaces", "la gasolina, la glucosa"],
                ]),
                .paragraph("Dos de estas formas tienen una fórmula que hay que saberse de memoria. La **energía cinética** es la de un cuerpo en movimiento: crece con la masa, y con el cuadrado de la velocidad. Duplicar la masa la duplica; duplicar la velocidad la cuadruplica. Ese cuadrado es lo que hace tan graves los accidentes a gran velocidad."),
                .formula("E_k = \\frac{1}{2} m v^2", caption: "Energía cinética: m en kg, v en m/s, E en J"),
                .paragraph("La **energía potencial gravitatoria** es la de un cuerpo situado a cierta altura: energía «en reserva», que se convertirá en movimiento si lo sueltas. Es proporcional a la masa y a la altura, y a la intensidad de la gravedad $g$, de unos $9.8$ N/kg en la Tierra, y seis veces menos en la Luna."),
                .formula("E_p = m g h", caption: "Energía potencial gravitatoria: g ≈ 9,8 N/kg, h en m"),
                .callout(
                    title: "Orden de magnitud",
                    text: "Un coche de 1000 kg a 50 km/h (≈ 14 m/s) lleva $E_k = \\frac{1}{2} \\times 1000 \\times 14^2 \\approx 98\\,000$ J, casi 100 kJ. A 100 km/h, **cuatro veces más**: 400 kJ, la energía que haría falta para subirlo a cuarenta metros de altura.",
                    tone: .example
                ),
                .paragraph("Este ejemplo muestra la trampa de las unidades: la velocidad tiene que estar en metros por segundo, no en kilómetros por hora, o el resultado se equivoca en un factor trece. Para convertir, se dividen los km/h entre 3,6. Es ==lo primero que hay que comprobar== en cualquier cálculo de energía cinética."),
                .keyFigure(value: "× 4", label: "cuando la velocidad se duplica, la energía cinética se cuadruplica: es el cuadrado de la fórmula"),
                .heading("Las unidades"),
                .paragraph("El julio es pequeño a la escala de la vida cotidiana, y se usan sus múltiplos: el kilojulio (1 kJ = 1000 J) para los alimentos, el megajulio para los combustibles, el kilovatio hora para la electricidad. Un gramo de azúcar libera unos 17 kJ; un litro de gasolina, 35 MJ; una tableta de chocolate, 1000 kJ: suficiente para subir un coche a lo alto de la torre Eiffel, si supiéramos convertir sin pérdidas."),
                .callout(
                    title: "Unidad",
                    text: "La energía se expresa en julios, nunca en vatios. El vatio mide la **potencia**: energía por segundo. Confundir ambos es confundir un litro con un litro por minuto.",
                    tone: .warning
                ),
                .list([
                    "1 kJ = 1000 J: la energía de un alimento figura en kJ en el envase",
                    "1 kWh = 3 600 000 J: la unidad de la factura de la luz",
                    "1 caloría ≈ 4,18 J: la unidad antigua, que sigue en las etiquetas",
                ]),
                .paragraph("Retén la lógica más que las cifras: la energía es siempre una cantidad, como un volumen, y se convierte de una forma a otra sin desaparecer nunca. Es este principio, el más importante de toda la física, el que enuncia el capítulo siguiente."),
            ]),
            DemoChapter(title: "Conservación y transferencias", blocks: [
                .paragraph("==bleu|La energía ni se crea ni se destruye==: pasa de una forma a otra, de un sistema a otro. Es el principio de conservación, y vale para todo, del átomo a la galaxia. Ningún experimento lo ha desmentido jamás."),
                .heading("Una caída"),
                .paragraph("Toma una pelota sujeta a dos metros del suelo. Tiene energía potencial, y ninguna energía cinética. Suéltala: al caer, su altura disminuye y su velocidad aumenta; la energía potencial se convierte en energía cinética, exactamente en la misma proporción. En el suelo, todo es cinético; en el choque, todo se convierte en calor y sonido."),
                .figure(.flow(title: "La cadena energética de una caída", steps: ["Energía potencial, arriba", "Se convierte en energía cinética", "Choque: calor y sonido", "Total sin cambios"])),
                .paragraph("Este razonamiento permite calcular sin conocer las fuerzas. Una pelota soltada desde 2 m pierde energía potencial y gana exactamente la misma cantidad de energía cinética, siempre que se desprecie el rozamiento: $mgh = \\frac{1}{2}mv^2$, así que la masa se simplifica y la velocidad en el suelo es $v = \\sqrt{2gh}$."),
                .formula("v = \\sqrt{2 g h} \\approx \\sqrt{2 \\times 9{,}8 \\times 2} \\approx 6{,}3 \\text{ m/s}", caption: "La velocidad en el suelo, sin rozamiento: la misma para una canica que para una bola de bolos"),
                .paragraph("El resultado no depende de la masa: una canica y una bola de bolos soltadas desde la misma altura llegan a la misma velocidad. Galileo lo observó desde lo alto de la torre de Pisa; la conservación de la energía lo explica en una línea. Esa es ==la fuerza de este principio==: da respuestas allí donde las ecuaciones del movimiento serían penosas."),
                .callout(
                    title: "Energía mecánica",
                    text: "La suma de la energía cinética y la potencial: $E_m = E_k + E_p$. Sin rozamiento, se conserva: lo que pierde una, lo gana la otra.",
                    tone: .definition
                ),
                .formula("E_m = E_k + E_p = \\text{constante}", caption: "En ausencia de rozamiento"),
                .paragraph("El péndulo es el ejemplo perfecto. En lo alto de su oscilación se detiene un instante: todo es potencial. Abajo va lo más rápido posible: todo es cinético. Entre medias, la energía pasa sin cesar de una forma a la otra, y el péndulo vuelve a subir exactamente hasta la altura de la que partió… si no fuera por el aire."),
                .heading("¿Y el rozamiento?"),
                .paragraph("En la vida real, el péndulo acaba parándose, la pelota rebota cada vez más bajo, el coche se detiene cuando se corta el motor. La energía mecánica disminuye. No ha desaparecido: el rozamiento la ha convertido en **energía térmica**, en el aire, en el suelo, en los frenos, que se calientan, a veces mucho."),
                .callout(
                    title: "Qué hace el rozamiento",
                    text: "No «destruye» nada: la energía mecánica perdida se convierte en energía térmica. El total se conserva siempre, simplemente es **menos útil**: el calor difuso ya no mueve nada.",
                    tone: .insight
                ),
                .paragraph("Esta pérdida de utilidad es una idea profunda. La energía se conserva, pero se **degrada**: cada conversión deja una parte en forma de calor tibio que ya no se puede recuperar. Por eso el movimiento perpetuo es imposible, y por eso hay que alimentar un motor continuamente."),
                .list([
                    "Trabajo: energía transferida por una fuerza que desplaza algo: empujar, levantar, frenar",
                    "Calor: transferencia debida a una diferencia de temperatura: una cazuela en el fuego",
                    "Radiación: transferencia mediante la luz: el Sol que te calienta la piel",
                ]),
                .paragraph("Estos tres modos son las únicas vías por las que la energía pasa de un sistema a otro. Hacer un **balance energético** es elegir un sistema, anotar lo que entra y lo que sale por estas tres vías, y comprobar que las cuentas cuadran: ==lo que entra menos lo que sale es lo que se queda==."),
            ]),
            DemoChapter(title: "Potencia y rendimiento", blocks: [
                .paragraph("La **potencia** dice a qué velocidad se transfiere la energía. Un radiador de 2000 W transfiere 2000 julios cada segundo. Dos aparatos pueden consumir la misma energía, uno en un minuto y otro en una hora: el primero es sesenta veces más potente."),
                .heading("La potencia"),
                .formula("P = \\frac{E}{\\Delta t}", caption: "P en vatios (W), E en julios, Δt en segundos"),
                .paragraph("La fórmula se lee en los dos sentidos. Conociendo la potencia y la duración, se obtiene la energía: $E = P \\times \\Delta t$. Un horno de 2000 W encendido durante una hora consume $2000 \\times 3600 = 7.2 \\times 10^6$ J, es decir, 7,2 MJ. Vale la pena retener los órdenes de magnitud de la tabla."),
                .table(title: "Algunas potencias", headers: ["Qué", "Potencia"], rows: [
                    ["Una persona en reposo", "≈ 100 W"],
                    ["Un ciclista a pleno esfuerzo", "≈ 300 W"],
                    ["Un horno", "2000 W"],
                    ["Un coche", "≈ 100 kW"],
                    ["Un aerogenerador", "≈ 3 MW"],
                    ["Un reactor nuclear", "≈ 1000 MW"],
                ]),
                .paragraph("Una persona en reposo desprende aproximadamente la potencia de una bombilla antigua: por eso una sala llena se calienta deprisa. Y un reactor nuclear produce diez millones de veces más: suficiente para abastecer a un millón de hogares. La potencia es ==el caudal de la energía==, como el caudal de un grifo lo es del agua."),
                .callout(
                    title: "El kilovatio hora",
                    text: "1 kWh son 1000 W durante una hora: $1000 \\times 3600 = 3.6 \\times 10^6$ J. Es la unidad de la factura de la luz, y cuesta unos veinte céntimos.",
                    tone: .example
                ),
                .paragraph("El kilovatio hora es una energía, no una potencia; la «hora» está ahí para recordarlo: una potencia multiplicada por un tiempo. Un hogar francés consume unos 4700 kWh de electricidad al año, algo más de 500 W de media, día y noche. Un radiador de 2000 W encendido durante una noche de ocho horas consume él solo 16."),
                .heading("El rendimiento"),
                .paragraph("Ningún convertidor es perfecto: una parte de la energía recibida sale en forma de calor y no ha servido para nada. El ==rendimiento== compara lo útil con lo aportado. Un motor de gasolina recibe la energía química del combustible y solo devuelve un tercio en forma de movimiento: el resto calienta el motor, el tubo de escape y el aire de alrededor."),
                .formula("\\eta = \\frac{E_{\\text{útil}}}{E_{\\text{aportada}}}", caption: "Siempre menor o igual que 1 (100 %)"),
                .paragraph("El rendimiento se da a menudo en porcentaje, y se multiplica a lo largo de una cadena: si una central tiene un rendimiento del 35 % y la red, del 90 %, el rendimiento del conjunto es $0.35 \\times 0.9 \\approx 0.32$. Cada eslabón de más hace perder algo, y por eso se intenta tener los menos posibles."),
                .bars(title: "Rendimiento de algunos convertidores", unit: "%", bars: [
                    DemoBar(label: "Motor de gasolina", value: 35),
                    DemoBar(label: "Bombilla LED", value: 40),
                    DemoBar(label: "Motor eléctrico", value: 90),
                    DemoBar(label: "Radiador eléctrico", value: 100),
                ]),
                .paragraph("El gráfico explica buena parte de la transición energética. Un motor eléctrico convierte en movimiento nueve décimas partes de lo que recibe, y un motor de gasolina, un tercio: con la misma energía de partida, el coche eléctrico llega casi tres veces más lejos. Una bombilla incandescente, por su parte, tenía un rendimiento del 5 %: era un radiador que daba un poco de luz."),
                .callout(
                    title: "¿Rendimiento del 100 %?",
                    text: "Un radiador eléctrico lo convierte todo en calor, pero el calor es justo lo que queremos: su rendimiento es del 100 %. Para un motor, ese mismo calor es una pérdida. Lo **útil** depende de lo que se le pida al aparato.",
                    tone: .warning
                ),
                .list([
                    "Potencia: energía por segundo, en vatios",
                    "Energía: potencia por duración, en julios, o en kWh en la factura",
                    "Rendimiento: útil entre aportada, nunca mayor que 1, y se multiplica a lo largo de una cadena",
                ]),
                .paragraph("Estas tres nociones permiten leer cualquier ficha técnica y comprobar cualquier promesa. Un aparato que declarara más energía útil de la que recibe violaría el primer principio; un rendimiento mayor que uno ==no existe==, diga lo que diga la publicidad."),
            ]),
            DemoChapter(title: "Las cadenas energéticas", blocks: [
                .paragraph("Una **cadena energética** es el diagrama que cuenta el viaje de la energía: de dónde viene, por qué convertidores pasa, en qué forma sale y qué se pierde por el camino. Es ==la herramienta del balance energético==, y casi siempre es lo que te piden dibujar en un examen."),
                .heading("Leer una cadena"),
                .paragraph("El diagrama se lee de izquierda a derecha. En los dos extremos, **depósitos**: donde está almacenada la energía al principio y donde termina. Entre ellos, **convertidores**: los aparatos que la hacen cambiar de forma. Cada flecha lleva una forma de energía, y cada convertidor deja salir una flecha de calor: las pérdidas. Una central hidroeléctrica es el ejemplo más claro."),
                .figure(.flow(title: "Una central hidroeléctrica", steps: ["Agua embalsada: potencial", "Caída: cinética", "Turbina: mecánica", "Alternador: eléctrica", "Red"])),
                .paragraph("El agua del embalse tiene energía potencial, por su altura. Al caer por las tuberías, la convierte en energía cinética. La turbina convierte el movimiento del agua en rotación; el alternador transforma la rotación en corriente; las líneas se llevan la corriente. En cada paso se escapa un poco de calor, pero muy poco: una central hidroeléctrica tiene un rendimiento cercano al 90 %, el mejor de todos."),
                .paragraph("La misma lógica describe cualquier sistema, incluido un cuerpo humano. Un ciclista convierte la energía química de los alimentos en energía mecánica en los músculos, con un rendimiento de alrededor del 25 %: tres cuartas partes salen en forma de calor, y por eso se suda."),
                .figure(.flow(title: "Un ciclista", steps: ["Alimentos: química", "Músculos: mecánica", "Ruedas: cinética", "Rozamiento: calor"])),
                .heading("Los convertidores"),
                .paragraph("Un convertidor se define por lo que recibe y lo que devuelve. La tabla reúne los del temario; para cada uno, la última columna indica en qué forma sale la parte no aprovechada. Fíjate en que es **siempre calor**: es la forma final de toda energía degradada."),
                .table(title: "Algunos convertidores", headers: ["Convertidor", "Recibe", "Devuelve", "Pierde"], rows: [
                    ["Motor eléctrico", "Eléctrica", "Mecánica", "Calor"],
                    ["Panel solar", "Radiación", "Eléctrica", "Calor"],
                    ["Pila", "Química", "Eléctrica", "Calor"],
                    ["Lámpara LED", "Eléctrica", "Luz", "Calor"],
                    ["Motor de gasolina", "Química", "Mecánica", "Calor, gases"],
                ]),
                .paragraph("Dibujar la cadena de un aparato ya es comprender cómo funciona, y a menudo por qué se calienta. Un ordenador recibe energía eléctrica y, al final, no devuelve más que calor: el cálculo en sí no almacena nada. Un cargador de móvil tibio es un convertidor que pierde un pequeño porcentaje por el camino."),
                .callout(
                    title: "La tostadora",
                    text: "Recibe 1000 W de energía eléctrica y devuelve 1000 W de calor: rendimiento del 100 %. Pero si la electricidad viene de una central térmica con un 35 % de rendimiento, hubo que quemar casi 3000 W de gas para tostar el pan. Cuenta **toda la cadena**, no solo el último eslabón.",
                    tone: .example
                ),
                .heading("De dónde viene la electricidad"),
                .paragraph("Remontar la cadena hasta el principio lleva a las **fuentes** de energía: lo que quemamos, lo que dejamos caer, lo que captamos. Algunas se renuevan a escala humana —sol, viento, agua, biomasa—, otras se agotan —carbón, petróleo, gas, uranio—. El gráfico muestra de dónde viene la electricidad en Francia, donde la nuclear domina desde los años ochenta."),
                .bars(title: "De dónde viene la electricidad de Francia (órdenes de magnitud)", unit: "%", bars: [
                    DemoBar(label: "Nuclear", value: 65),
                    DemoBar(label: "Hidráulica", value: 12),
                    DemoBar(label: "Eólica", value: 10),
                    DemoBar(label: "Solar", value: 5),
                    DemoBar(label: "Gas, carbón", value: 8),
                ]),
                .paragraph("Estas proporciones cambian de un año a otro —un invierno seco vacía los embalses, un año ventoso dispara la eólica—, pero el orden se mantiene: dos tercios nuclear, una cuarta parte renovable, y una parte fósil que se usa sobre todo en los picos de demanda. En otros países de Europa, el gas y el carbón pesan mucho más, y allí la electricidad emite varias veces más CO₂."),
                .callout(
                    title: "Renovable, no gratuita",
                    text: "Una fuente renovable se regenera, pero captarla tiene un coste: materiales, terreno, pérdidas a lo largo de la cadena. Y «renovable» no significa «sin efectos»: una presa inunda un valle, un aerogenerador necesita cobre. **Ninguna cadena carece de pérdidas, y ninguna fuente carece de consecuencias.**",
                    tone: .warning
                ),
                .list([
                    "Depósitos en los dos extremos, convertidores entre ellos, una forma de energía por flecha",
                    "Cada convertidor pierde calor: el rendimiento lo mide",
                    "Los rendimientos se multiplican a lo largo de la cadena",
                    "La fuente, al principio de todo, decide lo que cuesta la energía, y lo que emite",
                ]),
                .paragraph("Con estas cuatro reglas, puedes dibujar y comentar cualquier cadena: la de un móvil, un tren, una central. Es el capítulo que une la física con lo que lees en las noticias, y ==el más útil== de los cuatro para entender el mundo que te rodea."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "¿Qué le ocurre a la energía potencial de una pelota que cae?",
                back: "Se convierte en energía cinética durante la caída (la velocidad aumenta), y después en energía térmica y sonora en el choque. El total se conserva.",
                figure: .flow(title: "Cadena energética", steps: ["Potencial", "Cinética", "Calor y sonido"]),
                chapter: 1
            ),
            DemoCard(
                kind: .choice,
                front: "Si la velocidad de un coche se duplica, su energía cinética…",
                back: "Se cuadruplica: $E_k = \\frac{1}{2} m v^2$ depende del cuadrado de la velocidad.",
                choices: ["se duplica", "se cuadruplica", "no cambia", "se reduce a la mitad"],
                answerIndex: 1,
                chapter: 0
            ),
            DemoCard(
                kind: .cloze,
                front: "La potencia es la energía transferida por unidad de …: se expresa en vatios.",
                back: "tiempo",
                chapter: 2
            ),
            DemoCard(kind: .basic, front: "¿Cuál es la fórmula de la energía potencial gravitatoria?", back: "$E_p = m g h$, con m en kg, g ≈ 9,8 N/kg y h en metros.", chapter: 0),
            DemoCard(kind: .cloze, front: "El rendimiento es el cociente entre la energía … y la energía aportada.", back: "útil", chapter: 2),
            DemoCard(kind: .choice, front: "¿Cuál es la unidad de energía?", back: "El julio (J). El vatio mide la potencia, es decir, la energía por segundo.", choices: ["El vatio", "El julio", "El newton", "El voltio"], answerIndex: 1, chapter: 0),
            DemoCard(kind: .basic, front: "¿Qué es una cadena energética?", back: "El diagrama que sigue a la energía de un depósito a otro, pasando por convertidores: una forma de energía por flecha y, en cada convertidor, una flecha de pérdidas en forma de calor.", chapter: 3),
            DemoCard(kind: .cloze, front: "En una central hidroeléctrica, la energía … del agua embalsada se convierte en energía cinética en la caída.", back: "potencial", chapter: 3),
        ]
    )
}
