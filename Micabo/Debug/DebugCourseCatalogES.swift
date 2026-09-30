import Foundation

#if DEBUG
// MARK: - Los seis cursos de depuración, en español

/// Seis cursos completos, escritos de antemano, **reservados a las builds de depuración**: con qué
/// llenar la biblioteca de un solo gesto para probar las fichas, el esquema, las tarjetas y el repaso
/// sin generar nada. Siguen la misma regla que los cursos de demostración —cuatro
/// capítulos, texto entre cada objeto enriquecido, ningún objeto pegado a otro— y
/// el mismo nivel de exigencia: bachillerato o primer curso de universidad, hechos exactos, cifras
/// correctas y cálculos verificados.
///
/// Los identificadores son estables de un idioma a otro; las asignaturas son los nombres
/// canónicos de `SubjectCatalog`.
extension DebugCourseCatalog {
    static let spanish: [OnboardingDemoCourse] = [
        revolutionES, geneticsES, probabilityES, supplyDemandES, circuitsES, mitosisES,
    ]

    // MARK: Historia: la Revolución francesa

    private static let revolutionES = OnboardingDemoCourse(
        id: "debug-revolution",
        emoji: "🇫🇷",
        subject: "Histoire",
        title: "La Revolución francesa (1789–1799)",
        summary: "Diez años que llevan a Francia de la monarquía absoluta a la República: la crisis de 1789, la monarquía constitucional, el Terror y, después, el Directorio hasta el golpe de Estado de Bonaparte.",
        accentIndex: 1,
        chapters: [
            DemoChapter(title: "La crisis del Antiguo Régimen (1787–1789)", blocks: [
                .paragraph("En 1789, Francia es el reino más poblado de Europa: unos ==28 millones de habitantes==, gobernados por un rey que recibe su poder de Dios y no lo comparte con nadie. En diez años, este régimen de varios siglos de antigüedad se derrumba. Para entender cómo, hay que partir de lo que más tarde se llamará el **Antiguo Régimen**."),
                .heading("Una sociedad estamental"),
                .paragraph("La sociedad está dividida en tres estamentos, desiguales ante la ley. El **clero** reza, la **nobleza** combate y el **tercer estado** trabaja: eso dice, al menos, la teoría. Los dos primeros estamentos disfrutan de **privilegios**, es decir, derechos particulares, como la exención de la talla, el principal impuesto directo, o el derecho a cobrar rentas a los campesinos."),
                .callout(
                    title: "Privilegio",
                    text: "Literalmente, una «ley privada»: un derecho o una exención concedidos a un grupo o a una persona, y no a todos. En el Antiguo Régimen, la desigualdad ante la ley y ante los impuestos es **la norma**, no la excepción.",
                    tone: .definition
                ),
                .paragraph("El tercer estado reúne a todos los que no son ni clérigos ni nobles, es decir, a casi todo el mundo: los campesinos, que forman la inmensa mayoría, los artesanos y los obreros de las ciudades, pero también una **burguesía** rica e instruida —comerciantes, abogados, banqueros— que soporta cada vez peor verse excluida de los honores reservados al nacimiento."),
                .bars(title: "Peso de los tres estamentos en la población (hacia 1789)", unit: "%", bars: [
                    DemoBar(label: "Clero", value: 0.5),
                    DemoBar(label: "Nobleza", value: 1.5),
                    DemoBar(label: "Tercer estado", value: 98),
                ]),
                .paragraph("El gráfico muestra el núcleo del problema: el dos por ciento de la población acapara la mayor parte de los privilegios, buena parte de la tierra y casi todos los altos cargos. En enero de 1789, el abate Sieyès resume la situación en un célebre panfleto: «¿Qué es el tercer estado? Todo. ¿Qué ha sido hasta ahora? Nada. ¿Qué pide? Ser algo»."),
                .heading("Tres crisis a la vez"),
                .paragraph("La Revolución nace del encuentro de tres crisis. En primer lugar, una **crisis financiera**: las guerras, y sobre todo el apoyo a la independencia estadounidense, han disparado la deuda, cuyo pago absorbe cerca de ==la mitad de los gastos del Estado==. Los sucesivos ministros proponen que paguen los privilegiados; los privilegiados se niegan."),
                .paragraph("Después, una **crisis económica**: la cosecha de 1788, arrasada por el granizo, es catastrófica, y el precio del pan se dispara. El 14 de julio de 1789 alcanza en París su nivel más alto del siglo. Por último, una **crisis de las ideas**: los filósofos de la Ilustración —Montesquieu y la separación de poderes, Rousseau y la soberanía del pueblo, Voltaire y la tolerancia— han enseñado a las élites a juzgar el poder en nombre de la razón."),
                .figure(.flow(title: "De la crisis a la Revolución", steps: ["Deuda y amenaza de bancarrota", "Los privilegiados rechazan el impuesto", "El rey convoca los Estados Generales", "El tercer estado exige el voto por cabeza", "El tercer estado se proclama Asamblea Nacional"])),
                .paragraph("Acorralado, Luis XVI convoca los **Estados Generales**, una asamblea de los tres estamentos que no se reunía desde 1614. En todo el reino se redactan **cuadernos de quejas** para decirle al rey lo que no funciona: cerca de sesenta mil, que reclaman sobre todo la igualdad ante los impuestos y el fin de los abusos, pero casi nunca el fin de la monarquía."),
                .callout(
                    title: "El voto por estamento",
                    text: "En los Estados Generales, cada estamento vota por separado y dispone de **un voto**: el clero y la nobleza, unidos, vencen siempre al tercer estado por dos votos contra uno. El tercer estado ha logrado tener tantos diputados como los otros dos estamentos juntos, pero hace falta que se vote **por cabeza** para que ese número cuente.",
                    tone: .insight
                ),
                .paragraph("Todo se decide en esta cuestión de procedimiento. El 17 de junio de 1789, a falta de acuerdo, los diputados del tercer estado se proclaman ==bleu|Asamblea Nacional==: ya no representan a un estamento, sino a la nación entera. El 20 de junio, al encontrar cerrada su sala, se reúnen en la sala del Juego de Pelota y juran no separarse hasta haber dado una constitución a Francia. La soberanía acaba de cambiar de bando."),
            ]),
            DemoChapter(title: "1789: el fin del absolutismo", blocks: [
                .paragraph("El verano de 1789 deshace en pocas semanas lo que habían construido siglos. La revolución de los diputados en Versalles se ve respaldada por ==la revolución de los parisinos== y, después, por la del campo: es esta conjunción la que la vuelve irreversible."),
                .timeline(title: "El verano y el otoño de 1789", events: [
                    DemoEvent(date: "5 de mayo", label: "Apertura de los Estados Generales en Versalles"),
                    DemoEvent(date: "20 de junio", label: "Juramento del Juego de Pelota"),
                    DemoEvent(date: "14 de julio", label: "Toma de la Bastilla"),
                    DemoEvent(date: "4 de agosto", label: "Abolición de los privilegios"),
                    DemoEvent(date: "26 de agosto", label: "Declaración de los Derechos del Hombre y del Ciudadano"),
                    DemoEvent(date: "5–6 de octubre", label: "El rey es llevado de Versalles a París"),
                ]),
                .paragraph("A principios de julio, el rey concentra tropas alrededor de París y destituye a Necker, el ministro popular. Los parisinos ven en ello la preparación de un golpe de fuerza contra la Asamblea. El 14 de julio, en busca de pólvora para los fusiles tomados en los Inválidos, la multitud asalta la **Bastilla**, fortaleza real y prisión de Estado. Solo alberga a siete presos, pero su caída es un símbolo: el pueblo ha doblegado al rey."),
                .heading("La noche del 4 de agosto"),
                .paragraph("En el campo, un rumor de conspiración aristocrática desencadena el **Gran Miedo**: campesinos armados asaltan los castillos y queman los registros donde constan los derechos señoriales. Para devolver la calma, la Asamblea vota, en la noche del 4 de agosto, la ==abolición de los privilegios==: fin de los derechos feudales, del diezmo y de la venalidad de los cargos, e igualdad de todos ante los impuestos y los empleos."),
                .callout(
                    title: "Declaración de los Derechos del Hombre y del Ciudadano",
                    text: "Aprobada el 26 de agosto de 1789, establece en diecisiete artículos los principios del nuevo régimen. Artículo 1: «Los hombres nacen y permanecen libres e iguales en derechos». Artículo 3: la soberanía reside en **la nación**. Artículo 16: no hay constitución sin separación de poderes.",
                    tone: .definition
                ),
                .paragraph("La Declaración es un texto universal —habla del hombre, no del francés—, y por eso tuvo tanta influencia fuera de Francia. Pero también tiene sus puntos ciegos: no dice nada de las mujeres y no cuestiona la esclavitud en las colonias. En 1791, Olympe de Gouges le responde con una *Declaración de los Derechos de la Mujer y de la Ciudadana*."),
                .figure(.split(
                    title: "Dos fuentes del poder",
                    left: DemoColumn(title: "Antiguo Régimen", items: ["Monarquía de derecho divino", "Sociedad estamental", "Privilegios", "El rey hace la ley", "Súbditos"]),
                    right: DemoColumn(title: "Principios de 1789", items: ["Soberanía nacional", "Igualdad de derechos", "Una ley común para todos", "Separación de poderes", "Ciudadanos"])
                )),
                .paragraph("La comparación resume lo que cambió en 1789: el poder ya no viene de Dios, sino de la nación, y la ley ya no es la voluntad de uno solo, sino ==la expresión de la voluntad general==. El rey sigue en su puesto, pero ya no es más que el primer funcionario de un Estado cuya soberanía ha dejado de poseer."),
                .heading("La monarquía constitucional"),
                .paragraph("De 1789 a 1791, la Asamblea Constituyente rehace Francia. Crea los **departamentos** (1790), nacionaliza los bienes del clero para pagar la deuda e impone al clero una **Constitución civil** que convierte a los sacerdotes en funcionarios elegidos. La Constitución de 1791 instaura una monarquía constitucional: el rey conserva el poder ejecutivo y un derecho de veto suspensivo; una Asamblea Legislativa vota las leyes."),
                .callout(
                    title: "El sufragio censitario",
                    text: "En 1791 solo votan los **ciudadanos activos**: los hombres mayores de 25 años que pagan un impuesto equivalente, como mínimo, a tres jornadas de trabajo, es decir, unos 4,3 millones de franceses. Los demás son ciudadanos «pasivos»: iguales en derechos, pero no en derechos políticos.",
                    tone: .warning
                ),
                .paragraph("Este compromiso descansa en la buena fe del rey, y el rey no la tiene. En la noche del 20 al 21 de junio de 1791, Luis XVI huye con su familia hacia la frontera del este; es reconocido y detenido en **Varennes**. El vínculo de confianza se rompe: para una parte de los parisinos, un rey que huye de su nación ya no puede representarla."),
            ]),
            DemoChapter(title: "La República y el Terror (1792–1794)", blocks: [
                .paragraph("En abril de 1792, Francia declara la guerra a Austria. Los revolucionarios esperan exportar la libertad; el rey espera en secreto la derrota, que lo restauraría. La guerra va a ==radicalizar la Revolución==: derrotas, traiciones reales o supuestas, levantamientos internos y la convicción de que hay que vencer a toda costa."),
                .heading("La caída de la monarquía"),
                .paragraph("El 10 de agosto de 1792, los sans-culottes parisinos y los federados llegados de provincias asaltan el palacio de las Tullerías. El rey es suspendido y luego encarcelado. Una nueva asamblea, la **Convención**, es elegida por primera vez por **sufragio universal masculino**. El 20 de septiembre, el ejército francés detiene a los prusianos en Valmy; el 21, la Convención abole la monarquía. Ha nacido la República."),
                .keyFigure(value: "21 ene. 1793", label: "Luis XVI, juzgado por la Convención y declarado culpable de traición, es guillotinado en la plaza de la Revolución"),
                .paragraph("La ejecución del rey convierte a Francia en enemiga de todas las monarquías de Europa: Inglaterra, España y las Provincias Unidas se suman a la coalición. Para reclutar soldados, la Convención decreta una leva de 300 000 hombres, y el oeste se subleva: es el comienzo de la **guerra de la Vendée**, que causará unos doscientos mil muertos en ambos bandos."),
                .figure(.split(
                    title: "Dos bandos en la Convención",
                    left: DemoColumn(title: "Girondinos", items: ["Brissot, Vergniaud", "Apoyo de las provincias", "Desconfianza hacia París", "Liberalismo económico", "Rechazo de las medidas de excepción"]),
                    right: DemoColumn(title: "Montañeses", items: ["Robespierre, Danton, Marat", "Apoyo de los sans-culottes", "Poder central fuerte", "Control de precios", "Medidas de excepción"])
                )),
                .paragraph("Entre ambos grupos, la **Llanura** —la mayoría de los diputados— inclina las votaciones. Bajo la presión de los sans-culottes, que rodean la Convención el 2 de junio de 1793, los líderes girondinos son detenidos. Desde entonces, los montañeses gobiernan solos, a través del **Comité de Salvación Pública**, cuya figura dominante pasa a ser Robespierre."),
                .heading("El Terror"),
                .callout(
                    title: "El Terror",
                    text: "El gobierno de excepción de 1793–1794, que suspende las libertades para salvar a la República, amenazada por la guerra exterior y la guerra civil. Sus instrumentos: la **ley de sospechosos** (septiembre de 1793), el Tribunal Revolucionario, los representantes en misión y la guillotina.",
                    tone: .definition
                ),
                .paragraph("El Terror es también una política económica y social: el **máximo general** fija el precio de los productos de primera necesidad, la **leva en masa** moviliza a todos los hombres de 18 a 25 años y la Convención abole la esclavitud en las colonias el 4 de febrero de 1794. Impone un calendario republicano que hace empezar el tiempo el 22 de septiembre de 1792, año I de la libertad."),
                .paragraph("El balance humano es grave. Los tribunales dictan unas ==rose|17 000 condenas a muerte==, sin contar las ejecuciones sumarias y las matanzas de la guerra civil. En contra de una idea muy extendida, las víctimas no son sobre todo nobles: son en su mayoría gente del pueblo, sospechosa de rebelión, de fraude o de tibieza."),
                .bars(title: "Condenados a muerte durante el Terror, según su origen social", unit: "%", bars: [
                    DemoBar(label: "Obreros, artesanos", value: 31),
                    DemoBar(label: "Campesinos", value: 28),
                    DemoBar(label: "Burguesía", value: 25),
                    DemoBar(label: "Nobleza", value: 8.5),
                    DemoBar(label: "Clero", value: 6.5),
                ]),
                .paragraph("Estas cifras, establecidas por el historiador Donald Greer en 1935, muestran que el Terror golpea primero allí donde la República se siente amenazada —la Vendée, Lyon, Marsella, Tolón— y, por tanto, allí donde vive la mayoría de la gente. En la primavera de 1794, las victorias militares hacen menos justificable la excepción; pero la ley del 22 de pradial (junio de 1794) acelera todavía más los juicios: es el **Gran Terror**."),
                .callout(
                    title: "El 9 de termidor",
                    text: "El 27 de julio de 1794 (9 de termidor del año II), unos diputados que temen por su propia cabeza hacen detener a Robespierre y a sus allegados. Son guillotinados al día siguiente. El Terror termina, no porque sus adversarios lo hayan vencido desde fuera, sino porque ==sus propios actores== se volvieron contra él.",
                    tone: .insight
                ),
            ]),
            DemoChapter(title: "Del Directorio a Bonaparte (1795–1799), y lo que queda de todo ello", blocks: [
                .paragraph("Tras Termidor, los republicanos moderados quieren ==poner fin a la Revolución==: ni vuelta del rey ni vuelta del Terror. La Constitución del año III (1795) está pensada para impedir a la vez la dictadura de un hombre y la de una asamblea."),
                .heading("Un régimen frágil"),
                .paragraph("El poder ejecutivo se confía a cinco **directores**, y el poder legislativo, a dos consejos: el de los Quinientos, que propone las leyes, y el de los Ancianos, que las vota. El sufragio vuelve a ser censitario. El régimen queda atrapado entre los monárquicos, que ganan las elecciones de 1797, y los neojacobinos, que ganan las de 1798: cada vez, el Directorio anula el resultado mediante un golpe de fuerza y se apoya cada vez más en el ejército."),
                .table(title: "Los regímenes de la década", headers: ["Régimen", "Fechas", "Quién gobierna", "Sufragio"], rows: [
                    ["Monarquía absoluta", "hasta 1789", "El rey solo", "Ninguno"],
                    ["Monarquía constitucional", "1791–1792", "El rey y la Asamblea Legislativa", "Censitario"],
                    ["República: la Convención", "1792–1795", "La Convención, el Comité de Salvación Pública", "Universal masculino"],
                    ["República: el Directorio", "1795–1799", "Cinco directores, dos consejos", "Censitario"],
                    ["Consulado", "desde 1799", "Bonaparte, primer cónsul", "Plebiscitos"],
                ]),
                .paragraph("La tabla se lee como una curva: el poder se amplía hasta 1793 y luego se estrecha. Y, en cada etapa, el sufragio sigue el mismo movimiento. La Revolución estableció el principio de la soberanía nacional, pero nunca dejó de discutir sobre ==quién tiene derecho a hablar en nombre de la nación==."),
                .paragraph("Mientras tanto, un joven general se impone. Napoleón Bonaparte aplastó una insurrección monárquica en París en 1795, conquistó Italia en 1796–1797 y después dirigió la expedición a Egipto. De vuelta en Francia, rodeado del prestigio de sus victorias, se alía con Sieyès, ahora director, que busca «una espada» para reformar la Constitución."),
                .callout(
                    title: "El golpe de Estado del 18 de brumario",
                    text: "El 9 de noviembre de 1799 (18 de brumario del año VIII), Bonaparte y Sieyès derriban el Directorio; al día siguiente, los granaderos dispersan a los Quinientos. El Consulado que le sigue concentra el poder en manos del primer cónsul. Tradicionalmente se fecha en este día **el fin de la Revolución**.",
                    tone: .example
                ),
                .heading("Lo que queda de la Revolución"),
                .paragraph("Bonaparte conserva gran parte de la herencia: el Código Civil de 1804 consagra la igualdad ante la ley, la propiedad y el fin del feudalismo. Borra otras partes: restablece la esclavitud en 1802 y sustituye la soberanía de las asambleas por la suya propia. La herencia revolucionaria se lee, pues, en dos columnas: principios adquiridos para siempre y luchas que durarán todo el siglo XIX."),
                .list([
                    "Logros duraderos: fin de los privilegios y de la sociedad estamental, igualdad ante la ley y los impuestos, departamentos, sistema métrico, registro civil laico",
                    "Principios establecidos: soberanía nacional, derechos humanos, separación de poderes",
                    "Luchas inacabadas: sufragio universal (1848), abolición definitiva de la esclavitud (1848), derecho de voto de las mujeres (1944)",
                ]),
                .paragraph("Las fechas de la última línea muestran que hizo falta siglo y medio para cumplir todas las promesas de 1789. Es este desfase entre ==los principios proclamados y su aplicación== lo que hace de la Revolución un momento fundacional: dio a las generaciones siguientes las palabras con las que reclamar lo que ella misma no había concedido."),
                .figure(.flow(title: "La dinámica de la década", steps: ["1789: la nación asume la soberanía", "1791: compromiso con el rey", "1792: guerra y República", "1793–1794: el Terror", "1795–1799: estabilización y, después, el ejército"])),
                .paragraph("Este esquema es la columna vertebral de una redacción sobre el periodo. Cada etapa responde al fracaso de la anterior: el compromiso de 1791 fracasa por culpa del rey, la República moderada por culpa de la guerra, el Terror por sus excesos y el Directorio por falta de legitimidad. Explicar ==por qué cada etapa conduce a la siguiente== es comprender la Revolución en lugar de recitarla."),
                .callout(
                    title: "El error clásico",
                    text: "Escribir que la Revolución abolió la monarquía en 1789. En 1789 abolió el **absolutismo** y los privilegios; la monarquía constitucional duró hasta el 10 de agosto de 1792, y la República no se proclamó hasta septiembre de 1792.",
                    tone: .warning
                ),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "¿Cuáles son los tres estamentos de la sociedad del Antiguo Régimen?",
                back: "El clero y la nobleza, estamentos privilegiados (en torno al 2 % de la población), y el tercer estado (en torno al 98 %), que paga la mayor parte de los impuestos.",
                figure: .split(
                    title: "Una sociedad estamental",
                    left: DemoColumn(title: "Privilegiados", items: ["Clero", "Nobleza"]),
                    right: DemoColumn(title: "No privilegiados", items: ["Tercer estado"])
                ),
                chapter: 0
            ),
            DemoCard(
                kind: .choice,
                front: "¿Qué vota la Asamblea en la noche del 4 de agosto de 1789?",
                back: "La abolición de los privilegios: fin de los derechos feudales, del diezmo y de la venalidad de los cargos, e igualdad ante los impuestos.",
                choices: ["La Declaración de los Derechos del Hombre", "La abolición de los privilegios", "La abolición de la monarquía", "La Constitución civil del clero"],
                answerIndex: 1,
                chapter: 1
            ),
            DemoCard(
                kind: .cloze,
                front: "Luis XVI es detenido en … en junio de 1791, cuando huía hacia la frontera del este.",
                back: "Varennes",
                chapter: 1
            ),
            DemoCard(kind: .basic, front: "¿Por qué es decisiva en 1789 la cuestión del voto por estamento o por cabeza?", back: "Por estamento, el clero y la nobleza ganan siempre por dos votos contra uno. Por cabeza, el tercer estado, que tiene tantos diputados como los otros dos estamentos juntos, puede obtener la mayoría con unos pocos aliados.", hint: "Cuenta los votos en cada caso.", chapter: 0),
            DemoCard(kind: .cloze, front: "El 17 de junio de 1789, los diputados del tercer estado se proclaman … .", back: "Asamblea Nacional", chapter: 0),
            DemoCard(kind: .choice, front: "¿Cuándo se proclama la República en Francia?", back: "En septiembre de 1792: la Convención abole la monarquía el 21 de septiembre, al día siguiente de Valmy.", choices: ["Julio de 1789", "Junio de 1791", "Septiembre de 1792", "Julio de 1794"], answerIndex: 2, chapter: 2),
            DemoCard(kind: .basic, front: "¿Qué es el Terror?", back: "El gobierno de excepción de 1793–1794 que suspende las libertades para salvar a la República en guerra: ley de sospechosos, Tribunal Revolucionario, unas 17 000 condenas a muerte. Termina con la caída de Robespierre el 9 de termidor del año II (27 de julio de 1794).", chapter: 2),
            DemoCard(kind: .cloze, front: "El artículo 1 de la Declaración de 1789 afirma: «Los hombres nacen y permanecen libres e … en derechos».", back: "iguales", chapter: 1),
            DemoCard(kind: .choice, front: "¿Qué grupo social cuenta con más condenados a muerte durante el Terror?", back: "La gente del pueblo: obreros, artesanos y campesinos suman casi seis de cada diez condenados; los nobles, en torno al 8 %.", choices: ["La nobleza", "El clero", "Los obreros, artesanos y campesinos", "Los oficiales del ejército"], answerIndex: 2, chapter: 2),
            DemoCard(kind: .basic, front: "¿Qué es el sufragio censitario?", back: "Un derecho de voto reservado a quienes pagan una determinada cantidad de impuestos (el censo). En 1791 solo votan los ciudadanos «activos», unos 4,3 millones de hombres.", chapter: 1),
            DemoCard(kind: .cloze, front: "El golpe de Estado del 18 de … del año VIII (9 de noviembre de 1799) lleva a Bonaparte al poder.", back: "brumario", chapter: 3),
            DemoCard(kind: .choice, front: "¿Cuántos directores ejercen el poder ejecutivo durante el Directorio?", back: "Cinco, frente a dos consejos: el de los Quinientos y el de los Ancianos.", choices: ["Uno", "Tres", "Cinco", "Siete"], answerIndex: 2, chapter: 3),
        ]
    )

    // MARK: Biología: genética y ADN

    private static let geneticsES = OnboardingDemoCourse(
        id: "debug-genetics",
        emoji: "🧬",
        subject: "SVT",
        title: "Genética y ADN",
        summary: "La molécula de ADN, su replicación, el paso del gen a la proteína, las mutaciones que crean la diversidad y las leyes de Mendel que describen su transmisión.",
        accentIndex: 4,
        chapters: [
            DemoChapter(title: "La molécula de ADN", blocks: [
                .paragraph("Cada célula de tu cuerpo contiene en su núcleo unos ==dos metros de ADN==, plegados en unos pocos micrómetros. Esta molécula lleva la información que permite construir y hacer funcionar a un ser vivo, y la transmite de una célula a sus hijas y de los padres a sus hijos."),
                .heading("Una doble hélice"),
                .paragraph("El ADN —el ácido desoxirribonucleico— es una larga cadena de **nucleótidos**. Cada nucleótido está formado por tres elementos: un grupo fosfato, un azúcar, la desoxirribosa, y una **base nitrogenada**. Existen cuatro bases: la adenina (A), la timina (T), la guanina (G) y la citosina (C). El orden de estas bases a lo largo de la molécula es lo que constituye la información genética."),
                .callout(
                    title: "Complementariedad de las bases",
                    text: "Las dos hebras del ADN están unidas por sus bases, que siempre se emparejan del mismo modo: **A con T** (dos puentes de hidrógeno) y **G con C** (tres puentes de hidrógeno). Así pues, conocer una hebra es conocer la otra.",
                    tone: .definition
                ),
                .paragraph("Esta regla se había detectado antes de que se comprendiera la estructura: en 1950, Erwin Chargaff demuestra que en el ADN de todas las especies hay tanta adenina como timina, y tanta guanina como citosina. En cambio, las proporciones de A y de G varían de una especie a otra."),
                .formula("A = T \\;\\;\\;\\; G = C \\;\\;\\;\\; A + G = T + C", caption: "Las reglas de Chargaff, en proporciones de bases: una consecuencia del emparejamiento"),
                .paragraph("En 1953, James Watson y Francis Crick proponen el modelo de la **doble hélice**, basándose en las imágenes de difracción de rayos X obtenidas por Rosalind Franklin. Las dos hebras se enrollan una alrededor de la otra como una escalera retorcida: los largueros son las cadenas de azúcares y fosfatos, y los peldaños, los pares de bases. Las dos hebras son ==antiparalelas==: discurren en sentidos opuestos."),
                .heading("Genes, cromosomas, genoma"),
                .paragraph("En una célula humana, el ADN está dividido en **46 cromosomas**, 23 heredados de la madre y 23 del padre. Un **gen** es un fragmento de ADN que lleva la información para fabricar una proteína; ocupa un lugar concreto en un cromosoma, su **locus**. El conjunto del ADN de un organismo es su **genoma**: en el ser humano, unos 3200 millones de pares de bases por cada juego de cromosomas."),
                .bars(title: "Número de genes que codifican proteínas (órdenes de magnitud)", unit: "miles", bars: [
                    DemoBar(label: "Bacteria E. coli", value: 4.3),
                    DemoBar(label: "Levadura", value: 6),
                    DemoBar(label: "Drosófila", value: 14),
                    DemoBar(label: "Gusano C. elegans", value: 20),
                    DemoBar(label: "Ser humano", value: 20),
                ]),
                .paragraph("El gráfico guarda una sorpresa: un gusano de un milímetro tiene aproximadamente tantos genes como nosotros. La complejidad de un organismo no depende, por tanto, del número de sus genes, sino de ==la forma en que se utilizan==: cuándo, dónde y cuánto. En el ser humano, además, los genes que codifican proteínas solo ocupan en torno al 1,5 % del genoma."),
                .table(title: "El vocabulario básico", headers: ["Término", "Definición"], rows: [
                    ["Gen", "Fragmento de ADN que codifica una proteína"],
                    ["Alelo", "Una versión de un gen, que se diferencia por su secuencia"],
                    ["Locus", "La posición de un gen en un cromosoma"],
                    ["Genotipo", "Los alelos que posee un individuo"],
                    ["Fenotipo", "Los caracteres observables que resultan de ellos"],
                ]),
                .paragraph("Estos cinco términos aparecen en todo el resto del curso, y cada uno designa un nivel distinto: la molécula, su variante, su posición, lo que posee un individuo y lo que se ve de él. Un fenotipo depende del genotipo, pero también del ambiente: dos gemelos idénticos tienen el mismo genotipo, pero no necesariamente la misma estatura."),
            ]),
            DemoChapter(title: "La replicación del ADN", blocks: [
                .paragraph("Antes de cada división, una célula debe copiar sus 3200 millones de pares de bases —dos veces, ya que tiene dos juegos— para entregar un ejemplar completo a cada una de sus hijas. Esta copia se llama **replicación**, y su fidelidad es ==casi perfecta==."),
                .heading("Un mecanismo semiconservativo"),
                .paragraph("El principio se deriva directamente de la complementariedad. Las dos hebras de la doble hélice se separan, como una cremallera que se abre; cada hebra sirve entonces de **molde** para fabricar una hebra nueva, colocando frente a cada base su base complementaria. Se obtienen dos moléculas idénticas a la molécula de partida."),
                .figure(.flow(title: "Las etapas de la replicación", steps: ["La helicasa abre la doble hélice", "Cada hebra sirve de molde", "La ADN polimerasa añade los nucleótidos complementarios", "Dos moléculas idénticas, cada una con una hebra antigua y una nueva"])),
                .paragraph("Cada molécula hija contiene, por tanto, una hebra heredada de la molécula madre y una hebra recién sintetizada: se dice que la replicación es **semiconservativa**. La ADN polimerasa solo trabaja en un sentido, alargando la hebra nueva desde su extremo 5′ hacia su extremo 3′, y la replicación comienza en muchos puntos a la vez a lo largo de cada cromosoma."),
                .callout(
                    title: "El experimento de Meselson y Stahl (1958)",
                    text: "Unas bacterias cultivadas en nitrógeno pesado (¹⁵N) se trasladan a nitrógeno ligero (¹⁴N). Tras una división, todo su ADN tiene densidad **intermedia**; tras dos, la mitad es intermedio y la otra mitad, ligero. Solo el modelo semiconservativo predice exactamente este resultado.",
                    tone: .example
                ),
                .paragraph("Este experimento es un modelo de método científico: había tres hipótesis posibles —conservativa, semiconservativa y dispersiva—, cada una predecía un resultado distinto y bastó una sola medida para decidir. Recuerda el razonamiento tanto como la conclusión: es lo que te pedirán que apliques en el examen."),
                .keyFigure(value: "1 / 10⁹", label: "el orden de magnitud de la tasa de error por nucleótido copiado, una vez superados los sistemas de corrección"),
                .paragraph("Un error por cada mil millones equivale más o menos a una errata por cada mil libros copiados a mano. Esta tasa extraordinaria se consigue en dos tiempos: la ADN polimerasa relee lo que acaba de escribir y corrige sus propios errores, y después otras enzimas pasan detrás de ella para reparar lo que se le ha escapado. Pero un error por cada mil millones, en seis mil millones de bases, sigue siendo ==unos pocos errores en cada división==."),
                .callout(
                    title: "No confundir",
                    text: "La replicación copia **ADN en ADN**, en el núcleo, antes de una división. La transcripción, que veremos en el capítulo siguiente, copia **un gen en ARN**, en cualquier momento de la vida de la célula. El mismo principio de complementariedad, dos funciones distintas.",
                    tone: .warning
                ),
                .list([
                    "Replicación: antes de cada división, durante la fase S del ciclo celular",
                    "Semiconservativa: cada molécula hija conserva una hebra de la molécula madre",
                    "Enzima clave: la ADN polimerasa, que ensambla y revisa",
                    "Fidelidad: aproximadamente un error por cada mil millones de nucleótidos",
                ]),
                .paragraph("Estos errores residuales no son solo un defecto. Son ellos, acumulados a lo largo de las generaciones, los que producen nuevos alelos y, por tanto, la diversidad sobre la que actúa la evolución. Un sistema de copia perfecto daría especies inmóviles: es ==la imperfección de la replicación== lo que hace posible la evolución."),
            ]),
            DemoChapter(title: "Del gen a la proteína", blocks: [
                .paragraph("El ADN permanece en el núcleo, pero las proteínas se fabrican en el citoplasma. Hace falta, pues, un intermediario que copie la información y la transporte: el **ARN mensajero**. La expresión de un gen se realiza en dos etapas: la ==menthe|transcripción== y después la ==bleu|traducción==."),
                .figure(.flow(title: "La expresión de un gen", steps: ["ADN (el gen, en el núcleo)", "Transcripción: ARN mensajero", "El ARNm sale del núcleo", "Traducción por los ribosomas", "Proteína"])),
                .paragraph("La **transcripción** tiene lugar en el núcleo. La ARN polimerasa abre la doble hélice a la altura de un gen y fabrica una copia de una sola de las dos hebras, la hebra molde, por complementariedad. La molécula obtenida es un ARN: se parece al ADN, con tres diferencias."),
                .figure(.split(
                    title: "ADN y ARN",
                    left: DemoColumn(title: "ADN", items: ["Dos hebras", "Azúcar: desoxirribosa", "Bases A, T, G, C", "Muy largo, en el núcleo", "Estable, se conserva"]),
                    right: DemoColumn(title: "ARN mensajero", items: ["Una sola hebra", "Azúcar: ribosa", "Bases A, U, G, C", "Corto: un gen", "Efímero, se destruye tras su uso"])
                )),
                .paragraph("La diferencia más útil en los ejercicios es la de las bases: en el ARN, **el uracilo (U) sustituye a la timina**. Frente a una A de la hebra molde, la ARN polimerasa coloca, por tanto, una U. Así, la secuencia del ARNm es idéntica a la de la hebra no transcrita del ADN, llamada hebra codificante, salvo por las T, que en él se convierten en U."),
                .heading("El código genético"),
                .paragraph("La **traducción** tiene lugar en el citoplasma, en los ribosomas. Allí, el ARNm se lee en grupos de tres nucleótidos, los **codones**; cada codón corresponde a un aminoácido, y los aminoácidos se encadenan para formar la proteína. La correspondencia entre codones y aminoácidos es el **código genético**."),
                .formula("4^3 = 64 \\text{ codones} \\;\\; \\text{para} \\;\\; 20 \\text{ aminoácidos}", caption: "Cuatro bases, tres posiciones: más que suficiente para veinte aminoácidos"),
                .paragraph("Hay, por tanto, más codones que aminoácidos: 61 codones designan un aminoácido y 3 son codones de **terminación** que ponen fin a la traducción. Varios codones pueden codificar el mismo aminoácido —se dice que el código es **degenerado**—, pero un codón nunca codifica más que un único aminoácido. La traducción comienza siempre en el codón AUG, que codifica la metionina."),
                .table(title: "Algunos codones del ARNm", headers: ["Codón", "Aminoácido"], rows: [
                    ["AUG", "Metionina (codón de inicio)"],
                    ["GCA", "Alanina"],
                    ["UGG", "Triptófano"],
                    ["GAG", "Ácido glutámico"],
                    ["GUG", "Valina"],
                    ["UAA, UAG, UGA", "Terminación"],
                ]),
                .paragraph("La tabla ya muestra la degeneración: GAG y GAA codifican ambos el ácido glutámico, y veremos en el último capítulo que un solo cambio de letra —GAG convertido en GUG— basta para sustituir este aminoácido por una valina. Para traducir un ARN mensajero se procede siempre en el mismo orden: localizar el codón AUG, dividir en tripletes y leer la tabla hasta el primer codón de terminación."),
                .callout(
                    title: "Ejemplo completo",
                    text: "Hebra codificante del ADN: 5′-ATG GCA TGG-3′. ARN mensajero: 5′-AUG GCA UGG-3′ (se sustituye T por U). Proteína: **Met – Ala – Trp**. Se lee siempre codón a codón, a partir del codón de inicio, sin solapamiento.",
                    tone: .example
                ),
                .paragraph("El código genético es ==universal==: salvo raras excepciones, el mismo codón designa el mismo aminoácido en una bacteria, un roble y un ser humano. Es un argumento sólido a favor de un origen común de todos los seres vivos, y es lo que permite hacer que unas bacterias fabriquen insulina humana simplemente dándoles el gen."),
            ]),
            DemoChapter(title: "Mutaciones y herencia", blocks: [
                .paragraph("Una **mutación** es una modificación de la secuencia del ADN. Puede ser espontánea —un error de replicación no corregido— o estar provocada por un **agente mutágeno**: rayos UV, rayos X, algunas sustancias químicas como las del humo del tabaco. No todas las mutaciones son iguales, y su efecto depende de ==el lugar donde se producen==."),
                .heading("Los tipos de mutaciones"),
                .table(title: "Mutaciones puntuales y sus consecuencias", headers: ["Tipo", "Qué cambia", "Efecto sobre la proteína"], rows: [
                    ["Sustitución silenciosa", "Una base, pero el mismo aminoácido", "Ninguno, gracias a la degeneración del código"],
                    ["Sustitución de cambio de sentido", "Una base, un aminoácido distinto", "Variable: de nulo a grave"],
                    ["Sustitución sin sentido", "Un codón se convierte en codón de terminación", "Proteína truncada, a menudo inactiva"],
                    ["Inserción o deleción", "Una base de más o de menos", "Desplazamiento del marco de lectura: proteína muy alterada"],
                ]),
                .paragraph("La anemia falciforme es el ejemplo más estudiado. En el gen de la hemoglobina, el sexto codón pasa de GAG a GTG: cambia una sola base, y el ácido glutámico se sustituye por una valina. Esta hemoglobina anómala se polimeriza cuando le falta oxígeno y deforma los glóbulos rojos en forma de hoz."),
                .callout(
                    title: "Una mutación, dos efectos",
                    text: "Las personas que portan dos alelos mutados están enfermas; las que solo portan uno están sanas y, además, **mejor protegidas contra la malaria**. Por eso el alelo es frecuente en el África subsahariana: allí donde hay malaria, favorece a sus portadores.",
                    tone: .insight
                ),
                .paragraph("Solo las mutaciones que afectan a las células reproductoras —las **mutaciones germinales**— se transmiten a la descendencia. Una mutación en una célula de la piel, llamada **somática**, solo afecta al individuo y a las células procedentes de la que ha mutado: puede provocar un cáncer, pero no una enfermedad hereditaria."),
                .heading("Las leyes de Mendel"),
                .paragraph("En 1865, el monje Gregor Mendel publica los resultados de ocho años de cruces de guisantes. Cruza líneas puras de semillas lisas con líneas puras de semillas rugosas: toda la primera generación (F1) tiene semillas lisas. Después cruza estos híbridos entre sí: en la segunda generación (F2) reaparece el carácter rugoso, en una proporción notablemente estable."),
                .bars(title: "Las semillas de Mendel en la segunda generación", unit: "semillas", bars: [
                    DemoBar(label: "Lisas", value: 5474),
                    DemoBar(label: "Rugosas", value: 1850),
                ]),
                .paragraph("La proporción es $5474 / 1850 \\approx 2{,}96$, es decir, casi exactamente **tres a uno**. Mendel lo explica con una hipótesis audaz para su época: cada individuo posee dos «factores» para un carácter —nosotros decimos dos ==alelos==—, transmite solo uno a cada gameto, y el alelo liso (R) es **dominante** sobre el alelo rugoso (r), que es **recesivo**."),
                .table(title: "Cuadro de Punnett: Rr × Rr", headers: ["", "Gameto R", "Gameto r"], rows: [
                    ["Gameto R", "RR (liso)", "Rr (liso)"],
                    ["Gameto r", "Rr (liso)", "rr (rugoso)"],
                ]),
                .paragraph("Cada casilla tiene una probabilidad de un cuarto. Se obtienen los genotipos RR, Rr y rr en las proporciones 1/4, 1/2 y 1/4 y, por tanto, los fenotipos liso y rugoso en las proporciones 3/4 y 1/4. Solo los individuos **homocigotos** rr expresan el carácter recesivo; los **heterocigotos** Rr lo portan sin manifestarlo."),
                .formula("P(rr) = \\frac{1}{2} \\times \\frac{1}{2} = \\frac{1}{4}", caption: "Cada progenitor heterocigoto transmite r con una probabilidad de 1/2, con independencia del otro"),
                .paragraph("El mismo razonamiento sirve para las enfermedades humanas recesivas, como la **fibrosis quística**: dos progenitores portadores sanos, heterocigotos, tienen en cada embarazo una probabilidad de 1/4 de tener un hijo enfermo. «En cada embarazo» es esencial: ==el azar no tiene memoria==, y haber tenido un hijo enfermo no protege al siguiente."),
                .timeline(title: "Los grandes hitos de la genética", events: [
                    DemoEvent(date: "1865", label: "Mendel publica sus leyes de la herencia"),
                    DemoEvent(date: "1944", label: "Avery demuestra que el ADN lleva la información hereditaria"),
                    DemoEvent(date: "1953", label: "Watson, Crick y Franklin: la doble hélice"),
                    DemoEvent(date: "1966", label: "El código genético, completamente descifrado"),
                    DemoEvent(date: "2003", label: "Secuencia completa del genoma humano"),
                    DemoEvent(date: "2012", label: "Charpentier y Doudna: la herramienta CRISPR-Cas9"),
                ]),
                .paragraph("Ciento cincuenta años separan los guisantes de Mendel de las tijeras moleculares que hoy permiten modificar un gen concreto. Cada etapa respondió a una pregunta que había dejado abierta la anterior: qué se transmite, de qué está hecho, cómo se copia, cómo se lee y, ahora, ==cómo corregirlo==."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "¿Cómo se emparejan las bases del ADN entre las dos hebras?",
                back: "La adenina con la timina (A–T, dos puentes de hidrógeno) y la guanina con la citosina (G–C, tres puentes de hidrógeno). Por tanto, una hebra determina por completo la otra.",
                figure: .split(
                    title: "Complementariedad",
                    left: DemoColumn(title: "Hebra 1", items: ["A", "G", "T", "C"]),
                    right: DemoColumn(title: "Hebra 2", items: ["T", "C", "A", "G"])
                ),
                chapter: 0
            ),
            DemoCard(
                kind: .choice,
                front: "¿Cuál es el ARN mensajero transcrito a partir de la hebra codificante 5′-ATG GCA TGG-3′?",
                back: "5′-AUG GCA UGG-3′: el ARNm tiene la secuencia de la hebra codificante, con U en lugar de T. Se traduce como Met – Ala – Trp.",
                choices: ["5′-UAC CGU ACC-3′", "5′-AUG GCA UGG-3′", "5′-TAC CGT ACC-3′", "5′-ATG GCA TGG-3′"],
                answerIndex: 1,
                chapter: 2
            ),
            DemoCard(
                kind: .cloze,
                front: "Se dice que la replicación del ADN es …, porque cada molécula hija conserva una hebra de la molécula madre.",
                back: "semiconservativa",
                chapter: 1
            ),
            DemoCard(kind: .basic, front: "¿Cuál es la diferencia entre un gen y un alelo?", back: "Un gen es un fragmento de ADN, en un locus determinado, que codifica una proteína. Un alelo es una de las versiones de ese gen, que se diferencia de las demás por su secuencia.", chapter: 0),
            DemoCard(kind: .choice, front: "¿Cuántos codones distintos existen?", back: "64 = 4³: cuatro bases posibles en cada una de las tres posiciones. 61 codifican un aminoácido y 3 son codones de terminación.", choices: ["20", "46", "61", "64"], answerIndex: 3, chapter: 2),
            DemoCard(kind: .cloze, front: "En el ARN, la timina se sustituye por el … .", back: "uracilo", chapter: 2),
            DemoCard(kind: .basic, front: "¿Qué demuestra el experimento de Meselson y Stahl?", back: "Que la replicación es semiconservativa: tras una división en medio con ¹⁴N, todo el ADN tiene densidad intermedia; tras dos, la mitad es intermedio y la otra mitad, ligero.", hint: "Piensa en las densidades tras una y dos divisiones.", chapter: 1),
            DemoCard(kind: .choice, front: "¿Qué mutación desplaza el marco de lectura?", back: "La inserción o la deleción de una base: todos los codones situados a continuación se modifican, y la proteína queda muy alterada.", choices: ["Una sustitución silenciosa", "Una sustitución de cambio de sentido", "Una deleción de una base", "Una sustitución sin sentido"], answerIndex: 2, chapter: 3),
            DemoCard(kind: .cloze, front: "Dos progenitores heterocigotos Rr tienen, en cada nacimiento, una probabilidad de … de tener un hijo rr.", back: "1/4", chapter: 3),
            DemoCard(kind: .basic, front: "¿Por qué el alelo de la anemia falciforme es frecuente allí donde hay malaria?", back: "Porque los heterocigotos, portadores de un solo alelo mutado, están sanos y mejor protegidos contra la malaria: la selección natural mantiene el alelo.", chapter: 3),
            DemoCard(kind: .cloze, front: "Según las reglas de Chargaff, en un ADN de doble hebra, el porcentaje de guanina es igual al de … .", back: "citosina", chapter: 0),
            DemoCard(kind: .choice, front: "¿Dónde tiene lugar la traducción?", back: "En el citoplasma, en los ribosomas, que leen el ARN mensajero codón a codón.", choices: ["En el núcleo", "En los ribosomas del citoplasma", "En las mitocondrias", "En la membrana plasmática"], answerIndex: 1, chapter: 2),
        ]
    )

    // MARK: Matemáticas: la probabilidad

    private static let probabilityES = OnboardingDemoCourse(
        id: "debug-probability",
        emoji: "🎲",
        subject: "Mathématiques",
        title: "Probabilidad",
        summary: "El vocabulario de los sucesos, la probabilidad condicionada y los diagramas de árbol, la independencia y, después, las variables aleatorias, la esperanza y la distribución binomial.",
        accentIndex: 0,
        chapters: [
            DemoChapter(title: "El lenguaje de la probabilidad", blocks: [
                .paragraph("La probabilidad mide ==el grado de certeza== de un suceso cuyo resultado no se conoce de antemano: el lanzamiento de un dado, un sorteo, el resultado de una prueba. No predice lo que va a ocurrir; dice, con precisión, hasta qué punto es verosímil cada resultado."),
                .heading("Experimento, espacio muestral, suceso"),
                .paragraph("Un **experimento aleatorio** es un experimento del que se conocen todos los resultados posibles, sin poder prever cuál se producirá. Cada resultado es un **suceso elemental**; el conjunto de los resultados es el **espacio muestral**, representado por $\\Omega$. Para un dado de seis caras, $\\Omega$ = {1, 2, 3, 4, 5, 6}."),
                .callout(
                    title: "Suceso",
                    text: "Un **suceso** es un subconjunto del espacio muestral, es decir, un conjunto de resultados. «Obtener un número par» es el suceso $A$ = {2, 4, 6}. Se verifica si el resultado obtenido pertenece a él.",
                    tone: .definition
                ),
                .paragraph("Los sucesos se combinan como conjuntos. La **intersección** $A \\cap B$ («A y B») se verifica cuando se verifican ambos; la **unión** $A \\cup B$ («A o B»), cuando se verifica al menos uno de los dos; el **contrario** $Ā$, cuando no se verifica $A$. Dos sucesos son **incompatibles** si no pueden producirse a la vez: $A \\cap B = \\emptyset$."),
                .heading("Calcular una probabilidad"),
                .paragraph("Cuando todos los resultados tienen la misma posibilidad de producirse —se habla de **equiprobabilidad**—, la probabilidad de un suceso es el número de casos favorables dividido por el número de casos posibles. Es la regla de Laplace, y solo es válida ==en ese caso==: un dado trucado o una ruleta desigual requieren otro método."),
                .formula("P(A) = \\frac{\\text{número de casos favorables}}{\\text{número de casos posibles}}", caption: "Solo en situación de equiprobabilidad"),
                .paragraph("Lancemos dos dados y fijémonos en la suma. Hay $6 \\times 6 = 36$ parejas equiprobables, pero las sumas no lo son: hay una sola manera de obtener 2 (1 y 1) y seis maneras de obtener 7. El gráfico da, para cada suma, el número de parejas que la producen."),
                .bars(title: "Suma de dos dados: número de parejas de 36", unit: nil, bars: [
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
                .paragraph("Se lee que $P(\\text{suma} = 7) = 6/36 = 1/6$, y $P(\\text{suma} = 2) = 1/36$. El error clásico es razonar sobre las once sumas posibles como si fueran equiprobables, lo que daría 1/11 a cada una. ==Siempre hay que contar sobre resultados equiprobables==, aquí las parejas, y nunca sobre resultados que no lo son."),
                .table(title: "Las propiedades que hay que conocer", headers: ["Propiedad", "Fórmula"], rows: [
                    ["Cotas", "0 ≤ P(A) ≤ 1"],
                    ["Espacio muestral", "P(Ω) = 1"],
                    ["Contrario", "P(Ā) = 1 − P(A)"],
                    ["Unión", "P(A ∪ B) = P(A) + P(B) − P(A ∩ B)"],
                    ["Incompatibles", "P(A ∪ B) = P(A) + P(B)"],
                ]),
                .paragraph("La fórmula de la unión resta $P(A \\cap B)$ porque los resultados comunes se han contado dos veces. Y pasar al contrario suele ser el atajo más eficaz: para «al menos un seis en cuatro lanzamientos», es mucho más sencillo calcular «ningún seis», es decir, $(5/6)^4 \\approx 0{,}48$, y después tomar el complementario: $1 - 0{,}48 \\approx 0{,}52$."),
                .callout(
                    title: "El reflejo del «al menos uno»",
                    text: "En cuanto un enunciado diga «al menos uno», piensa en el contrario: «ninguno». Casi siempre es un solo producto que calcular, en lugar de una larga suma de casos.",
                    tone: .insight
                ),
            ]),
            DemoChapter(title: "Probabilidad condicionada y diagramas de árbol", blocks: [
                .paragraph("Una información nueva cambia las probabilidades. Saber que una prueba ha dado positivo cambia la probabilidad de estar enfermo; saber que el dado ha caído en un número par cambia la de haber sacado un 2. La **probabilidad condicionada** mide la probabilidad de un suceso ==cuando se sabe que otro se ha verificado==."),
                .callout(
                    title: "Probabilidad condicionada",
                    text: "Si $P(A) \\neq 0$, la probabilidad de $B$ condicionada a $A$ es $P(B | A) = \\frac{P(A \\cap B)}{P(A)}$, que algunos manuales escriben también P_A(B). Se restringe el espacio muestral a los resultados de $A$ y se mira qué parte de ellos verifica también $B$.",
                    tone: .definition
                ),
                .paragraph("Ejemplo: se lanza un dado y se sabe que el resultado es par. La probabilidad de que sea un 2 ya no es 1/6, sino $\\frac{1/6}{1/2} = \\frac{1}{3}$: solo quedan tres resultados posibles, 2, 4 y 6. La fórmula también se puede dar la vuelta, y es la forma que se usa en los árboles: $P(A \\cap B) = P(A) \\times P(B | A)$."),
                .heading("El diagrama de árbol"),
                .paragraph("Un **diagrama de árbol** representa un experimento en varias etapas. Cada rama lleva una probabilidad; las ramas que salen de un mismo nudo suman 1; la probabilidad de un camino es el producto de las probabilidades de sus ramas. Y cuando un suceso está al final de varios caminos, se suman."),
                .figure(.flow(title: "Leer un diagrama de árbol", steps: ["Primera etapa: A o Ā", "Segunda etapa: B o B̄, sabida la primera", "Un camino: se multiplican las ramas", "Varios caminos hacia B: se suman"])),
                .paragraph("La última etapa tiene nombre: el **teorema de la probabilidad total**. Si $A$ y $Ā$ dividen el espacio muestral en dos, entonces $B$ se verifica o bien con $A$, o bien con $Ā$, y estos dos casos son incompatibles. Se suman, por tanto, los dos caminos que llevan a $B$."),
                .formula("P(B) = P(A) \\times P(B | A) + P(Ā) \\times P(B | Ā)", caption: "El teorema de la probabilidad total, para una partición en A y Ā"),
                .heading("Una prueba de cribado"),
                .paragraph("Una enfermedad afecta al 1 % de la población. Una prueba la detecta en el 99 % de los enfermos, pero también da positivo en el 2 % de las personas sanas. Una persona da positivo: ¿cuál es la probabilidad de que esté enferma? La intuición responde «99 %». El cálculo responde algo muy distinto. Imaginemos 10 000 personas analizadas."),
                .table(title: "10 000 personas analizadas", headers: ["", "Positivo", "Negativo", "Total"], rows: [
                    ["Enfermas", "99", "1", "100"],
                    ["Sanas", "198", "9 702", "9 900"],
                    ["Total", "297", "9 703", "10 000"],
                ]),
                .paragraph("De los 297 positivos, solo 99 están enfermos. Con el árbol y las fórmulas: $P(+) = 0{,}01 \\times 0{,}99 + 0{,}99 \\times 0{,}02 = 0{,}0297$, y después $P(M | +) = \\frac{0{,}0099}{0{,}0297} = \\frac{1}{3}$. Los falsos positivos, extraídos de una población sana cien veces más numerosa, ==ahogan a los verdaderos positivos==."),
                .keyFigure(value: "33 %", label: "la probabilidad de estar enfermo cuando la prueba da positivo, pese a que la prueba acierta en el 99 % de los enfermos"),
                .paragraph("El resultado depende menos de la calidad de la prueba que de la rareza de la enfermedad. Si afectara al 10 % de la población, la misma prueba daría $P(M | +) = \\frac{0{,}099}{0{,}099 + 0{,}018} \\approx 0{,}85$. Una probabilidad condicionada se calcula siempre ==con la probabilidad de partida==: olvidar la prevalencia es olvidar la primera rama del árbol."),
                .callout(
                    title: "No invertir",
                    text: "$P(+ | M)$ y $P(M | +)$ no son lo mismo: la primera vale 0,99 y la segunda, alrededor de 0,33. Confundir «la probabilidad de dar positivo sabiendo que se está enfermo» con «la probabilidad de estar enfermo sabiendo que se ha dado positivo» es el error más extendido, incluso entre los médicos.",
                    tone: .warning
                ),
                .paragraph("Por eso, un positivo en un cribado masivo siempre se confirma con una segunda prueba, más precisa. El cálculo de una probabilidad «invertida» a partir del árbol recibe el nombre de **teorema de Bayes**, por el pastor inglés que lo enunció en el siglo XVIII."),
            ]),
            DemoChapter(title: "La independencia", blocks: [
                .paragraph("Dos sucesos son independientes cuando saber que uno se ha verificado ==no cambia nada== la probabilidad del otro. El resultado de una moneda no depende del de la moneda anterior; el color de los ojos no depende del día de nacimiento."),
                .formula("A \\text{ y } B \\text{ independientes} \\Leftrightarrow P(A \\cap B) = P(A) \\times P(B)", caption: "La definición, equivalente a P(B | A) = P(B) cuando P(A) ≠ 0"),
                .paragraph("La independencia se comprueba con el cálculo, nunca a ojo. Lancemos un dado: sean $A$ = «par» = {2, 4, 6} y $B$ = «como mucho 2» = {1, 2}. Tenemos $P(A) = 1/2$, $P(B) = 1/3$, y $A \\cap B$ = {2}, luego $P(A \\cap B) = 1/6$. Como $\\frac{1}{2} \\times \\frac{1}{3} = \\frac{1}{6}$, los dos sucesos son independientes, algo que no se veía a simple vista."),
                .figure(.split(
                    title: "Dos nociones que no hay que confundir",
                    left: DemoColumn(title: "Incompatibles", items: ["No pueden ocurrir a la vez", "A ∩ B = ∅", "P(A ∩ B) = 0", "Noción de conjuntos"]),
                    right: DemoColumn(title: "Independientes", items: ["Uno no informa sobre el otro", "P(A ∩ B) = P(A) × P(B)", "Se comprueba con el cálculo", "Noción probabilística"])
                )),
                .paragraph("Las dos nociones son incluso casi opuestas: si $A$ y $B$ son incompatibles y de probabilidad no nula, saber que se ha verificado $A$ indica con certeza que no se ha verificado $B$. Son, por tanto, ==muy dependientes==. Sacar «cara» y sacar «cruz» en el mismo lanzamiento son sucesos incompatibles; «cara» en el primer lanzamiento y «cruz» en el segundo son independientes."),
                .heading("Repetir un experimento"),
                .paragraph("Cuando se repite un experimento en las mismas condiciones —lanzar varias veces una moneda, extraer con reemplazamiento—, los resultados sucesivos son independientes, y la probabilidad de una serie de resultados es el producto de las probabilidades de cada uno. Sacar tres veces «cara» con una moneda equilibrada: $\\left(\\frac{1}{2}\\right)^3 = \\frac{1}{8}$."),
                .callout(
                    title: "La falacia del jugador",
                    text: "Tras diez «rojos» seguidos en la ruleta, al «negro» no «le toca»: las tiradas son independientes, la ruleta no tiene memoria, y la probabilidad de negro en la siguiente tirada es exactamente la misma que en la primera.",
                    tone: .warning
                ),
                .paragraph("Y, sin embargo, es lo que, a largo plazo, da la razón a la intuición de las frecuencias. La **ley de los grandes números**, demostrada por Jakob Bernoulli en 1713, afirma que, en un número muy grande de repeticiones independientes, la frecuencia de un suceso se aproxima a su probabilidad. No porque las desviaciones se «compensen», sino porque se vuelven despreciables frente al número total de intentos."),
                .timeline(title: "Una breve historia de la probabilidad", events: [
                    DemoEvent(date: "1654", label: "Pascal y Fermat resuelven el problema del reparto"),
                    DemoEvent(date: "1713", label: "Jakob Bernoulli: la ley de los grandes números"),
                    DemoEvent(date: "1763", label: "Publicación póstuma del teorema de Bayes"),
                    DemoEvent(date: "1812", label: "Laplace, Teoría analítica de las probabilidades"),
                    DemoEvent(date: "1933", label: "Kolmogórov fundamenta la probabilidad en axiomas"),
                ]),
                .paragraph("La disciplina nació de una pregunta de jugadores: ¿cómo repartir de forma justa las apuestas de una partida interrumpida? Tres siglos después, sirve para evaluar un medicamento, fijar la prima de un seguro o transmitir una señal sin errores. El método, en cambio, no ha cambiado: ==contar, condicionar, multiplicar, sumar==."),
            ]),
            DemoChapter(title: "Variables aleatorias y distribución binomial", blocks: [
                .paragraph("A menudo, lo que interesa no es el resultado en sí, sino un número que depende de él: la ganancia en un juego, el número de respuestas correctas, el número de piezas defectuosas. Una **variable aleatoria** asocia un número real a cada resultado, y su **distribución** da la probabilidad de cada uno de sus valores."),
                .heading("La esperanza"),
                .paragraph("Un juego: se apuestan 2 €, se lanza un dado y se reciben 10 € si sale un 6. Sea $X$ la ganancia neta. Si sale el 6, $X = 10 - 2 = 8$; si no, $X = -2$. La distribución de $X$ cabe en una tabla de dos columnas."),
                .table(title: "Distribución de la ganancia neta X", headers: ["Valor de X", "−2 €", "8 €"], rows: [
                    ["Probabilidad", "5/6", "1/6"],
                ]),
                .paragraph("La **esperanza** es la media de los valores ponderada por sus probabilidades: es la ganancia media por partida si se jugara un número muy grande de veces. Aquí $E(X) = -2 \\times \\frac{5}{6} + 8 \\times \\frac{1}{6} = \\frac{-10 + 8}{6} = -\\frac{1}{3}$. El jugador pierde de media unos 33 céntimos por partida: el juego es ==desfavorable==."),
                .formula("E(X) = \\sum_{i} x_i \\, P(X = x_i) \\;\\;\\;\\; V(X) = \\sum_{i} P(X = x_i)\\,(x_i - E(X))^2", caption: "La esperanza mide el centro; la varianza, la dispersión a su alrededor"),
                .paragraph("La **varianza** mide cuánto se alejan los valores de la esperanza, y la **desviación típica** $\\sigma(X) = \\sqrt{V(X)}$ devuelve esa medida a la unidad de $X$. Dos juegos con la misma esperanza pueden ser muy distintos: uno da casi siempre la misma pequeña cantidad; el otro, nada la mayoría de las veces y mucho en contadas ocasiones."),
                .heading("La distribución binomial"),
                .callout(
                    title: "Esquema de Bernoulli",
                    text: "Se repite $n$ veces, de forma **independiente**, una prueba con dos resultados: éxito, con probabilidad $p$, o fracaso. El número $X$ de éxitos sigue la **distribución binomial** $B(n, p)$.",
                    tone: .definition
                ),
                .formula("P(X = k) = \\binom{n}{k}\\, p^k \\,(1-p)^{n-k}", caption: "El número combinatorio cuenta los caminos del árbol que llevan a k éxitos"),
                .paragraph("La fórmula se lee en el árbol: cada camino con $k$ éxitos y $n - k$ fracasos tiene probabilidad $p^k (1-p)^{n-k}$, y el número de esos caminos es el número combinatorio «$n$ sobre $k$». Ejemplo: un test de 10 preguntas con 4 opciones, respondido completamente al azar. El número de respuestas correctas sigue $B(10\\,;\\,0{,}25)$, cuya distribución es esta."),
                .bars(title: "Distribución de B(10 ; 0,25): probabilidad de acertar k respuestas", unit: "%", bars: [
                    DemoBar(label: "k = 0", value: 5.6),
                    DemoBar(label: "k = 1", value: 18.8),
                    DemoBar(label: "k = 2", value: 28.2),
                    DemoBar(label: "k = 3", value: 25.0),
                    DemoBar(label: "k = 4", value: 14.6),
                    DemoBar(label: "k = 5", value: 5.8),
                    DemoBar(label: "k = 6", value: 1.6),
                    DemoBar(label: "k = 7", value: 0.3),
                ]),
                .paragraph("La distribución alcanza su máximo en torno a 2 o 3 respuestas correctas, y se desploma a partir de ahí. Aprobar, 5 de 10, respondiendo al azar solo ocurre con una probabilidad de alrededor del ==7,8 %==; no acertar ninguna, $0{,}75^{10} \\approx 5{,}6\\,\\%$. Para una distribución binomial, la esperanza y la varianza tienen fórmulas directas."),
                .formula("E(X) = np \\;\\;\\;\\; V(X) = np(1-p)", caption: "Aquí: E(X) = 10 × 0,25 = 2,5 y V(X) = 2,5 × 0,75 = 1,875"),
                .keyFigure(value: "2,5", label: "respuestas correctas de media en 10 preguntas de cuatro opciones, respondiendo al azar"),
                .paragraph("La desviación típica vale $\\sqrt{1{,}875} \\approx 1{,}37$: la mayoría de los candidatos que responden al azar aciertan entre 1 y 4 preguntas. Es exactamente lo que mostraba el gráfico, y es la razón por la que algunos tests restan puntos por cada respuesta incorrecta: así se reduce a cero la esperanza del azar."),
                .callout(
                    title: "Método: justificar una distribución binomial",
                    text: "Tres puntos que hay que escribir, siempre: 1. una prueba con **dos resultados** (éxito con probabilidad $p$); 2. repetida $n$ veces de forma **idéntica e independiente**; 3. $X$ cuenta el **número de éxitos**. Sin estas tres frases, la respuesta está incompleta.",
                    tone: .insight
                ),
                .paragraph("El segundo punto es el que se olvida: una extracción **sin reemplazamiento** en una urna pequeña no es una repetición independiente, y la distribución binomial no se aplica. Comprobar las hipótesis antes de aplicar la fórmula marca ==toda la diferencia== entre un cálculo correcto y un cálculo que solo lo parece."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "¿Cómo se calcula la probabilidad de un suceso situado al final de varios caminos de un diagrama de árbol?",
                back: "Se multiplican las probabilidades a lo largo de cada camino y después se suman los resultados de los caminos que llevan al suceso: es el teorema de la probabilidad total.",
                figure: .flow(title: "Leer un árbol", steps: ["Multiplicar a lo largo de un camino", "Sumar los caminos"]),
                chapter: 1
            ),
            DemoCard(
                kind: .choice,
                front: "Se lanzan dos dados equilibrados. ¿Cuál es la probabilidad de que la suma sea 7?",
                back: "1/6: seis parejas de 36 dan 7: (1,6), (2,5), (3,4), (4,3), (5,2), (6,1).",
                choices: ["1/11", "1/12", "1/6", "7/36"],
                answerIndex: 2,
                chapter: 0
            ),
            DemoCard(
                kind: .cloze,
                front: "Dos sucesos A y B son independientes si y solo si $P(A \\cap B) = $ … .",
                back: "$P(A) \\times P(B)$",
                chapter: 2
            ),
            DemoCard(kind: .basic, front: "¿Cuál es la fórmula de la probabilidad de B condicionada a A?", back: "$P(B | A) = \\frac{P(A \\cap B)}{P(A)}$, para $P(A) \\neq 0$.", chapter: 1),
            DemoCard(kind: .choice, front: "Una enfermedad afecta al 1 % de la población; una prueba da positivo en el 99 % de los enfermos y en el 2 % de las personas sanas. ¿Cuál es la probabilidad de estar enfermo si la prueba da positivo?", back: "Alrededor de 1/3: $\\frac{0{,}01 \\times 0{,}99}{0{,}01 \\times 0{,}99 + 0{,}99 \\times 0{,}02} = \\frac{0{,}0099}{0{,}0297}$.", hint: "Imagina 10 000 personas analizadas.", choices: ["99 %", "98 %", "Alrededor del 33 %", "1 %"], answerIndex: 2, chapter: 1),
            DemoCard(kind: .cloze, front: "La probabilidad del suceso contrario es $P(Ā) = $ … .", back: "$1 - P(A)$", chapter: 0),
            DemoCard(kind: .basic, front: "¿Cuál es la diferencia entre dos sucesos incompatibles y dos sucesos independientes?", back: "Incompatibles: no pueden producirse a la vez ($A \\cap B = \\emptyset$). Independientes: que se verifique uno no cambia la probabilidad del otro ($P(A \\cap B) = P(A)P(B)$). Dos sucesos incompatibles de probabilidad no nula nunca son independientes.", chapter: 2),
            DemoCard(kind: .choice, front: "¿Cuál es la esperanza de una variable aleatoria que sigue la distribución binomial $B(n, p)$?", back: "$E(X) = np$. Su varianza vale $np(1-p)$.", choices: ["$p$", "$np$", "$np(1-p)$", "$n/p$"], answerIndex: 1, chapter: 3),
            DemoCard(kind: .basic, front: "¿Qué condiciones hay que comprobar para afirmar que una variable sigue una distribución binomial?", back: "Una prueba con dos resultados (éxito con probabilidad p), repetida n veces de forma idéntica e independiente, y una variable X que cuenta el número de éxitos.", chapter: 3),
            DemoCard(kind: .cloze, front: "Para calcular la probabilidad de obtener «al menos un» éxito, se pasa por el suceso contrario: «…».", back: "ninguno", chapter: 0),
            DemoCard(kind: .choice, front: "Se apuestan 2 € y se reciben 10 € si el dado sale 6. ¿Cuál es la esperanza de la ganancia neta?", back: "$-2 \\times \\frac{5}{6} + 8 \\times \\frac{1}{6} = -\\frac{1}{3}$, es decir, una pérdida media de unos 0,33 € por partida.", choices: ["$-\\frac{1}{3}$ €", "0 €", "$\\frac{1}{3}$ €", "$\\frac{5}{3}$ €"], answerIndex: 0, chapter: 3),
            DemoCard(kind: .cloze, front: "La ley de los … afirma que la frecuencia de un suceso se aproxima a su probabilidad cuando el número de repeticiones se hace muy grande.", back: "grandes números", chapter: 2),
        ]
    )

    // MARK: Economía: la oferta y la demanda

    private static let supplyDemandES = OnboardingDemoCourse(
        id: "debug-supply-demand",
        emoji: "⚖️",
        subject: "Économie",
        title: "La oferta y la demanda",
        summary: "Cómo fija un mercado un precio: las curvas de oferta y de demanda, el equilibrio, lo que lo desplaza, la elasticidad y lo que cambia cuando interviene el Estado.",
        accentIndex: 5,
        chapters: [
            DemoChapter(title: "El mercado y la demanda", blocks: [
                .paragraph("¿Por qué una fresa cuesta tres veces más en marzo que en junio? Nadie ha decidido ese precio: resulta del encuentro de millones de decisiones de compra y de venta. El modelo de la oferta y la demanda explica ==cómo fija un mercado un precio== sin que nadie lo fije."),
                .heading("¿Qué es un mercado?"),
                .callout(
                    title: "Mercado",
                    text: "El lugar, físico o no, donde se encuentran la **oferta** (lo que proponen los vendedores) y la **demanda** (lo que desean adquirir los compradores) de un bien o servicio, y donde se forma su **precio**.",
                    tone: .definition
                ),
                .paragraph("Un mercado no es necesariamente un lugar: el mercado de trabajo, el mercado de divisas o el mercado inmobiliario no tienen plaza de abastos. Para razonar, los economistas parten de un caso ideal, la **competencia perfecta**, en la que ningún agente tiene peso suficiente para imponer su precio. Se basa en cinco condiciones."),
                .list([
                    "Atomicidad: muchos compradores y vendedores, cada uno demasiado pequeño para influir en el precio",
                    "Homogeneidad: todos los vendedores ofrecen el mismo producto",
                    "Transparencia: todo el mundo conoce los precios y la calidad",
                    "Libre entrada: cualquiera puede entrar en el mercado o salir de él",
                    "Libre circulación de los factores de producción: el trabajo y el capital van adonde más rinden",
                ]),
                .paragraph("Ningún mercado real cumple perfectamente estas cinco condiciones, y no es ese el objetivo: el modelo sirve de ==punto de comparación==. Un mercado mayorista de productos agrícolas se acerca a él; un mercado dominado por tres operadores de telefonía se aleja, y eso es precisamente lo que se mide al compararlo con el modelo."),
                .heading("La demanda"),
                .paragraph("La **demanda** es la cantidad de un bien que los compradores desean adquirir a cada precio posible. Obedece a una ley casi universal: cuando el precio sube, la cantidad demandada baja. Por dos razones. El **efecto sustitución**: el bien se encarece respecto a sus competidores, y se pasa a comprar estos. El **efecto renta**: con el mismo presupuesto, se puede comprar menos."),
                .formula("Q_d = 120 - 20\\,p", caption: "Una demanda lineal: cantidad demandada (en miles) en función del precio p (en euros)"),
                .paragraph("Esta función servirá de ejemplo a lo largo de todo el curso: imagina el mercado semanal de un queso en una comarca, en miles de piezas. A 1 €, los compradores quieren 100 000; a 5 €, solo 20 000. Cada euro de más hace renunciar a 20 000 compradores. Representada con el precio en el eje de ordenadas, es una recta **decreciente**: la curva de demanda."),
                .callout(
                    title: "La trampa del vocabulario",
                    text: "Cuando cambia el precio de un bien, nos **desplazamos a lo largo** de su curva de demanda: lo que varía es la *cantidad demandada*. Cuando cambia otra cosa —la renta, los gustos, el precio de otro bien—, es **la curva entera la que se desplaza**: lo que varía es la *demanda*.",
                    tone: .warning
                ),
                .paragraph("Esta distinción es el origen de la mayoría de los errores en los ejercicios. «La demanda baja porque el precio sube» es falso: lo que baja es la cantidad demandada. La demanda, en cambio, baja cuando disminuyen las rentas, cuando un producto de la competencia se abarata o cuando un estudio revela un peligro para la salud."),
                .timeline(title: "Los padres del modelo", events: [
                    DemoEvent(date: "1776", label: "Adam Smith, La riqueza de las naciones: la «mano invisible»"),
                    DemoEvent(date: "1838", label: "Antoine-Augustin Cournot traza la primera curva de demanda"),
                    DemoEvent(date: "1874", label: "Léon Walras, la teoría del equilibrio general"),
                    DemoEvent(date: "1890", label: "Alfred Marshall cruza la oferta y la demanda"),
                ]),
                .paragraph("Marshall comparaba la oferta y la demanda con las dos hojas de unas tijeras: preguntarse cuál de ellas corta el papel no tiene sentido, y preguntarse si es la oferta o la demanda la que fija el precio, tampoco. Es ==su encuentro== lo que lo determina, y ese es el objeto del capítulo siguiente."),
            ]),
            DemoChapter(title: "La oferta y el equilibrio", blocks: [
                .paragraph("Frente a los compradores, los productores. La **oferta** es la cantidad que están dispuestos a vender a cada precio posible, y obedece a la ley inversa de la demanda: cuanto más alto es el precio, más quieren vender. Un precio más alto hace rentable producir más y atrae a nuevos productores."),
                .heading("La curva de oferta"),
                .paragraph("¿Por qué hace falta un precio más alto para producir más? Porque, a corto plazo, producir cada unidad adicional cuesta cada vez más: horas extra, máquinas forzadas por encima de su régimen, materias primas más difíciles de conseguir. El productor solo acepta producir una unidad más si el precio cubre ese **coste marginal** creciente."),
                .formula("Q_s = 20\\,p", caption: "La oferta del mismo mercado: cantidad ofrecida (en miles) en función del precio p"),
                .paragraph("A corto plazo, la oferta acaba incluso chocando con un muro: la capacidad de producción. Una quesería no puede producir más de lo que le permiten sus cubas y su leche, sea cual sea el precio. La cantidad ofrecida sube primero deprisa con el precio, luego cada vez menos, hasta un techo."),
                .figure(.plot(title: "La oferta a corto plazo tiene un techo", caption: "En el eje de abscisas, el precio; en el de ordenadas, la cantidad ofrecida: aumenta con el precio y después choca con la capacidad de producción.", kind: .saturation)),
                .paragraph("Por eso, una subida repentina de la demanda hace subir al principio los precios más que las cantidades: los productores no pueden seguirla de inmediato. A largo plazo, invierten, llegan nuevos productores y el techo se eleva. En nuestro ejemplo, nos quedamos en la zona en la que la oferta es una recta."),
                .heading("El equilibrio"),
                .paragraph("Pongamos cara a cara los dos lados del mercado. Para cada precio, se compara la cantidad que quieren los compradores con la que ofrecen los vendedores. La tabla se lee fila a fila, y una sola fila hace coincidir ambas."),
                .table(title: "El mercado del queso, precio a precio", headers: ["Precio", "Demanda (miles)", "Oferta (miles)", "Situación"], rows: [
                    ["1 €", "100", "20", "Escasez de 80"],
                    ["2 €", "80", "40", "Escasez de 40"],
                    ["3 €", "60", "60", "Equilibrio"],
                    ["4 €", "40", "80", "Excedente de 40"],
                    ["5 €", "20", "100", "Excedente de 80"],
                ]),
                .paragraph("El **precio de equilibrio** es aquel para el que la cantidad ofrecida es igual a la cantidad demandada. Gráficamente, es el punto de intersección de las dos curvas; algebraicamente, es la solución de una ecuación de primer grado."),
                .formula("120 - 20\\,p = 20\\,p \\;\\Rightarrow\\; p^* = 3 \\text{ €} \\;\\text{ y }\\; Q^* = 60", caption: "El equilibrio: la oferta es igual a la demanda"),
                .paragraph("Al precio de 3 €, se venden 60 000 quesos cada semana, y todos salen ganando: todos los compradores dispuestos a pagar 3 € quedan servidos, y todos los vendedores dispuestos a vender a 3 € han colocado su producción. No hay ==ni colas ni excedentes sin vender==."),
                .keyFigure(value: "3 €", label: "el precio de equilibrio, el único al que 60 000 quesos encuentran a la vez vendedor y comprador"),
                .paragraph("Este precio no es solo un punto en un gráfico: es aquel al que el mercado vuelve por sí solo. Si el precio es demasiado bajo, los compradores se disputan una mercancía escasa y lo hacen subir; si es demasiado alto, los vendedores se quedan con excedentes y lo bajan. El mecanismo se lee en cuatro tiempos."),
                .figure(.flow(title: "La vuelta al equilibrio, desde un precio demasiado bajo", steps: ["Precio de 2 €: escasez de 40 000", "Los compradores pujan, el precio sube", "La cantidad demandada baja, la oferta aumenta", "La escasez desaparece a 3 €"])),
                .paragraph("El mecanismo es simétrico desde un precio demasiado alto: a 4 €, los vendedores tienen 40 000 piezas sin vender, bajan sus precios para darles salida y el mercado desciende hacia 3 €. En ambos casos, son las diferencias entre oferta y demanda las que mueven el precio, y es su desaparición lo que lo detiene."),
                .callout(
                    title: "La mano invisible",
                    text: "La expresión de Adam Smith designa este mecanismo: cada uno persigue su propio interés —el comprador, pagar menos; el vendedor, ganar más— y el precio se ajusta hasta coordinar sus decisiones, **sin que intervenga ningún planificador**. El precio es una señal: indica a los productores qué producir y a los consumidores qué ahorrar.",
                    tone: .insight
                ),
                .paragraph("El mecanismo tiene una consecuencia sorprendente: ==la escasez es un síntoma de un precio demasiado bajo==, no de una producción demasiado débil. Es lo que se observa cada vez que un precio se bloquea por debajo del equilibrio, y es lo que estudiará el último capítulo."),
            ]),
            DemoChapter(title: "Cuando el equilibrio se desplaza", blocks: [
                .paragraph("El equilibrio solo dura mientras no cambie nada. Pero todo cambia: las rentas, los gustos, los costes, el tiempo atmosférico. Cada vez, una de las curvas se desplaza, y el mercado encuentra ==un nuevo equilibrio==, con otro precio y otra cantidad."),
                .figure(.split(
                    title: "Lo que desplaza las curvas",
                    left: DemoColumn(title: "La demanda", items: ["Renta de los hogares", "Precio de los bienes sustitutivos", "Precio de los bienes complementarios", "Gustos, modas, información", "Tamaño de la población"]),
                    right: DemoColumn(title: "La oferta", items: ["Coste de las materias primas", "Salarios, energía", "Progreso técnico", "Número de productores", "Clima, impuestos, subvenciones"])
                )),
                .paragraph("El método de análisis es siempre el mismo, en tres preguntas: ¿qué curva se desplaza? ¿En qué sentido? ¿Qué ocurre con el precio y la cantidad de equilibrio? Si la demanda aumenta, el precio y la cantidad suben los dos. Si la oferta disminuye, el precio sube, pero la cantidad baja."),
                .callout(
                    title: "Una helada en Brasil",
                    text: "Brasil produce más de un tercio del café mundial. Cuando una helada destruye parte de la cosecha, la **oferta** de café disminuye: su curva se desplaza hacia la izquierda. En el nuevo equilibrio, el precio del café sube y la cantidad intercambiada baja, sin que la demanda se haya movido.",
                    tone: .example
                ),
                .paragraph("Algunos mercados no recuperan su equilibrio de forma suave. Cuando la producción requiere tiempo —criar cerdos, plantar frutales—, los productores deciden lo que venderán mañana mirando el precio de hoy. Un precio alto los empuja a todos a producir más; la producción llega a la vez, el precio se hunde y todos reducen su producción. Es el **ciclo del cerdo**, descrito ya en los años treinta del siglo XX."),
                .figure(.cycle(title: "El ciclo del cerdo", nodes: ["Precio alto", "Los ganaderos producen más", "Sobreproducción: el precio cae", "Los ganaderos producen menos"])),
                .paragraph("Este ciclo es un límite del modelo simple: supone que las cantidades se ajustan al instante. Explica también por qué los precios agrícolas son tan inestables y por qué tantos países han puesto en marcha políticas para estabilizarlos, como la **política agrícola común** europea a partir de 1962."),
                .heading("La elasticidad-precio"),
                .paragraph("No todas las demandas reaccionan igual al precio. Una subida del 10 % del precio de la gasolina apenas reduce las compras a corto plazo: hay que ir a trabajar. La misma subida en un viaje de ocio puede hacer que muchos renuncien. La **elasticidad-precio** mide esta sensibilidad."),
                .formula("e = \\frac{\\Delta Q / Q}{\\Delta p / p}", caption: "La variación relativa de la cantidad demandada dividida entre la variación relativa del precio: casi siempre negativa"),
                .paragraph("Si el precio sube un 10 % y la cantidad baja un 5 %, $e = -5 / 10 = -0{,}5$: la demanda es **inelástica**, porque $|e| < 1$. Si la cantidad baja un 20 %, $e = -2$: la demanda es **elástica**, porque $|e| > 1$. Y eso lo cambia todo para el vendedor, porque su **ingreso** es el precio multiplicado por la cantidad vendida."),
                .bars(title: "Ingreso total de los vendedores según el precio (miles de euros)", unit: "k€", bars: [
                    DemoBar(label: "1 €", value: 100),
                    DemoBar(label: "2 €", value: 160),
                    DemoBar(label: "3 €", value: 180),
                    DemoBar(label: "4 €", value: 160),
                    DemoBar(label: "5 €", value: 100),
                ]),
                .paragraph("El gráfico muestra el ingreso $R = p \\times Q_d$ en nuestro mercado. Sube hasta 3 € y luego vuelve a bajar. No es casualidad: a lo largo de una demanda lineal, la elasticidad cambia en cada punto, y el ingreso es máximo exactamente ==donde la elasticidad vale −1==."),
                .table(title: "La elasticidad a lo largo de la demanda Q = 120 − 20p", headers: ["Precio", "Cantidad", "Elasticidad", "Si el precio sube, el ingreso…"], rows: [
                    ["1 €", "100", "−0,2", "aumenta"],
                    ["2 €", "80", "−0,5", "aumenta"],
                    ["3 €", "60", "−1", "es máximo"],
                    ["4 €", "40", "−2", "disminuye"],
                    ["5 €", "20", "−5", "disminuye"],
                ]),
                .paragraph("La regla es general: cuando la demanda es inelástica, una subida de precio aumenta el ingreso, porque la cantidad baja proporcionalmente menos de lo que sube el precio. Por eso el Estado grava con gusto el tabaco y los carburantes, cuya demanda es poco elástica a corto plazo: el impuesto recauda y las ventas no se hunden."),
            ]),
            DemoChapter(title: "El Estado y el mercado", blocks: [
                .paragraph("El precio de equilibrio no siempre se considera aceptable: demasiado alto para los inquilinos, demasiado bajo para los agricultores o los asalariados. El Estado interviene entonces fijando un precio, gravando o subvencionando. El modelo permite prever ==los efectos de estas intervenciones==, incluidos los no deseados."),
                .heading("Precio máximo, precio mínimo"),
                .callout(
                    title: "Precio máximo y precio mínimo",
                    text: "Un **precio máximo** es un precio tope fijado por el Estado, por debajo del equilibrio, para proteger a los compradores (limitación de los alquileres). Un **precio mínimo** es un precio suelo, por encima del equilibrio, para proteger a los vendedores (salario mínimo, precios agrícolas garantizados).",
                    tone: .definition
                ),
                .paragraph("Volvamos a nuestro mercado. Un precio máximo de 2 € abarata el queso para quienes lo encuentran, pero la demanda sube a 80 000 y la oferta cae a 40 000: se instala ==una escasez de 40 000==, con colas y mercado negro. Un precio mínimo de 4 € garantiza un buen precio a los productores, pero estos ofrecen 80 000 piezas cuando los compradores solo quieren 40 000: un excedente de 40 000 que hay que almacenar, destruir o exportar."),
                .table(title: "Los instrumentos del Estado", headers: ["Instrumento", "Ejemplo", "Efecto esperado", "Posible efecto perverso"], rows: [
                    ["Precio máximo", "Limitación de los alquileres", "Precios más bajos", "Escasez, viviendas retiradas del mercado"],
                    ["Precio mínimo", "Salario mínimo", "Ingresos más altos", "Exceso de oferta: paro si el mínimo es demasiado alto"],
                    ["Impuesto", "Impuesto sobre el tabaco", "Menos consumo, más recaudación", "Contrabando"],
                    ["Subvención", "Ayuda a la compra de vehículos limpios", "Más compras del bien subvencionado", "Coste para las finanzas públicas"],
                ]),
                .paragraph("La última columna no es una acusación: estos efectos dependen de la distancia entre el precio fijado y el equilibrio, y de la elasticidad de las curvas. Un salario mínimo moderado puede tener un efecto muy débil sobre el empleo; una limitación estricta y duradera de los alquileres reduce casi siempre la oferta de viviendas en alquiler. El modelo no dice si hay que intervenir: dice ==lo que cuesta la intervención==."),
                .heading("¿Quién paga un impuesto?"),
                .paragraph("El Estado establece un impuesto de 1 € por queso, que ingresan los vendedores. Para vender una pieza, un productor exige ahora 1 € más que antes: si recibe $p$ de los compradores, solo se queda con $p - 1$. Su oferta pasa a ser $Q_s = 20(p - 1)$, y el equilibrio se desplaza."),
                .formula("120 - 20\\,p = 20\\,(p - 1) \\;\\Rightarrow\\; p = 3{,}5 \\text{ €} \\;\\text{ y }\\; Q = 50", caption: "El nuevo equilibrio, con un impuesto de 1 € por unidad"),
                .paragraph("Los compradores pagan ahora 3,50 € en lugar de 3 €: soportan 50 céntimos del impuesto. Los vendedores reciben 3,50 €, pero entregan 1 € al Estado: les quedan 2,50 € en lugar de 3 €, es decir, 50 céntimos de pérdida. El impuesto se reparte ==a partes iguales==, porque aquí las dos curvas tienen la misma pendiente. El Estado recauda $1 \\times 50\\,000 = 50\\,000$ € por semana."),
                .callout(
                    title: "Ingresar no es pagar",
                    text: "El vendedor **ingresa** el impuesto al Estado, pero es la elasticidad de las curvas la que decide quién lo **soporta**. El lado del mercado menos elástico —el que no puede escabullirse— paga la mayor parte. En el caso del tabaco, cuya demanda es poco elástica, son sobre todo los fumadores.",
                    tone: .warning
                ),
                .paragraph("El impuesto tiene además un coste oculto. En el equilibrio, el **excedente del consumidor** —lo que los compradores estaban dispuestos a pagar por encima del precio— y el **excedente del productor** —lo que los vendedores reciben por encima de su coste— valían 90 000 € cada uno, es decir, 180 000 € en total. Tras el impuesto, ese total se reparte de otro modo, y una parte desaparece."),
                .bars(title: "El excedente de 180 000 € tras el impuesto (miles de euros)", unit: "k€", bars: [
                    DemoBar(label: "Consumidores", value: 62.5),
                    DemoBar(label: "Productores", value: 62.5),
                    DemoBar(label: "Estado (recaudación fiscal)", value: 50),
                    DemoBar(label: "Pérdida irrecuperable", value: 5),
                ]),
                .paragraph("La **pérdida irrecuperable de eficiencia** —5000 € por semana— corresponde a los 10 000 quesos que ya no se intercambian aunque un comprador y un vendedor habrían salido ganando. No beneficia a nadie. Es el coste de eficiencia del impuesto, y es tanto mayor cuanto más elásticas son las curvas."),
                .list([
                    "Precio máximo por debajo del equilibrio: escasez",
                    "Precio mínimo por encima del equilibrio: excedente",
                    "Impuesto: sube el precio pagado, baja el precio recibido, baja la cantidad, pérdida irrecuperable",
                    "Reparto del impuesto: el lado menos elástico soporta la mayor parte",
                ]),
                .paragraph("Estos cuatro resultados valen para cualquier mercado, del petróleo al trabajo, pasando por la vivienda. No dicen que una intervención sea buena o mala —el Estado puede querer reducir el consumo de tabaco o garantizar una renta—, pero obligan a ==cuantificar sus efectos==, que es la primera tarea del economista."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "¿Qué ocurre en un mercado cuando el precio es inferior al precio de equilibrio?",
                back: "La cantidad demandada supera a la cantidad ofrecida: hay escasez. Los compradores pujan, el precio sube, la cantidad demandada baja y la oferta aumenta hasta volver al equilibrio.",
                figure: .flow(title: "Vuelta al equilibrio", steps: ["Precio demasiado bajo", "Escasez", "El precio sube", "Equilibrio"]),
                chapter: 1
            ),
            DemoCard(
                kind: .choice,
                front: "Una helada destruye parte de la cosecha de café. ¿Qué ocurre con el precio y la cantidad de equilibrio?",
                back: "La oferta disminuye (su curva se desplaza hacia la izquierda): el precio de equilibrio sube y la cantidad intercambiada baja.",
                choices: ["El precio sube, la cantidad sube", "El precio sube, la cantidad baja", "El precio baja, la cantidad baja", "No cambia nada"],
                answerIndex: 1,
                chapter: 2
            ),
            DemoCard(
                kind: .cloze,
                front: "Cuando el precio de un bien aumenta, nos desplazamos … su curva de demanda: lo que varía es la cantidad demandada, no la demanda.",
                back: "a lo largo de",
                chapter: 0
            ),
            DemoCard(kind: .basic, front: "Con $Q_d = 120 - 20p$ y $Q_s = 20p$, ¿cuál es el equilibrio?", back: "$120 - 20p = 20p$ da $p^* = 3$ € y $Q^* = 60$ (miles).", hint: "Iguala la oferta y la demanda.", chapter: 1),
            DemoCard(kind: .choice, front: "El precio aumenta un 10 % y la cantidad demandada baja un 5 %. ¿Cuál es la elasticidad-precio de la demanda?", back: "$e = -5 / 10 = -0{,}5$: la demanda es inelástica, y una subida de precio aumenta el ingreso.", choices: ["−2", "−0,5", "0,5", "−5"], answerIndex: 1, chapter: 2),
            DemoCard(kind: .cloze, front: "Un precio máximo fijado por debajo del precio de equilibrio provoca … .", back: "escasez", chapter: 3),
            DemoCard(kind: .basic, front: "¿Cuáles son las cinco condiciones de la competencia perfecta?", back: "Atomicidad, homogeneidad del producto, transparencia de la información, libertad de entrada y salida del mercado, y libre circulación de los factores de producción.", chapter: 0),
            DemoCard(kind: .choice, front: "¿Cuál de estos acontecimientos desplaza hacia la derecha la curva de demanda de coches eléctricos?", back: "Una subida del precio de la gasolina: el coche de combustión, bien sustitutivo, pasa a ser más caro de usar. Una bajada del precio del propio coche eléctrico no desplaza la curva: nos movemos a lo largo de ella.", choices: ["Una bajada del precio de los coches eléctricos", "Una subida del precio de la gasolina", "Una subida del coste de las baterías", "Una bajada de la renta de los hogares"], answerIndex: 1, chapter: 2),
            DemoCard(kind: .basic, front: "¿Quién soporta un impuesto que grava un mercado?", back: "Compradores y vendedores se lo reparten, sea quien sea el que lo ingresa. El lado menos elástico soporta la mayor parte.", chapter: 3),
            DemoCard(kind: .cloze, front: "A lo largo de una demanda lineal, el ingreso de los vendedores es máximo en el punto en que la elasticidad-precio vale … .", back: "−1", chapter: 2),
            DemoCard(kind: .choice, front: "¿Qué efecto tiene un precio mínimo fijado por encima del equilibrio?", back: "Un exceso de oferta: los vendedores ofrecen más de lo que los compradores quieren comprar a ese precio.", choices: ["Escasez", "Un exceso de oferta", "Ningún efecto", "Una bajada del precio pagado"], answerIndex: 1, chapter: 3),
            DemoCard(kind: .cloze, front: "La pérdida de excedente causada por un impuesto, que no beneficia a nadie, se llama pérdida … de eficiencia.", back: "irrecuperable", chapter: 3),
        ]
    )

    // MARK: Física: los circuitos eléctricos

    private static let circuitsES = OnboardingDemoCourse(
        id: "debug-circuits",
        emoji: "🔌",
        subject: "Physique",
        title: "La electricidad: circuitos",
        summary: "La corriente y la tensión, la ley de Ohm, los montajes en serie y en paralelo y, después, la potencia, la energía y las normas de seguridad, con cálculos hechos paso a paso.",
        accentIndex: 2,
        chapters: [
            DemoChapter(title: "Corriente y tensión", blocks: [
                .paragraph("Cuando se pulsa un interruptor, la lámpara se enciende al instante y, sin embargo, los electrones avanzan por los cables a menos de un milímetro por segundo. Esta paradoja resume lo esencial: un circuito eléctrico es ==un bucle ya lleno de cargas==, que el generador pone en movimiento todas a la vez."),
                .heading("La corriente eléctrica"),
                .paragraph("Una **corriente eléctrica** es un desplazamiento de conjunto de portadores de carga. En los metales son **electrones libres**, que pasan de átomo en átomo; en las disoluciones son iones. Su **intensidad** $I$ mide la cantidad de carga que atraviesa una sección del cable cada segundo. Se expresa en **amperios** (A)."),
                .formula("I = \\frac{Q}{\\Delta t}", caption: "I en amperios (A), Q en culombios (C), Δt en segundos (s)"),
                .paragraph("Un electrón lleva una carga de $1{,}6 \\times 10^{-19}$ C. Por tanto, una corriente de 1 A corresponde al paso de $1 / (1{,}6 \\times 10^{-19}) \\approx 6{,}25 \\times 10^{18}$ electrones por segundo: más de seis trillones. Por eso nunca se cuentan los electrones uno a uno, sino los culombios."),
                .callout(
                    title: "Sentido convencional",
                    text: "Por convenio, la corriente circula **del borne + al borne −** del generador, por el exterior de este. Los electrones, con carga negativa, se desplazan **en sentido contrario**. El convenio es anterior al descubrimiento del electrón, y se ha mantenido.",
                    tone: .warning
                ),
                .paragraph("Para que circule una corriente hace falta un **circuito cerrado**: un generador, cables, al menos un receptor y ningún corte. Abrir un interruptor es cortar el circuito, y la corriente se detiene en todas partes a la vez, tanto antes como después del interruptor."),
                .figure(.cycle(title: "Un circuito cerrado", nodes: ["Borne + del generador", "Cable de conexión", "Receptor (lámpara)", "Vuelta al borne −"])),
                .paragraph("En un circuito simple, sin ramificaciones, la intensidad es ==la misma en todos los puntos==: la corriente no se gasta al atravesar la lámpara. Lo que se «consume» es la energía que transportan las cargas, no las cargas en sí. La lámpara no se come los electrones: transforma energía eléctrica en luz y calor."),
                .heading("La tensión"),
                .callout(
                    title: "Tensión eléctrica",
                    text: "La **tensión** $U$ entre dos puntos de un circuito es la diferencia de su potencial eléctrico. Se mide en **voltios** (V). Es lo que pone en movimiento las cargas: sin tensión, no hay corriente.",
                    tone: .definition
                ),
                .paragraph("Una imagen ayuda a fijar las ideas: en un circuito de agua, la bomba crea una diferencia de presión y el agua circula. El generador es la bomba, la tensión es la diferencia de presión y la intensidad es el caudal. Una pila de 1,5 V, una batería de coche de 12 V y un enchufe de 230 V no tienen la misma «presión»."),
                .table(title: "Medir en un circuito", headers: ["Aparato", "Mide", "Unidad", "Conexión"], rows: [
                    ["Amperímetro", "La intensidad", "Amperio (A)", "En serie, dentro del circuito"],
                    ["Voltímetro", "La tensión", "Voltio (V)", "En paralelo, entre los bornes del componente"],
                    ["Óhmetro", "La resistencia", "Ohmio (Ω)", "Entre los bornes del componente, fuera del circuito"],
                ]),
                .paragraph("La conexión se deduce de lo que mide el aparato. Un amperímetro cuenta lo que pasa: debe atravesarlo la corriente y, por tanto, se coloca **dentro** del circuito. Un voltímetro compara dos puntos: se conecta **entre** ellos. Conectar un amperímetro en paralelo es provocar un cortocircuito y, a menudo, fundir su fusible."),
                .list([
                    "Ley de los nudos: la suma de las intensidades que llegan a un nudo es igual a la suma de las que salen de él",
                    "Ley de las mallas: en una malla, la tensión del generador es igual a la suma de las tensiones entre los bornes de los receptores",
                    "En un circuito simple, la intensidad es la misma en todas partes",
                ]),
            ]),
            DemoChapter(title: "La ley de Ohm", blocks: [
                .paragraph("Un cable de cobre deja pasar la corriente casi sin resistencia; un filamento de wolframio la frena con fuerza. La **resistencia** $R$ de un componente mide ==hasta qué punto se opone al paso de la corriente==. Se expresa en ohmios (Ω), por el físico alemán Georg Ohm."),
                .heading("Una relación de proporcionalidad"),
                .paragraph("Conectemos un **conductor óhmico** —una resistencia, en el sentido del componente— a un generador regulable y midamos la intensidad para varias tensiones. Los resultados, para una resistencia de 100 Ω, caen sobre una recta que pasa por el origen."),
                .table(title: "Medidas entre los bornes de una resistencia de 100 Ω", headers: ["Tensión U (V)", "Intensidad I (mA)", "U / I (Ω)"], rows: [
                    ["2", "20", "100"],
                    ["4", "40", "100"],
                    ["6", "60", "100"],
                    ["8", "80", "100"],
                    ["10", "100", "100"],
                ]),
                .paragraph("El cociente $U / I$ es constante: es la resistencia. Cuidado con las unidades: 20 mA son 0,020 A, y $2 / 0{,}020 = 100$ Ω. Esta proporcionalidad entre la tensión y la intensidad es la **ley de Ohm**, la relación más utilizada de toda la electricidad."),
                .formula("U = R \\times I", caption: "U en voltios (V), R en ohmios (Ω), I en amperios (A)"),
                .paragraph("La fórmula se lee en los tres sentidos: $U = RI$, $I = U / R$, $R = U / I$. Para una tensión dada, cuanto mayor es la resistencia, menor es la intensidad. Ejemplo: por una resistencia de 470 Ω sometida a 12 V circula $I = 12 / 470 \\approx 0{,}026$ A, es decir, unos 26 mA."),
                .heading("No todos los componentes son óhmicos"),
                .paragraph("La ley de Ohm solo es válida para los conductores óhmicos. Una lámpara incandescente, por ejemplo, no la cumple: cuando la tensión aumenta, el filamento se calienta, su resistencia aumenta y la intensidad crece cada vez más despacio. Su **curva característica** —la curva de la intensidad en función de la tensión— no es una recta, sino una curva que se va aplanando."),
                .figure(.plot(title: "Curva característica de una lámpara incandescente", caption: "En el eje de abscisas, la tensión; en el de ordenadas, la intensidad: cuanto más se calienta el filamento, más aumenta su resistencia y más le cuesta a la intensidad seguir el ritmo.", kind: .saturation)),
                .paragraph("Compárala con la recta de una resistencia: en la lámpara, el cociente $U / I$ no es constante, sino que aumenta con la tensión. Es la ==seña de identidad de un componente no óhmico==. Los diodos son otro ejemplo, todavía más marcado: dejan pasar la corriente en un sentido y casi nada en el otro."),
                .keyFigure(value: "× 10", label: "como mínimo: la resistencia de un filamento de wolframio a 2500 °C, comparada con su resistencia en frío"),
                .paragraph("Por eso una bombilla incandescente se funde casi siempre al encenderla: en frío, su resistencia es baja y una corriente intensa la atraviesa durante una fracción de segundo antes de que el filamento se caliente. Así pues, un óhmetro que mide una lámpara apagada da un valor muy distinto de su resistencia en funcionamiento."),
                .callout(
                    title: "Método",
                    text: "Para aplicar la ley de Ohm: 1. comprobar que el componente es óhmico; 2. pasar a unidades básicas —voltios, amperios, ohmios— (1 mA = 0,001 A, 1 kΩ = 1000 Ω); 3. despejar la magnitud buscada; 4. dar el resultado con su unidad y un número razonable de cifras.",
                    tone: .insight
                ),
                .paragraph("El paso dos es el que más puntos hace perder: $12 / 470$ da 0,026, y es un resultado en amperios. Escribir «0,026 mA» es equivocarse en un factor mil. Un orden de magnitud mental —==unas decenas de miliamperios para unos cientos de ohmios a 12 V==— basta para detectar el error."),
            ]),
            DemoChapter(title: "Serie y paralelo", blocks: [
                .paragraph("En cuanto un circuito tiene más de un receptor, hay que saber cómo están conectados. Solo existen dos formas elementales: **en serie**, uno detrás de otro en un mismo circuito; **en paralelo**, en ramas paralelas entre los mismos dos puntos. Todo circuito, incluso complejo, se descompone en estos dos montajes."),
                .figure(.split(
                    title: "Dos montajes",
                    left: DemoColumn(title: "En serie", items: ["Un solo circuito", "Misma intensidad en todas partes", "Las tensiones se suman", "Las resistencias se suman", "Si un elemento se funde, se corta todo"]),
                    right: DemoColumn(title: "En paralelo", items: ["Varias ramas", "Misma tensión entre los bornes", "Las intensidades se suman", "Resistencia equivalente menor", "Cada rama es independiente"])
                )),
                .paragraph("Cada fila de la tabla se deduce de las dos leyes del primer capítulo. En serie no hay nudos, así que la intensidad es la misma en todas partes; la ley de las mallas dice que las tensiones se suman. En paralelo, las ramas están conectadas entre los mismos dos puntos, así que tienen la misma tensión; la ley de los nudos dice que las intensidades se suman."),
                .heading("En serie"),
                .formula("R_{eq} = R_1 + R_2", caption: "Dos resistencias en serie equivalen a una sola, igual a su suma"),
                .callout(
                    title: "Ejemplo: dos resistencias en serie",
                    text: "Un generador de 12 V alimenta $R_1 = 100$ Ω y $R_2 = 200$ Ω en serie. $R_{eq} = 300$ Ω, luego $I = 12 / 300 = 0{,}040$ A = 40 mA. Tensiones: $U_1 = 100 \\times 0{,}040 = 4$ V y $U_2 = 200 \\times 0{,}040 = 8$ V. Comprobación: $4 + 8 = 12$ V.",
                    tone: .example
                ),
                .paragraph("La tensión se reparte ==proporcionalmente a las resistencias==: la resistencia el doble de grande recibe una tensión el doble de grande. Este montaje se llama **divisor de tensión**, y está en todas partes en electrónica para obtener una tensión menor a partir de una alimentación fija."),
                .heading("En paralelo"),
                .formula("\\frac{1}{R_{eq}} = \\frac{1}{R_1} + \\frac{1}{R_2} \\;\\;\\Leftrightarrow\\;\\; R_{eq} = \\frac{R_1 R_2}{R_1 + R_2}", caption: "En paralelo, lo que se suma son las inversas de las resistencias"),
                .paragraph("Conectemos ahora las mismas resistencias en paralelo al mismo generador. Cada una recibe los 12 V: $I_1 = 12 / 100 = 0{,}12$ A e $I_2 = 12 / 200 = 0{,}06$ A. El generador suministra su suma, $0{,}18$ A. La resistencia equivalente vale $\\frac{100 \\times 200}{300} \\approx 66{,}7$ Ω, y se comprueba que $12 / 66{,}7 \\approx 0{,}18$ A."),
                .table(title: "Las mismas resistencias, dos montajes (generador de 12 V)", headers: ["", "En serie", "En paralelo"], rows: [
                    ["Resistencia equivalente", "300 Ω", "≈ 66,7 Ω"],
                    ["Intensidad suministrada", "40 mA", "180 mA"],
                    ["Tensión entre los bornes de R₁", "4 V", "12 V"],
                    ["Tensión entre los bornes de R₂", "8 V", "12 V"],
                    ["Potencia total", "0,48 W", "2,16 W"],
                ]),
                .paragraph("El resultado va contra la intuición: añadir una resistencia **en paralelo disminuye** la resistencia equivalente, porque se le ofrece a la corriente un camino más. La resistencia equivalente es siempre menor que la menor de las resistencias en paralelo: aquí, 66,7 Ω, menos que 100 Ω."),
                .callout(
                    title: "Por qué los enchufes están en paralelo",
                    text: "En una casa, todos los aparatos están conectados en paralelo: cada uno recibe los 230 V, y se puede apagar uno sin cortar los demás. Pero cada aparato que se añade aumenta la intensidad total del circuito: así es como una regleta sobrecargada hace **saltar el automático**.",
                    tone: .warning
                ),
                .paragraph("Recuerda la regla de oro: ==en serie, la intensidad es común; en paralelo, lo es la tensión==. Todo lo demás —la suma de tensiones o de intensidades, el cálculo de las resistencias equivalentes— se deduce de ahí, y es lo primero que hay que identificar ante un esquema."),
            ]),
            DemoChapter(title: "Potencia, energía y seguridad", blocks: [
                .paragraph("Un aparato eléctrico se elige ante todo por su **potencia**: 8 W para una bombilla LED, 2000 W para un hervidor. La potencia eléctrica que recibe un componente es el producto de la tensión entre sus bornes por la intensidad que lo atraviesa. Mide ==el ritmo de energía== que recibe."),
                .formula("P = U \\times I", caption: "P en vatios (W), U en voltios (V), I en amperios (A)"),
                .paragraph("Combinada con la ley de Ohm, la fórmula adopta otras dos formas para un conductor óhmico: $P = R I^2$ y $P = U^2 / R$. La primera explica el **efecto Joule**: un conductor por el que pasa una corriente se calienta, tanto más cuanto mayor es la intensidad. Es útil en un radiador o en una tostadora, y es una pérdida en todos los demás casos."),
                .table(title: "Potencia e intensidad de algunos aparatos a 230 V", headers: ["Aparato", "Potencia", "Intensidad (I = P / U)"], rows: [
                    ["Bombilla LED", "8 W", "≈ 0,035 A"],
                    ["Cargador de móvil", "20 W", "≈ 0,09 A"],
                    ["Televisor", "100 W", "≈ 0,43 A"],
                    ["Hervidor", "2000 W", "≈ 8,7 A"],
                    ["Horno", "3000 W", "≈ 13 A"],
                ]),
                .paragraph("Un enchufe estándar está diseñado para 16 A, es decir, $230 \\times 16 \\approx 3\\,700$ W como máximo. Conectar un hervidor y un horno a la misma regleta supone pedir más de 21 A: los cables se calientan por efecto Joule, y así empiezan muchos incendios domésticos."),
                .heading("La energía consumida"),
                .formula("E = P \\times \\Delta t", caption: "E en julios si P está en vatios y Δt en segundos; en kWh si P está en kW y Δt en horas"),
                .callout(
                    title: "¿Cuánto cuesta un té?",
                    text: "Un hervidor de 2000 W calienta el agua en 3 minutos: $E = 2 \\text{ kW} \\times 0{,}05 \\text{ h} = 0{,}1$ kWh. A unos 0,20 € el kWh, cuesta **dos céntimos**. En julios: $2000 \\times 180 = 360\\,000$ J.",
                    tone: .example
                ),
                .paragraph("El kilovatio hora es la unidad de la factura porque el julio es demasiado pequeño a la escala de un hogar: 1 kWh equivale a $3{,}6 \\times 10^6$ J. Lo que sale caro no son los aparatos potentes que se usan unos minutos, sino los que funcionan mucho tiempo: un radiador de 1500 W encendido diez horas consume 15 kWh, ciento cincuenta veces más que el té."),
                .heading("La electricidad y el cuerpo humano"),
                .paragraph("El peligro eléctrico depende de ==la intensidad que atraviesa el cuerpo==, no directamente de la tensión. Pero es la tensión la que la provoca: el cuerpo humano tiene una resistencia del orden de 1000 Ω entre las dos manos, con la piel húmeda. A 230 V, la ley de Ohm da $I = 230 / 1000 = 0{,}23$ A, es decir, 230 mA: una intensidad mortal."),
                .bars(title: "Efectos de una corriente alterna que atraviesa el cuerpo", unit: "mA", bars: [
                    DemoBar(label: "Umbral de percepción", value: 0.5),
                    DemoBar(label: "Contracción: ya no se puede soltar", value: 10),
                    DemoBar(label: "Parálisis respiratoria", value: 30),
                    DemoBar(label: "Fibrilación cardiaca", value: 75),
                ]),
                .paragraph("Estos umbrales explican la cifra que aparece en todos los cuadros eléctricos: los **interruptores diferenciales de 30 mA**. Comparan la corriente que va hacia un aparato con la que vuelve de él; si la diferencia supera los 30 mA, es que parte de la corriente se escapa —quizá a través de alguien—, y cortan en unas centésimas de segundo."),
                .list([
                    "Fusible o interruptor automático: corta el circuito en caso de sobreintensidad (cortocircuito, sobrecarga) y protege la instalación",
                    "Interruptor diferencial de 30 mA: corta en caso de fuga de corriente y protege a las personas",
                    "Toma de tierra: deriva al suelo la corriente de un aparato con carcasa metálica defectuoso",
                    "Nunca aparatos eléctricos cerca del agua: la piel mojada divide la resistencia del cuerpo",
                ]),
                .paragraph("Estas protecciones son el resultado de dos siglos de dominio de la electricidad. Primero hubo que producirla de forma continua, después comprender sus leyes, luego distribuirla a gran escala y, en cada etapa, aprender a protegerse de ella."),
                .timeline(title: "Dos siglos de electricidad", events: [
                    DemoEvent(date: "1800", label: "Alessandro Volta inventa la pila: la primera corriente continua"),
                    DemoEvent(date: "1820", label: "Ørsted descubre que una corriente desvía una brújula"),
                    DemoEvent(date: "1827", label: "Georg Ohm publica la ley que lleva su nombre"),
                    DemoEvent(date: "1831", label: "Faraday descubre la inducción: ya se sabe producir corriente"),
                    DemoEvent(date: "1879", label: "Lámpara incandescente duradera de Swan y Edison"),
                    DemoEvent(date: "1882", label: "Primera central eléctrica pública, en Nueva York"),
                ]),
                .paragraph("La unidad de intensidad lleva el nombre de Ampère; la de tensión, el de Volta; la de resistencia, el de Ohm: tres de las letras que escribes en cada ejercicio son ==un homenaje a los pioneros== de esta historia. Y cada uno de sus descubrimientos se resume hoy en una fórmula de unos pocos caracteres."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "¿Cómo se comportan la intensidad y la tensión en un montaje en serie y en un montaje en paralelo?",
                back: "En serie, la intensidad es la misma en todas partes y las tensiones se suman. En paralelo, la tensión es la misma entre los bornes de cada rama y las intensidades se suman.",
                figure: .split(
                    title: "Dos montajes",
                    left: DemoColumn(title: "Serie", items: ["I común", "Las U se suman"]),
                    right: DemoColumn(title: "Paralelo", items: ["U común", "Las I se suman"])
                ),
                chapter: 2
            ),
            DemoCard(
                kind: .choice,
                front: "Una resistencia de 470 Ω se somete a una tensión de 12 V. ¿Qué intensidad la atraviesa?",
                back: "$I = U / R = 12 / 470 \\approx 0{,}026$ A, es decir, unos 26 mA.",
                choices: ["≈ 26 mA", "≈ 39 A", "≈ 5,6 A", "≈ 0,26 mA"],
                answerIndex: 0,
                chapter: 1
            ),
            DemoCard(
                kind: .cloze,
                front: "Un voltímetro se conecta en … entre los bornes del componente cuya tensión se quiere medir.",
                back: "paralelo",
                chapter: 0
            ),
            DemoCard(kind: .basic, front: "Enuncia la ley de Ohm.", back: "En un conductor óhmico, la tensión entre sus bornes es proporcional a la intensidad que lo atraviesa: $U = R \\times I$, con U en voltios, R en ohmios e I en amperios.", chapter: 1),
            DemoCard(kind: .choice, front: "Dos resistencias de 100 Ω y 200 Ω están montadas en serie con un generador de 12 V. ¿Cuál es la tensión entre los bornes de la resistencia de 200 Ω?", back: "$I = 12 / 300 = 0{,}04$ A, luego $U_2 = 200 \\times 0{,}04 = 8$ V.", hint: "Calcula primero la intensidad común.", choices: ["4 V", "6 V", "8 V", "12 V"], answerIndex: 2, chapter: 2),
            DemoCard(kind: .cloze, front: "Por convenio, la corriente circula del borne … al borne − del generador, por el exterior de este.", back: "+", chapter: 0),
            DemoCard(kind: .basic, front: "¿Por qué añadir una resistencia en paralelo disminuye la resistencia equivalente?", back: "Porque se le ofrece a la corriente un camino más: las intensidades de las ramas se suman, el generador suministra más con la misma tensión y, por tanto, $R_{eq} = U / I$ disminuye.", chapter: 2),
            DemoCard(kind: .choice, front: "¿Qué energía consume un hervidor de 2000 W funcionando durante 3 minutos?", back: "$E = P \\times \\Delta t = 2 \\text{ kW} \\times 0{,}05 \\text{ h} = 0{,}1$ kWh, es decir, 360 000 J.", choices: ["6 kWh", "0,1 kWh", "6000 J", "0,6 kWh"], answerIndex: 1, chapter: 3),
            DemoCard(kind: .cloze, front: "La potencia eléctrica que recibe un componente vale $P = U \\times$ … .", back: "$I$", chapter: 3),
            DemoCard(kind: .basic, front: "¿A quién protege un interruptor diferencial de 30 mA, y cómo?", back: "A las personas: compara la corriente que va hacia un aparato con la que vuelve de él, y corta si la diferencia supera los 30 mA, señal de una fuga de corriente, quizá a través de un cuerpo.", chapter: 3),
            DemoCard(kind: .choice, front: "¿A partir de qué intensidad, aproximadamente, puede provocar una parálisis respiratoria una corriente que atraviesa el cuerpo?", back: "Unos 30 mA, de ahí la sensibilidad de los interruptores diferenciales domésticos.", choices: ["0,5 mA", "30 mA", "1 A", "10 A"], answerIndex: 1, chapter: 3),
            DemoCard(kind: .cloze, front: "Un electrón lleva una carga de $1{,}6 \\times 10^{-19}$ … .", back: "culombios", chapter: 0),
        ]
    )

    // MARK: Biología: la célula y la mitosis

    private static let mitosisES = OnboardingDemoCourse(
        id: "debug-mitosis",
        emoji: "🔬",
        subject: "SVT",
        title: "La célula y la mitosis",
        summary: "La célula y sus orgánulos, el ciclo celular, las fases de la mitosis, la meiosis que fabrica los gametos y el cáncer, cuando la división escapa a todo control.",
        accentIndex: 3,
        chapters: [
            DemoChapter(title: "La célula, unidad de los seres vivos", blocks: [
                .paragraph("Todo ser vivo está hecho de células: una sola en el caso de una bacteria, unos ==30 billones== en el de un ser humano. Y toda célula nace de otra célula, por división. Estas dos frases forman la **teoría celular**, uno de los pilares de la biología."),
                .heading("Un descubrimiento de dos siglos"),
                .paragraph("Hubo que inventar el microscopio para ver las células, y después dos siglos de observaciones para comprender que eran lo que tenían en común todos los seres vivos. La línea del tiempo resume este largo camino, que culmina cuando por fin se observa una célula dividiéndose."),
                .timeline(title: "La teoría celular", events: [
                    DemoEvent(date: "1665", label: "Robert Hooke observa «células» en el corcho"),
                    DemoEvent(date: "1674", label: "Van Leeuwenhoek descubre seres vivos microscópicos"),
                    DemoEvent(date: "1838–1839", label: "Schleiden y Schwann: plantas y animales están hechos de células"),
                    DemoEvent(date: "1855", label: "Virchow: toda célula procede de otra célula"),
                    DemoEvent(date: "1882", label: "Flemming describe la mitosis y le da nombre"),
                ]),
                .paragraph("La frase de Virchow, *omnis cellula e cellula*, tiene una consecuencia vertiginosa: cada una de tus células desciende, por una cadena ininterrumpida de divisiones, de la primerísima célula viva. La división celular no es un detalle del funcionamiento de los seres vivos: es ==lo que hace que perduren==."),
                .callout(
                    title: "Célula",
                    text: "La unidad estructural y funcional más pequeña de los seres vivos: un espacio delimitado por una **membrana plasmática**, que contiene un **citoplasma** e información genética en forma de **ADN**, capaz de nutrirse, producir energía y reproducirse.",
                    tone: .definition
                ),
                .paragraph("Existen dos grandes tipos de células. Las **procariotas** —las bacterias— no tienen núcleo: su ADN flota en el citoplasma. Las **eucariotas** —animales, plantas, hongos, protistas— tienen un núcleo que encierra el ADN y compartimentos especializados, los **orgánulos**."),
                .heading("Los orgánulos"),
                .table(title: "Los principales orgánulos de una célula eucariota", headers: ["Orgánulo", "Función"], rows: [
                    ["Núcleo", "Contiene el ADN; es donde tienen lugar la replicación y la transcripción"],
                    ["Mitocondria", "Respiración celular: produce el ATP"],
                    ["Ribosoma", "Traducción: fabrica las proteínas"],
                    ["Retículo endoplasmático", "Síntesis y transporte de proteínas y lípidos"],
                    ["Aparato de Golgi", "Modifica, clasifica y envía las proteínas"],
                    ["Cloroplasto", "Fotosíntesis, solo en las células vegetales"],
                ]),
                .paragraph("La célula vegetal posee además una **pared** rígida de celulosa alrededor de su membrana, una gran **vacuola** llena de agua que la mantiene turgente y cloroplastos. La célula animal no tiene ni pared ni cloroplastos, pero sí **centrosomas**, que desempeñarán un papel central durante la división."),
                .keyFigure(value: "10 a 100 µm", label: "el tamaño típico de una célula eucariota, unas diez veces el de una bacteria: invisible a simple vista"),
                .paragraph("Este tamaño no es casual. Una célula lo intercambia todo —nutrientes, oxígeno, desechos— a través de su membrana, y cuando su volumen aumenta, su superficie lo hace más despacio. Por encima de cierto tamaño, ==la membrana ya no basta== para alimentar el interior: la célula debe dividirse o morir."),
            ]),
            DemoChapter(title: "El ciclo celular", blocks: [
                .paragraph("Una célula que se divide pasa por una sucesión de etapas que se repiten en cada generación: es el **ciclo celular**. Comprende una larga **interfase**, durante la cual la célula crece y copia su ADN, y una breve **mitosis**, durante la cual se divide en dos."),
                .figure(.cycle(title: "El ciclo celular", nodes: ["G1: crecimiento", "S: replicación del ADN", "G2: preparación", "M: mitosis y citocinesis"])),
                .paragraph("La fase **G1** (del inglés *gap*, intervalo) es aquella en la que la célula crece y funciona con normalidad. En la fase **S** (síntesis), replica todo su ADN. En la fase **G2**, comprueba la copia y prepara la división. La fase **M** es la mitosis propiamente dicha, seguida de la **citocinesis**, que reparte el citoplasma."),
                .bars(title: "Duración de las fases en una célula humana en cultivo", unit: "h", bars: [
                    DemoBar(label: "G1", value: 11),
                    DemoBar(label: "S", value: 8),
                    DemoBar(label: "G2", value: 4),
                    DemoBar(label: "M", value: 1),
                ]),
                .paragraph("En un ciclo de unas 24 horas, la mitosis solo ocupa una hora. Por eso, en una preparación al microscopio, la inmensa mayoría de las células están en interfase: la proporción de células observadas en cada fase ==refleja la duración de esa fase==. Muchas células, como las neuronas, llegan incluso a salir del ciclo hacia una fase de reposo, llamada G0, y ya no se dividen."),
                .heading("Cromosomas y cromátidas"),
                .callout(
                    title: "Cromosoma y cromátida",
                    text: "Un **cromosoma** es una molécula de ADN asociada a proteínas. Tras la fase S, cada cromosoma está formado por **dos cromátidas hermanas**, dos copias idénticas unidas por un **centrómero**. Sigue habiendo **un solo** cromosoma, pero con dos cromátidas.",
                    tone: .definition
                ),
                .paragraph("La cantidad de ADN de una célula sigue, por tanto, el ciclo. Llamemos $Q$ a la cantidad de ADN de una célula en G1. Durante la fase S, se duplica progresivamente hasta alcanzar $2Q$. Al final de la mitosis, cada célula hija se queda con $Q$. La curva de la cantidad de ADN en función del tiempo tiene forma de escalera que sube en S y vuelve a bajar de golpe en la división."),
                .formula("Q \\;\\to\\; 2Q \\;\\to\\; Q", caption: "La cantidad de ADN por célula: se duplica durante la fase S y se reparte en la mitosis"),
                .paragraph("El número de cromosomas, en cambio, no varía durante la fase S: una célula humana tiene 46 cromosomas en G1, y sigue teniendo 46 en G2, pero con dos cromátidas cada uno. Se escribe ==2n = 46==: $n$ es el número de cromosomas de un juego, 23 en el ser humano, y las células del cuerpo tienen dos juegos, uno materno y otro paterno."),
                .callout(
                    title: "El error clásico",
                    text: "Creer que la replicación duplica el número de cromosomas. Duplica **la cantidad de ADN**, no el número de cromosomas: 46 cromosomas de una cromátida pasan a ser 46 cromosomas de dos cromátidas. El número solo se duplica un instante, en la anafase, cuando las cromátidas se separan.",
                    tone: .warning
                ),
                .list([
                    "G1: crecimiento, cromosomas de una cromátida, cantidad de ADN Q",
                    "S: replicación, la cantidad de ADN pasa de Q a 2Q",
                    "G2: cromosomas de dos cromátidas, comprobación de la copia",
                    "M: mitosis, cada célula hija recibe Q",
                ]),
                .paragraph("El paso de una fase a otra no es automático: lo controlan unos **puntos de control**, en los que la célula comprueba que todo está en orden antes de continuar: que el ADN está intacto antes de la fase S y que se ha copiado por completo antes de la mitosis. Su descubrimiento valió el premio Nobel de 2001 a Hartwell, Hunt y Nurse, y es su fallo lo que abre la puerta al cáncer."),
            ]),
            DemoChapter(title: "Las fases de la mitosis", blocks: [
                .paragraph("La mitosis es la división de una célula en ==dos células hijas genéticamente idénticas== a la célula madre. Su objetivo es sencillo de enunciar y temible de llevar a cabo: repartir exactamente una copia de cada uno de los 46 cromosomas en cada una de las dos células, sin perder ni duplicar ninguno."),
                .figure(.flow(title: "Las etapas de la mitosis", steps: ["Profase: los cromosomas se condensan", "Metafase: se alinean en el ecuador", "Anafase: las cromátidas hermanas se separan", "Telofase: se vuelven a formar dos núcleos", "Citocinesis: dos células hijas"])),
                .paragraph("Cada fase tiene sus rasgos visibles al microscopio, y es lo que te pedirán que reconozcas en una fotografía. La tabla los reúne; la metafase es la más fácil de identificar, con sus cromosomas alineados como una fila de soldados en el centro de la célula."),
                .table(title: "Lo que se ve en cada fase", headers: ["Fase", "Qué ocurre"], rows: [
                    ["Profase", "Los cromosomas se condensan y se hacen visibles; la envoltura nuclear desaparece; se forma el huso mitótico"],
                    ["Metafase", "Los cromosomas, de dos cromátidas, se alinean en la placa ecuatorial, unidos al huso por su centrómero"],
                    ["Anafase", "Las cromátidas hermanas se separan y migran hacia polos opuestos: cada polo recibe 46 cromosomas de una cromátida"],
                    ["Telofase", "Los cromosomas se descondensan; se vuelve a formar una envoltura nuclear alrededor de cada grupo"],
                ]),
                .paragraph("El **huso mitótico** es la máquina que hace posible todo esto: una red de fibras de proteínas, los microtúbulos, tendidas entre los dos polos de la célula. Se unen a los centrómeros, alinean los cromosomas y después se acortan para tirar de las cromátidas hacia los polos. Un punto de control bloquea la anafase mientras quede un solo cromosoma mal unido."),
                .callout(
                    title: "El balance de la mitosis",
                    text: "Una célula madre con 2n = 46 cromosomas da **dos células hijas con 2n = 46 cromosomas**, que llevan exactamente la misma información genética. La mitosis es una **reproducción conforme**: es lo que permite el crecimiento, la renovación de los tejidos y la cicatrización.",
                    tone: .insight
                ),
                .paragraph("La citocinesis varía según el tipo de célula. La célula animal se estrangula por la mitad, como un globo al que se pellizca, gracias a un anillo de proteínas contráctiles. La célula vegetal, prisionera de su pared rígida, no puede estrangularse: construye una nueva pared en el centro, de dentro hacia fuera."),
                .figure(.split(
                    title: "Dos formas de dividirse",
                    left: DemoColumn(title: "Célula animal", items: ["Centrosomas en los polos", "Anillo contráctil", "Estrangulamiento del citoplasma"]),
                    right: DemoColumn(title: "Célula vegetal", items: ["Sin centrosomas", "Pared rígida", "Nueva pared construida en el centro"])
                )),
                .paragraph("Cada división duplica el número de células. Partiendo de una célula, hay 2 tras una división, 4 tras dos y 8 tras tres: el crecimiento es **exponencial**. Tras $k$ divisiones, una población de $N_0$ células cuenta con $N_0 \\times 2^k$."),
                .formula("N = N_0 \\times 2^k", caption: "El número de células tras k divisiones sucesivas, si todas se dividen"),
                .paragraph("Diez divisiones dan ya $2^{10} = 1\\,024$ células; cuarenta y cinco divisiones, unos 35 billones: el orden de magnitud de un cuerpo humano. En realidad, no todas las células de un organismo se dividen, y muchas mueren: el crecimiento de un tejido sano es un ==equilibrio entre divisiones y muertes celulares==, que el organismo regula continuamente."),
            ]),
            DemoChapter(title: "Meiosis, mitosis y cáncer", blocks: [
                .paragraph("La mitosis fabrica copias conformes. Pero la reproducción sexual necesita otra cosa: células con un solo juego de cromosomas, para que en la fecundación el óvulo y el espermatozoide reconstituyan una célula con dos juegos. Es la función de la **meiosis**, que tiene lugar únicamente en las gónadas."),
                .table(title: "Mitosis y meiosis, cara a cara", headers: ["", "Mitosis", "Meiosis"], rows: [
                    ["Dónde", "Casi todas las células del cuerpo", "Las células reproductoras de las gónadas"],
                    ["Divisiones", "Una", "Dos sucesivas"],
                    ["Células obtenidas", "2", "4"],
                    ["Cromosomas", "2n = 46, como la madre", "n = 23, la mitad"],
                    ["Información genética", "Idéntica a la célula madre", "Distinta de una célula a otra"],
                    ["Función", "Crecimiento, renovación", "Formación de los gametos"],
                ]),
                .paragraph("La primera división meiótica separa los cromosomas **homólogos** —el cromosoma de origen materno y el de origen paterno de cada par—; reduce a la mitad el número de cromosomas. La segunda separa las cromátidas hermanas, como una mitosis. De paso, la meiosis ==recombina la información genética== de dos formas."),
                .formula("2^{23} \\approx 8{,}4 \\times 10^{6}", caption: "El número de combinaciones de cromosomas posibles en un gameto humano, solo por la recombinación intercromosómica"),
                .paragraph("La **recombinación intercromosómica** se debe a que cada par se separa con independencia de los demás: para cada uno de los 23 pares, el gameto recibe el homólogo materno o el paterno, de ahí $2^{23}$, más de ocho millones de combinaciones. La **recombinación intracromosómica**, mediante intercambios de fragmentos entre homólogos llamados *sobrecruzamiento*, multiplica aún más esa cifra. Dos hermanos, salvo los gemelos idénticos, nunca reciben la misma combinación."),
                .heading("Cuando la división escapa al control"),
                .paragraph("En un organismo sano, cada célula solo se divide cuando recibe la señal, y se detiene cuando se le ordena. Dos familias de genes regulan este control. Los **protooncogenes** funcionan como un acelerador: empujan a la célula a dividirse. Los **genes supresores de tumores** funcionan como un freno: detienen el ciclo si hay algún problema."),
                .callout(
                    title: "Cáncer",
                    text: "Una enfermedad debida a la **proliferación descontrolada** de células que han acumulado mutaciones: un acelerador bloqueado (un protooncogén convertido en **oncogén**) y unos frenos rotos (genes supresores inactivados). Las células forman un tumor y después pueden invadir los tejidos vecinos y diseminarse a distancia: son las **metástasis**.",
                    tone: .definition
                ),
                .paragraph("El más célebre de los frenos es la proteína **p53**, apodada «la guardiana del genoma»: cuando el ADN está dañado, bloquea el ciclo el tiempo necesario para repararlo, o desencadena el suicidio de la célula si los daños son demasiado graves. El gen que la codifica está mutado en alrededor de la mitad de los cánceres humanos. En general, hacen falta ==varias mutaciones sucesivas==, acumuladas a lo largo de años, para que una célula se vuelva cancerosa, lo que explica que el riesgo aumente con la edad."),
                .keyFigure(value: "≈ 30", label: "duplicaciones para que una sola célula se convierta en un tumor de un centímetro, es decir, unos mil millones de células (2³⁰ ≈ 1,07 × 10⁹)"),
                .paragraph("Así pues, un tumor solo es detectable tras una larga historia silenciosa: treinta duplicaciones para alcanzar un centímetro, cuando diez más bastarían para multiplicarlo por mil. Ese es todo el reto del **cribado**: localizar el tumor lo antes posible en esta curva exponencial, cuando todavía es pequeño y está localizado."),
                .callout(
                    title: "Por qué la quimioterapia hace caer el pelo",
                    text: "La mayoría de las quimioterapias se dirigen contra las células **que se dividen**, bloqueando la replicación del ADN o el huso mitótico. Por eso afectan también a las células sanas que se dividen deprisa: raíces del pelo, mucosa intestinal, médula ósea. Los efectos secundarios son la consecuencia directa de la diana.",
                    tone: .warning
                ),
                .list([
                    "Tabaco: la primera causa evitable de cáncer en Francia",
                    "Alcohol, sobrepeso, sedentarismo: factores de riesgo importantes",
                    "Rayos UV: las quemaduras solares, sobre todo en la infancia, favorecen los melanomas",
                    "Algunos virus: el virus del papiloma humano, contra el que existe una vacuna",
                ]),
                .paragraph("Todos estos factores actúan del mismo modo: aumentan el número de mutaciones en las células que se dividen. Comprender la mitosis es, por tanto, comprender a la vez ==cómo el cuerpo se construye y se repara== y cómo, a veces, esa misma máquina se descontrola."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "¿Cuáles son las fases del ciclo celular?",
                back: "La interfase, formada por G1 (crecimiento), S (replicación del ADN) y G2 (preparación), y después la fase M: la mitosis, seguida de la citocinesis.",
                figure: .cycle(title: "El ciclo celular", nodes: ["G1", "S", "G2", "M"]),
                chapter: 1
            ),
            DemoCard(
                kind: .choice,
                front: "¿En qué fase de la mitosis se separan las cromátidas hermanas?",
                back: "En la anafase: las cromátidas hermanas migran hacia polos opuestos, y cada polo recibe un cromosoma de una cromátida de cada tipo.",
                choices: ["Profase", "Metafase", "Anafase", "Telofase"],
                answerIndex: 2,
                chapter: 2
            ),
            DemoCard(
                kind: .cloze,
                front: "El ADN de una célula se replica durante la fase … de la interfase.",
                back: "S",
                chapter: 1
            ),
            DemoCard(kind: .basic, front: "¿Cuál es la diferencia entre un procariota y un eucariota?", back: "Un procariota (una bacteria) no tiene núcleo: su ADN está en el citoplasma. Un eucariota tiene un núcleo que encierra su ADN, y orgánulos.", chapter: 0),
            DemoCard(kind: .choice, front: "¿Qué orgánulo produce la mayor parte del ATP de la célula?", back: "La mitocondria, donde tiene lugar la respiración celular.", choices: ["El núcleo", "La mitocondria", "El ribosoma", "El aparato de Golgi"], answerIndex: 1, chapter: 0),
            DemoCard(kind: .cloze, front: "Tras la fase S, cada cromosoma está formado por dos … hermanas unidas por un centrómero.", back: "cromátidas", chapter: 1),
            DemoCard(kind: .basic, front: "¿Qué ocurre con el número de cromosomas y la cantidad de ADN a lo largo del ciclo celular?", back: "La cantidad de ADN se duplica en la fase S (de Q a 2Q) y vuelve a Q en la división. El número de cromosomas sigue siendo 46: pasan de una a dos cromátidas.", hint: "Distingue la cantidad de ADN del número de cromosomas.", chapter: 1),
            DemoCard(kind: .choice, front: "¿Cuántas células, y con cuántos cromosomas, produce la meiosis a partir de una célula humana?", back: "Cuatro células con n = 23 cromosomas, genéticamente distintas entre sí.", choices: ["2 células con 46 cromosomas", "2 células con 23 cromosomas", "4 células con 23 cromosomas", "4 células con 46 cromosomas"], answerIndex: 2, chapter: 3),
            DemoCard(kind: .cloze, front: "Durante la …, los cromosomas se alinean en la placa ecuatorial.", back: "metafase", chapter: 2),
            DemoCard(kind: .basic, front: "¿Qué es un cáncer, a escala celular?", back: "La proliferación descontrolada de células que han acumulado mutaciones: protooncogenes convertidos en oncogenes (acelerador bloqueado) y genes supresores de tumores inactivados (frenos rotos).", chapter: 3),
            DemoCard(kind: .choice, front: "¿Cuántas combinaciones de cromosomas puede recibir un gameto humano solo por la recombinación intercromosómica?", back: "$2^{23}$, es decir, unos 8,4 millones: cada uno de los 23 pares se separa con independencia de los demás.", choices: ["23", "46", "$2^{23}$, unos 8,4 millones", "$23^2$, es decir, 529"], answerIndex: 2, chapter: 3),
            DemoCard(kind: .cloze, front: "La mitosis produce dos células hijas genéticamente … a la célula madre.", back: "idénticas", chapter: 2),
        ]
    )
}
#endif
