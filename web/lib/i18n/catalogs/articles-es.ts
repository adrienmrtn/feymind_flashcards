/** Versión española de las tres páginas de contenido. */
export const articlesEs = {
  shared: {
    navAria: "Páginas",
    nextTitle: "Para leer después",
    ctaTitle: "Deja un curso y mira en qué se convierte.",
    ctaBody: "En el sitio y en el iPhone, con la misma cuenta y el mismo plan.",
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
    buttonsCaption: "Los intervalos los calcula el planificador de la app, no están escritos a mano.",
    planner3:
      "El intervalo está escrito en el botón **antes** de pulsar. Un planificador que decide a solas se desobedece pronto: se marca « fácil » para ir más rápido, la tarjeta se va tres semanas y se redescubre el día del examen.",
    stepMinutes: "{n} min",
    stepJoin: ", luego ",
    paceTitle: "El ritmo: lo que pide la carga, no una cuota",
    pace1: "Micabo no pide ni un número de tarjetas al día ni un presupuesto de minutos. Mira lo que exigen tus fechas hoy, lo sirve entero y dice cuánto va a costar. Un estudiante ve unas {seen} tarjetas en una hora.",
    pace2: "Aquí hubo un tope de tarjetas nuevas, calibrado sobre los {reps} pases que una tarjeta necesita para quedarse. Tenía un fallo decisivo: a tres días de un parcial, rechazaba tarjetas de ese mismo parcial en nombre del ritmo del día. Retener trabajo el día en que más hace falta es equivocarse de oficio.",
    paceNote: "Lo que el plan reparte son los pases hasta el día del examen. Un día perdido no deja hueco: desplaza, y el plan se rehace en el cálculo siguiente.",
    sheetTitle: "La ficha primero, las tarjetas después",
    sheet1:
      "Una flashcard supone que ya se ha entendido. Ponerse a prueba sobre una idea no leída es aprender de memoria una respuesta sin saber de qué habla — la tarjeta acertará, el examen no.",
    sheetFigure: "El documento depositado se convierte en **una ficha**: el curso en orden, los pasajes que importan marcados. De ahí salen después las tarjetas. Es el mismo componente de ficha que en la app, sobre el curso de demostración.",
    sheet2:
      "Por eso Micabo escribe primero **la ficha** a partir de tu documento: el curso en orden, los pasajes que importan marcados. Las tarjetas salen de esa ficha, no del documento bruto. Lees, luego te pones a prueba.",
    sheet3:
      "Micabo no define nunca un término del que el documento no hable. Cuando el contexto no decide, la palabra dudosa no aparece en la ficha: una definición inventada es perfectamente creíble, y por eso es peligrosa.",
    formatsTitle: "Cuatro formas de preguntarte sobre la misma ficha",
    formats1: "El recuerdo activo no se limita al anverso y el reverso. Sobre una misma ficha, Micabo plantea tests, textos con hueco y tarjetas, y compone simulacros puntuados. Las preguntas salen de tus documentos, y el planificador las trata todas igual: una respuesta recuperada aleja la siguiente.",
    formatsFigure: "Un test se reconoce por sus viñetas, un texto con hueco por su línea vacía, una tarjeta por su anverso mudo. **Los cuatro formatos salen de la misma ficha**, y se puntúan en la misma escala.",
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
    dailyTitle: "Cada jornada lleva un trabajo con nombre",
    daily1: "Un plan que dice «repasar 30 minutos» no se distingue de un temporizador. El de Micabo dice lo que hay que hacer: un test sobre el capítulo 3, un simulacro, una explicación en voz alta, un día de descanso. Abres la app y la jornada ya está escrita.",
    dailyFigure: "El plan se lee en el sentido del tiempo, y la última línea es el examen. **Un día perdido desplaza el trabajo, no abre un agujero**: el plan se rehace en el siguiente cálculo.",
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
    metaDescription: "Anki es abierto, probado y excelente. Micabo escribe las tarjetas a partir de tu curso y replanifica todo alrededor de una fecha de examen. Una comparación honesta, incluso donde gana Anki.",
    eyebrow: "Comparación",
    h1: "Micabo o Anki: lo que cambia de verdad",
    lead1: "Anki es un programa muy bueno. Es abierto, tiene veinte años de recorrido y una comunidad que lo ha documentado todo. Si ya lo usas y te va bien, no tienes ninguna razón para cambiar.",
    lead2:
      "La diferencia no está en la planificación — **es el mismo SM-2**. Está antes, en el tiempo que hace falta para tener tarjetas, y después, en lo que ocurre cuando cae una fecha de examen.",
    tableTitle: "Línea a línea",
    tableLead: "Tres líneas van para Anki, y están escritas tal cual.",
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
    rowQuestions: "Las formas de preguntar",
    rowQuestionsMicabo: "Tarjetas, tests, textos con hueco, simulacros puntuados, explicación en voz alta.",
    rowQuestionsAnki: "El anverso y el reverso, y los tipos de tarjeta que uno construye por su cuenta.",
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
    costTitle: "Lo que Anki cuesta de verdad: tiempo",
    cost1:
      "Un mazo de Anki útil para un curso de facultad son dos a cuatro horas de tecleo por capítulo: cortar, formular una pregunta por idea, no apilar cinco elementos en una tarjeta. Ese trabajo enseña — negarlo sería deshonesto — pero es el trabajo que hace que se abra Anki en septiembre y ya no en noviembre.",
    costFigure: "Apuntes, fotos, Word, PowerPoint, vídeo, audio: **todo entra tal cual**, y un mazo de Anki también. Desaparece el tecleo, queda la relectura.",
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
    pickAnki: "**Quédate en Anki** si te gusta ajustar tu planificador, si quieres FSRS, si estás en Android, o si te importa una herramienta abierta cuyos archivos te pertenecen.",
    pickMicabo:
      "**Prueba Micabo** si lo que te frena no es el repaso sino fabricar las tarjetas, o si tus repasos giran en torno a fechas de examen y no a un flujo continuo.",
    pickBoth:
      "Y si dudas: [[method]] es la misma en los dos. Es ella la que hace el trabajo, no el programa que la lleva.",
    methodLink: "el método",
  },
} as const;
