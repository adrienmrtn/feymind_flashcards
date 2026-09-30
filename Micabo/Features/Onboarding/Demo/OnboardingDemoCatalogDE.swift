import Foundation

// MARK: - The four courses, in German

/// The demo courses, in German. High-school level: what a teacher would write on the
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
    static let german: [OnboardingDemoCourse] = [
        coldWarDE, photosynthesisDE, derivativesDE, energyDE,
    ]

    // MARK: History: the Cold War

    private static let coldWarDE = OnboardingDemoCourse(
        id: "history-cold-war",
        emoji: "🏛️",
        subject: "Histoire",
        title: "Der Kalte Krieg (1947–1991)",
        summary: "Zwei Blöcke, zwei Modelle und nie ein direkter Krieg: vierundvierzig Jahre voller Spannungen, Krisen und Entspannung, bis die Mauer fiel.",
        accentIndex: 3,
        chapters: [
            DemoChapter(title: "Zwei Blöcke stehen sich gegenüber (1947–1953)", blocks: [
                .paragraph("1945 verbindet die Sieger des Krieges nichts mehr. Die USA und die UdSSR, Verbündete gegen das nationalsozialistische Deutschland, werden zu ==den beiden Supermächten== einer Welt, die in zwei Teile zerfällt. Alles, was folgt – vierundvierzig Jahre Spannungen –, erklärt sich aus diesem Bruch."),
                .heading("Eine zweigeteilte Welt"),
                .paragraph("Die Konferenzen von Jalta (Februar 1945) und Potsdam (Juli 1945) sollten den Frieden ordnen. Stattdessen ordnen sie die Teilung: Osteuropa, von der Roten Armee befreit, bleibt unter sowjetischer Kontrolle; Westeuropa, von den Angloamerikanern befreit, gerät in den Einflussbereich Washingtons. Schon im März 1946 spricht Churchill von einem **Eisernen Vorhang**, der sich über den Kontinent gesenkt hat."),
                .callout(
                    title: "Kalter Krieg",
                    text: "Eine Konfrontation **ohne direkten Krieg** zwischen den USA und der UdSSR von 1947 bis 1991, ausgetragen mit wirtschaftlichem Druck, Propaganda, Wettrüsten und Stellvertreterkriegen.",
                    tone: .definition
                ),
                .paragraph("Das Wort „kalt“ sagt das Wesentliche: Die beiden Giganten kämpfen nie gegeneinander. Sie stoßen überall sonst aufeinander, und mit allen anderen Mitteln. Was sie trennt, ist nicht nur eine Machtrivalität, sondern ==zwei Arten, eine Gesellschaft zu organisieren==, die miteinander unvereinbar sind."),
                .figure(.split(
                    title: "Zwei Modelle",
                    left: DemoColumn(title: "Westblock", items: ["USA", "Liberale Demokratie", "Marktwirtschaft", "Marshallplan (1947)", "NATO (1949)"]),
                    right: DemoColumn(title: "Ostblock", items: ["UdSSR", "Einparteiensystem", "Planwirtschaft", "Kominform (1947)", "Warschauer Pakt (1955)"])
                )),
                .paragraph("Im Westen gibt es freie Wahlen, mehrere Parteien, eine unabhängige Presse und eine Wirtschaft, in der Unternehmen privat und Preise frei sind. Im Osten eine einzige Partei, die Kommunistische Partei, die Staat, Presse und Wirtschaft kontrolliert: Der in Moskau beschlossene Plan legt fest, was produziert wird und zu welchem Preis. Jedes Lager sieht sich als die freie Welt und beschreibt das andere als Bedrohung."),
                .heading("Eindämmung"),
                .paragraph("Im März 1947 verspricht Präsident Truman, jedem vom Kommunismus bedrohten Land zu helfen: Das ist die ==bleu|Truman-Doktrin==, auch *Containment* (Eindämmung) genannt – den Kommunismus dort aufhalten, wo er ist, ohne ihn dort stürzen zu wollen, wo er herrscht. Der Marshallplan finanziert drei Monate später mit 13 Milliarden Dollar den Wiederaufbau Westeuropas und bindet es an das amerikanische Lager. Die UdSSR antwortet, indem sie ihren Satellitenstaaten verbietet, ihn anzunehmen, und gründet das Kominform, um die kommunistischen Parteien zu koordinieren."),
                .timeline(title: "Die ersten Jahre", events: [
                    DemoEvent(date: "1947", label: "Truman-Doktrin und Marshallplan"),
                    DemoEvent(date: "1948", label: "Berlin-Blockade"),
                    DemoEvent(date: "1949", label: "Gründung der NATO, erste sowjetische Atombombe"),
                    DemoEvent(date: "1950", label: "Beginn des Koreakriegs"),
                ]),
                .paragraph("Berlin ist die erste Kraftprobe. Die Stadt liegt mitten in der sowjetischen Zone und ist selbst in vier Sektoren geteilt. Als die Westmächte im Juni 1948 eine gemeinsame Währung für ihre Zonen einführen, sperrt Stalin alle Straßen und Bahnlinien nach West-Berlin: Zwei Millionen Einwohner sind plötzlich eingeschlossen."),
                .callout(
                    title: "Merke",
                    text: "Die Berlin-Blockade (Juni 1948 bis Mai 1949) ist die erste Krise: Die UdSSR sperrt die Zugangswege nach West-Berlin, die Alliierten antworten mit einer ==Luftbrücke==, die elf Monate dauert – alle zwei Minuten ein Flugzeug. Kein einziger Schuss fällt, und doch ist alles gesagt.",
                    tone: .insight
                ),
                .paragraph("Die Blockade scheitert, und sie legt die Spielregeln für vierzig Jahre fest: Jedes Lager testet das andere, aber keines überschreitet die Linie, die zum Krieg führen würde. 1949 zündet die UdSSR ihre erste Atombombe, vier Jahre nach Hiroshima. Beide Lager besitzen nun die ultimative Waffe, und **das Gleichgewicht des Schreckens** entsteht."),
                .list([
                    "Eiserner Vorhang: die Grenze, die Europa von der Ostsee bis zur Adria in zwei Teile trennt",
                    "Containment: die amerikanische Strategie – aufhalten, ohne anzugreifen",
                    "Satellitenstaat: ein osteuropäisches Land, das von einer an Moskau ausgerichteten kommunistischen Partei regiert wird",
                ]),
                .paragraph("Der Koreakrieg im Juni 1950 zeigt, was ein Konflikt in diesem Rahmen wird: Der kommunistische Norden überfällt den Süden, die Amerikaner greifen unter UN-Flagge ein, China schickt seine „Freiwilligen“. Drei Jahre Kämpfe, zwei Millionen Tote und eine Grenze, die am Ende genau dort verläuft, wo sie vorher war. Beide Lager folgen derselben Regel: keinen Fußbreit nachgeben, niemals auf die andere Supermacht schießen."),
            ]),
            DemoChapter(title: "Krisen und Gleichgewicht des Schreckens (1953–1975)", blocks: [
                .paragraph("Nach Stalins Tod (1953) schlägt Chruschtschow die „friedliche Koexistenz“ vor: Die beiden Systeme können nebeneinander bestehen, und die Wirtschaft wird zeigen, welches besser ist. Doch die Koexistenz verhindert weder Krisen noch das Wettrüsten. Jedes Lager rüstet seine Verbündeten auf und kämpft **stellvertretend**, von Korea bis Vietnam."),
                .paragraph("Die Koexistenz hat ihre Grenzen, und Budapest zeigt sie schon 1956: Als Ungarn versucht, den Warschauer Pakt zu verlassen, schlagen sowjetische Panzer den Aufstand in wenigen Tagen nieder. Der Westen protestiert und rührt sich nicht. Jede Seite bleibt Herr im eigenen Haus: Das ist die ungeschriebene Regel des Kalten Krieges."),
                .table(title: "Die großen Krisen", headers: ["Krise", "Datum", "Worum es geht"], rows: [
                    ["Koreakrieg", "1950–1953", "Der 38. Breitengrad, ein zweigeteiltes Korea"],
                    ["Berliner Mauer", "1961", "Der Osten mauert seine Bevölkerung ein, um die Flucht in den Westen zu stoppen"],
                    ["Kubakrise", "1962", "Sowjetische Raketen 150 km vor Florida"],
                    ["Vietnamkrieg", "1955–1975", "Die USA verstricken sich und ziehen sich dann zurück"],
                ]),
                .heading("Wieder Berlin"),
                .paragraph("Zwischen 1949 und 1961 gehen fast drei Millionen Ostdeutsche in den Westen, die meisten über Berlin, wo es reicht, in die U-Bahn zu steigen. Der DDR laufen Ärzte, Ingenieure und junge Menschen davon. In der Nacht vom 12. auf den 13. August 1961 schließt sie die Grenze: erst Stacheldraht, dann eine Betonmauer, Wachtürme, ein Todesstreifen. ==Die Mauer== wird zum Symbol des gesamten Kalten Krieges – und dessen, was jedes Lager in den Augen des anderen wert ist."),
                .keyFigure(value: "13 Tage", label: "dauerte die Kubakrise im Oktober 1962, bis die Raketen abgezogen wurden"),
                .paragraph("Im Oktober 1962 fotografieren amerikanische Spionageflugzeuge sowjetische Raketenstellungen auf Kuba, hundertfünfzig Kilometer vor Florida. Kennedy verhängt eine Seeblockade über die Insel und verlangt den Abzug der Raketen; dreizehn Tage lang hält die Welt den Atem an. Chruschtschow zieht die Raketen schließlich ab, im Gegenzug für das Versprechen, Kuba nicht anzugreifen – und den stillen Abzug amerikanischer Raketen aus der Türkei. ==Die Abschreckung hat gehalten==: der heißeste Moment des gesamten Kalten Krieges."),
                .figure(.flow(title: "Die Logik der Abschreckung", steps: ["Beide Lager haben die Bombe", "Wer zuschlägt, wird getroffen", "Niemand schlägt zu", "Der Krieg findet anderswo statt"])),
                .paragraph("Diese Logik hat einen Namen: **gegenseitig zugesicherte Zerstörung**. Kein Lager kann das andere vernichten, ohne selbst vernichtet zu werden, also schlägt keines zuerst zu. Die Bombe wird paradoxerweise zur Friedensgarantie zwischen den beiden Giganten – und genau deshalb verlagert sich der Krieg anderswohin, zu den Verbündeten, wo er konventionell bleiben kann."),
                .callout(
                    title: "Stellvertretend",
                    text: "Vietnam ist das Beispiel: Die USA unterstützen den Süden, die UdSSR und China den Norden. Ein echter Krieg, Millionen Tote – und nie steht ein amerikanischer Soldat einem sowjetischen gegenüber.",
                    tone: .example
                ),
                .paragraph("Die USA engagieren sich ab 1965 in Vietnam: mehr als fünfhunderttausend Soldaten im Jahr 1968, massive Bombardierungen und eine öffentliche Meinung, die kippt, als die Bilder ins Fernsehen kommen. 1973 ziehen sie ab; 1975 fällt Saigon. Es ist der erste Krieg, den Amerika verliert, und es verliert ihn, ==ohne je der UdSSR gegenüberzustehen==."),
                .heading("Wettlauf auf allen Ebenen"),
                .paragraph("Die Konfrontation spielt sich auch am Himmel ab, in den Laboren und in den Stadien. Jeder Satellit, jede Medaille, jeder Rekord wird als Beweis präsentiert, dass ein System besser ist als das andere. Der Wettlauf ins All ist sein Schaufenster: Die UdSSR geht in Führung, Amerika holt auf, indem es sich zehn Jahre Zeit gibt."),
                .list([
                    "1957: Sputnik, der erste Satellit, eröffnet den Wettlauf ins All",
                    "1961: Gagarin, der erste Mensch im Weltraum",
                    "1963: Das rote Telefon verbindet Washington und Moskau – die Lehre aus Kuba",
                    "1969: Apollo 11, Amerika betritt den Mond",
                ]),
                .paragraph("Das nach Kuba eingerichtete rote Telefon fasst die Zeit zusammen: zwei Gegner, die einander nicht trauen, aber wissen, dass ein Missverständnis alles in die Luft jagen könnte. Sie reden miteinander, um nicht zu kämpfen. Aus dieser Vorsicht entsteht die Entspannung der 1970er-Jahre."),
            ]),
            DemoChapter(title: "Von der Entspannung zum Mauerfall (1975–1991)", blocks: [
                .paragraph("Die 1970er-Jahre lockern den Griff. Beide Lager haben verstanden, dass sie nicht gewinnen werden und dass das Wettrüsten ein Vermögen kostet: Sie verhandeln. Doch der ==rose|neue Kalte Krieg== beginnt 1979, als die UdSSR in Afghanistan einmarschiert und Reagan das Wettrüsten neu entfacht."),
                .heading("Entspannung"),
                .paragraph("Die SALT-Abkommen (1972) begrenzen erstmals die Zahl der Atomraketen. Die Konferenz von Helsinki (1975) erkennt die nach dem Krieg entstandenen Grenzen an – was Moskau wollte – im Austausch gegen eine Verpflichtung zu den Menschenrechten, auf die sich die Dissidenten im Osten fünfzehn Jahre lang berufen werden. Nixon reist nach Peking und Moskau; der Handel lebt wieder auf; die beiden deutschen Staaten erkennen einander an."),
                .paragraph("Die Atempause ist kurz. Im Dezember 1979 marschiert die Rote Armee in Afghanistan ein, um ein wankendes kommunistisches Regime zu stützen: zehn Jahre Krieg, eine Million Tote, und die UdSSR verstrickt sich in ihrem eigenen Vietnam. Die USA boykottieren die Olympischen Spiele in Moskau, bewaffnen den afghanischen Widerstand, und Ronald Reagan, 1980 gewählt, nennt die UdSSR ein „Reich des Bösen“. Sein Raketenabwehrprojekt SDI löst einen technologischen Wettlauf aus, bei dem Moskau nicht mehr mithalten kann."),
                .paragraph("1985 kommt Michail Gorbatschow in einer erschöpften UdSSR an die Macht: Die Regale der Geschäfte sind leer, die Industrie ist veraltet, die Armee verschlingt einen riesigen Teil des Wohlstands. Er startet die **Perestroika** (Umbau der Wirtschaft) und die **Glasnost** (Offenheit im öffentlichen Leben), verhandelt mit Reagan über Abrüstung und hört auf, die kommunistischen Regime Osteuropas zu stützen: Jedes ist nun für sein eigenes Schicksal verantwortlich."),
                .timeline(title: "Das Ende", events: [
                    DemoEvent(date: "1985", label: "Gorbatschow kommt an die Macht"),
                    DemoEvent(date: "1987", label: "Washingtoner Vertrag: Ende der Mittelstreckenraketen in Europa"),
                    DemoEvent(date: "9. Nov. 1989", label: "Fall der Berliner Mauer"),
                    DemoEvent(date: "1990", label: "Deutsche Wiedervereinigung"),
                    DemoEvent(date: "25. Dez. 1991", label: "Auflösung der UdSSR"),
                ]),
                .paragraph("Das Jahr 1989 fegt alles hinweg. In Polen gewinnt die Gewerkschaft Solidarność im Juni freie Wahlen. In Ungarn öffnet die Regierung im September die Grenze zu Österreich: Tausende DDR-Bürger strömen hindurch. In der DDR versammeln die Montagsdemonstrationen in Leipzig Hunderttausende Menschen, und das Regime kann ohne die Unterstützung Moskaus nicht mehr schießen lassen."),
                .heading("Warum die UdSSR verloren hat"),
                .paragraph("Der Kalte Krieg wurde ebenso über die Wirtschaft ausgetragen wie über die Waffen. Die UdSSR steckte einen Anteil ihres Wohlstands in ihre Armee, den die USA nie erreichen mussten – und das mit einer halb so großen Wirtschaft. Jede zusätzliche Rakete war ein Krankenhaus oder eine Fabrik weniger, und die Bevölkerung wusste das."),
                .bars(title: "Militärausgaben in Prozent des BIP, um 1985 (Schätzung)", unit: "%", bars: [
                    DemoBar(label: "USA", value: 6),
                    DemoBar(label: "UdSSR", value: 15),
                    DemoBar(label: "Frankreich", value: 4),
                ]),
                .paragraph("Das Diagramm lässt sich auf einen Blick lesen: Für eine vergleichbare militärische Anstrengung opfert die UdSSR mehr als doppelt so viel wie die USA. Diese Erschöpfung versucht Gorbatschow aufzuhalten – und indem er den Griff lockert, setzt er die Kräfte frei, die das System auflösen werden."),
                .callout(
                    title: "Warum die Mauer fällt",
                    text: "Ohne die Unterstützung Moskaus brechen die Regime im Osten 1989 eines nach dem anderen zusammen. Am 9. November verkündet ein Sprecher der DDR versehentlich, die Grenzen seien „sofort, unverzüglich“ offen: In einer einzigen Nacht strömen Zehntausende Berliner hinüber, und das Symbol der Teilung verschwindet.",
                    tone: .insight
                ),
                .paragraph("Deutschland wird im Oktober 1990 wiedervereinigt, unter dem Schutz der NATO – was Moskau fünf Jahre zuvor abgelehnt hätte. In der UdSSR fordern die Republiken ihre Unabhängigkeit; ein gescheiterter Putsch im August 1991 bringt die Partei endgültig in Verruf. Am 25. Dezember 1991 wird die sowjetische Flagge über dem Kreml eingeholt. Der Kalte Krieg endet ==ohne eine Schlacht==, durch die Erschöpfung eines der beiden Lager."),
            ]),
            DemoChapter(title: "Den Kalten Krieg verstehen", blocks: [
                .paragraph("Vierundvierzig Jahre, Dutzende Krisen, Hunderte Daten: Den Kalten Krieg lernt man nicht Datum für Datum auswendig, man versteht ihn über seine Mechanismen. Dieses Kapitel versammelt ==die Begriffe, die Logik und die Methode==, um in einer Prüfung darüber zu schreiben."),
                .heading("Die Begriffe"),
                .paragraph("Jedes der folgenden Wörter bezeichnet einen genauen Mechanismus, und wer eines mit einem anderen verwechselt, macht einen Verständnisfehler, keinen Wortschatzfehler. „Entspannung“ ist nicht „Frieden“, „Eindämmung“ ist nicht „Angriff“, „Satellitenstaat“ ist nicht „Verbündeter“."),
                .table(title: "Wichtige Begriffe", headers: ["Begriff", "Bedeutung"], rows: [
                    ["Eiserner Vorhang", "Die geschlossene Grenze, die Europa in zwei Teile trennt"],
                    ["Containment", "Den Kommunismus aufhalten, ohne ihn dort anzugreifen, wo er herrscht"],
                    ["Abschreckung", "Nicht zuschlagen, weil man sonst selbst getroffen würde"],
                    ["Stellvertreterkrieg", "Ein Krieg, den Verbündete führen, nicht die beiden Giganten"],
                    ["Entspannung", "Das Nachlassen der Spannungen in den 1970er-Jahren"],
                    ["Satellitenstaat", "Ein Land im Osten, regiert von einer an Moskau ausgerichteten Partei"],
                ]),
                .paragraph("Diese Wörter beschreiben einen einzigen Kreislauf, der sich von 1947 bis 1991 wiederholt. Die Spannung steigt, eine Krise bricht aus, die beiden Lager verhandeln, weil keines einen Krieg will, die Spannung sinkt – dann beginnt woanders eine neue Krise. Berlin, Kuba, Vietnam, Afghanistan: Es ist immer derselbe Kreislauf."),
                .figure(.cycle(title: "Der Kreislauf der Krisen", nodes: ["Die Spannung steigt", "Eine Krise bricht aus", "Man verhandelt", "Die Spannung sinkt"])),
                .paragraph("Wer diesen Kreislauf versteht, kann jede Krise erklären, ohne sie auswendig gelernt zu haben: wer wen testet, wie weit, und warum es nicht zum Krieg kommt. Die Antwort ist fast immer dieselbe – **die atomare Abschreckung** –, und sie unterscheidet den Kalten Krieg von allen Rivalitäten davor."),
                .heading("In der Prüfung"),
                .callout(
                    title: "Methode",
                    text: "Für einen Aufsatz: 1. Eine Gliederung in drei Teilen – die Entstehung der Blöcke, Krisen und Koexistenz, Entspannung und Ende. 2. Ein Datum und ein genaues Beispiel pro Gedanke. 3. Ein Schluss, der die Frage beantwortet: Warum „kalt“, und warum endet er ohne Krieg?",
                    tone: .insight
                ),
                .paragraph("Bei einer Quellenanalyse ist die erste Frage die nach dem Standpunkt: Wer spricht, aus welchem Lager, in welchem Moment des Kreislaufs? Ein sowjetisches Plakat von 1950 und eine Rede Kennedys von 1963 sagen nicht dasselbe, und genau diesen Unterschied sollst du erklären."),
                .callout(
                    title: "Der klassische Fehler",
                    text: "Zu schreiben, dass die USA und die UdSSR gegeneinander Krieg geführt haben. Sie haben **nie** direkt gegeneinander gekämpft: Das ist genau die Definition des Kalten Krieges, und die Abschreckung erklärt es.",
                    tone: .warning
                ),
                .list([
                    "1947: Truman-Doktrin, Marshallplan – die Blöcke entstehen",
                    "1949: NATO, sowjetische Bombe – das Gleichgewicht des Schreckens beginnt",
                    "1961: die Mauer – die Teilung wird zu Beton",
                    "1962: Kuba – die Abschreckung hält",
                    "1975: Helsinki – die Entspannung",
                    "1989: Die Mauer fällt – das Ende",
                    "1991: Die UdSSR verschwindet",
                ]),
                .paragraph("Sieben Daten genügen, um die ganze Epoche im Griff zu haben – vorausgesetzt, du weißt, was jedes davon eröffnet oder abschließt. Lerne sie mit ihrem Mechanismus, nicht nur mit ihrem Ereignis: Diese Verbindung macht den Unterschied zwischen dem Aufsagen einer Zeitleiste und dem ==Erklären einer Epoche==."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Welches sind die beiden Blöcke des Kalten Krieges, und wer führt sie an?",
                back: "Der Westblock unter Führung der USA (liberale Demokratie, Marktwirtschaft) und der Ostblock unter Führung der UdSSR (Einparteiensystem, Planwirtschaft).",
                figure: .split(
                    title: "Zwei Modelle",
                    left: DemoColumn(title: "Westen", items: ["USA", "NATO"]),
                    right: DemoColumn(title: "Osten", items: ["UdSSR", "Warschauer Pakt"])
                ),
                chapter: 0
            ),
            DemoCard(
                kind: .choice,
                front: "Welche Krise brachte die Welt 1962 an den Rand eines Atomkriegs?",
                back: "Die Kubakrise: sowjetische Raketen auf Kuba, dreizehn Tage Kräftemessen, dann ein Abzug im Austausch gegen das Versprechen, die Insel nicht anzugreifen.",
                choices: ["Die Berlin-Blockade", "Die Kubakrise", "Der Koreakrieg", "Der Einmarsch in Afghanistan"],
                answerIndex: 1,
                chapter: 1
            ),
            DemoCard(
                kind: .cloze,
                front: "Die Berliner Mauer fällt am 9. November …, zwei Jahre vor der Auflösung der UdSSR.",
                back: "1989",
                chapter: 2
            ),
            DemoCard(kind: .basic, front: "Was ist die Truman-Doktrin?", back: "Die Zusage der USA vom März 1947, jedem vom Kommunismus bedrohten Land zu helfen: die Politik der Eindämmung (Containment).", chapter: 0),
            DemoCard(kind: .cloze, front: "Der …plan (1947) finanziert den Wiederaufbau Westeuropas.", back: "Marshall", chapter: 0),
            DemoCard(kind: .choice, front: "Wer leitete Perestroika und Glasnost ein?", back: "Michail Gorbatschow, ab 1985 an der Macht, versuchte, die UdSSR von innen heraus zu reformieren.", choices: ["Stalin", "Chruschtschow", "Gorbatschow", "Breschnew"], answerIndex: 2, chapter: 2),
            DemoCard(kind: .basic, front: "Warum haben die USA und die UdSSR nie direkt gegeneinander gekämpft?", back: "Wegen der atomaren Abschreckung: Da jedes Lager das andere vernichten konnte, hätte ein Erstschlag bedeutet, selbst getroffen zu werden. Der Krieg wird deshalb stellvertretend geführt, über die Verbündeten.", chapter: 3),
            DemoCard(kind: .cloze, front: "Das Nachlassen der Spannungen zwischen den beiden Blöcken in den 1970er-Jahren nennt man … .", back: "Entspannung", chapter: 3),
        ]
    )

    // MARK: Biology: photosynthesis

    private static let photosynthesisDE = OnboardingDemoCourse(
        id: "biology-photosynthesis",
        emoji: "🌿",
        subject: "SVT",
        title: "Fotosynthese",
        summary: "Wie ein Blatt aus Licht, Wasser und Kohlenstoffdioxid Zucker herstellt – und warum fast alles Leben davon abhängt.",
        accentIndex: 4,
        chapters: [
            DemoChapter(title: "Licht einfangen", blocks: [
                .paragraph("Ein Blatt ist eine Fabrik: Es nimmt Licht, Wasser und Kohlenstoffdioxid auf und verwandelt sie in ==Zucker und Sauerstoff==. Dieser Vorgang ist die Fotosynthese, und sie ernährt fast alles Leben auf der Erde – auch uns, die wir Pflanzen essen oder Tiere, die Pflanzen fressen."),
                .heading("Ein Blatt aus der Nähe"),
                .paragraph("Das Blatt ist für diese Aufgabe gebaut. Es ist flach und dünn, um dem Licht eine möglichst große Fläche zu bieten. Seine Unterseite ist von Tausenden **Spaltöffnungen** (Stomata) durchbrochen, winzigen Poren, die sich tagsüber öffnen, um das CO₂ der Luft herein- und den Sauerstoff hinauszulassen. Zwischen den beiden Seiten liegen Zellen voller Chloroplasten; und Leitbündel bringen Wasser aus den Wurzeln herauf und transportieren den Zucker ab."),
                .callout(
                    title: "Fotosynthese",
                    text: "Der Aufbau organischer Stoffe (Glucose) durch grüne Pflanzen aus anorganischen Stoffen (CO₂ und Wasser) mithilfe von Lichtenergie.",
                    tone: .definition
                ),
                .paragraph("Die Definition passt in eine Gleichung. Sechs Moleküle Kohlenstoffdioxid und sechs Moleküle Wasser ergeben ein Molekül Glucose und sechs Moleküle Sauerstoff. Nichts entsteht aus dem Nichts: Die Kohlenstoffatome des Zuckers stammen aus dem CO₂ der Luft, der freigesetzte Sauerstoff stammt aus dem Wasser. Erst ==die Energie des Lichts== macht diesen Aufbau möglich."),
                .formula("6\\,CO_2 + 6\\,H_2O \\rightarrow C_6H_{12}O_6 + 6\\,O_2", caption: "Die Gesamtgleichung, angetrieben durch Licht"),
                .paragraph("Alles geschieht in den **Chloroplasten**, grünen Zellorganellen, die zu Dutzenden in jeder Zelle des Blattgewebes vorkommen. Ihre Farbe verdanken sie dem ==menthe|Chlorophyll==, dem Farbstoff, der rotes und blaues Licht absorbiert und grünes reflektiert. Es ist der einzige Ort in der Zelle, an dem Licht eingefangen wird: ohne Chloroplast keine Fotosynthese."),
                .heading("Vom Photon zum Zucker"),
                .paragraph("Was darin geschieht, lässt sich in vier Schritten zusammenfassen, die in Sekundenbruchteilen aufeinander folgen. Licht trifft auf das Chlorophyll; die aufgenommene Energie wird genutzt, um Wassermoleküle zu spalten, wodurch Sauerstoff frei wird; diese Energie wird in einer Form gespeichert, die die Zelle nutzen kann, dem ATP; und das ATP wird schließlich genutzt, um CO₂ in Glucose einzubauen."),
                .figure(.flow(title: "Vom Photon zum Zucker", steps: ["Chlorophyll absorbiert Licht", "Wasser wird gespalten: O₂ frei", "Energie wird gespeichert (ATP)", "CO₂ wird zu Glucose gebunden"])),
                .paragraph("Nicht alle Lichtfarben sind für das Blatt gleich viel wert. Das weiße Sonnenlicht ist eine Mischung; Chlorophyll fängt vor allem die beiden Enden des Spektrums ein – Blau und Rot – und lässt die Mitte durch. Man misst das, indem man eine Chlorophylllösung Farbe für Farbe beleuchtet und beobachtet, was hindurchgeht."),
                .bars(title: "Was Chlorophyll absorbiert, nach Farbe", unit: "%", bars: [
                    DemoBar(label: "Blau", value: 90),
                    DemoBar(label: "Grün", value: 15),
                    DemoBar(label: "Rot", value: 80),
                ]),
                .paragraph("Das Diagramm lässt sich auf einen Blick lesen: Neun von zehn blauen Photonen werden eingefangen, acht von zehn roten, und kaum eines von sechs grünen. Grün geht nicht ganz verloren – einige Hilfspigmente, die Carotinoide, nehmen einen Teil davon auf –, aber der Großteil wird zurückgeworfen."),
                .callout(
                    title: "Warum Blätter grün sind",
                    text: "Weil Grün die Farbe ist, die Chlorophyll **nicht absorbiert**: Es reflektiert sie zu unseren Augen. Ein Blatt ist aus demselben Grund grün, aus dem ein rotes Tuch rot ist – es ist die Farbe, die es zurückweist.",
                    tone: .insight
                ),
                .paragraph("Ein einfaches Experiment zeigt es: Eine Pflanze unter grünem Licht wächst schlecht, eine Pflanze unter rotem oder blauem Licht wächst gut. Deshalb beleuchten moderne Gewächshäuser ihre Kulturen in Pink, einer Mischung aus Rot und Blau – kein einziges Photon wird für Grün verschwendet, das die Pflanze nicht nutzen würde."),
                .paragraph("Man kann auch überprüfen, dass das Blatt wirklich Zucker herstellt. Ein belichtetes Blatt, das entfärbt und dann in Iod-Kaliumiodid-Lösung (Lugolsche Lösung) getaucht wird, färbt sich blauschwarz: Es enthält Stärke, die Form, in der die Pflanze ihre Glucose speichert. Ein im Dunkeln gehaltenes Blatt bleibt gelb: ==kein Licht, kein Zucker==."),
            ]),
            DemoChapter(title: "Glucose herstellen", blocks: [
                .paragraph("Die Fotosynthese läuft in zwei Phasen ab, an zwei Orten im Chloroplasten. Die **lichtabhängige Reaktion** braucht Licht: Sie spaltet Wasser, setzt Sauerstoff frei und speichert Energie. Die **lichtunabhängige Reaktion** braucht es nicht direkt: Sie nutzt diese Energie, um CO₂ zu binden und Glucose aufzubauen. Die erste erzeugt den Treibstoff, die zweite verbraucht ihn."),
                .heading("Die lichtabhängige Reaktion"),
                .paragraph("Sie findet in den **Thylakoiden** statt, gestapelten Membransäckchen im Inneren des Chloroplasten, in denen das Chlorophyll verankert ist. Trifft ein Photon auf ein Chlorophyllmolekül, schlägt es ein Elektron heraus, und dieses Elektron wird durch die Spaltung eines Wassermoleküls ersetzt: Das ist die **Fotolyse des Wassers**. Der Sauerstoff des Wassers wird als O₂ frei – der, den wir atmen –, und die Energie des Elektrons wird genutzt, um ATP herzustellen, die Energiewährung jeder lebenden Zelle."),
                .table(title: "Die zwei Phasen", headers: ["", "Lichtabhängige Reaktion", "Lichtunabhängige Reaktion"], rows: [
                    ["Wo", "Thylakoidmembranen", "Stroma des Chloroplasten"],
                    ["Licht", "Unverzichtbar", "Nicht direkt"],
                    ["Hinein", "Wasser, Licht", "CO₂, ATP"],
                    ["Heraus", "O₂, ATP", "Glucose"],
                ]),
                .paragraph("Die Tabelle liest man spaltenweise: Was aus der lichtabhängigen Reaktion herauskommt – ATP –, ist genau das, was die lichtunabhängige Reaktion braucht. Die beiden Phasen sind also gekoppelt: Die zweite stoppt, sobald die erste sie nicht mehr versorgt, und das geschieht wenige Minuten nach Sonnenuntergang."),
                .heading("Der Calvin-Zyklus"),
                .paragraph("Die lichtunabhängige Reaktion findet im **Stroma** statt, der Flüssigkeit, die die Thylakoide umgibt. Sie trägt den Namen des Chemikers, der sie 1950 mithilfe von radioaktivem Kohlenstoff aufklärte: Melvin Calvin. Es ist ein Zyklus, also eine Abfolge von Reaktionen, die zu ihrem Ausgangspunkt zurückkehrt und dabei Zucker herstellt."),
                .figure(.cycle(title: "Der Calvin-Zyklus", nodes: ["CO₂-Fixierung", "Reduktion mit ATP", "Zuckerbildung", "Regeneration des Akzeptors"])),
                .paragraph("Bei jedem Umlauf wird ein CO₂-Molekül von einem Enzym namens RuBisCO – dem häufigsten Protein der Erde – an ein Trägermolekül, den Akzeptor, gebunden. Die entstandene Verbindung wird mithilfe des ATP aus der lichtabhängigen Reaktion reduziert, und ein Teil des Produkts verlässt den Zyklus, um ==Glucose== zu bilden, während der Rest den Akzeptor für den nächsten Umlauf regeneriert. Für ein Glucosemolekül braucht es **sechs Umläufe**: einen pro Kohlenstoffatom."),
                .keyFigure(value: "6 Umläufe", label: "des Calvin-Zyklus, um ein einziges Glucosemolekül aufzubauen"),
                .paragraph("Die hergestellte Glucose bleibt nicht lange Glucose. Die Pflanze baut sie zu **Stärke** zusammen, um sie im Blatt oder in einer Knolle zu speichern – das ist die Stärke der Kartoffel –, zu **Saccharose**, um sie über den Siebröhrensaft bis zu den Wurzeln und in die Früchte zu transportieren, oder zu **Cellulose**, um ihre Zellwände zu bauen. Das Holz eines Baumes ist über Jahrzehnte aufgeschichteter Zucker."),
                .callout(
                    title: "Klassische Falle",
                    text: "Die lichtunabhängige Reaktion findet nicht „nachts“ statt: Sie läuft auch tagsüber, sobald die lichtabhängige Reaktion Energie liefert. „Lichtunabhängig“ heißt, dass sie Licht nicht direkt nutzt – nicht, dass sie auf die Dunkelheit wartet.",
                    tone: .warning
                ),
                .list([
                    "Lichtabhängige Reaktion: Thylakoide, Licht, Wasser gespalten, O₂ frei, ATP erzeugt",
                    "Lichtunabhängige Reaktion: Stroma, Calvin-Zyklus, CO₂ gebunden, Glucose hergestellt",
                    "Sechs Umläufe des Zyklus pro Glucosemolekül, einer pro Kohlenstoffatom",
                ]),
                .paragraph("Merke dir den roten Faden statt der Namen: Licht wird zu chemischer Energie, chemische Energie wird zu Zucker, und Zucker wird zu allem anderen in der Pflanze. Jeder Schritt hat seinen Ort und seinen Treibstoff, und ==keiner funktioniert ohne den vorherigen==."),
            ]),
            DemoChapter(title: "Fotosynthese und der Planet", blocks: [
                .paragraph("Jedes Jahr binden Pflanzen etwa ==120 Milliarden Tonnen Kohlenstoff==. Die Fotosynthese ist der Eintrittspunkt organischer Stoffe in die Nahrungsketten und die Quelle des gesamten Sauerstoffs, den wir atmen. Auf der Ebene des Planeten ist sie der Vorgang, der den Kohlenstoffkreislauf antreibt."),
                .heading("Der Kohlenstoffkreislauf"),
                .paragraph("Kohlenstoff zirkuliert zwischen Luft, Lebewesen und Boden, und die Fotosynthese ist einer der beiden Motoren dieses Kreislaufs. Sie entzieht der Atmosphäre CO₂ und bindet es in der Substanz der Pflanzen. Zellatmung und Zersetzung laufen in die andere Richtung: Sie verbrennen diese Substanz und geben das CO₂ an die Luft zurück. Solange sich beide die Waage halten, bleibt die CO₂-Menge in der Atmosphäre stabil."),
                .figure(.cycle(title: "Der Kohlenstoffkreislauf", nodes: ["CO₂ in der Atmosphäre", "Fotosynthese: in Pflanzen gebunden", "Zellatmung, Zersetzung", "Zurück in die Atmosphäre"])),
                .paragraph("Pflanzen sind die **Produzenten**: Sie stellen die organischen Stoffe her, von denen alles andere lebt. Ein Pflanzenfresser frisst die Pflanze, ein Fleischfresser frisst den Pflanzenfresser, und bei jedem Schritt geht der Kohlenstoff von einem Lebewesen auf das nächste über. Ohne Fotosynthese fehlt der Kette das erste Glied."),
                .heading("Was sie steuert"),
                .paragraph("Drei Faktoren bestimmen die Geschwindigkeit der Fotosynthese: Licht, CO₂-Konzentration und Temperatur. Fehlt einer davon, ändert eine Steigerung der anderen nichts: Das ist der **begrenzende Faktor**, der das Tempo für alles andere vorgibt – wie die langsamste Station an einem Fließband."),
                .figure(.plot(title: "Licht, bis zu einer Obergrenze", caption: "Mehr Licht beschleunigt die Fotosynthese bis zu einem Plateau: Darüber hinaus begrenzen CO₂ oder Temperatur.", kind: .saturation)),
                .paragraph("Die Kurve liest sich in zwei Teilen. Zuerst steigt sie: Jedes zusätzliche Photon wird genutzt, Licht ist der begrenzende Faktor. Dann flacht sie ab: Die Pflanze erhält mehr Licht, als sie nutzen kann, und es ist das verfügbare CO₂ – oder die Geschwindigkeit der Enzyme, die von der Temperatur abhängt –, das das Tempo bremst. Auf dem Plateau ändert zusätzliches Licht nichts mehr."),
                .list([
                    "Licht: Je mehr, desto schneller läuft die Fotosynthese – bis zur Sättigung",
                    "CO₂: mit 0,04 % der Luft bei vollem Tageslicht oft der begrenzende Faktor",
                    "Temperatur: ein Optimum bei etwa 25 bis 30 °C, darüber versagen die Enzyme",
                ]),
                .callout(
                    title: "Im Gewächshaus",
                    text: "Gärtner reichern die Luft manchmal mit CO₂ an, bis zum Dreifachen der natürlichen Konzentration: Bei starkem Licht ist es das, was das Wachstum bremst, und wenn man es zugibt, wachsen Tomaten schneller.",
                    tone: .example
                ),
                .paragraph("Dieselbe Überlegung erklärt, warum Pflanzen im Winter kaum wachsen, selbst bei schönem Wetter: Das Licht ist da, aber die Temperatur bremst die Enzyme. Und warum eine Zimmerpflanze weit weg vom Fenster kümmert: Die Temperatur stimmt, aber es fehlt an Licht. ==Den begrenzenden Faktor zu erkennen== heißt zu wissen, was man ändern muss."),
                .heading("Die Lunge des Planeten"),
                .paragraph("Wälder werden oft als Lunge der Erde bezeichnet. Das ist nur halb richtig: Wälder binden zwar Kohlenstoff, aber fast die Hälfte der weltweiten Fotosynthese findet in den Ozeanen statt, durch das **Phytoplankton** – mikroskopisch kleine, im Wasser schwebende Algen. Ein Liter Meerwasser enthält Millionen davon, und ihnen verdanken wir jeden zweiten Atemzug."),
                .keyFigure(value: "≈ 50 %", label: "des jährlich auf der Erde erzeugten Sauerstoffs stammen vom Phytoplankton der Ozeane"),
                .paragraph("Deshalb steht die Fotosynthese auch im Zentrum der Klimafrage. Seit zwei Jahrhunderten geben wir durch das Verbrennen von Kohle und Öl Kohlenstoff an die Luft zurück, den die Fotosynthese vor Millionen von Jahren im Untergrund eingeschlossen hat. Pflanzen und Ozeane nehmen einen Teil davon wieder auf, aber nicht alles: Das Gleichgewicht des Kreislaufs ist gestört, und CO₂ reichert sich an."),
            ]),
            DemoChapter(title: "Fotosynthese und Zellatmung", blocks: [
                .paragraph("Die Fotosynthese stellt Zucker her; die **Zellatmung** verbrennt ihn. Die beiden Vorgänge sind ==die Umkehrung voneinander==, und eine Pflanze betreibt beide – auch am helllichten Tag. Die beiden zu verwechseln ist der häufigste Fehler bei diesem Thema, und dieses Kapitel ist dazu da, dass er dir nicht passiert."),
                .heading("Der umgekehrte Weg"),
                .paragraph("Die Zellatmung nimmt Glucose und Sauerstoff auf und setzt CO₂, Wasser und vor allem Energie in Form von ATP frei. Das tut jede unserer Zellen, ständig, und das tut auch jede Pflanzenzelle: Eine Pflanze braucht Energie, um zu wachsen, ihren Saft zu transportieren, ihre Spaltöffnungen zu öffnen – und diese Energie gewinnt sie aus ihrem eigenen Zucker."),
                .formula("C_6H_{12}O_6 + 6\\,O_2 \\rightarrow 6\\,CO_2 + 6\\,H_2O + \\text{Energie}", caption: "Zellatmung: die Fotosynthesegleichung, rückwärts gelesen"),
                .paragraph("Die beiden Gleichungen sind symmetrisch, aber sie laufen weder am selben Ort noch im selben Takt ab. Die Fotosynthese findet in den Chloroplasten statt, und nur bei Licht; die Zellatmung in den **Mitochondrien**, und zwar ständig. Die Tabelle stellt beide einander gegenüber."),
                .table(title: "Gegenüberstellung", headers: ["", "Fotosynthese", "Zellatmung"], rows: [
                    ["Wo", "Chloroplasten", "Mitochondrien"],
                    ["Wann", "Bei Licht", "Tag und Nacht"],
                    ["Verbraucht", "CO₂, Wasser, Licht", "Glucose, O₂"],
                    ["Erzeugt", "Glucose, O₂", "CO₂, Wasser, ATP"],
                    ["Wer", "Pflanzen, Algen", "Alle Lebewesen"],
                ]),
                .paragraph("Tagsüber macht eine Pflanze beides gleichzeitig, aber die Fotosynthese überwiegt bei Weitem: Sie bindet viel mehr CO₂, als die Zellatmung freisetzt, und unterm Strich steht ein Gewinn an Substanz. Nachts läuft nur die Zellatmung weiter: Die Pflanze verbraucht etwas von ihrem Zucker und gibt etwas CO₂ ab. Über vierundzwanzig Stunden bleibt die Bilanz deutlich positiv – deshalb wächst die Pflanze."),
                .callout(
                    title: "Klassische Falle",
                    text: "„Pflanzen atmen nachts und betreiben tagsüber Fotosynthese.“ Falsch: Sie atmen **ständig**. Tagsüber überdeckt die Fotosynthese die Zellatmung nur, weil sie viel stärker ist.",
                    tone: .warning
                ),
                .heading("Woher die Energie kommt"),
                .paragraph("Hintereinandergestellt erzählen die beiden Vorgänge den Weg der Energie durch die Welt des Lebendigen. Sie kommt von der Sonne; die Fotosynthese speichert sie in den Bindungen der Glucose; die Zellatmung setzt sie als ATP frei; und ATP bezahlt die gesamte Arbeit der Zelle. Jede Kalorie, die du verbrauchst, war einmal ein Photon, das ein Blatt eingefangen hat."),
                .figure(.flow(title: "Der Weg der Energie", steps: ["Sonnenlicht", "Glucose (Fotosynthese)", "ATP (Zellatmung)", "Arbeit der Zelle"])),
                .paragraph("Dieser Weg teilt die Lebewesen in zwei Gruppen. **Autotrophe** – Pflanzen, Algen, manche Bakterien – stellen ihre organischen Stoffe selbst aus anorganischen Stoffen her: Sie brauchen nur Licht, Wasser und CO₂. **Heterotrophe** – Tiere, Pilze, wir – können das nicht: Sie müssen organische Stoffe essen, die direkt oder indirekt ein Autotropher hergestellt hat."),
                .callout(
                    title: "Autotroph, heterotroph",
                    text: "Ein **autotrophes** Lebewesen stellt seine organischen Stoffe aus anorganischen Stoffen her; ein **heterotrophes** Lebewesen muss sie von anderen Lebewesen aufnehmen. Jede Nahrungskette beginnt mit einem autotrophen Lebewesen.",
                    tone: .definition
                ),
                .list([
                    "Fotosynthese: stellt Glucose her, bei Licht, in den Chloroplasten",
                    "Zellatmung: verbrennt Glucose, ständig, in den Mitochondrien",
                    "Tagsüber überwiegt die Fotosynthese; nachts läuft nur die Zellatmung",
                    "Autotrophe am Anfang der Kette, Heterotrophe dahinter",
                ]),
                .paragraph("Dieser letzte Punkt ist der Schlüssel zum ganzen Kapitel und zu vielen anderen: Das Leben auf der Erde läuft mit Sonnenenergie, ==ein einziges Mal umgewandelt== durch die Fotosynthese und dann entlang der Nahrungsketten von Maul zu Maul weitergegeben. Alles andere – atmen, laufen, denken – ist eine Art, diese Energie auszugeben."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Was sind die Ausgangsstoffe und die Produkte der Fotosynthese?",
                back: "Ausgangsstoffe: Kohlenstoffdioxid (CO₂) und Wasser (H₂O), dazu Lichtenergie. Produkte: Glucose (C₆H₁₂O₆) und Sauerstoff (O₂).",
                figure: .flow(title: "Vom Photon zum Zucker", steps: ["Licht", "Wasser gespalten, O₂", "ATP", "Glucose"]),
                chapter: 0
            ),
            DemoCard(
                kind: .choice,
                front: "Wo findet die lichtabhängige Reaktion der Fotosynthese statt?",
                back: "In den Thylakoidmembranen, im Inneren des Chloroplasten. Im Stroma läuft der Calvin-Zyklus ab.",
                choices: ["Im Stroma", "In den Thylakoidmembranen", "Im Zellkern", "In den Mitochondrien"],
                answerIndex: 1,
                chapter: 1
            ),
            DemoCard(
                kind: .cloze,
                front: "Chlorophyll absorbiert vor allem Blau und Rot und reflektiert …, daher die Farbe der Blätter.",
                back: "Grün",
                chapter: 0
            ),
            DemoCard(kind: .basic, front: "Was ist ein begrenzender Faktor?", back: "Der Faktor (Licht, CO₂ oder Temperatur), dessen Mangel die Fotosynthese bremst: Solange er fehlt, ändert eine Steigerung der anderen nichts.", chapter: 2),
            DemoCard(kind: .cloze, front: "Es braucht … Umläufe des Calvin-Zyklus, um ein Glucosemolekül aufzubauen.", back: "sechs", chapter: 1),
            DemoCard(kind: .choice, front: "Welches Gas setzt die Fotosynthese frei?", back: "Sauerstoff (O₂), aus der Spaltung von Wassermolekülen während der lichtabhängigen Reaktion.", choices: ["Kohlenstoffdioxid", "Sauerstoff", "Stickstoff", "Wasserstoff"], answerIndex: 1, chapter: 0),
            DemoCard(kind: .basic, front: "Was ist der Unterschied zwischen Fotosynthese und Zellatmung?", back: "Die Fotosynthese stellt aus CO₂ und Wasser Glucose her, bei Licht, in den Chloroplasten. Die Zellatmung verbrennt diese Glucose mit Sauerstoff, um Energie (ATP) freizusetzen, ständig, in den Mitochondrien.", chapter: 3),
            DemoCard(kind: .cloze, front: "Ein Lebewesen, das seine organischen Stoffe selbst aus anorganischen Stoffen herstellt, nennt man … .", back: "autotroph", chapter: 3),
        ]
    )

    // MARK: Maths: derivatives

    private static let derivativesDE = OnboardingDemoCourse(
        id: "maths-derivatives",
        emoji: "📐",
        subject: "Mathématiques",
        title: "Ableitungen",
        summary: "Die Ableitung an einer Stelle, die Tangente, die Grundableitungen und Ableitungsregeln, das Vorzeichen der Ableitung für das Monotonieverhalten und Optimierungsprobleme.",
        accentIndex: 0,
        chapters: [
            DemoChapter(title: "Ableitung und Tangente", blocks: [
                .paragraph("Ableiten heißt messen, ==wie schnell sich eine Funktion ändert==. An einer Kurve sieht man diese Geschwindigkeit: Es ist die Steigung der Tangente an der betrachteten Stelle. Das ganze Kapitel steckt in dieser Idee, der Rest ist nur Rechnen."),
                .heading("Die Änderungsrate"),
                .paragraph("Vor der momentanen Geschwindigkeit kommt die durchschnittliche. Zwischen zwei Punkten mit den x-Werten $a$ und $a+h$ hat sich die Funktion um $f(a+h) - f(a)$ geändert, während sich $x$ um $h$ geändert hat. Der Quotient der beiden ist die **Änderungsrate** (Differenzenquotient): Es ist die Steigung der Geraden durch die beiden Kurvenpunkte, der Sekante."),
                .formula("\\frac{f(a+h) - f(a)}{h}", caption: "Die Änderungsrate von f zwischen a und a + h: die Steigung der Sekante"),
                .paragraph("Diese Rate hängt von $h$ ab: Je näher die beiden Punkte beieinanderliegen, desto mehr ähnelt die Sekante der Kurve selbst in der Nähe von $a$. Die Idee der Ableitung ist, $h$ gegen null gehen zu lassen – die beiden Punkte zusammenzuschieben, bis sie verschmelzen – und zu betrachten, wogegen die Steigung strebt."),
                .callout(
                    title: "Ableitung an einer Stelle",
                    text: "Die Ableitung von $f$ an der Stelle $a$, geschrieben $f'(a)$, ist der Grenzwert der Änderungsrate zwischen $a$ und $a+h$, wenn $h$ gegen 0 geht. Existiert dieser Grenzwert, nennt man $f$ an der Stelle $a$ **differenzierbar**.",
                    tone: .definition
                ),
                .formula("f'(a) = \\lim_{h \\to 0} \\frac{f(a+h) - f(a)}{h}", caption: "Die Änderungsrate, wenn h unendlich klein wird"),
                .paragraph("Geometrisch wird die Sekante, wenn die beiden Punkte zusammenfallen, zur ==Tangente==: der Geraden, die die Kurve in $a$ berührt und dabei ihrer Richtung folgt. Die Ableitung ist ihre Steigung. Eine steile positive Steigung bedeutet, dass die Kurve schnell steigt; eine Steigung null, dass die Kurve dort waagerecht verläuft."),
                .figure(.plot(title: "Die Tangente an einer Stelle", caption: "Die Gerade, die sich in $a$ an die Kurve „anschmiegt“: Ihre Steigung ist $f'(a)$.", kind: .tangent)),
                .paragraph("Steigung und ein Punkt genügen, um die Gerade aufzustellen. Die Gleichung der Tangente in $a$ lautet $y = f'(a)(x - a) + f(a)$: eine Gerade durch den Punkt $(a, f(a))$ mit der Steigung $f'(a)$. Diese Formel musst du auswendig kennen, denn sie kommt in fast jeder Klausur vor."),
                .callout(
                    title: "Beispiel",
                    text: "Für $f(x) = x^2$ an der Stelle $a = 1$: Die Änderungsrate ist $\\frac{(1+h)^2 - 1}{h} = 2 + h$, und sie strebt gegen $2$. Also ist $f'(1) = 2$, und die Tangente lautet $y = 2(x - 1) + 1 = 2x - 1$.",
                    tone: .example
                ),
                .paragraph("Das Vorzeichen der Ableitung lässt sich direkt an der Kurve ablesen, und darum wird es im ganzen dritten Kapitel gehen. Eine von links nach rechts steigende Tangente hat eine positive Steigung; eine fallende Tangente eine negative; eine waagerechte Tangente die Steigung null – und genau dort passiert oft etwas."),
                .list([
                    "$f'(a) > 0$: Die Kurve steigt in $a$",
                    "$f'(a) < 0$: Sie fällt",
                    "$f'(a) = 0$: waagerechte Tangente, oft ein Hoch- oder Tiefpunkt",
                ]),
                .heading("Warum das wichtig ist"),
                .paragraph("Die Ableitung ist nicht nur ein Schulstoff: Sie steckt überall, wo sich etwas ändert. Die Geschwindigkeit ist die Ableitung des Ortes nach der Zeit; die Beschleunigung die Ableitung der Geschwindigkeit. In der Wirtschaft sind die Grenzkosten die Ableitung der Gesamtkosten. Wenn eine Physikerin oder ein Ökonom fragt „mit welcher Rate?“, fragen sie nach einer Ableitung."),
                .paragraph("Deshalb wurde der Begriff im 17. Jahrhundert auch zweimal erfunden: von Newton, um die Bewegung der Planeten zu beschreiben, und von Leibniz für die Geometrie der Kurven. Zwei Probleme, eine Idee: ==betrachten, was unendlich nah an einem Punkt passiert==."),
            ]),
            DemoChapter(title: "Eine Ableitung berechnen", blocks: [
                .paragraph("Grenzwerte berechnet man fast nie von Hand: Man lernt **die Grundableitungen** und die Regeln, mit denen man sie kombiniert. Mit einer Tabelle von acht Zeilen und drei Regeln kannst du jede Funktion des Lehrplans ableiten – und das muss zur Routine werden."),
                .heading("Die Grundableitungen"),
                .paragraph("Jede Zeile der Tabelle lässt sich mit der Definition aus dem vorigen Kapitel beweisen, und es lohnt sich, das wenigstens einmal für $x^2$ getan zu haben. In der Praxis kennt man sie aber auswendig. Die wichtigste Zeile ist die für $x^n$: Der Exponent wandert als Faktor nach vorn, und der Exponent verringert sich um eins."),
                .table(title: "Grundableitungen", headers: ["f(x)", "f′(x)"], rows: [
                    ["k (Konstante)", "0"],
                    ["x", "1"],
                    ["x²", "2x"],
                    ["xⁿ", "n · xⁿ⁻¹"],
                    ["1/x", "−1/x²"],
                    ["√x", "1/(2√x)"],
                    ["eˣ", "eˣ"],
                    ["ln x", "1/x"],
                ]),
                .paragraph("Zwei Zeilen verdienen eine Bemerkung. Die Ableitung einer Konstanten ist null: Eine Funktion, die sich nicht ändert, hat die Geschwindigkeit null, das ist logisch. Und die Ableitung von $e^x$ ist $e^x$ selbst: Sie ist ==die einzige Funktion==, die ihre eigene Ableitung ist, und genau deshalb ist die Exponentialfunktion in der Physik allgegenwärtig – sie beschreibt alles, was proportional zu seiner Größe wächst."),
                .heading("Die Regeln"),
                .callout(
                    title: "Die drei Regeln",
                    text: "**Summenregel**: $(u+v)' = u' + v'$. **Produktregel**: $(uv)' = u'v + uv'$. **Quotientenregel**: $(u/v)' = (u'v - uv')/v^2$. Und für eine Konstante $k$: $(ku)' = ku'$.",
                    tone: .insight
                ),
                .paragraph("Die Summenregel ist die natürlichste: summandenweise ableiten. Beispiel: $f(x) = 3x^2 - 5x + 2$ ergibt $f'(x) = 6x - 5$. Konstanten fallen weg, ==Exponenten sinken um eins==, Koeffizienten bleiben als Faktoren stehen. Ein Polynom leitet man so in einer Zeile ab."),
                .formula("(uv)' = u'v + uv'", caption: "Die Ableitung eines Produkts: jeden Faktor nacheinander ableiten, dann addieren"),
                .paragraph("Die Produktregel verlangt etwas mehr Sorgfalt. Für $f(x) = x^2 e^x$ setzt man $u = x^2$ und $v = e^x$, also $u' = 2x$ und $v' = e^x$: $f'(x) = 2x\\,e^x + x^2 e^x = (2x + x^2)\\,e^x$. Den ersten Faktor ableiten und den zweiten stehen lassen, dann umgekehrt, und addieren. Das Ausklammern am Ende ist keine Kosmetik: Erst damit kannst du das Vorzeichen untersuchen."),
                .callout(
                    title: "Der Fehler, den du vermeiden musst",
                    text: "$(uv)' \\neq u'v'$. Die Ableitung eines Produkts ist **nicht** das Produkt der Ableitungen: $(x \\cdot x)' = 2x$, nicht $1 \\cdot 1$. Dasselbe gilt für den Quotienten.",
                    tone: .warning
                ),
                .paragraph("Der Quotient folgt derselben Logik, mit einem Minuszeichen und einem Quadrat im Nenner. Für $f(x) = \\frac{x}{x+1}$: $u = x$, $v = x + 1$, also $f'(x) = \\frac{1 \\cdot (x+1) - x \\cdot 1}{(x+1)^2} = \\frac{1}{(x+1)^2}$. Der Zähler vereinfacht sich oft stark – wenn nicht, überprüfe die Rechnung."),
                .heading("Eine Funktion in einer anderen"),
                .paragraph("Bleibt der Fall, dass eine Funktion in eine andere eingesetzt ist: $(2x+1)^3$, $\\sqrt{x^2+1}$, $e^{-x}$. Man leitet die äußere Funktion ab und lässt die innere stehen, dann multipliziert man mit der Ableitung der inneren. Für eine Potenz ergibt das die folgende Formel; für die Exponentialfunktion $(e^{u})' = u'\\,e^{u}$."),
                .formula("(u^n)' = n\\,u'\\,u^{n-1}", caption: "Ableitung einer Potenz einer Funktion: äußere Ableitung mal innere Ableitung"),
                .paragraph("Beispiel: $f(x) = (2x+1)^3$. Die innere Funktion ist $u = 2x+1$ mit der Ableitung $u' = 2$; also $f'(x) = 3 \\cdot 2 \\cdot (2x+1)^2 = 6(2x+1)^2$. Den Faktor $u'$ zu vergessen ist der häufigste Fehler im ganzen Kapitel: Die innere Ableitung ==darf nie fehlen==."),
                .list([
                    "Die Form erkennen: Summe, Produkt, Quotient oder verkettete Funktion",
                    "Jeden Teil mithilfe der Tabelle ableiten",
                    "Mit der passenden Regel zusammensetzen",
                    "Vereinfachen und ausklammern, dann das Vorzeichen prüfen",
                ], ordered: true),
                .paragraph("Diese vier Schritte sind für jede Funktion dieselbe Routine. Mit Übung laufen sie im Kopf ab; ohne Übung auf dem Schmierzettel. So oder so ist der letzte – das Ausklammern – derjenige, der das nächste Kapitel vorbereitet."),
            ]),
            DemoChapter(title: "Ableitung und Monotonie", blocks: [
                .paragraph("Das Vorzeichen der Ableitung sagt dir, ==in welche Richtung die Funktion verläuft==: positiv, sie steigt; negativ, sie fällt. Das ist der Schlüssel zu jeder Monotonietabelle – und der Grund, warum du ableiten gelernt hast."),
                .heading("Der Satz"),
                .paragraph("Ist $f'$ auf einem Intervall positiv, so ist $f$ auf diesem Intervall steigend; ist $f'$ negativ, so ist $f$ fallend; ist $f'$ auf dem ganzen Intervall null, so ist $f$ konstant. Die Anschauung ist die aus Kapitel eins: Eine überall positive Steigung ist eine Kurve, die überall steigt."),
                .figure(.plot(title: "Vorzeichen von f′ und Verlauf von f", caption: "Wo $f'$ positiv ist, steigt $f$; wo $f'$ null wird und dabei das Vorzeichen wechselt, erreicht $f$ ein Extremum.", kind: .variation)),
                .paragraph("Das Diagramm zeigt die beiden Kurven untereinander. Solange $f'$ oberhalb der Achse liegt, steigt $f$; in dem Moment, in dem $f'$ die Achse nach unten schneidet, erreicht $f$ einen Hochpunkt und fällt wieder. Die Stelle, an der $f'$ null wird **und dabei das Vorzeichen wechselt**, ist ein **lokales Extremum**: ein Maximum, wenn $f'$ von positiv zu negativ wechselt, ein Minimum im umgekehrten Fall."),
                .heading("Ein vollständiges Beispiel"),
                .paragraph("Für $f(x) = x^3 - 3x$: $f'(x) = 3x^2 - 3 = 3(x-1)(x+1)$. Die Ableitung wird bei $-1$ und $1$ null. Eine Vorzeichentabelle für ein Produkt aus zwei Faktoren ergibt: positiv vor $-1$, negativ zwischen $-1$ und $1$, positiv nach $1$. Daraus folgt ein **lokales Maximum** bei $-1$ mit $f(-1) = 2$ und ein **lokales Minimum** bei $1$ mit $f(1) = -2$."),
                .table(title: "Monotonie von f(x) = x³ − 3x", headers: ["Intervall", "Vorzeichen von f′", "Verlauf von f"], rows: [
                    ["]−∞ ; −1[", "+", "steigend"],
                    ["]−1 ; 1[", "−", "fallend"],
                    ["]1 ; +∞[", "+", "steigend"],
                ]),
                .paragraph("Die Tabelle ist die erwartete Antwort auf „Untersuche das Monotonieverhalten von $f$“: oben die Intervalle, in der Mitte das Vorzeichen der Ableitung, unten die Pfeile, mit den Funktionswerten an den Stellen, an denen sich die Richtung ändert. Sie ist ein Standardwerkzeug und muss genau in dieser Reihenfolge aufgebaut werden."),
                .callout(
                    title: "Methode",
                    text: "1. Ableiten. 2. Das Vorzeichen von $f'$ untersuchen (ausklammern!). 3. Das Monotonieverhalten folgern. 4. Die Werte an den Rändern und an den Extremstellen berechnen. 5. Die Tabelle aufstellen.",
                    tone: .insight
                ),
                .paragraph("Beim zweiten Schritt geht es schief. Das Vorzeichen einer Ableitung lässt sich an $6x - 5$ oder $3x^2 - 3$ nicht einfach so ablesen: Du musst ==$f'(x) = 0$ lösen== und dann eine Vorzeichentabelle aufstellen, oder ausklammern, um das Vorzeichen jedes Faktors abzulesen. Eine nicht faktorisierte Ableitung ist eine Ableitung, über die du nichts weißt."),
                .keyFigure(value: "f′ = 0", label: "dort hat die Kurve eine waagerechte Tangente: ein Hochpunkt, ein Tiefpunkt oder ein Sattelpunkt"),
                .paragraph("Eine waagerechte Tangente ist also ein Hinweis, kein Beweis: Sie sagt, dass die Funktion für einen Augenblick aufhört zu steigen oder zu fallen, aber nicht, ob sie danach in die andere Richtung weiterläuft. Das entscheidet die Vorzeichentabelle, und nur sie."),
                .callout(
                    title: "Achtung",
                    text: "$f'(a) = 0$ reicht für ein Extremum nicht aus: $x^3$ hat bei 0 die Ableitung null und ändert seine Richtung nicht – das ist ein Sattelpunkt. $f'$ muss bei $a$ **das Vorzeichen wechseln**.",
                    tone: .warning
                ),
                .heading("Eine Kurve lesen"),
                .paragraph("Der Zusammenhang funktioniert auch umgekehrt: Aus dem Graphen von $f$ kannst du das Vorzeichen von $f'$ erschließen, und aus dem Graphen von $f'$ das Monotonieverhalten von $f$. Das ist eine klassische Aufgabe: Man bekommt den Graphen der Ableitung und soll angeben, wo die Funktion steigt. Die Antwort lautet: dort, wo der Graph von $f'$ oberhalb der x-Achse liegt."),
                .list([
                    "Graph von $f$ steigt ⇔ $f'$ positiv",
                    "Hoch- oder Tiefpunkt von $f$ ⇔ $f'$ wird null und wechselt das Vorzeichen",
                    "Graph von $f'$ oberhalb der Achse ⇔ $f$ steigend",
                ]),
                .paragraph("Dieses Hin-und-her-Lesen unterscheidet jemanden, der ein Rezept anwendet, von jemandem, der versteht: Die Ableitung ist nicht noch eine Rechnung mehr, sie ist ==die Kurve aus einem anderen Blickwinkel==. Und sie macht das nächste Kapitel möglich, in dem wir den besten Punkt einer Kurve suchen, die wir nicht gezeichnet haben."),
            ]),
            DemoChapter(title: "Ein Optimierungsproblem lösen", blocks: [
                .paragraph("Optimieren heißt, ==den größten oder den kleinsten Wert== zu finden, den eine Größe annehmen kann: den maximalen Flächeninhalt eines Geheges, die minimalen Kosten einer Schachtel, den höchsten Gewinn. Das sind die Aufgaben, in denen die Ableitung etwas Konkretes leistet – und die, die die meisten Punkte bringen."),
                .heading("Ein Gehege an einer Mauer"),
                .paragraph("Du hast 40 Meter Zaun, um ein rechteckiges Gehege an einer Mauer einzuzäunen: Die Mauer bildet eine Seite, der Zaun die anderen drei. Welche Maße ergeben den größten Flächeninhalt? Nenne $x$ die Breite, senkrecht zur Mauer. Die beiden Breiten verbrauchen $2x$ Meter Zaun; für die Länge bleiben $40 - 2x$. Der Flächeninhalt ist das Produkt der beiden."),
                .formula("A(x) = x\\,(40 - 2x) = 40x - 2x^2", caption: "Der Flächeninhalt des Geheges, für x zwischen 0 und 20"),
                .paragraph("Die Aufgabe ist zu einer Funktionsuntersuchung geworden: Wir suchen das Maximum von $A$ auf $[0 ; 20]$ – über 20 hinaus wäre die Länge negativ. Ableiten: $A'(x) = 40 - 4x$, das bei $x = 10$ null wird, davor positiv, danach negativ. Die Monotonietabelle liefert die Antwort."),
                .table(title: "Monotonie von A(x) = 40x − 2x²", headers: ["x", "Vorzeichen von A′", "Verlauf von A"], rows: [
                    ["[0 ; 10[", "+", "steigend, von 0 bis 200"],
                    ["x = 10", "0", "Maximum: A(10) = 200"],
                    ["]10 ; 20]", "−", "fallend, von 200 bis 0"],
                ]),
                .paragraph("Der maximale Flächeninhalt beträgt $200$ m², bei einer Breite von $10$ m und einer Länge von $20$ m. Beachte, dass es kein Quadrat ist: Weil die Mauer eine Seite ersetzt, ist das beste Rechteck doppelt so lang wie breit. Ohne die Ableitung hätten wir Werte auf gut Glück ausprobieren können; mit ihr haben wir ==die Gewissheit==, dass dies das Beste ist."),
                .callout(
                    title: "Methode",
                    text: "1. Die Variable wählen und das Intervall, in dem sie sinnvoll ist. 2. Die zu optimierende Größe als Funktion dieser einen Variablen ausdrücken. 3. Ableiten, das Vorzeichen untersuchen, die Tabelle aufstellen. 4. Das Extremum ablesen und **die gestellte Frage beantworten** – mit Einheit.",
                    tone: .insight
                ),
                .heading("Ein zweites Beispiel"),
                .paragraph("Ein Unternehmen stellt täglich $x$ hundert Stück her, zu Gesamtkosten von $C(x) = x^2 + 4x + 16$ (in hundert Euro), für $x$ zwischen 1 und 10. Die Durchschnittskosten pro hundert Stück betragen $M(x) = C(x)/x = x + 4 + 16/x$. Bei welcher Produktionsmenge sind diese Durchschnittskosten am niedrigsten?"),
                .formula("M'(x) = 1 - \\frac{16}{x^2} = \\frac{x^2 - 16}{x^2} = \\frac{(x-4)(x+4)}{x^2}", caption: "Die Ableitung, faktorisiert, um ihr Vorzeichen abzulesen"),
                .paragraph("Auf $[1 ; 10]$ sind der Nenner und $x + 4$ positiv: Das Vorzeichen von $M'$ ist das von $x - 4$, negativ vor 4, positiv danach. Die Durchschnittskosten sinken bis $x = 4$ und steigen dann wieder: Das Minimum liegt bei $x = 4$ und beträgt $M(4) = 4 + 4 + 4 = 12$, also 1.200 Euro pro hundert Stück. Vierhundert Stück pro Tag herzustellen ist **die wirtschaftlichste Produktionsmenge**."),
                .figure(.flow(title: "Das Vorgehen", steps: ["Eine Variable", "Eine Funktion", "Ihre Ableitung", "Ihre Tabelle", "Die Antwort"])),
                .paragraph("Die beiden Beispiele folgen genau demselben Weg, und es ist immer derselbe: Die Schwierigkeit eines Optimierungsproblems liegt fast nie in der Ableitung, sondern im **Aufstellen** – die richtige Variable finden und die Größe als Funktion davon schreiben. Steht die Funktion erst einmal, ist der Rest Kapitel drei."),
                .callout(
                    title: "Die Fallen",
                    text: "Das Intervall vergessen (eine negative Länge gibt es nicht); die falsche Größe ableiten (die Gesamtkosten statt der Durchschnittskosten); bei $x = 10$ aufhören, ohne zu sagen, dass der Flächeninhalt $200$ m² beträgt. Erwartet wird **die Antwort auf die Frage**, nicht nur die Tabelle.",
                    tone: .warning
                ),
                .list([
                    "Gehege, Schachtel, Zylinder: eine freie Abmessung, eine Nebenbedingung für Länge oder Volumen",
                    "Kosten, Gewinn, Erlös: eine Produktionsmenge, eine ökonomische Funktion",
                    "Strecke, Geschwindigkeit, Zeit: ein Ort oder ein Zeitpunkt, der zu wählen ist",
                ]),
                .paragraph("Diese drei Aufgabentypen decken fast jede Prüfungsfrage ab. Jedes Mal ist die versteckte Frage dieselbe: ==Für welchen Wert von $x$ wird die Ableitung null und wechselt dabei das Vorzeichen?== Wenn du sie in jeder Verkleidung erkennst, beherrschst du das Kapitel."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Was stellt die Ableitung $f'(a)$ geometrisch dar?",
                back: "Die Steigung der Tangente an den Graphen von $f$ im Punkt mit dem x-Wert $a$.",
                figure: .plot(title: "Die Tangente in a", caption: "", kind: .tangent),
                chapter: 0
            ),
            DemoCard(
                kind: .choice,
                front: "Was ist die Ableitung von $f(x) = 3x^2 - 5x + 2$?",
                back: "$f'(x) = 6x - 5$: Der Exponent sinkt um eins, aus dem $x$-Term wird seine Steigung, die Konstante fällt weg.",
                choices: ["$6x - 5$", "$3x - 5$", "$6x + 2$", "$x^2 - 5$"],
                answerIndex: 0,
                chapter: 1
            ),
            DemoCard(
                kind: .cloze,
                front: "Auf einem Intervall, auf dem $f'$ … ist, ist die Funktion $f$ steigend.",
                back: "positiv",
                chapter: 2
            ),
            DemoCard(kind: .basic, front: "Wie lautet die Formel für die Ableitung eines Produkts?", back: "$(uv)' = u'v + uv'$: jeden Faktor nacheinander ableiten und addieren.", chapter: 1),
            DemoCard(kind: .cloze, front: "Die Ableitung von $e^x$ ist … .", back: "$e^x$", chapter: 1),
            DemoCard(kind: .choice, front: "An welchen Stellen hat $f(x) = x^3 - 3x$ ein lokales Extremum?", back: "Bei $x = -1$ (Maximum, Wert 2) und $x = 1$ (Minimum, Wert $-2$): dort, wo $f'(x) = 3(x-1)(x+1)$ null wird und das Vorzeichen wechselt.", choices: ["$x = 0$", "$x = -1$ und $x = 1$", "$x = 3$", "Keine"], answerIndex: 1, chapter: 2),
            DemoCard(kind: .basic, front: "Wie findet man bei einem Optimierungsproblem das Maximum einer Größe?", back: "Die Größe als Funktion einer einzigen Variablen auf dem Intervall ausdrücken, auf dem sie sinnvoll ist, ableiten, das Vorzeichen der Ableitung untersuchen und das Maximum in der Monotonietabelle dort ablesen, wo die Ableitung null wird und von positiv zu negativ wechselt.", chapter: 3),
            DemoCard(kind: .cloze, front: "Mit 40 m Zaun an einer Mauer ist der Flächeninhalt des Geheges bei einer Breite von … m am größten.", back: "10", chapter: 3),
        ]
    )

    // MARK: Physics: energy

    private static let energyDE = OnboardingDemoCourse(
        id: "physics-energy",
        emoji: "⚡️",
        subject: "Physique",
        title: "Energie",
        summary: "Die Energieformen, ihre Erhaltung beim Übergang von einer Form in eine andere, Leistung und Wirkungsgrad, dann Energieflussketten – mit den Formeln und Größenordnungen aus dem Lehrplan.",
        accentIndex: 6,
        chapters: [
            DemoChapter(title: "Die Energieformen", blocks: [
                .paragraph("Energie kann man nicht sehen, sie **wandelt sich um**: ein fallender Apfel, die Wärme eines Motors, das Licht einer Lampe sind dieselbe Größe in verschiedenen Formen. Sie wird in ==Joule (J)== gemessen, und ein Joule ist ungefähr die Energie, die man braucht, um einen Apfel einen Meter hochzuheben."),
                .heading("Eine Größe, mehrere Formen"),
                .paragraph("Physiker haben zwei Jahrhunderte gebraucht, um zu verstehen, dass Wärme, Bewegung, Licht und Elektrizität ein und dasselbe in verschiedenen Kleidern sind. Was sie verbindet: Jede lässt sich in eine andere umwandeln – ein Motor macht aus Wärme Bewegung, ein Dynamo aus Bewegung Elektrizität –, und die Gesamtmenge ändert sich dabei nie. Die folgende Tabelle listet die Formen aus dem Lehrplan auf."),
                .table(title: "Die gängigen Formen", headers: ["Form", "Hängt ab von", "Beispiel"], rows: [
                    ["Kinetisch", "Masse und Geschwindigkeit", "ein fahrendes Auto"],
                    ["Potenziell (Lageenergie)", "Masse und Höhe", "ein Apfel am Baum"],
                    ["Thermisch", "Teilchenbewegung", "ein heißer Topf"],
                    ["Elektrisch", "Strom", "eine Batterie"],
                    ["Chemisch", "Bindungen", "Benzin, Glucose"],
                ]),
                .paragraph("Für zwei dieser Formen musst du die Formel auswendig kennen. Die **kinetische Energie** ist die eines bewegten Körpers: Sie wächst mit der Masse und mit dem Quadrat der Geschwindigkeit. Doppelte Masse bedeutet doppelte Energie; doppelte Geschwindigkeit vierfache. Dieses Quadrat macht Unfälle bei hoher Geschwindigkeit so schwer."),
                .formula("E_k = \\frac{1}{2} m v^2", caption: "Kinetische Energie: m in kg, v in m/s, E in J"),
                .paragraph("Die **potenzielle Energie** (Lageenergie) ist die eines Körpers in einer bestimmten Höhe: Energie „auf Vorrat“, die zu Bewegung wird, wenn man loslässt. Sie ist proportional zur Masse, zur Höhe und zur Stärke der Schwerkraft $g$, auf der Erde etwa $9.8$ N/kg – und auf dem Mond sechsmal weniger."),
                .formula("E_p = m g h", caption: "Potenzielle Energie: g ≈ 9,8 N/kg, h in m"),
                .callout(
                    title: "Größenordnung",
                    text: "Ein Auto mit 1.000 kg bei 50 km/h (≈ 14 m/s) hat $E_k = \\frac{1}{2} \\times 1000 \\times 14^2 \\approx 98\\,000$ J, fast 100 kJ. Bei 100 km/h **viermal so viel**: 400 kJ, die Energie, die nötig wäre, um es vierzig Meter hochzuheben.",
                    tone: .example
                ),
                .paragraph("Dieses Beispiel zeigt die Einheitenfalle: Die Geschwindigkeit muss in Metern pro Sekunde stehen, nicht in Kilometern pro Stunde, sonst ist das Ergebnis um den Faktor dreizehn falsch. Zum Umrechnen teilt man km/h durch 3,6. Das ist ==das Erste, was man prüfen muss==, bei jeder Berechnung der kinetischen Energie."),
                .keyFigure(value: "× 4", label: "wenn sich die Geschwindigkeit verdoppelt, vervierfacht sich die kinetische Energie: Das ist das Quadrat in der Formel"),
                .heading("Einheiten"),
                .paragraph("Das Joule ist im Alltag eine kleine Einheit, deshalb verwendet man Vielfache: das Kilojoule (1 kJ = 1.000 J) für Lebensmittel, das Megajoule für Kraftstoffe, die Kilowattstunde für Strom. Ein Gramm Zucker liefert etwa 17 kJ; ein Liter Benzin 35 MJ; ein Schokoriegel 1.000 kJ – genug, um ein Auto auf die Spitze des Eiffelturms zu heben, wenn man ohne Verluste umwandeln könnte."),
                .callout(
                    title: "Einheit",
                    text: "Energie wird in Joule angegeben, nie in Watt. Das Watt misst die **Leistung**: Energie pro Sekunde. Die beiden zu verwechseln ist, als würde man einen Liter mit einem Liter pro Minute verwechseln.",
                    tone: .warning
                ),
                .list([
                    "1 kJ = 1.000 J: Der Energiegehalt eines Lebensmittels steht in kJ auf der Verpackung",
                    "1 kWh = 3.600.000 J: die Einheit auf der Stromrechnung",
                    "1 Kalorie ≈ 4,18 J: die alte Einheit, noch immer auf Etiketten",
                ]),
                .paragraph("Merke dir die Logik statt der Zahlen: Energie ist immer eine Menge, wie ein Volumen, und sie wandelt sich von einer Form in eine andere um, ohne je zu verschwinden. Genau dieses Prinzip, das wichtigste der gesamten Physik, formuliert das nächste Kapitel."),
            ]),
            DemoChapter(title: "Erhaltung und Übertragung", blocks: [
                .paragraph("==bleu|Energie wird weder erzeugt noch vernichtet==: Sie geht von einer Form in eine andere über, von einem System in ein anderes. Das ist der Energieerhaltungssatz, und er gilt für alles, vom Atom bis zur Galaxie. Kein Experiment hat ihn je widerlegt."),
                .heading("Ein Fall"),
                .paragraph("Nimm einen Ball, den du zwei Meter über dem Boden hältst. Er hat potenzielle Energie und keine kinetische Energie. Lass ihn los: Während er fällt, nimmt seine Höhe ab und seine Geschwindigkeit zu – potenzielle Energie wird zu kinetischer Energie, in genau gleichem Maß. Am Boden ist alles kinetisch; beim Aufprall wird alles zu Wärme und Schall."),
                .figure(.flow(title: "Die Energiekette eines Falls", steps: ["Potenzielle Energie, oben", "Wird zu kinetischer Energie", "Aufprall: Wärme und Schall", "Gesamtenergie unverändert"])),
                .paragraph("Mit dieser Überlegung kann man rechnen, ohne die Kräfte zu kennen. Ein aus 2 m fallengelassener Ball verliert potenzielle Energie und gewinnt genau so viel kinetische Energie, solange man die Reibung vernachlässigt: $mgh = \\frac{1}{2}mv^2$, die Masse kürzt sich also heraus, und die Geschwindigkeit am Boden ist $v = \\sqrt{2gh}$."),
                .formula("v = \\sqrt{2 g h} \\approx \\sqrt{2 \\times 9{,}8 \\times 2} \\approx 6{,}3 \\text{ m/s}", caption: "Die Geschwindigkeit am Boden, ohne Reibung: gleich für eine Murmel und eine Bowlingkugel"),
                .paragraph("Das Ergebnis hängt nicht von der Masse ab: Eine Murmel und eine Bowlingkugel, die aus derselben Höhe fallengelassen werden, kommen mit derselben Geschwindigkeit an. Galilei soll es vom Schiefen Turm von Pisa aus beobachtet haben; die Energieerhaltung erklärt es in einer Zeile. Das ist ==die Stärke dieses Prinzips==: Es liefert Antworten, wo die Bewegungsgleichungen mühsam wären."),
                .callout(
                    title: "Mechanische Energie",
                    text: "Die Summe aus kinetischer und potenzieller Energie: $E_m = E_k + E_p$. Ohne Reibung bleibt sie erhalten: Was die eine verliert, gewinnt die andere.",
                    tone: .definition
                ),
                .formula("E_m = E_k + E_p = \\text{konstant}", caption: "Wenn keine Reibung wirkt"),
                .paragraph("Das Pendel ist das perfekte Beispiel. Am höchsten Punkt seiner Schwingung steht es einen Augenblick still: Alles ist potenziell. Am tiefsten Punkt ist es am schnellsten: Alles ist kinetisch. Dazwischen geht die Energie unaufhörlich von einer Form in die andere über, und das Pendel steigt genau wieder auf die Höhe, von der es gestartet ist – gäbe es nicht die Luft."),
                .heading("Und die Reibung?"),
                .paragraph("Im echten Leben bleibt das Pendel irgendwann stehen, der Ball springt immer weniger hoch, das Auto hält an, wenn man den Motor abstellt. Die mechanische Energie nimmt ab. Sie ist nicht verschwunden: Die Reibung hat sie in **thermische Energie** umgewandelt, in der Luft, im Boden, in den Bremsen – die sich erwärmen, manchmal stark."),
                .callout(
                    title: "Was Reibung bewirkt",
                    text: "Sie „vernichtet“ nichts: Die verlorene mechanische Energie wird zu thermischer Energie. Die Gesamtenergie bleibt immer erhalten, sie ist nur **weniger nutzbar** – verteilte Wärme bringt nichts mehr in Bewegung.",
                    tone: .insight
                ),
                .paragraph("Dieser Verlust an Nutzbarkeit ist ein tiefer Gedanke. Energie bleibt erhalten, aber sie **wird entwertet**: Jede Umwandlung hinterlässt einen kleinen Teil als lauwarme Wärme, die sich nicht mehr zurückgewinnen lässt. Deshalb ist ein Perpetuum mobile unmöglich, und deshalb muss ein Motor ständig versorgt werden."),
                .list([
                    "Arbeit: Energie, die durch eine Kraft übertragen wird, die etwas bewegt – schieben, heben, bremsen",
                    "Wärme: Übertragung durch einen Temperaturunterschied – ein Topf auf dem Herd",
                    "Strahlung: Übertragung durch Licht – die Sonne, die deine Haut wärmt",
                ]),
                .paragraph("Diese drei Arten sind die einzigen Wege, auf denen Energie von einem System in ein anderes gelangt. Eine **Energiebilanz** aufzustellen heißt, ein System zu wählen, aufzulisten, was auf diesen drei Wegen hineinkommt und hinausgeht, und zu prüfen, ob die Rechnung aufgeht: ==Was hineinkommt minus was hinausgeht, ist das, was bleibt==."),
            ]),
            DemoChapter(title: "Leistung und Wirkungsgrad", blocks: [
                .paragraph("Die **Leistung** gibt an, wie schnell Energie übertragen wird. Ein Heizgerät mit 2.000 W überträgt 2.000 Joule pro Sekunde. Zwei Geräte können dieselbe Energie umsetzen, das eine in einer Minute, das andere in einer Stunde: Das erste ist sechzigmal leistungsstärker."),
                .heading("Leistung"),
                .formula("P = \\frac{E}{\\Delta t}", caption: "P in Watt (W), E in Joule, Δt in Sekunden"),
                .paragraph("Die Formel lässt sich in beide Richtungen lesen. Kennt man Leistung und Dauer, erhält man die Energie: $E = P \\times \\Delta t$. Ein Backofen mit 2.000 W, der eine Stunde lang läuft, verbraucht $2000 \\times 3600 = 7.2 \\times 10^6$ J, also 7,2 MJ. Die Größenordnungen in der Tabelle solltest du dir merken."),
                .table(title: "Einige Leistungen", headers: ["Was", "Leistung"], rows: [
                    ["Ein Mensch in Ruhe", "≈ 100 W"],
                    ["Ein Radfahrer bei voller Anstrengung", "≈ 300 W"],
                    ["Ein Backofen", "2.000 W"],
                    ["Ein Auto", "≈ 100 kW"],
                    ["Eine Windkraftanlage", "≈ 3 MW"],
                    ["Ein Kernreaktor", "≈ 1.000 MW"],
                ]),
                .paragraph("Ein Mensch in Ruhe gibt ungefähr die Leistung einer altmodischen Glühbirne ab: Deshalb wird ein voller Raum schnell warm. Und ein Kernreaktor liefert zehn Millionen Mal mehr – genug, um eine Million Haushalte zu versorgen. Die Leistung ist ==der Durchfluss der Energie==, so wie der Durchfluss eines Wasserhahns der des Wassers ist."),
                .callout(
                    title: "Die Kilowattstunde",
                    text: "1 kWh sind 1.000 W eine Stunde lang: $1000 \\times 3600 = 3.6 \\times 10^6$ J. Sie ist die Einheit auf der Stromrechnung und kostet etwa zwanzig Cent.",
                    tone: .example
                ),
                .paragraph("Die Kilowattstunde ist eine Energie, keine Leistung – die „Stunde“ erinnert daran: eine Leistung mal eine Zeit. Ein französischer Haushalt verbraucht etwa 4.700 kWh Strom im Jahr, im Schnitt etwas mehr als 500 W, Tag und Nacht. Ein Heizkörper mit 2.000 W, der eine achtstündige Nacht lang läuft, verbraucht allein 16 davon."),
                .heading("Wirkungsgrad"),
                .paragraph("Kein Energiewandler ist perfekt: Ein Teil der aufgenommenen Energie geht als Wärme ab und hat keinen Nutzen gebracht. Der ==Wirkungsgrad== vergleicht das Nutzbare mit dem Zugeführten. Ein Benzinmotor erhält die chemische Energie des Kraftstoffs und gibt nur ein Drittel davon als Bewegung ab: Der Rest erwärmt den Motor, den Auspuff und die umgebende Luft."),
                .formula("\\eta = \\frac{E_{\\text{nutz}}}{E_{\\text{zu}}}", caption: "Immer kleiner oder gleich 1 (100 %)"),
                .paragraph("Der Wirkungsgrad wird oft in Prozent angegeben, und entlang einer Kette multipliziert er sich: Hat ein Kraftwerk einen Wirkungsgrad von 35 % und das Stromnetz einen von 90 %, beträgt der Gesamtwirkungsgrad $0.35 \\times 0.9 \\approx 0.32$. Jedes zusätzliche Glied verliert etwas, deshalb versucht man, so wenige wie möglich zu haben."),
                .bars(title: "Wirkungsgrad einiger Energiewandler", unit: "%", bars: [
                    DemoBar(label: "Benzinmotor", value: 35),
                    DemoBar(label: "LED-Lampe", value: 40),
                    DemoBar(label: "Elektromotor", value: 90),
                    DemoBar(label: "Elektroheizung", value: 100),
                ]),
                .paragraph("Das Diagramm erklärt einen guten Teil der Energiewende. Ein Elektromotor wandelt neun Zehntel dessen, was er aufnimmt, in Bewegung um, ein Benzinmotor ein Drittel: Bei gleicher Energie am Anfang kommt das Elektroauto fast dreimal so weit. Eine Glühbirne dagegen hatte einen Wirkungsgrad von 5 % – sie war eine Heizung, die ein bisschen Licht abgab."),
                .callout(
                    title: "100 % Wirkungsgrad?",
                    text: "Eine Elektroheizung wandelt alles in Wärme um, aber Wärme ist genau das, was man will: Ihr Wirkungsgrad beträgt 100 %. Für einen Motor ist dieselbe Wärme ein Verlust. Was **nutzbar** ist, hängt davon ab, was man von dem Gerät verlangt.",
                    tone: .warning
                ),
                .list([
                    "Leistung: Energie pro Sekunde, in Watt",
                    "Energie: Leistung mal Dauer – in Joule oder auf der Rechnung in kWh",
                    "Wirkungsgrad: nutzbar geteilt durch zugeführt, nie größer als 1, und entlang einer Kette multipliziert er sich",
                ]),
                .paragraph("Mit diesen drei Begriffen kannst du jedes Datenblatt lesen und jedes Versprechen überprüfen. Ein Gerät, das mehr nutzbare Energie abgeben würde, als es aufnimmt, würde den Energieerhaltungssatz verletzen; einen Wirkungsgrad über eins ==gibt es nicht==, was auch immer die Werbung sagt."),
            ]),
            DemoChapter(title: "Energieflussketten", blocks: [
                .paragraph("Eine **Energieflusskette** ist das Diagramm, das den Weg der Energie erzählt: woher sie kommt, durch welche Energiewandler sie geht, in welcher Form sie herauskommt und was unterwegs verloren geht. Sie ist ==das Werkzeug der Energiebilanz==, und in einer Prüfung sollst du fast immer eine zeichnen."),
                .heading("Eine Kette lesen"),
                .paragraph("Das Diagramm liest man von links nach rechts. An beiden Enden stehen **Speicher**: wo die Energie am Anfang gespeichert ist und wo sie am Ende landet. Dazwischen stehen **Energiewandler**: die Geräte, die sie ihre Form ändern lassen. Jeder Pfeil trägt eine Energieform, und aus jedem Wandler geht ein Wärmepfeil hinaus – die Verluste. Ein Wasserkraftwerk ist das anschaulichste Beispiel."),
                .figure(.flow(title: "Ein Wasserkraftwerk", steps: ["Gespeichertes Wasser: potenziell", "Fall: kinetisch", "Turbine: mechanisch", "Generator: elektrisch", "Stromnetz"])),
                .paragraph("Das Wasser im Stausee hat wegen seiner Höhe potenzielle Energie. Beim Fallen durch die Rohre wandelt es sie in kinetische Energie um. Die Turbine macht aus dem bewegten Wasser eine Drehung; der Generator macht aus der Drehung Strom; die Leitungen transportieren den Strom ab. Bei jedem Schritt entweicht ein wenig Wärme – aber sehr wenig: Ein Wasserkraftwerk hat einen Wirkungsgrad von fast 90 %, den besten von allen."),
                .paragraph("Dieselbe Logik beschreibt jedes System, auch den menschlichen Körper. Ein Radfahrer wandelt die chemische Energie der Nahrung in seinen Muskeln in mechanische Energie um, mit einem Wirkungsgrad von etwa 25 %: Drei Viertel gehen als Wärme ab, und deshalb schwitzt man."),
                .figure(.flow(title: "Ein Radfahrer", steps: ["Nahrung: chemisch", "Muskeln: mechanisch", "Räder: kinetisch", "Reibung: Wärme"])),
                .heading("Energiewandler"),
                .paragraph("Ein Energiewandler ist dadurch bestimmt, was er aufnimmt und was er abgibt. Die Tabelle fasst die Wandler aus dem Lehrplan zusammen; für jeden gibt die letzte Spalte an, in welcher Form der ungenutzte Teil abgeht. Beachte, dass es **immer Wärme** ist: Sie ist die Endform aller entwerteten Energie."),
                .table(title: "Einige Energiewandler", headers: ["Wandler", "Nimmt auf", "Gibt ab", "Verliert"], rows: [
                    ["Elektromotor", "Elektrisch", "Mechanisch", "Wärme"],
                    ["Solarzelle", "Strahlung", "Elektrisch", "Wärme"],
                    ["Batterie", "Chemisch", "Elektrisch", "Wärme"],
                    ["LED-Lampe", "Elektrisch", "Licht", "Wärme"],
                    ["Benzinmotor", "Chemisch", "Mechanisch", "Wärme, Abgase"],
                ]),
                .paragraph("Die Kette eines Geräts zu zeichnen heißt schon zu verstehen, wie es funktioniert – und oft, warum es warm wird. Ein Computer nimmt elektrische Energie auf und gibt am Ende nichts als Wärme ab: Das Rechnen selbst speichert nichts. Ein warmes Handyladegerät ist ein Energiewandler, der unterwegs ein paar Prozent verliert."),
                .callout(
                    title: "Der Toaster",
                    text: "Er nimmt 1.000 W elektrische Energie auf und gibt 1.000 W Wärme ab: Wirkungsgrad 100 %. Stammt der Strom aber aus einem Wärmekraftwerk mit 35 %, mussten fast 3.000 W Gas verbrannt werden, um das Brot zu toasten. **Die ganze Kette** zählt, nicht nur das letzte Glied.",
                    tone: .example
                ),
                .heading("Woher der Strom kommt"),
                .paragraph("Verfolgt man die Kette ganz zurück, gelangt man zu den **Energiequellen**: was wir verbrennen, was wir fallen lassen, was wir einfangen. Manche erneuern sich in menschlichen Zeiträumen – Sonne, Wind, Wasser, Biomasse –, andere gehen zur Neige – Kohle, Öl, Gas, Uran. Das Diagramm zeigt, woher der Strom in Frankreich kommt, wo die Kernkraft seit den 1980er-Jahren dominiert."),
                .bars(title: "Woher Frankreichs Strom kommt (Größenordnungen)", unit: "%", bars: [
                    DemoBar(label: "Kernkraft", value: 65),
                    DemoBar(label: "Wasserkraft", value: 12),
                    DemoBar(label: "Wind", value: 10),
                    DemoBar(label: "Solar", value: 5),
                    DemoBar(label: "Gas, Kohle", value: 8),
                ]),
                .paragraph("Diese Anteile ändern sich von Jahr zu Jahr – ein trockener Winter leert die Stauseen, ein windreiches Jahr lässt die Windkraft anschwellen –, aber die Reihenfolge bleibt: zwei Drittel Kernkraft, ein Viertel erneuerbare Energien und ein fossiler Anteil, der vor allem für Verbrauchsspitzen genutzt wird. Anderswo in Europa haben Gas und Kohle ein viel größeres Gewicht, und der Strom verursacht dort ein Vielfaches an CO₂."),
                .callout(
                    title: "Erneuerbar, nicht kostenlos",
                    text: "Eine erneuerbare Quelle erneuert sich selbst, aber sie zu nutzen hat seinen Preis: Material, Fläche, Verluste entlang der Kette. Und „erneuerbar“ heißt nicht „folgenlos“: Ein Staudamm überflutet ein Tal, eine Windkraftanlage braucht Kupfer. **Keine Kette ist ohne Verlust, und keine Quelle ohne Folgen.**",
                    tone: .warning
                ),
                .list([
                    "Speicher an beiden Enden, Energiewandler dazwischen, eine Energieform pro Pfeil",
                    "Jeder Wandler verliert Wärme: Der Wirkungsgrad misst das",
                    "Die Wirkungsgrade multiplizieren sich entlang der Kette",
                    "Die Quelle ganz am Anfang entscheidet, was die Energie kostet – und was sie ausstößt",
                ]),
                .paragraph("Mit diesen vier Regeln kannst du jede Kette zeichnen und kommentieren: die eines Handys, eines Zuges, eines Kraftwerks. Es ist das Kapitel, das die Physik mit dem verbindet, was du in den Nachrichten liest – und ==das nützlichste== der vier, um die Welt um dich herum zu verstehen."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Was geschieht mit der potenziellen Energie eines fallenden Balls?",
                back: "Sie wird während des Falls in kinetische Energie umgewandelt (die Geschwindigkeit nimmt zu), beim Aufprall dann in thermische Energie und Schall. Die Gesamtenergie bleibt erhalten.",
                figure: .flow(title: "Energiekette", steps: ["Potenziell", "Kinetisch", "Wärme und Schall"]),
                chapter: 1
            ),
            DemoCard(
                kind: .choice,
                front: "Verdoppelt sich die Geschwindigkeit eines Autos, dann ist seine kinetische Energie …",
                back: "Vervierfacht: $E_k = \\frac{1}{2} m v^2$ hängt vom Quadrat der Geschwindigkeit ab.",
                choices: ["verdoppelt", "vervierfacht", "unverändert", "halbiert"],
                answerIndex: 1,
                chapter: 0
            ),
            DemoCard(
                kind: .cloze,
                front: "Die Leistung ist die pro … übertragene Energie: Sie wird in Watt angegeben.",
                back: "Zeiteinheit",
                chapter: 2
            ),
            DemoCard(kind: .basic, front: "Wie lautet die Formel für die potenzielle Energie (Lageenergie)?", back: "$E_p = m g h$, mit m in kg, g ≈ 9,8 N/kg und h in Metern.", chapter: 0),
            DemoCard(kind: .cloze, front: "Der Wirkungsgrad ist das Verhältnis der … Energie zur zugeführten Energie.", back: "nutzbaren", chapter: 2),
            DemoCard(kind: .choice, front: "Was ist die Einheit der Energie?", back: "Das Joule (J). Das Watt misst die Leistung, also Energie pro Sekunde.", choices: ["Das Watt", "Das Joule", "Das Newton", "Das Volt"], answerIndex: 1, chapter: 0),
            DemoCard(kind: .basic, front: "Was ist eine Energieflusskette?", back: "Das Diagramm, das die Energie von einem Speicher zum anderen durch Energiewandler verfolgt: eine Energieform pro Pfeil und an jedem Wandler ein Pfeil für die Verluste, als Wärme.", chapter: 3),
            DemoCard(kind: .cloze, front: "In einem Wasserkraftwerk wird die … Energie des gespeicherten Wassers beim Fall zu kinetischer Energie.", back: "potenzielle", chapter: 3),
        ]
    )
}
