/** Versión española de las tres páginas de contenido. */
export const articlesEs = {
  shared: {
    navAria: "Páginas",
    nextTitle: "Para leer después",
    ctaTitle: "Deja un curso y mira en qué se convierte.",
    ctaBody: "El primero es gratis, en el sitio y en el iPhone.",
  },
  method: {
    metaTitle: "El método: repetición espaciada y recuerdo activo",
    metaDescription:
      "Releer un curso no lo hace quedar. Lo que se recupera de memoria se queda, sobre todo si la pregunta vuelve justo antes de olvidarla. Cómo aplica Micabo la repetición espaciada, con los intervalos de verdad.",
    h1: "Releer no basta. Acordarse, sí.",
    lead1:
      "Una página releída cuatro veces da una impresión de dominio que no sobrevive al examen. Lo que avanza es el reconocimiento — « sí, esto ya lo he visto » — y el reconocimiento no es lo que pide un examen.",
    lead2:
      "Lo que se queda es lo que hubo que **sacar de memoria**, y lo que vuelve **justo antes de olvidarlo**. Dos ideas antiguas, medidas desde hace más de un siglo, y dos ideas pesadas de aplicar a mano. Ese es todo el trabajo de Micabo.",
    activeTitle: "El recuerdo activo: la pregunta antes que la respuesta",
    active1:
      "Ponerse a prueba es más eficaz que releer, incluso cuando uno se equivoca. El esfuerzo de recuperar es lo que refuerza la huella: una respuesta que se busca tres segundos vale más que una que se lee en uno.",
    active2:
      "Por eso una ficha lleva **una sola cosa que recuperar**. Una tarjeta que pide cinco elementos de golpe no se puede puntuar: se recuerdan tres, y no hay un botón para « tres quintos ».",
    spacingTitle: "El espaciado: volver en el último momento útil",
    spacing1:
      "Sin repaso, lo que se retiene de un curso cae a casi nada en un mes. Cada recuerdo pone el contador a cien — y la bajada que sigue es **más lenta que la anterior**. Repasar en el momento justo no pide más tiempo: pide menos, a medida que la memoria se estabiliza.",
    spacing2:
      "Lo que importa no es la forma de cada curva, es **el punto en que se separan**: el primer repaso. Lo que la repetición espaciada automatiza es la elección de ese instante, tarjeta a tarjeta.",
    plannerTitle: "Lo que Micabo calcula en cada nota",
    planner1:
      "Micabo planifica con **SM-2**, la regla de Anki en sus ajustes por defecto. Una tarjeta nueva pasa por peldaños cortos — {steps} — antes de salir a días. Luego cada nota multiplica el intervalo por una facilidad propia de la tarjeta, que parte de {ease} y se mueve según tus respuestas.",
    planner2:
      "Cuatro botones, no dos: « lo sé / no lo sé » no distingue la tarjeta recuperada con esfuerzo de la que vino sola, y es justo ese margen el que decide la fecha siguiente. Esto es lo que anuncian los cuatro botones en una tarjeta nueva:",
    planner3:
      "El intervalo está escrito en el botón **antes** de pulsar. Un planificador que decide a solas se desobedece pronto: se marca « fácil » para ir más rápido, la tarjeta se va tres semanas y se redescubre el día del examen.",
    stepMinutes: "{n} min",
    stepJoin: ", luego ",
    paceTitle: "El ritmo: minutos, no un cupo de tarjetas",
    pace1:
      "El ajuste que pide Micabo es un tiempo al día, no un número de tarjetas. A {minutes} minutos — el valor por defecto — se ven unas {seen} tarjetas, y el producto solo introduce **{perDay} nuevas**.",
    pace2:
      "La diferencia entre las dos es el núcleo del ajuste: una tarjeta nueva no cuesta un paso, cuesta unos {reps} antes de quedar. Meter cincuenta hoy porque hay tiempo es pedirse una deuda de sesiones para las tres semanas siguientes — y así se abandona un mazo.",
    paceNote:
      "El tope del día no bloquea los repasos debidos: esos pasan todos. Solo raciona la introducción de tarjetas nuevas. Un día perdido no abre un agujero, desplaza.",
    sheetTitle: "La ficha primero, las tarjetas después",
    sheet1:
      "Una flashcard supone que ya se ha entendido. Ponerse a prueba sobre una idea no leída es aprender de memoria una respuesta sin saber de qué habla — la tarjeta acertará, el examen no.",
    sheet2:
      "Por eso Micabo escribe primero **la ficha** a partir de tu documento: el curso en orden, los pasajes que importan marcados. Las tarjetas salen de esa ficha, no del documento bruto. Lees, luego te pones a prueba.",
    sheet3:
      "Micabo no define nunca un término del que el documento no hable. Cuando el contexto no decide, la palabra dudosa no aparece en la ficha: una definición inventada es perfectamente creíble, y por eso es peligrosa.",
    limitsTitle: "Lo que el método no hace",
    limits1:
      "La repetición espaciada coloca los repasos. No entiende por ti, no redacta un ensayo y no recupera un capítulo empezado la víspera: no hay espaciado posible en una noche.",
    limits2:
      "También ignora las fechas, por construcción: SM-2 no sabe que hay un examen dentro de tres semanas. Eso es exactamente lo que el [[exam]] viene a corregir.",
    examLink: "modo examen",
  },
  exam: {
    metaTitle: "El modo examen: das la fecha, el plan se aprieta",
    metaDescription:
      "La repetición espaciada ignora el día D. El modo examen de Micabo le da una fecha tope, aprieta los pasos al acercarse la prueba e impide que una tarjeta se vaya más allá.",
    h1: "Das la fecha. Micabo lo reorganiza todo.",
    lead1:
      "La repetición espaciada coloca cada tarjeta en el último momento útil, sin fin. No sabe que hay un parcial el 14. Una tarjeta marcada « fácil » hoy se va tres semanas, aunque la prueba sea dentro de diez días — y no vuelve antes.",
    lead2:
      "El modo examen da al planificador lo que le falta: **una fecha tope**. Pones el día D, él replanifica el mazo alrededor.",
    trapTitle: "Por qué un plan normal se deja pillar",
    trap1:
      "Un mazo de doscientas tarjetas en repetición espaciada es perfecto para un control continuo y malo para una fecha fija. Tres cosas se tuerce: unas tarjetas caen después del examen, otras nunca se introdujeron, y las más frágiles vuelven demasiado pronto para servir el día D.",
    trap2:
      "La respuesta a mano es repasarlo todo la víspera. Es exactamente lo que el método evita: una sesión de trescientas tarjetas en una noche no deja nada al día siguiente, y se sabe antes de empezar.",
    capTitle: "Ninguna tarjeta se va más allá del día D",
    cap1:
      "Es la regla que lo sostiene todo, y es más radical de lo que parece. Durante un examen activo, el intervalo que recibe una tarjeta está **limitado a la fecha de la prueba**.",
    cap2:
      "Sin ese tope, la primera respuesta buena deshace el plan: la tarjeta se va tres semanas y sale del campo. Con él, vuelve una última vez antes del día D. Los intervalos anunciados bajo los botones son por eso más cortos de lo habitual, y la sesión lo dice arriba — si no, parecería el planificador roto.",
    planTitle: "El plan, anunciado antes de aplicarse",
    plan1:
      "Micabo muestra la proyección **antes** de mover nada: cuántas tarjetas están cubiertas, cuántos pasos colocados, en cuántos días. Una replanificación que se descubre después es una que se cancela.",
    plan2:
      "La carga se aprieta hacia el final sin amontonarse en la víspera: los últimos pasos se reparten en los {days} últimos días, desfasados de una tarjeta a otra.",
    intensityTitle: "Tres intensidades, según la nota que quieres",
    intensityLead:
      "Cuántas veces debe volver cada tarjeta antes de la prueba no es la misma pregunta para « quiero aprobar » y para « quiero la máxima ». Pones la nota objetivo, Micabo deduce la intensidad:",
    intensityLight: "Ligera",
    intensityStandard: "Normal",
    intensityIntense: "Intensiva",
    intensityPasses: "pasos por tarjeta",
    intensityScale:
      "La escala de notas sigue tu país de estudios: un 20 francés, un 100 quebequés y un A-Level británico no se comparan, y un control que valiera en todas partes no valdría en ninguna.",
    severalTitle: "Varios exámenes, varios cursos",
    several1:
      "Un examen cubre los cursos que le das, y un curso puede estar en varios exámenes. Cuando dos fechas se disputan la misma tarjeta, **la más cercana** pone el tope: es la primera cota, y respetar la segunda primero fallaría las dos.",
    severalNote:
      "Pasado el día D, el examen deja de forzar y el mazo vuelve a su planificación normal. Nada que desactivar: una fecha pasada ya no es una fecha.",
    limitsTitle: "Lo que el modo examen no hace",
    limits1:
      "No fabrica tiempo. Declarar un examen para mañana sobre doscientas tarjetas nuevas da un plan honesto e insostenible, y Micabo lo muestra tal cual en vez de tranquilizar.",
    limits2:
      "Tampoco sustituye al método: [[method]] hacen el trabajo, el modo examen solo les da un plazo. Si vienes de Anki, la [[anki]] dice exactamente qué cambia.",
    methodLink: "el recuerdo activo y el espaciado",
    ankiLink: "comparación",
  },
  anki: {
    metaTitle: "Micabo o Anki: lo que cambia de verdad",
    metaDescription:
      "Anki es gratis, abierto y excelente. Micabo escribe las tarjetas a partir de tu curso y replanifica todo alrededor de una fecha de examen. Comparación honesta, también donde Anki gana.",
    eyebrow: "Comparación",
    h1: "Micabo o Anki: lo que cambia de verdad",
    lead1:
      "Anki es un muy buen programa. Es gratis, abierto, tiene veinte años de recorrido y una comunidad que lo ha documentado todo. Si ya lo usas y te vale, no tienes ninguna razón para cambiar.",
    lead2:
      "La diferencia no está en la planificación — **es el mismo SM-2**. Está antes, en el tiempo que hace falta para tener tarjetas, y después, en lo que ocurre cuando cae una fecha de examen.",
    tableTitle: "Línea a línea",
    tableLead:
      "Tres líneas se las lleva Anki, entre ellas la más importante para mucha gente: no cuesta nada.",
    tableCaption: "Comparación de Micabo y Anki, criterio a criterio.",
    colCriterion: "Criterio",
    rowAlgo: "El algoritmo",
    rowAlgoMicabo: "SM-2, con los ajustes por defecto de Anki.",
    rowAlgoAnki: "SM-2 históricamente, FSRS hoy, y los dos se ajustan.",
    rowWrite: "Escribir las tarjetas",
    rowWriteMicabo:
      "El curso se vuelve ficha, la ficha se vuelve tarjetas. Lees y corriges.",
    rowWriteAnki: "A ti. Ahí se va la mayor parte del tiempo.",
    rowDate: "Una fecha de examen",
    rowDateMicabo: "El mazo se replanifica alrededor del día D, y nada se va más allá.",
    rowDateAnki: "No hay idea de fecha tope. Se adelanta el mazo a mano.",
    rowPrice: "El precio",
    rowPriceMicabo:
      "Un curso gratis, {cards} tarjetas por sesión. Más allá, {price} al año.",
    rowPriceAnki: "Gratis y de código abierto, salvo la app de iPhone.",
    rowPlatforms: "Las plataformas",
    rowPlatformsMicabo: "iPhone y navegador, la misma cuenta en los dos lados.",
    rowPlatformsAnki: "Ordenador, Android, iPhone, navegador.",
    rowDecks: "Los mazos ya hechos",
    rowDecksMicabo: "Ningún catálogo. Tus cursos, y los que comparten tus amigos.",
    rowDecksAnki: "Miles de mazos públicos, de calidad desigual.",
    rowFriends: "Los cursos de tus compañeros",
    rowFriendsMicabo: "Un curso compartido se retoma de un gesto y se vuelve tuyo.",
    rowFriendsAnki: "Un archivo que hay que enviarse.",
    rowStart: "La puesta en marcha",
    rowStartMicabo: "Un documento dejado, una ficha que leer, una sesión esa misma noche.",
    rowStartAnki: "Ajustes que entender antes de la primera tarjeta.",
    costTitle: "El coste de Anki no es su precio",
    cost1:
      "Un mazo de Anki útil para un curso de facultad son dos a cuatro horas de tecleo por capítulo: cortar, formular una pregunta por idea, no apilar cinco elementos en una tarjeta. Ese trabajo enseña — negarlo sería deshonesto — pero es el trabajo que hace que se abra Anki en septiembre y ya no en noviembre.",
    cost2:
      "Micabo asume ese paso. El curso se vuelve una ficha ordenada, luego tarjetas sacadas de esa ficha. Lees, corriges lo falso, borras lo que no sirve. Sigue siendo tu trabajo, pero empieza en la relectura en vez de en la página en blanco.",
    costNote:
      "El reverso es real: una tarjeta generada puede estar mal formulada o salir de un escaneo mal leído. Por eso la ficha va antes que las tarjetas, y Micabo no define un término del que el documento no habla. Una ficha que se equivoca no parece un error.",
    dateTitle: "Lo que Anki no hace: la fecha",
    date1:
      "Esa es la diferencia de mecánica de verdad. La repetición espaciada coloca cada tarjeta en el último momento útil, sin fin. No sabe que hay un parcial el 14: una tarjeta marcada « fácil » se va tres semanas y no vuelve antes de la prueba.",
    date2:
      "En Anki se sale adelantando el mazo a mano, o repasándolo todo la víspera. En Micabo pones la fecha y el mazo se replanifica alrededor, con un tope que impide que una tarjeta se vaya más allá del día D. [[exam]] detalla cómo.",
    examLink: "El modo examen",
    pickTitle: "Cuál coger",
    pickAnki:
      "**Quédate en Anki** si te gusta ajustar el planificador, si quieres FSRS, si estás en Android, o si quieres una herramienta gratis y abierta cuyos archivos te pertenecen.",
    pickMicabo:
      "**Prueba Micabo** si lo que te frena no es el repaso sino fabricar las tarjetas, o si tus repasos giran en torno a fechas de examen y no a un flujo continuo.",
    pickBoth:
      "Y si dudas: [[method]] es la misma en los dos. Es ella la que hace el trabajo, no el programa que la lleva.",
    methodLink: "el método",
  },
} as const;
