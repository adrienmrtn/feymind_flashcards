export const legalEs = {
  backHome: "Volver al inicio",
  eyebrow: "Micabo · iPhone y sitio",
  updated: "Última actualización: {date}.",
  updatedDate: "2 de septiembre de 2026",
  privacy: {
    metaTitle: "Privacidad",
    metaDescription:
      "Lo que Micabo retiene de usted, en el iPhone y en el sitio, y lo que puede hacer con ello.",
    heading: "Política de privacidad",
    linkLabel: "política de privacidad",
    intro1:
      "Esta política describe los datos que Micabo trata cuando utiliza el sitio [[site]] o la aplicación iPhone (identificador {bundle}). Ambos clientes comparten la misma cuenta y la misma base. También se aplica si aún no tiene cuenta y solo consulta el sitio.",
    intro2:
      "El responsable del tratamiento es {editor}, que edita Micabo. Para cualquier pregunta, corrección o supresión: [[contact]].",
    whatTitle: "Qué es Micabo",
    whatBody:
      "Micabo transforma un curso (PDF, foto, documento, vídeo) en una ficha y en flashcards, y las hace volver antes de que las olvide. Un modo examen aprieta las revisiones al acercarse una fecha. Puede compartir un curso con amigos o guardarlo para usted.",
    dataTitle: "Qué datos tratamos",
    dataAccount:
      "**La cuenta.** Dirección de correo, identificadores que proporcionan Apple o Google si elige esas conexiones, y un nombre de usuario. No almacenamos su contraseña: la conexión por correo se hace con un enlace, no con un secreto que guardaríamos.",
    dataSchool:
      "**El recorrido escolar.** País de estudios, nivel, asignaturas, centro si lo indica. Sirve para escribir la ficha en el idioma y el sistema adecuados, y para mostrarle a los compañeros del mismo centro si un curso está compartido.",
    dataCourses:
      "**Sus cursos.** Los archivos o enlaces que deposita, el texto extraído, las fichas y las tarjetas generadas, las imágenes de esquemas, los exámenes (nombre, fecha, nota objetivo) y el historial de revisión (cuándo vuelve una tarjeta, cómo la ha valorado).",
    dataFriends:
      "**Los amigos.** Las solicitudes de amistad, su lista de amigos y la visibilidad que pone en cada curso al importarlo: solo usted, sus amigos o los compañeros de su centro. No existe un catálogo público en el que un desconocido tropiece con sus fichas.",
    dataSubscription:
      "**La suscripción.** El estado de su acceso Pro (activo, prueba, cancelado), no el número de su tarjeta. El pago lo cobra Apple en el iPhone y Stripe en el sitio. RevenueCat sostiene el derecho, para que el iPhone y el navegador coincidan.",
    dataWaitlist:
      "**La lista de espera.** Si deja su dirección antes de tener cuenta, la guardamos para avisarle de la apertura, con la página de la que viene. No está ligada a una cuenta y no es visible desde la aplicación.",
    dataFeedback:
      "**Los comentarios.** Si envía un error o una idea desde la app, guardamos el mensaje, el tipo (error o idea) y el vínculo con su cuenta, para responder. Permanecen 24 meses y luego se borran. No sirven para perfilarle.",
    dataUsage:
      "**El uso de las generaciones.** Un contador por día y por función (ficha, tarjetas, explicación), sin el contenido del curso. Sirve para limitar abusos, no para perfilarle.",
    dataDirectory:
      "**El directorio.** Su nombre de usuario y, si lo ha indicado, su centro. Eso es lo que ve un amigo o un compañero, no su correo ni sus preferencias.",
    dataDevice:
      "**Lo que queda en el aparato.** En el iPhone, algunas piezas (imágenes de oclusión, audio de una tarjeta) pueden no salir nunca del teléfono. Las respuestas del recorrido de bienvenida quedan primero en el aparato y se escriben en la base una vez abierta la cuenta.",
    dataNoSell:
      "No vendemos sus datos. No mostramos publicidad. No entrenamos un modelo de lenguaje con sus cursos, salvo que un ajuste explícito lo proponga un día — y ese ajuste no existe hoy.",
    whyTitle: "Por qué los tratamos",
    whyLead: "Las bases jurídicas, en el sentido del RGPD:",
    whyContract:
      "**La ejecución del contrato** — crear la cuenta, importar un curso, escribir la ficha y las tarjetas, revisarlas, sincronizar iPhone y sitio, gestionar la suscripción.",
    whyLegitimate:
      "**El interés legítimo** — asegurar el servicio, impedir abusos, diagnosticar una avería y leer los comentarios que nos envía. Ese interés no pasa por delante del suyo: el aislamiento está en la base, no solo en la aplicación.",
    whyLegal:
      "**La obligación legal** — conservar lo que la facturación o la contabilidad exigen, el tiempo prescrito.",
    whyConsent:
      "**El consentimiento** — cuando elige compartir un curso, abrir la cámara o conectarse con Apple o Google.",
    accessTitle: "Quién tiene acceso",
    accessBody:
      "Sus cursos solo los puede leer usted, salvo que los haya compartido. Cada consulta a la base se evalúa con su identidad: no existe una consulta que pueda pedir los cursos de otra persona. Los comentarios que envía los lee el equipo, en [[contact]]. Nadie más tiene acceso desde la aplicación.",
    accessLead:
      "Algunos prestadores ven una parte de los datos, solo para prestar el servicio:",
    accessSupabase:
      "**Supabase** (Unión Europea, región Estocolmo) — cuenta, base, archivos.",
    accessVercel:
      "**Vercel** — alojamiento del sitio y registros técnicos (dirección IP, URL). El tratamiento puede tener lugar fuera de la Unión Europea, bajo las cláusulas contractuales tipo del prestador.",
    accessApple:
      "**Apple y Google** — si se conecta con ellos o si paga en el App Store.",
    accessStripe: "**Stripe** — pago en el sitio.",
    accessRevenuecat:
      "**RevenueCat** — estado de la suscripción, compartido entre iPhone y sitio.",
    accessFal:
      "**fal.ai y los modelos que llama** (hoy, modelos de lenguaje, sobre todo de Google) — el texto o la imagen de su curso, el tiempo de escribir la ficha o las tarjetas. No tienen derecho a usarlos para otra cosa que esa generación.",
    accessYoutube:
      "**YouTube / Google** — si importa un vídeo, leemos sus metadatos y subtítulos.",
    accessTransfer:
      "Algunos de estos prestadores están establecidos fuera de la Unión Europea. La transferencia solo tiene entonces lugar para prestar el servicio, y se apoya en las garantías previstas por el RGPD (decisión de adecuación o cláusulas contractuales tipo del prestador).",
    cookiesTitle: "Cookies y rastreadores",
    cookiesWeb:
      "El sitio coloca las cookies necesarias para la sesión (reconocerle de una página a otra una vez conectado) y una cookie de preferencia de idioma de interfaz (`micabo.ui_locale`), guardada un año, que retiene el francés, el alemán, el español o el turco. No colocamos cookie de medición de audiencia, ni de publicidad, ni de rastreo entre sitios. Por eso no hay banner de consentimiento: no hay nada que rechazar de ese lado.",
    cookiesIos:
      "El iPhone no usa cookies. Guarda un token de sesión en el llavero del aparato.",
    retentionTitle: "Cuánto tiempo los guardamos",
    retentionWhile:
      "Mientras exista la cuenta. Los comentarios se van a más tardar a los 24 meses. Si la elimina, desde Ajustes en el sitio o en la app iPhone, o escribiéndonos, borramos el perfil, los cursos (incluido el texto extraído), las fichas, las tarjetas, el historial, los exámenes, las amistades, los contadores de uso, los comentarios y la dirección que haya dejado en la lista de espera.",
    retentionShared:
      "Un curso que ha compartido desaparece para sus amigos cuando lo elimina. Un amigo que ya ha revisado sus tarjetas conserva su propio historial, no su documento.",
    retentionAfter:
      "Tras la eliminación, queda en los prestadores lo que la ley o su contrato impone: facturas de Stripe o Apple, identificador de suscripción de RevenueCat, registros técnicos (Vercel, Supabase) unas semanas. fal.ai recibe el texto el tiempo de escribir la ficha; no le pedimos que lo conserve.",
    rightsTitle: "Sus derechos",
    rightsBody:
      "Puede acceder a sus datos, corregirlos, exportarlos, oponerse a un tratamiento o pedir la supresión. Para descargar una copia: Ajustes → «Descargar mis datos». Para borrar la cuenta: Ajustes → «Eliminar la cuenta», en el sitio o en la app iPhone. También puede escribir a [[contact]]. Respondemos en el plazo de un mes.",
    rightsCnil: "También puede presentar una reclamación ante la CNIL (cnil.fr).",
    minorsTitle: "Menores",
    minorsBody:
      "Micabo se dirige a estudiantes, también de bachillerato. No pedimos la fecha de nacimiento. Si tiene menos de quince años, el uso del servicio debe hacerse con el acuerdo de un titular de la patria potestad. No usamos los datos de un menor para publicidad ni para un perfilado comercial.",
    iosTitle: "El iPhone, además del sitio",
    iosBody:
      "La app puede pedir acceso a sus fotos o a la cámara para importar un curso. No es obligatorio: el sitio acepta un archivo depositado. Las notificaciones, si las autoriza, solo sirven para recordarle una revisión. La misma cuenta abre la app y el sitio.",
    changesTitle: "Modificaciones",
    changesBody:
      "Si esta política cambia de forma sustancial, actualizamos la fecha al inicio de la página. El uso continuado después de esa fecha vale para la nueva versión, salvo que la ley exija un acuerdo distinto.",
    changesAlso: "Las [[terms]] completan este texto.",
  },
  terms: {
    metaTitle: "Condiciones de uso",
    metaDescription:
      "Las reglas del servicio Micabo, para el iPhone y el sitio: cuenta, cursos, suscripción, responsabilidades.",
    heading: "Condiciones de uso",
    linkLabel: "condiciones de uso",
    intro1:
      "Estas condiciones rigen el uso de Micabo — el sitio [[site]] y la aplicación iPhone ({bundle}). Al crear una cuenta o al usar el servicio, las acepta. Si no está de acuerdo, no abra una cuenta.",
    intro2: "El editor es {editor}. Contacto: [[contact]].",
    serviceTitle: "El servicio",
    serviceBody:
      "Micabo lee un documento de curso que usted deposita y escribe una ficha y flashcards. Las hace volver según una repetición espaciada (la misma regla SM-2 en el iPhone y en el sitio). Puede fijar la fecha de un examen: el plan de revisión se aprieta entonces hacia ese día. Una misma cuenta abre los dos clientes.",
    servicePro:
      "Una parte del servicio es accesible sin suscripción. El acceso Pro (cursos y tarjetas más allá del techo gratuito, según la oferta mostrada en el momento de la compra) es de pago.",
    accountTitle: "La cuenta",
    accountBody:
      "Puede conectarse con Apple, Google o un enlace enviado por correo. Es responsable del acceso a su buzón y a esas cuentas de terceros. Una sola cuenta por persona.",
    accountDelete:
      "Puede eliminar la cuenta desde Ajustes, en el sitio o en la app iPhone. Eso borra sus cursos, sus tarjetas y su historial. Las compras ya cobradas por Apple o Stripe siguen sujetas a sus reglas de reembolso.",
    coursesTitle: "Sus cursos",
    coursesOwn:
      "Usted conserva la propiedad de lo que deposita. Solo nos da el derecho, limitado y revocable, de leerlo, almacenarlo y transformarlo en ficha y en tarjetas, para prestarle el servicio — incluido enviarlo a un modelo de lenguaje el tiempo de la generación.",
    coursesRights:
      "Solo deposita documentos que tiene derecho a usar. Un temario de su profesor, sus apuntes, un vídeo cuyo import está autorizado: sí. Una obra entera copiada, el trabajo de otro, un contenido ilegal: no. Podemos retirar un curso o cerrar una cuenta que rompa esta regla.",
    coursesShare:
      "La visibilidad se decide al importar. Un curso privado se queda entre usted. Un curso compartido solo lo ven las personas que ha elegido (amigos o compañeros del centro). No es una biblioteca abierta a todos.",
    notTitle: "Lo que Micabo no es",
    notBody:
      "La ficha y las tarjetas se generan automáticamente. Pueden equivocarse, omitir un pasaje o leer mal un escaneo. Micabo no es un profesor ni una garantía de nota. Usted sigue siendo responsable de lo que aprende y de lo que entrega el día del examen.",
    notInvent:
      "Nos esforzamos en no inventar una definición cuando el documento no la lleva. Eso no hace el resultado infalible.",
    subTitle: "La suscripción",
    subPrices:
      "Los precios, la duración y la prueba eventual son los mostrados antes del pago. Pueden cambiar para las compras nuevas; una suscripción ya en curso conserva sus condiciones hasta su renovación.",
    subIos:
      "**En el iPhone**, el pago pasa por el App Store. La cancelación, la renovación y los reembolsos siguen las reglas de Apple. Gestione la suscripción en los ajustes de su cuenta Apple.",
    subWeb:
      "**En el sitio**, el pago pasa por Stripe. La cancelación se hace desde el espacio de facturación indicado en el perfil, o escribiéndonos. Una prueba, si se ofrece, solo se convierte en pago si la deja llegar a su término.",
    subBoth:
      "El acceso Pro comprado de un lado vale del otro: la misma cuenta es Pro en el iPhone y en el sitio. Un incidente de pago puede abrir un periodo de gracia; no cerramos el acceso a la primera hora.",
    forbidTitle: "Lo que no hace",
    forbidHarm:
      "Usar el servicio para perjudicar a alguien, acosar o hacer trampas de un modo que viole el reglamento de su centro.",
    forbidAccess:
      "Intentar acceder a los cursos de otra cuenta, eludir el aislamiento o saturar el servicio a propósito.",
    forbidResell:
      "Revender el acceso, extraer el servicio con un robot más allá de un uso humano normal, o copiar Micabo para hacer un producto competidor a partir de nuestras generaciones.",
    forbidIllegal:
      "Depositar contenidos ilegales, de odio o que atenten contra la vida privada de terceros.",
    availTitle: "Disponibilidad",
    availBody:
      "Hacemos lo posible para que el iPhone y el sitio sigan accesibles. Un mantenimiento, una avería de un prestador (alojamiento, modelo, tienda) o un error de generación puede interrumpir el servicio. No ofrecemos garantía de resultado escolar ni de disponibilidad ininterrumpida.",
    liabilityTitle: "Responsabilidad",
    liabilityConsumer:
      "Si es consumidor, sus derechos legales (garantía, mediación, cláusulas abusivas) se aplican y estas condiciones no los apartan.",
    liabilityLimit:
      "Más allá, Micabo no es responsable de las notas obtenidas, de una ficha incompleta, de un olvido el día D o de un daño indirecto (tiempo perdido, examen fallido). Nuestra responsabilidad, si se retuviera por un incumplimiento que nos sea imputable, se limita al importe que nos ha abonado en los últimos doce meses — salvo falta grave, dolo o lesión a la integridad de la persona.",
    minorsTitle: "Menores",
    minorsBody:
      "Si tiene menos de quince años, un titular de la patria potestad debe aceptar estas condiciones y vigilar el uso. Compartir un curso con amigos sigue bajo su responsabilidad y bajo la de ellos.",
    lawTitle: "Derecho aplicable",
    lawBody:
      "Estas condiciones se rigen por el derecho francés. En caso de litigio, y tras un intento de resolución por escrito a [[contact]], son competentes los tribunales franceses — sin perjuicio de las normas de protección del consumidor que le fueran más favorables.",
    changesTitle: "Modificaciones",
    changesBody:
      "Podemos actualizar estas condiciones. La fecha al inicio de la página es la que cuenta. Un cambio que afecte al precio de una suscripción en curso se le anuncia antes de la renovación.",
    changesAlso: "La [[privacy]] describe el tratamiento de sus datos.",
  },
} as const;
