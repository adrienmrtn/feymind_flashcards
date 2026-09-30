import Foundation

#if DEBUG
// MARK: - Die sechs Debug-Kurse, auf Deutsch

/// Sechs vollständige, vorab geschriebene Kurse, **nur für Debug-Builds**: damit lässt sich
/// die Bibliothek mit einem Handgriff füllen, um Lernblätter, Gliederung, Karten und Wiederholung
/// zu testen, ohne etwas zu generieren. Sie folgen derselben Regel wie die Demo-Kurse — vier
/// Kapitel, Text zwischen jedem reichhaltigen Objekt, kein Objekt, das ein anderes berührt — und
/// demselben Anspruch: Oberstufe oder Studienbeginn, korrekte Fakten, stimmige Zahlen
/// und geprüfte Rechnungen.
///
/// Die Kennungen sind in allen Sprachen gleich; die Fächer sind die kanonischen Namen
/// aus `SubjectCatalog`.
extension DebugCourseCatalog {
    static let german: [OnboardingDemoCourse] = [
        revolutionDE, geneticsDE, probabilityDE, supplyDemandDE, circuitsDE, mitosisDE,
    ]

    // MARK: Geschichte: die Französische Revolution

    private static let revolutionDE = OnboardingDemoCourse(
        id: "debug-revolution",
        emoji: "🇫🇷",
        subject: "Histoire",
        title: "Die Französische Revolution (1789–1799)",
        summary: "Zehn Jahre, die Frankreich von der absoluten Monarchie zur Republik führen: die Krise von 1789, die konstitutionelle Monarchie, die Schreckensherrschaft und schließlich das Direktorium bis zum Staatsstreich Bonapartes.",
        accentIndex: 1,
        chapters: [
            DemoChapter(title: "Die Krise des Ancien Régime (1787–1789)", blocks: [
                .paragraph("1789 ist Frankreich das bevölkerungsreichste Königreich Europas: rund ==28 Millionen Einwohner==, regiert von einem König, der seine Macht von Gott herleitet und sie mit niemandem teilt. Innerhalb von zehn Jahren bricht dieses jahrhundertealte System zusammen. Um zu verstehen, wie, muss man bei dem ansetzen, was man im Nachhinein das **Ancien Régime** nennen wird."),
                .heading("Eine Ständegesellschaft"),
                .paragraph("Die Gesellschaft ist in drei Stände gegliedert, die rechtlich ungleich sind. Der **Klerus** betet, der **Adel** kämpft, der **Dritte Stand** arbeitet: So jedenfalls will es die Theorie. Die beiden ersten Stände genießen **Privilegien** — Sonderrechte wie die Befreiung von der Taille, der wichtigsten direkten Steuer, oder das Recht, von den Bauern Abgaben zu erheben."),
                .callout(
                    title: "Privileg",
                    text: "Wörtlich ein „privates Gesetz“: ein Recht oder eine Befreiung, die einer Gruppe oder einer Person gewährt wird und nicht allen. Im Ancien Régime ist die Ungleichheit vor dem Gesetz und vor der Steuer **die Regel**, nicht die Ausnahme.",
                    tone: .definition
                ),
                .paragraph("Zum Dritten Stand gehören alle, die weder Geistliche noch Adlige sind, also fast alle: die Bauern, die die überwältigende Mehrheit bilden, die Handwerker und Arbeiter der Städte, aber auch ein reiches und gebildetes **Bürgertum** — Kaufleute, Anwälte, Bankiers —, das es immer schlechter erträgt, von den der Geburt vorbehaltenen Ehren ausgeschlossen zu sein."),
                .bars(title: "Anteil der drei Stände an der Bevölkerung (um 1789)", unit: "%", bars: [
                    DemoBar(label: "Klerus", value: 0.5),
                    DemoBar(label: "Adel", value: 1.5),
                    DemoBar(label: "Dritter Stand", value: 98),
                ]),
                .paragraph("Das Diagramm zeigt den Kern des Problems: Zwei Prozent der Bevölkerung besitzen den Großteil der Privilegien, einen großen Teil des Bodens und fast alle hohen Ämter. Im Januar 1789 fasst Abbé Sieyès die Lage in einer berühmten Flugschrift zusammen: „Was ist der Dritte Stand? Alles. Was ist er bisher gewesen? Nichts. Was verlangt er? Etwas zu werden.“"),
                .heading("Drei Krisen zugleich"),
                .paragraph("Die Revolution entsteht aus dem Zusammentreffen dreier Krisen. Zunächst eine **Finanzkrise**: Die Kriege, vor allem die Unterstützung der amerikanischen Unabhängigkeit, haben die Schulden anwachsen lassen, deren Tilgung fast ==die Hälfte der Staatsausgaben== verschlingt. Die aufeinanderfolgenden Minister schlagen vor, die Privilegierten zahlen zu lassen; die Privilegierten lehnen ab."),
                .paragraph("Dann eine **Wirtschaftskrise**: Die Ernte von 1788, vom Hagel verwüstet, ist katastrophal, und der Brotpreis explodiert. Am 14. Juli 1789 erreicht er in Paris seinen höchsten Stand des Jahrhunderts. Schließlich eine **Krise der Ideen**: Die Philosophen der Aufklärung — Montesquieu und die Gewaltenteilung, Rousseau und die Volkssouveränität, Voltaire und die Toleranz — haben die Eliten gelehrt, die Macht im Namen der Vernunft zu beurteilen."),
                .figure(.flow(title: "Von der Krise zur Revolution", steps: ["Schulden und drohender Staatsbankrott", "Die Privilegierten verweigern die Steuer", "Der König beruft die Generalstände ein", "Der Dritte Stand fordert die Abstimmung nach Köpfen", "Der Dritte Stand erklärt sich zur Nationalversammlung"])),
                .paragraph("In die Enge getrieben, beruft Ludwig XVI. die **Generalstände** ein, eine Versammlung der drei Stände, die seit 1614 nicht mehr getagt hatte. Im ganzen Königreich werden **Beschwerdehefte** (cahiers de doléances) verfasst, um dem König zu sagen, was im Argen liegt: fast sechzigtausend, die vor allem Gleichheit bei der Steuer und das Ende der Missbräuche fordern, aber fast nie das Ende der Monarchie."),
                .callout(
                    title: "Die Abstimmung nach Ständen",
                    text: "In den Generalständen stimmt jeder Stand getrennt ab und hat **eine Stimme**: Klerus und Adel schlagen den Dritten Stand gemeinsam immer mit zwei zu eins. Der Dritte Stand hat erreicht, so viele Abgeordnete zu stellen wie die beiden anderen Stände zusammen — doch diese Zahl zählt nur, wenn **nach Köpfen** abgestimmt wird.",
                    tone: .insight
                ),
                .paragraph("Alles entscheidet sich an dieser Verfahrensfrage. Am 17. Juni 1789 erklären sich die Abgeordneten des Dritten Standes mangels Einigung zur ==bleu|Nationalversammlung==: Sie vertreten nicht mehr einen Stand, sondern die ganze Nation. Am 20. Juni finden sie ihren Saal verschlossen, versammeln sich im Ballhaus und schwören, nicht auseinanderzugehen, bevor sie Frankreich eine Verfassung gegeben haben. Die Souveränität hat die Seite gewechselt."),
            ]),
            DemoChapter(title: "1789: das Ende des Absolutismus", blocks: [
                .paragraph("Der Sommer 1789 reißt in wenigen Wochen ein, was Jahrhunderte aufgebaut hatten. Die Revolution der Abgeordneten in Versailles wird von ==der Revolution der Pariser== und dann von der des Landes weitergetragen: Erst dieses Zusammenwirken macht sie unumkehrbar."),
                .timeline(title: "Sommer und Herbst 1789", events: [
                    DemoEvent(date: "5. Mai", label: "Eröffnung der Generalstände in Versailles"),
                    DemoEvent(date: "20. Juni", label: "Ballhausschwur"),
                    DemoEvent(date: "14. Juli", label: "Sturm auf die Bastille"),
                    DemoEvent(date: "4. August", label: "Abschaffung der Privilegien"),
                    DemoEvent(date: "26. August", label: "Erklärung der Menschen- und Bürgerrechte"),
                    DemoEvent(date: "5.–6. Oktober", label: "Der König wird von Versailles nach Paris zurückgeholt"),
                ]),
                .paragraph("Anfang Juli zieht der König Truppen um Paris zusammen und entlässt Necker, den beliebten Minister. Die Pariser sehen darin die Vorbereitung eines Gewaltstreichs gegen die Versammlung. Am 14. Juli stürmt die Menge auf der Suche nach Pulver für die im Invalidendom erbeuteten Gewehre die **Bastille**, eine königliche Festung und Staatsgefängnis. Sie hält nur sieben Gefangene, doch ihr Fall ist ein Symbol: Das Volk hat den König in die Knie gezwungen."),
                .heading("Die Nacht des 4. August"),
                .paragraph("Auf dem Land löst das Gerücht einer aristokratischen Verschwörung die **Große Furcht** (Grande Peur) aus: Bewaffnete Bauern greifen Schlösser an und verbrennen die Register, in denen die grundherrlichen Rechte verzeichnet sind. Um die Ruhe wiederherzustellen, beschließt die Versammlung in der Nacht des 4. August die ==Abschaffung der Privilegien==: Ende der Feudalrechte, des Zehnten und der Käuflichkeit der Ämter, Gleichheit aller vor der Steuer und beim Zugang zu Ämtern."),
                .callout(
                    title: "Erklärung der Menschen- und Bürgerrechte",
                    text: "Am 26. August 1789 verabschiedet, legt sie in siebzehn Artikeln die Grundsätze der neuen Ordnung fest. Artikel 1: „Die Menschen werden frei und gleich an Rechten geboren und bleiben es.“ Artikel 3: Die Souveränität liegt bei **der Nation**. Artikel 16: keine Verfassung ohne Gewaltenteilung.",
                    tone: .definition
                ),
                .paragraph("Die Erklärung ist ein universeller Text — sie spricht vom Menschen, nicht vom Franzosen —, und deshalb hatte sie außerhalb Frankreichs so großen Einfluss. Doch sie hat auch blinde Flecken: Sie sagt nichts über die Frauen und stellt die Sklaverei in den Kolonien nicht infrage. 1791 antwortet Olympe de Gouges darauf mit einer *Erklärung der Rechte der Frau und Bürgerin*."),
                .figure(.split(
                    title: "Zwei Quellen der Macht",
                    left: DemoColumn(title: "Ancien Régime", items: ["Monarchie von Gottes Gnaden", "Ständegesellschaft", "Privilegien", "Der König macht das Gesetz", "Untertanen"]),
                    right: DemoColumn(title: "Grundsätze von 1789", items: ["Nationale Souveränität", "Gleichheit an Rechten", "Ein Gesetz für alle", "Gewaltenteilung", "Bürger"])
                )),
                .paragraph("Die Gegenüberstellung fasst zusammen, was sich 1789 geändert hat: Die Macht kommt nicht mehr von Gott, sondern von der Nation, und das Gesetz ist nicht mehr der Wille eines Einzelnen, sondern ==der Ausdruck des allgemeinen Willens==. Der König bleibt im Amt, doch er ist nur noch der erste Beamte eines Staates, dessen Souveränität er nicht mehr besitzt."),
                .heading("Die konstitutionelle Monarchie"),
                .paragraph("Von 1789 bis 1791 gestaltet die Verfassunggebende Versammlung Frankreich neu. Sie schafft die **Departements** (1790), verstaatlicht die Kirchengüter, um die Schulden zu tilgen, und zwingt dem Klerus eine **Zivilverfassung** auf, die die Priester zu gewählten Beamten macht. Die Verfassung von 1791 errichtet eine konstitutionelle Monarchie: Der König behält die ausführende Gewalt und ein aufschiebendes Vetorecht; eine Gesetzgebende Versammlung beschließt die Gesetze."),
                .callout(
                    title: "Das Zensuswahlrecht",
                    text: "1791 wählen nur die **Aktivbürger**: Männer über 25 Jahre, die eine Steuer von mindestens drei Arbeitstagelöhnen zahlen, also rund 4,3 Millionen Franzosen. Die übrigen sind „Passivbürger“: gleich an Rechten, aber nicht an politischen Rechten.",
                    tone: .warning
                ),
                .paragraph("Dieser Kompromiss beruht auf dem guten Willen des Königs, und der König hat ihn nicht. In der Nacht vom 20. auf den 21. Juni 1791 flieht Ludwig XVI. mit seiner Familie Richtung Ostgrenze; er wird erkannt und in **Varennes** festgenommen. Das Vertrauen ist zerbrochen: Für einen Teil der Pariser kann ein König, der vor seiner Nation flieht, sie nicht mehr vertreten."),
            ]),
            DemoChapter(title: "Die Republik und die Schreckensherrschaft (1792–1794)", blocks: [
                .paragraph("Im April 1792 erklärt Frankreich Österreich den Krieg. Die Revolutionäre hoffen, die Freiheit zu exportieren; der König hofft insgeheim auf die Niederlage, die ihn wieder einsetzen würde. Der Krieg wird ==die Revolution radikalisieren==: Niederlagen, tatsächlicher oder vermuteter Verrat, Aufstände im Inneren und die Überzeugung, um jeden Preis siegen zu müssen."),
                .heading("Der Sturz der Monarchie"),
                .paragraph("Am 10. August 1792 stürmen die Pariser Sansculottes und die aus der Provinz gekommenen Föderierten den Tuilerienpalast. Der König wird abgesetzt und dann eingekerkert. Eine neue Versammlung, der **Nationalkonvent**, wird erstmals nach dem **allgemeinen Männerwahlrecht** gewählt. Am 20. September hält die französische Armee die Preußen bei Valmy auf; am 21. schafft der Konvent das Königtum ab. Die Republik ist geboren."),
                .keyFigure(value: "21. Jan. 1793", label: "Ludwig XVI., vom Konvent verurteilt und des Hochverrats für schuldig befunden, wird auf der Place de la Révolution guillotiniert"),
                .paragraph("Die Hinrichtung des Königs macht Frankreich zum Feind aller Monarchien Europas: England, Spanien und die Vereinigten Niederlande schließen sich der Koalition an. Um Soldaten zu gewinnen, beschließt der Konvent eine Aushebung von 300 000 Mann, und der Westen gerät in Brand: Es ist der Beginn des **Vendée-Kriegs**, der auf beiden Seiten rund zweihunderttausend Tote fordern wird."),
                .figure(.split(
                    title: "Zwei Lager im Konvent",
                    left: DemoColumn(title: "Girondisten", items: ["Brissot, Vergniaud", "Rückhalt in den Provinzen", "Misstrauen gegenüber Paris", "Wirtschaftsliberalismus", "Ablehnung von Ausnahmemaßnahmen"]),
                    right: DemoColumn(title: "Montagnards", items: ["Robespierre, Danton, Marat", "Rückhalt bei den Sansculottes", "Starke Zentralgewalt", "Preiskontrolle", "Ausnahmemaßnahmen"])
                )),
                .paragraph("Zwischen den beiden Gruppen gibt die **Plaine** (die „Ebene“) — die Mehrheit der Abgeordneten — bei Abstimmungen den Ausschlag. Unter dem Druck der Sansculottes, die den Konvent am 2. Juni 1793 umstellen, werden die Anführer der Girondisten verhaftet. Die Montagnards regieren fortan allein, über den **Wohlfahrtsausschuss**, dessen beherrschende Figur Robespierre wird."),
                .heading("Die Schreckensherrschaft"),
                .callout(
                    title: "Die Schreckensherrschaft (Terreur)",
                    text: "Die Ausnahmeregierung von 1793–1794, die die Freiheiten aussetzt, um die durch äußeren Krieg und Bürgerkrieg bedrohte Republik zu retten. Ihre Werkzeuge: das **Gesetz über die Verdächtigen** (September 1793), das Revolutionstribunal, die Volksvertreter auf Mission und die Guillotine.",
                    tone: .definition
                ),
                .paragraph("Die Schreckensherrschaft ist auch eine Wirtschafts- und Sozialpolitik: Das **allgemeine Maximum** legt die Preise lebenswichtiger Güter fest, die **Levée en masse** mobilisiert alle Männer zwischen 18 und 25 Jahren, und der Konvent schafft am 4. Februar 1794 die Sklaverei in den Kolonien ab. Er führt einen Revolutionskalender ein, der die Zeitrechnung am 22. September 1792 beginnen lässt, dem Jahr I der Freiheit."),
                .paragraph("Die menschliche Bilanz ist schwer. Rund ==rose|17 000 Todesurteile== werden von den Gerichten verhängt, die summarischen Hinrichtungen und die Massaker des Bürgerkriegs nicht mitgerechnet. Entgegen einer verbreiteten Vorstellung sind die Opfer nicht vor allem Adlige: Mehrheitlich sind es einfache Leute, verdächtigt der Revolte, des Betrugs oder der Lauheit."),
                .bars(title: "Zum Tode Verurteilte der Schreckensherrschaft nach sozialer Herkunft", unit: "%", bars: [
                    DemoBar(label: "Arbeiter, Handwerker", value: 31),
                    DemoBar(label: "Bauern", value: 28),
                    DemoBar(label: "Bürgertum", value: 25),
                    DemoBar(label: "Adel", value: 8.5),
                    DemoBar(label: "Klerus", value: 6.5),
                ]),
                .paragraph("Diese Zahlen, 1935 vom Historiker Donald Greer ermittelt, zeigen, dass die Schreckensherrschaft vor allem dort zuschlägt, wo sich die Republik bedroht fühlt — in der Vendée, in Lyon, Marseille, Toulon —, und damit dort, wo die meisten Menschen leben. Im Frühjahr 1794 machen die militärischen Siege die Ausnahme schwerer zu rechtfertigen; doch das Gesetz vom 22. Prairial (Juni 1794) beschleunigt die Prozesse noch: Es ist die **Große Terreur**."),
                .callout(
                    title: "Der 9. Thermidor",
                    text: "Am 27. Juli 1794 (9. Thermidor des Jahres II) lassen Abgeordnete, die um ihren eigenen Kopf fürchten, Robespierre und seine Vertrauten verhaften. Sie werden am nächsten Tag guillotiniert. Die Schreckensherrschaft endet nicht, weil ihre Gegner sie von außen besiegt hätten, sondern weil sich ==ihre eigenen Akteure== gegen sie gewandt haben.",
                    tone: .insight
                ),
            ]),
            DemoChapter(title: "Vom Direktorium zu Bonaparte (1795–1799) und was davon bleibt", blocks: [
                .paragraph("Nach dem Thermidor wollen die gemäßigten Republikaner ==die Revolution beenden==: weder Rückkehr des Königs noch Rückkehr der Schreckensherrschaft. Die Verfassung des Jahres III (1795) soll zugleich die Diktatur eines Mannes und die einer Versammlung verhindern."),
                .heading("Ein zerbrechliches Regime"),
                .paragraph("Die ausführende Gewalt liegt bei fünf **Direktoren**, die gesetzgebende bei zwei Räten — dem Rat der Fünfhundert, der die Gesetze vorschlägt, und dem Rat der Alten, der sie beschließt. Das Wahlrecht wird wieder an den Zensus gebunden. Das Regime steckt in der Zange zwischen den Royalisten, die die Wahlen von 1797 gewinnen, und den Neojakobinern, die die von 1798 gewinnen: Jedes Mal annulliert das Direktorium das Ergebnis durch einen Gewaltstreich und stützt sich immer stärker auf die Armee."),
                .table(title: "Die Regierungsformen des Jahrzehnts", headers: ["Regime", "Zeitraum", "Wer regiert", "Wahlrecht"], rows: [
                    ["Absolute Monarchie", "bis 1789", "Der König allein", "Keines"],
                    ["Konstitutionelle Monarchie", "1791–1792", "Der König und die Gesetzgebende Versammlung", "Zensuswahlrecht"],
                    ["Republik: der Konvent", "1792–1795", "Der Konvent, der Wohlfahrtsausschuss", "Allgemeines Männerwahlrecht"],
                    ["Republik: das Direktorium", "1795–1799", "Fünf Direktoren, zwei Räte", "Zensuswahlrecht"],
                    ["Konsulat", "ab 1799", "Bonaparte, Erster Konsul", "Plebiszite"],
                ]),
                .paragraph("Die Tabelle liest sich wie eine Kurve: Die Macht weitet sich bis 1793 aus und verengt sich dann wieder. Und auf jeder Stufe folgt das Wahlrecht derselben Bewegung. Die Revolution hat den Grundsatz der nationalen Souveränität aufgestellt, doch sie hat nie aufgehört, darüber zu streiten, ==wer im Namen der Nation sprechen darf==."),
                .paragraph("Unterdessen setzt sich ein junger General durch. Napoleon Bonaparte hat 1795 einen royalistischen Aufstand in Paris niedergeschlagen, 1796–1797 Italien erobert und dann den Ägyptenfeldzug geführt. Umgeben vom Glanz seiner Siege nach Frankreich zurückgekehrt, verbündet er sich mit Sieyès, inzwischen Direktor, der „einen Säbel“ sucht, um die Verfassung zu ändern."),
                .callout(
                    title: "Der Staatsstreich des 18. Brumaire",
                    text: "Am 9. November 1799 (18. Brumaire des Jahres VIII) stürzen Bonaparte und Sieyès das Direktorium; am nächsten Tag treiben Grenadiere den Rat der Fünfhundert auseinander. Das folgende Konsulat bündelt die Macht in den Händen des Ersten Konsuls. Traditionell datiert man auf diesen Tag **das Ende der Revolution**.",
                    tone: .example
                ),
                .heading("Was von der Revolution bleibt"),
                .paragraph("Bonaparte bewahrt einen großen Teil des Erbes: Der Code civil von 1804 verankert die Gleichheit vor dem Gesetz, das Eigentum und das Ende des Feudalismus. Anderes tilgt er: 1802 führt er die Sklaverei wieder ein und ersetzt die Souveränität der Versammlungen durch seine eigene. Das revolutionäre Erbe lässt sich daher in zwei Spalten lesen: dauerhaft erworbene Grundsätze und Kämpfe, die das ganze 19. Jahrhundert andauern werden."),
                .list([
                    "Dauerhafte Errungenschaften: Ende der Privilegien und der Ständegesellschaft, Gleichheit vor Gesetz und Steuer, Departements, metrisches System, weltliches Personenstandswesen",
                    "Aufgestellte Grundsätze: nationale Souveränität, Menschenrechte, Gewaltenteilung",
                    "Unvollendete Kämpfe: allgemeines Wahlrecht (1848), endgültige Abschaffung der Sklaverei (1848), Frauenwahlrecht (1944)",
                ]),
                .paragraph("Die Jahreszahlen der letzten Zeile zeigen, dass es anderthalb Jahrhunderte gedauert hat, alle Versprechen von 1789 einzulösen. Gerade diese Kluft zwischen ==den verkündeten Grundsätzen und ihrer Umsetzung== macht die Revolution zu einem Gründungsmoment: Sie hat den folgenden Generationen die Worte gegeben, mit denen sie einfordern konnten, was sie selbst nicht gewährt hatte."),
                .figure(.flow(title: "Die Dynamik des Jahrzehnts", steps: ["1789: Die Nation übernimmt die Souveränität", "1791: Kompromiss mit dem König", "1792: Krieg und Republik", "1793–1794: Schreckensherrschaft", "1795–1799: Stabilisierung, dann die Armee"])),
                .paragraph("Dieses Schema ist das Rückgrat eines Aufsatzes über diese Epoche. Jede Stufe antwortet auf das Scheitern der vorigen: Der Kompromiss von 1791 scheitert am König, die gemäßigte Republik am Krieg, die Schreckensherrschaft an ihren Exzessen und das Direktorium an fehlender Legitimität. Zu erklären, ==warum jede Stufe zur nächsten führt==, heißt, die Revolution zu verstehen, statt sie aufzusagen."),
                .callout(
                    title: "Der klassische Fehler",
                    text: "Zu schreiben, die Revolution habe 1789 die Monarchie abgeschafft. 1789 schafft sie den **Absolutismus** und die Privilegien ab; die konstitutionelle Monarchie besteht bis zum 10. August 1792, und die Republik wird erst im September 1792 ausgerufen.",
                    tone: .warning
                ),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Welches sind die drei Stände der Gesellschaft des Ancien Régime?",
                back: "Klerus und Adel, die privilegierten Stände (rund 2 % der Bevölkerung), und der Dritte Stand (rund 98 %), der den Großteil der Steuern zahlt.",
                figure: .split(
                    title: "Eine Ständegesellschaft",
                    left: DemoColumn(title: "Privilegierte", items: ["Klerus", "Adel"]),
                    right: DemoColumn(title: "Nicht Privilegierte", items: ["Dritter Stand"])
                ),
                chapter: 0
            ),
            DemoCard(
                kind: .choice,
                front: "Was beschließt die Versammlung in der Nacht des 4. August 1789?",
                back: "Die Abschaffung der Privilegien: Ende der Feudalrechte, des Zehnten und der Käuflichkeit der Ämter, Gleichheit vor der Steuer.",
                choices: ["Die Erklärung der Menschenrechte", "Die Abschaffung der Privilegien", "Die Abschaffung des Königtums", "Die Zivilverfassung des Klerus"],
                answerIndex: 1,
                chapter: 1
            ),
            DemoCard(
                kind: .cloze,
                front: "Ludwig XVI. wird im Juni 1791 in … festgenommen, als er zur Ostgrenze flieht.",
                back: "Varennes",
                chapter: 1
            ),
            DemoCard(kind: .basic, front: "Warum ist die Frage der Abstimmung nach Ständen oder nach Köpfen 1789 entscheidend?", back: "Nach Ständen setzen sich Klerus und Adel immer mit zwei zu eins durch. Nach Köpfen kann der Dritte Stand, der so viele Abgeordnete hat wie die beiden anderen Stände zusammen, mit einigen Verbündeten die Mehrheit erringen.", hint: "Zählen Sie die Stimmen in beiden Fällen.", chapter: 0),
            DemoCard(kind: .cloze, front: "Am 17. Juni 1789 erklären sich die Abgeordneten des Dritten Standes zur … .", back: "Nationalversammlung", chapter: 0),
            DemoCard(kind: .choice, front: "Wann wird in Frankreich die Republik ausgerufen?", back: "Im September 1792: Der Konvent schafft am 21. September, einen Tag nach Valmy, das Königtum ab.", choices: ["Juli 1789", "Juni 1791", "September 1792", "Juli 1794"], answerIndex: 2, chapter: 2),
            DemoCard(kind: .basic, front: "Was ist die Schreckensherrschaft (Terreur)?", back: "Die Ausnahmeregierung von 1793–1794, die die Freiheiten aussetzt, um die Republik im Krieg zu retten: Gesetz über die Verdächtigen, Revolutionstribunal, rund 17 000 Todesurteile. Sie endet mit dem Sturz Robespierres am 9. Thermidor des Jahres II (27. Juli 1794).", chapter: 2),
            DemoCard(kind: .cloze, front: "Artikel 1 der Erklärung von 1789 lautet: „Die Menschen werden frei und … an Rechten geboren und bleiben es.“", back: "gleich", chapter: 1),
            DemoCard(kind: .choice, front: "Welche soziale Gruppe stellt während der Schreckensherrschaft die meisten Todesurteile?", back: "Die einfachen Leute: Arbeiter, Handwerker und Bauern machen fast sechs von zehn Verurteilten aus; die Adligen rund 8 %.", choices: ["Der Adel", "Der Klerus", "Die Arbeiter, Handwerker und Bauern", "Die Offiziere der Armee"], answerIndex: 2, chapter: 2),
            DemoCard(kind: .basic, front: "Was ist das Zensuswahlrecht?", back: "Ein Wahlrecht, das denen vorbehalten ist, die einen bestimmten Steuerbetrag (den Zensus) zahlen. 1791 wählen nur die „Aktivbürger“, rund 4,3 Millionen Männer.", chapter: 1),
            DemoCard(kind: .cloze, front: "Der Staatsstreich vom 18. … des Jahres VIII (9. November 1799) bringt Bonaparte an die Macht.", back: "Brumaire", chapter: 3),
            DemoCard(kind: .choice, front: "Wie viele Direktoren üben unter dem Direktorium die ausführende Gewalt aus?", back: "Fünf, denen zwei Räte gegenüberstehen: der Rat der Fünfhundert und der Rat der Alten.", choices: ["Einer", "Drei", "Fünf", "Sieben"], answerIndex: 2, chapter: 3),
        ]
    )

    // MARK: Biologie: Genetik und DNA

    private static let geneticsDE = OnboardingDemoCourse(
        id: "debug-genetics",
        emoji: "🧬",
        subject: "SVT",
        title: "Genetik und DNA",
        summary: "Das DNA-Molekül, seine Replikation, der Weg vom Gen zum Protein, die Mutationen, die Vielfalt erzeugen, und die Mendelschen Regeln, die ihre Vererbung beschreiben.",
        accentIndex: 4,
        chapters: [
            DemoChapter(title: "Das DNA-Molekül", blocks: [
                .paragraph("Jede Zelle Ihres Körpers enthält in ihrem Zellkern rund ==zwei Meter DNA==, gefaltet auf wenige Mikrometer. Dieses Molekül trägt die Information, mit der ein Lebewesen aufgebaut und betrieben wird, und es gibt sie von einer Zelle an ihre Tochterzellen weiter, von Eltern an ihre Kinder."),
                .heading("Eine Doppelhelix"),
                .paragraph("Die DNA — die Desoxyribonukleinsäure — ist eine lange Kette aus **Nukleotiden**. Jedes Nukleotid besteht aus drei Bausteinen: einer Phosphatgruppe, einem Zucker, der Desoxyribose, und einer **stickstoffhaltigen Base**. Es gibt vier Basen: Adenin (A), Thymin (T), Guanin (G) und Cytosin (C). Die Reihenfolge dieser Basen entlang des Moleküls bildet die genetische Information."),
                .callout(
                    title: "Basenkomplementarität",
                    text: "Die beiden DNA-Stränge sind über ihre Basen verbunden, die sich immer auf dieselbe Weise paaren: **A mit T** (zwei Wasserstoffbrückenbindungen), **G mit C** (drei Wasserstoffbrückenbindungen). Wer einen Strang kennt, kennt also auch den anderen.",
                    tone: .definition
                ),
                .paragraph("Diese Regel war schon bekannt, bevor man die Struktur verstand: 1950 zeigt Erwin Chargaff, dass die DNA aller Arten ebenso viel Adenin wie Thymin und ebenso viel Guanin wie Cytosin enthält. Die Anteile von A und G dagegen schwanken von Art zu Art."),
                .formula("A = T \\;\\;\\;\\; G = C \\;\\;\\;\\; A + G = T + C", caption: "Die Chargaff-Regeln, als Basenanteile: eine Folge der Basenpaarung"),
                .paragraph("1953 schlagen James Watson und Francis Crick das Modell der **Doppelhelix** vor, gestützt auf die Röntgenbeugungsaufnahmen von Rosalind Franklin. Die beiden Stränge winden sich umeinander wie eine verdrehte Strickleiter: Die Holme sind die Zucker-Phosphat-Ketten, die Sprossen die Basenpaare. Die beiden Stränge sind ==antiparallel==: Sie verlaufen in entgegengesetzter Richtung."),
                .heading("Gene, Chromosomen, Genom"),
                .paragraph("In einer menschlichen Zelle ist die DNA auf **46 Chromosomen** verteilt, 23 von der Mutter und 23 vom Vater. Ein **Gen** ist ein DNA-Abschnitt, der die Information zur Herstellung eines Proteins trägt; es nimmt einen bestimmten Platz auf einem Chromosom ein, seinen **Genort** (Locus). Die gesamte DNA eines Organismus ist sein **Genom**: beim Menschen rund 3,2 Milliarden Basenpaare pro Chromosomensatz."),
                .bars(title: "Anzahl proteincodierender Gene (Größenordnungen)", unit: "Tausend", bars: [
                    DemoBar(label: "Bakterium E. coli", value: 4.3),
                    DemoBar(label: "Hefe", value: 6),
                    DemoBar(label: "Taufliege", value: 14),
                    DemoBar(label: "Fadenwurm C. elegans", value: 20),
                    DemoBar(label: "Mensch", value: 20),
                ]),
                .paragraph("Das Diagramm birgt eine Überraschung: Ein einen Millimeter langer Wurm besitzt ungefähr so viele Gene wie wir. Die Komplexität eines Organismus hängt also nicht von der Zahl seiner Gene ab, sondern davon, ==wie sie genutzt werden== — wann, wo und wie stark. Beim Menschen machen die proteincodierenden Gene übrigens nur rund 1,5 % des Genoms aus."),
                .table(title: "Der Grundwortschatz", headers: ["Begriff", "Definition"], rows: [
                    ["Gen", "DNA-Abschnitt, der für ein Protein codiert"],
                    ["Allel", "Eine Variante eines Gens, die sich in ihrer Sequenz unterscheidet"],
                    ["Genort (Locus)", "Die Position eines Gens auf einem Chromosom"],
                    ["Genotyp", "Die Allele, die ein Individuum besitzt"],
                    ["Phänotyp", "Die daraus resultierenden beobachtbaren Merkmale"],
                ]),
                .paragraph("Diese fünf Begriffe kehren im ganzen weiteren Kurs wieder, und jeder bezeichnet eine andere Ebene: das Molekül, seine Variante, seinen Platz, das, was ein Individuum besitzt, und das, was man an ihm sieht. Ein Phänotyp hängt vom Genotyp ab, aber auch von der Umwelt: Eineiige Zwillinge haben denselben Genotyp, aber nicht unbedingt dieselbe Körpergröße."),
            ]),
            DemoChapter(title: "Die DNA-Replikation", blocks: [
                .paragraph("Vor jeder Teilung muss eine Zelle ihre 3,2 Milliarden Basenpaare kopieren — zweimal, da sie zwei Sätze davon besitzt —, um jeder Tochterzelle ein vollständiges Exemplar mitzugeben. Diese Kopie heißt **Replikation**, und sie ist ==nahezu fehlerfrei==."),
                .heading("Ein semikonservativer Mechanismus"),
                .paragraph("Das Prinzip ergibt sich unmittelbar aus der Komplementarität. Die beiden Stränge der Doppelhelix trennen sich wie ein Reißverschluss, den man öffnet; jeder Strang dient dann als **Matrize** für einen neuen Strang, indem jeder Base ihre komplementäre Base gegenübergestellt wird. So entstehen zwei Moleküle, die dem Ausgangsmolekül gleichen."),
                .figure(.flow(title: "Die Schritte der Replikation", steps: ["Die Helikase öffnet die Doppelhelix", "Jeder Strang dient als Matrize", "Die DNA-Polymerase fügt die komplementären Nukleotide an", "Zwei identische Moleküle, jedes mit einem alten und einem neuen Strang"])),
                .paragraph("Jedes Tochtermolekül enthält also einen vom Muttermolekül übernommenen und einen neu synthetisierten Strang: Man sagt, die Replikation ist **semikonservativ**. Die DNA-Polymerase arbeitet nur in eine Richtung und verlängert den neuen Strang von seinem 5′-Ende zum 3′-Ende hin; die Replikation beginnt an vielen Stellen jedes Chromosoms gleichzeitig."),
                .callout(
                    title: "Das Meselson-Stahl-Experiment (1958)",
                    text: "Bakterien, die auf schwerem Stickstoff (¹⁵N) gezüchtet wurden, werden auf leichten Stickstoff (¹⁴N) umgesetzt. Nach einer Teilung hat ihre gesamte DNA **mittlere** Dichte; nach zwei Teilungen ist sie zur Hälfte mittel, zur Hälfte leicht. Nur das semikonservative Modell sagt genau dieses Ergebnis voraus.",
                    tone: .example
                ),
                .paragraph("Dieses Experiment ist ein Musterbeispiel wissenschaftlichen Vorgehens: Drei Hypothesen standen zur Wahl — konservativ, semikonservativ, dispersiv —, jede sagte ein anderes Ergebnis voraus, und eine einzige Messung genügte zur Entscheidung. Merken Sie sich die Argumentation ebenso wie das Ergebnis: Genau sie sollen Sie in der Prüfung anwenden."),
                .keyFigure(value: "1 / 10⁹", label: "die Größenordnung der Fehlerrate pro kopiertem Nukleotid, nach Durchlaufen der Korrektursysteme"),
                .paragraph("Ein Fehler auf eine Milliarde, das ist etwa ein Tippfehler auf tausend abgeschriebene Bücher. Diese außergewöhnliche Rate wird in zwei Schritten erreicht: Die DNA-Polymerase liest gegen, was sie gerade geschrieben hat, und korrigiert ihre eigenen Fehler; danach reparieren andere Enzyme, was diesem Korrekturlesen entgangen ist. Doch ein Fehler auf eine Milliarde bei sechs Milliarden Basen sind immer noch ==einige Fehler bei jeder Teilung==."),
                .callout(
                    title: "Nicht verwechseln",
                    text: "Die Replikation kopiert **DNA in DNA**, im Zellkern, vor einer Teilung. Die Transkription, die wir im nächsten Kapitel sehen, kopiert **ein Gen in RNA**, zu jedem Zeitpunkt im Leben der Zelle. Gleiches Prinzip der Komplementarität, zwei verschiedene Aufgaben.",
                    tone: .warning
                ),
                .list([
                    "Replikation: vor jeder Teilung, in der S-Phase des Zellzyklus",
                    "Semikonservativ: Jedes Tochtermolekül behält einen Strang des Muttermoleküls",
                    "Schlüsselenzym: die DNA-Polymerase, die verknüpft und Korrektur liest",
                    "Genauigkeit: etwa ein Fehler pro Milliarde Nukleotide",
                ]),
                .paragraph("Diese verbleibenden Fehler sind nicht nur ein Mangel. Gerade sie, über Generationen angesammelt, erzeugen neue Allele und damit die Vielfalt, auf die die Evolution wirkt. Ein perfektes Kopiersystem ergäbe erstarrte Arten: Erst ==die Unvollkommenheit der Replikation== macht Evolution möglich."),
            ]),
            DemoChapter(title: "Vom Gen zum Protein", blocks: [
                .paragraph("Die DNA bleibt im Zellkern, doch die Proteine werden im Cytoplasma hergestellt. Es braucht also einen Vermittler, der die Information kopiert und transportiert: die **Boten-RNA** (mRNA). Die Expression eines Gens erfolgt in zwei Schritten, der ==menthe|Transkription== und der ==bleu|Translation==."),
                .figure(.flow(title: "Die Expression eines Gens", steps: ["DNA (das Gen, im Zellkern)", "Transkription: Boten-RNA", "Die mRNA verlässt den Zellkern", "Translation durch die Ribosomen", "Protein"])),
                .paragraph("Die **Transkription** findet im Zellkern statt. Die RNA-Polymerase öffnet die Doppelhelix im Bereich eines Gens und stellt eine Kopie nur eines der beiden Stränge her, des codogenen Strangs, nach dem Prinzip der Komplementarität. Das entstehende Molekül ist eine RNA: Sie ähnelt der DNA, mit drei Unterschieden."),
                .figure(.split(
                    title: "DNA und RNA",
                    left: DemoColumn(title: "DNA", items: ["Zwei Stränge", "Zucker: Desoxyribose", "Basen A, T, G, C", "Sehr lang, im Zellkern", "Stabil, dauerhaft erhalten"]),
                    right: DemoColumn(title: "Boten-RNA", items: ["Ein einziger Strang", "Zucker: Ribose", "Basen A, U, G, C", "Kurz: ein Gen", "Kurzlebig, nach Gebrauch abgebaut"])
                )),
                .paragraph("Der in Aufgaben nützlichste Unterschied betrifft die Basen: In der RNA **ersetzt Uracil (U) das Thymin**. Gegenüber einem A des codogenen Strangs setzt die RNA-Polymerase also ein U. Die Sequenz der mRNA ist damit identisch mit der des nicht abgelesenen DNA-Strangs, des sogenannten codierenden Strangs, bis auf die T, die dort zu U werden."),
                .heading("Der genetische Code"),
                .paragraph("Die **Translation** findet im Cytoplasma an den Ribosomen statt. Die mRNA wird dort in Dreiergruppen von Nukleotiden gelesen, den **Codons**; jedes Codon entspricht einer Aminosäure, und die Aminosäuren werden zum Protein verknüpft. Die Zuordnung zwischen Codons und Aminosäuren ist der **genetische Code**."),
                .formula("4^3 = 64 \\text{ Codons} \\;\\; \\text{für} \\;\\; 20 \\text{ Aminosäuren}", caption: "Vier Basen, drei Positionen: mehr als genug für zwanzig Aminosäuren"),
                .paragraph("Es gibt also mehr Codons als Aminosäuren: 61 Codons stehen für eine Aminosäure, und 3 sind **Stoppcodons**, die die Translation beenden. Mehrere Codons können dieselbe Aminosäure codieren — man sagt, der Code ist **degeneriert** (redundant) —, aber ein Codon codiert immer nur eine einzige Aminosäure. Die Translation beginnt stets am Codon AUG, das für Methionin codiert."),
                .table(title: "Einige Codons der mRNA", headers: ["Codon", "Aminosäure"], rows: [
                    ["AUG", "Methionin (Startcodon)"],
                    ["GCA", "Alanin"],
                    ["UGG", "Tryptophan"],
                    ["GAG", "Glutaminsäure"],
                    ["GUG", "Valin"],
                    ["UAA, UAG, UGA", "Stopp"],
                ]),
                .paragraph("Die Tabelle zeigt bereits die Redundanz: GAG und GAA codieren beide für Glutaminsäure, und im letzten Kapitel werden wir sehen, dass ein einziger vertauschter Buchstabe — GAG wird zu GUG — genügt, um diese Aminosäure durch Valin zu ersetzen. Um eine Boten-RNA zu übersetzen, geht man immer in derselben Reihenfolge vor: das Codon AUG suchen, in Tripletts unterteilen und dann die Tabelle bis zum ersten Stoppcodon ablesen."),
                .callout(
                    title: "Vollständiges Beispiel",
                    text: "Codierender DNA-Strang: 5′-ATG GCA TGG-3′. Boten-RNA: 5′-AUG GCA UGG-3′ (T wird durch U ersetzt). Protein: **Met – Ala – Trp**. Man liest immer Codon für Codon, ab dem Startcodon, ohne Überlappung.",
                    tone: .example
                ),
                .paragraph("Der genetische Code ist ==universell==: Von seltenen Ausnahmen abgesehen, steht dasselbe Codon bei einem Bakterium, einer Eiche und einem Menschen für dieselbe Aminosäure. Das ist ein starkes Argument für einen gemeinsamen Ursprung aller Lebewesen — und es erlaubt, menschliches Insulin von Bakterien herstellen zu lassen, indem man ihnen einfach das Gen gibt."),
            ]),
            DemoChapter(title: "Mutationen und Vererbung", blocks: [
                .paragraph("Eine **Mutation** ist eine Veränderung der DNA-Sequenz. Sie kann spontan auftreten — ein nicht korrigierter Replikationsfehler — oder durch ein **Mutagen** ausgelöst werden: UV-Strahlung, Röntgenstrahlung, bestimmte chemische Stoffe wie die im Tabakrauch. Nicht alle Mutationen sind gleichwertig, und ihre Wirkung hängt davon ab, ==wo sie auftreten==."),
                .heading("Die Arten von Mutationen"),
                .table(title: "Punktmutationen und ihre Folgen", headers: ["Art", "Was sich ändert", "Wirkung auf das Protein"], rows: [
                    ["Stumme Mutation", "Eine Base, aber dieselbe Aminosäure", "Keine, dank der Redundanz des Codes"],
                    ["Missense-Mutation", "Eine Base, eine andere Aminosäure", "Unterschiedlich: keine bis schwer"],
                    ["Nonsense-Mutation", "Ein Codon wird zum Stoppcodon", "Verkürztes, oft funktionsloses Protein"],
                    ["Insertion oder Deletion", "Eine Base mehr oder weniger", "Verschiebung des Leserasters: stark verändertes Protein"],
                ]),
                .paragraph("Die Sichelzellenanämie ist das am besten untersuchte Beispiel. Im Hämoglobin-Gen wird das sechste Codon von GAG zu GTG: Eine einzige Base ändert sich, und die Glutaminsäure wird durch Valin ersetzt. Dieses abnorme Hämoglobin polymerisiert bei Sauerstoffmangel und verformt die roten Blutkörperchen zu Sicheln."),
                .callout(
                    title: "Eine Mutation, zwei Wirkungen",
                    text: "Menschen mit zwei mutierten Allelen sind krank; wer nur eines trägt, ist gesund und zudem **besser gegen Malaria geschützt**. Deshalb ist das Allel in Afrika südlich der Sahara häufig: Wo Malaria verbreitet ist, verschafft es seinen Trägern einen Vorteil.",
                    tone: .insight
                ),
                .paragraph("Nur Mutationen in den Keimzellen — die **Keimbahnmutationen** — werden an die Nachkommen weitergegeben. Eine Mutation in einer Hautzelle, eine sogenannte **somatische** Mutation, betrifft nur das Individuum und die Zellen, die aus der mutierten Zelle hervorgehen: Sie kann Krebs auslösen, aber keine Erbkrankheit."),
                .heading("Die Mendelschen Regeln"),
                .paragraph("1865 veröffentlicht der Mönch Gregor Mendel die Ergebnisse aus acht Jahren Kreuzungsversuchen mit Erbsen. Er kreuzt reinerbige Linien mit runden Samen mit reinerbigen Linien mit runzligen Samen: Die gesamte erste Tochtergeneration (F1) hat runde Samen. Dann kreuzt er diese Hybride untereinander: In der zweiten Tochtergeneration (F2) tritt das runzlige Merkmal wieder auf, in einem bemerkenswert stabilen Verhältnis."),
                .bars(title: "Mendels Samen in der zweiten Tochtergeneration", unit: "Samen", bars: [
                    DemoBar(label: "Rund", value: 5474),
                    DemoBar(label: "Runzlig", value: 1850),
                ]),
                .paragraph("Das Verhältnis beträgt $5474 / 1850 \\approx 2{,}96$, also fast genau **drei zu eins**. Mendel erklärt es mit einer für seine Zeit kühnen Hypothese: Jedes Individuum besitzt für ein Merkmal zwei „Faktoren“ — wir sagen zwei ==Allele== —, gibt an jeden Gameten nur einen davon weiter, und das Allel rund (R) ist **dominant** über das Allel runzlig (r), das **rezessiv** ist."),
                .table(title: "Kreuzungsschema: Rr × Rr", headers: ["", "Gamet R", "Gamet r"], rows: [
                    ["Gamet R", "RR (rund)", "Rr (rund)"],
                    ["Gamet r", "Rr (rund)", "rr (runzlig)"],
                ]),
                .paragraph("Jedes Feld hat die Wahrscheinlichkeit ein Viertel. Man erhält die Genotypen RR, Rr und rr in den Anteilen 1/4, 1/2 und 1/4 und damit die Phänotypen rund und runzlig in den Anteilen 3/4 und 1/4. Nur **homozygote** Individuen rr zeigen das rezessive Merkmal; **heterozygote** Rr tragen es, ohne es zu zeigen."),
                .formula("P(rr) = \\frac{1}{2} \\times \\frac{1}{2} = \\frac{1}{4}", caption: "Jeder heterozygote Elternteil gibt r mit der Wahrscheinlichkeit 1/2 weiter, unabhängig vom anderen"),
                .paragraph("Dieselbe Überlegung gilt für rezessive Erbkrankheiten des Menschen wie die **Mukoviszidose**: Zwei gesunde Überträger, also heterozygote Eltern, haben bei jeder Schwangerschaft eine Wahrscheinlichkeit von 1/4 für ein krankes Kind. „Bei jeder Schwangerschaft“ ist entscheidend: ==Der Zufall hat kein Gedächtnis==, und ein bereits krankes Kind schützt das nächste nicht."),
                .timeline(title: "Die großen Etappen der Genetik", events: [
                    DemoEvent(date: "1865", label: "Mendel veröffentlicht seine Vererbungsregeln"),
                    DemoEvent(date: "1944", label: "Avery zeigt, dass die DNA die Erbinformation trägt"),
                    DemoEvent(date: "1953", label: "Watson, Crick und Franklin: die Doppelhelix"),
                    DemoEvent(date: "1966", label: "Der genetische Code ist vollständig entschlüsselt"),
                    DemoEvent(date: "2003", label: "Vollständige Sequenz des menschlichen Genoms"),
                    DemoEvent(date: "2012", label: "Charpentier und Doudna: das Werkzeug CRISPR-Cas9"),
                ]),
                .paragraph("Hundertfünfzig Jahre liegen zwischen Mendels Erbsen und den molekularen Scheren, mit denen man heute ein bestimmtes Gen verändern kann. Jede Etappe hat eine Frage beantwortet, die die vorige offengelassen hatte: was weitergegeben wird, woraus es besteht, wie es kopiert wird, wie es gelesen wird — und nun, ==wie man es korrigiert==."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Wie paaren sich die DNA-Basen zwischen den beiden Strängen?",
                back: "Adenin mit Thymin (A–T, zwei Wasserstoffbrückenbindungen) und Guanin mit Cytosin (G–C, drei Wasserstoffbrückenbindungen). Ein Strang legt den anderen also vollständig fest.",
                figure: .split(
                    title: "Komplementarität",
                    left: DemoColumn(title: "Strang 1", items: ["A", "G", "T", "C"]),
                    right: DemoColumn(title: "Strang 2", items: ["T", "C", "A", "G"])
                ),
                chapter: 0
            ),
            DemoCard(
                kind: .choice,
                front: "Welche Boten-RNA entsteht zum codierenden Strang 5′-ATG GCA TGG-3′?",
                back: "5′-AUG GCA UGG-3′: Die mRNA hat die Sequenz des codierenden Strangs, mit U statt T. Sie wird in Met – Ala – Trp übersetzt.",
                choices: ["5′-UAC CGU ACC-3′", "5′-AUG GCA UGG-3′", "5′-TAC CGT ACC-3′", "5′-ATG GCA TGG-3′"],
                answerIndex: 1,
                chapter: 2
            ),
            DemoCard(
                kind: .cloze,
                front: "Die DNA-Replikation wird als … bezeichnet, weil jedes Tochtermolekül einen Strang des Muttermoleküls behält.",
                back: "semikonservativ",
                chapter: 1
            ),
            DemoCard(kind: .basic, front: "Was ist der Unterschied zwischen einem Gen und einem Allel?", back: "Ein Gen ist ein DNA-Abschnitt an einem bestimmten Genort, der für ein Protein codiert. Ein Allel ist eine der Varianten dieses Gens, die sich in ihrer Sequenz von den anderen unterscheidet.", chapter: 0),
            DemoCard(kind: .choice, front: "Wie viele verschiedene Codons gibt es?", back: "64 = 4³: vier mögliche Basen an jeder der drei Positionen. 61 codieren eine Aminosäure, 3 sind Stoppcodons.", choices: ["20", "46", "61", "64"], answerIndex: 3, chapter: 2),
            DemoCard(kind: .cloze, front: "In der RNA wird Thymin durch … ersetzt.", back: "Uracil", chapter: 2),
            DemoCard(kind: .basic, front: "Was zeigt das Meselson-Stahl-Experiment?", back: "Dass die Replikation semikonservativ ist: Nach einer Teilung in ¹⁴N-Medium hat die gesamte DNA mittlere Dichte; nach zwei Teilungen ist sie zur Hälfte mittel, zur Hälfte leicht.", hint: "Denken Sie an die Dichten nach einer und nach zwei Teilungen.", chapter: 1),
            DemoCard(kind: .choice, front: "Welche Mutation verschiebt das Leseraster?", back: "Die Insertion oder Deletion einer Base: Alle folgenden Codons werden verändert, und das Protein ist stark verändert.", choices: ["Eine stumme Mutation", "Eine Missense-Mutation", "Die Deletion einer Base", "Eine Nonsense-Mutation"], answerIndex: 2, chapter: 3),
            DemoCard(kind: .cloze, front: "Zwei heterozygote Eltern Rr haben bei jeder Geburt eine Wahrscheinlichkeit von … für ein Kind rr.", back: "1/4", chapter: 3),
            DemoCard(kind: .basic, front: "Warum ist das Sichelzellallel dort häufig, wo Malaria verbreitet ist?", back: "Weil Heterozygote, die nur ein mutiertes Allel tragen, gesund und besser gegen Malaria geschützt sind: Die natürliche Selektion erhält das Allel.", chapter: 3),
            DemoCard(kind: .cloze, front: "Nach den Chargaff-Regeln ist in doppelsträngiger DNA der Anteil an Guanin gleich dem Anteil an … .", back: "Cytosin", chapter: 0),
            DemoCard(kind: .choice, front: "Wo findet die Translation statt?", back: "Im Cytoplasma, an den Ribosomen, die die Boten-RNA Codon für Codon ablesen.", choices: ["Im Zellkern", "An den Ribosomen im Cytoplasma", "In den Mitochondrien", "An der Zellmembran"], answerIndex: 1, chapter: 2),
        ]
    )

    // MARK: Mathematik: Wahrscheinlichkeitsrechnung

    private static let probabilityDE = OnboardingDemoCourse(
        id: "debug-probability",
        emoji: "🎲",
        subject: "Mathématiques",
        title: "Wahrscheinlichkeitsrechnung",
        summary: "Die Sprache der Ereignisse, bedingte Wahrscheinlichkeiten und Baumdiagramme, die Unabhängigkeit, dann Zufallsgrößen, Erwartungswert und Binomialverteilung.",
        accentIndex: 0,
        chapters: [
            DemoChapter(title: "Die Sprache der Wahrscheinlichkeit", blocks: [
                .paragraph("Wahrscheinlichkeiten messen ==den Grad der Gewissheit== eines Ereignisses, dessen Ausgang man vorher nicht kennt: ein Würfelwurf, eine Ziehung, das Ergebnis eines Tests. Sie sagen nicht voraus, was geschehen wird; sie sagen präzise, wie plausibel jeder Ausgang ist."),
                .heading("Zufallsexperiment, Ergebnismenge, Ereignis"),
                .paragraph("Ein **Zufallsexperiment** ist ein Experiment, dessen mögliche Ergebnisse man alle kennt, ohne vorhersagen zu können, welches eintreten wird. Jeder mögliche Ausgang ist ein **Ergebnis**; die Menge aller Ergebnisse ist die **Ergebnismenge**, geschrieben $\\Omega$. Für einen sechsseitigen Würfel ist $\\Omega$ = {1, 2, 3, 4, 5, 6}."),
                .callout(
                    title: "Ereignis",
                    text: "Ein **Ereignis** ist eine Teilmenge der Ergebnismenge, also eine Menge von Ergebnissen. „Eine gerade Zahl würfeln“ ist das Ereignis $A$ = {2, 4, 6}. Es tritt ein, wenn das erzielte Ergebnis dazugehört.",
                    tone: .definition
                ),
                .paragraph("Ereignisse verknüpft man wie Mengen. Die **Schnittmenge** $A \\cap B$ („A und B“) tritt ein, wenn beide eintreten; die **Vereinigung** $A \\cup B$ („A oder B“), wenn mindestens eines von beiden eintritt; das **Gegenereignis** $Ā$, wenn $A$ nicht eintritt. Zwei Ereignisse sind **unvereinbar**, wenn sie nicht zusammen eintreten können: $A \\cap B = \\emptyset$."),
                .heading("Eine Wahrscheinlichkeit berechnen"),
                .paragraph("Haben alle Ergebnisse dieselbe Chance einzutreten — man spricht von einem **Laplace-Experiment** —, so ist die Wahrscheinlichkeit eines Ereignisses die Anzahl der günstigen Ergebnisse geteilt durch die Anzahl der möglichen Ergebnisse. Das ist die Laplace-Formel, und sie gilt ==nur in diesem Fall==: Ein gezinkter Würfel oder ein ungleich geteiltes Glücksrad erfordern eine andere Methode."),
                .formula("P(A) = \\frac{\\text{Anzahl der günstigen Ergebnisse}}{\\text{Anzahl der möglichen Ergebnisse}}", caption: "Nur bei einem Laplace-Experiment"),
                .paragraph("Werfen wir zwei Würfel und betrachten die Augensumme. Es gibt $6 \\times 6 = 36$ gleich wahrscheinliche Paare, die Summen aber sind es nicht: nur eine Möglichkeit für 2 (1 und 1), sechs Möglichkeiten für 7. Das Diagramm gibt für jede Summe die Anzahl der Paare an, die sie ergeben."),
                .bars(title: "Augensumme zweier Würfel: Anzahl der Paare von 36", unit: nil, bars: [
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
                .paragraph("Man liest ab: $P(\\text{Summe} = 7) = 6/36 = 1/6$ und $P(\\text{Summe} = 2) = 1/36$. Der klassische Fehler besteht darin, mit den elf möglichen Summen so zu rechnen, als wären sie gleich wahrscheinlich, was jeder 1/11 gäbe. ==Man muss immer mit gleich wahrscheinlichen Ergebnissen zählen==, hier den Paaren, und nie mit Ausgängen, die es nicht sind."),
                .table(title: "Die Eigenschaften, die man kennen muss", headers: ["Eigenschaft", "Formel"], rows: [
                    ["Grenzen", "0 ≤ P(A) ≤ 1"],
                    ["Ergebnismenge", "P(Ω) = 1"],
                    ["Gegenereignis", "P(Ā) = 1 − P(A)"],
                    ["Vereinigung", "P(A ∪ B) = P(A) + P(B) − P(A ∩ B)"],
                    ["Unvereinbar", "P(A ∪ B) = P(A) + P(B)"],
                ]),
                .paragraph("Die Formel für die Vereinigung zieht $P(A \\cap B)$ ab, weil die gemeinsamen Ergebnisse doppelt gezählt wurden. Und der Übergang zum Gegenereignis ist oft die effizienteste Abkürzung: Für „mindestens eine Sechs in vier Würfen“ ist es viel einfacher, „keine Sechs“ zu berechnen, also $(5/6)^4 \\approx 0{,}48$, und dann das Gegenereignis zu nehmen: $1 - 0{,}48 \\approx 0{,}52$."),
                .callout(
                    title: "Der Reflex „mindestens ein“",
                    text: "Sobald eine Aufgabe „mindestens ein“ sagt, denken Sie an das Gegenereignis: „kein“. Fast immer ist dann nur ein einziges Produkt zu berechnen statt einer langen Summe von Fällen.",
                    tone: .insight
                ),
            ]),
            DemoChapter(title: "Bedingte Wahrscheinlichkeiten und Baumdiagramme", blocks: [
                .paragraph("Eine neue Information verändert die Wahrscheinlichkeiten. Zu wissen, dass ein Test positiv ist, verändert die Wahrscheinlichkeit, krank zu sein; zu wissen, dass der Würfel eine gerade Zahl zeigt, verändert die Wahrscheinlichkeit, eine 2 gewürfelt zu haben. Die **bedingte Wahrscheinlichkeit** misst die Wahrscheinlichkeit eines Ereignisses, ==wenn man weiß, dass ein anderes eingetreten ist==."),
                .callout(
                    title: "Bedingte Wahrscheinlichkeit",
                    text: "Ist $P(A) \\neq 0$, so ist die Wahrscheinlichkeit von $B$ unter der Bedingung $A$ gleich $P(B | A) = \\frac{P(A \\cap B)}{P(A)}$, in Schulbüchern auch P_A(B) geschrieben. Man schränkt die Ergebnismenge auf die Ergebnisse von $A$ ein und schaut, welcher Anteil davon auch $B$ erfüllt.",
                    tone: .definition
                ),
                .paragraph("Beispiel: Man wirft einen Würfel und erfährt, dass das Ergebnis gerade ist. Die Wahrscheinlichkeit, dass es eine 2 ist, beträgt nicht mehr 1/6, sondern $\\frac{1/6}{1/2} = \\frac{1}{3}$: Es bleiben nur drei mögliche Ergebnisse, 2, 4 und 6. Die Formel lässt sich auch umstellen, und in dieser Form verwendet man sie am Baumdiagramm: $P(A \\cap B) = P(A) \\times P(B | A)$."),
                .heading("Das Baumdiagramm"),
                .paragraph("Ein **Baumdiagramm** stellt ein mehrstufiges Experiment dar. Jeder Ast trägt eine Wahrscheinlichkeit; die Äste, die von einem Knoten ausgehen, haben zusammen die Summe 1; die Wahrscheinlichkeit eines Pfades ist das Produkt der Wahrscheinlichkeiten entlang seiner Äste. Und führen mehrere Pfade zu einem Ereignis, addiert man."),
                .figure(.flow(title: "Ein Baumdiagramm lesen", steps: ["Erste Stufe: A oder Ā", "Zweite Stufe: B oder B̄, abhängig von der ersten", "Ein Pfad: Wahrscheinlichkeiten multiplizieren", "Mehrere Pfade zu B: addieren"])),
                .paragraph("Der letzte Schritt hat einen Namen: der **Satz von der totalen Wahrscheinlichkeit**. Teilen $A$ und $Ā$ die Ergebnismenge in zwei Teile, so tritt $B$ entweder zusammen mit $A$ oder zusammen mit $Ā$ ein, und diese beiden Fälle sind unvereinbar. Man addiert also die beiden Pfade, die zu $B$ führen."),
                .formula("P(B) = P(A) \\times P(B | A) + P(Ā) \\times P(B | Ā)", caption: "Der Satz von der totalen Wahrscheinlichkeit, für eine Zerlegung in A und Ā"),
                .heading("Ein Screening-Test"),
                .paragraph("Eine Krankheit betrifft 1 % der Bevölkerung. Ein Test erkennt sie bei 99 % der Kranken, ist aber auch bei 2 % der Gesunden positiv. Eine Person wird positiv getestet: Wie wahrscheinlich ist es, dass sie krank ist? Die Intuition antwortet „99 %“. Die Rechnung antwortet etwas ganz anderes. Stellen wir uns 10 000 getestete Personen vor."),
                .table(title: "10 000 getestete Personen", headers: ["", "Test positiv", "Test negativ", "Summe"], rows: [
                    ["Krank", "99", "1", "100"],
                    ["Gesund", "198", "9 702", "9 900"],
                    ["Summe", "297", "9 703", "10 000"],
                ]),
                .paragraph("Von den 297 Positiven sind nur 99 krank. Mit Baumdiagramm und Formeln: $P(+) = 0{,}01 \\times 0{,}99 + 0{,}99 \\times 0{,}02 = 0{,}0297$, dann $P(M | +) = \\frac{0{,}0099}{0{,}0297} = \\frac{1}{3}$. Die falsch Positiven, die aus einer hundertmal größeren gesunden Bevölkerung stammen, ==überdecken die richtig Positiven==."),
                .keyFigure(value: "33 %", label: "die Wahrscheinlichkeit, bei positivem Test krank zu sein, obwohl der Test bei Kranken zu 99 % zuverlässig ist"),
                .paragraph("Das Ergebnis hängt weniger von der Güte des Tests ab als von der Seltenheit der Krankheit. Beträfe sie 10 % der Bevölkerung, ergäbe derselbe Test $P(M | +) = \\frac{0{,}099}{0{,}099 + 0{,}018} \\approx 0{,}85$. Eine bedingte Wahrscheinlichkeit berechnet man immer ==mit der Ausgangswahrscheinlichkeit==: Wer die Prävalenz vergisst, vergisst den ersten Ast des Baumes."),
                .callout(
                    title: "Nicht vertauschen",
                    text: "$P(+ | M)$ und $P(M | +)$ sind nicht dasselbe: Die erste beträgt 0,99, die zweite etwa 0,33. „Die Wahrscheinlichkeit eines positiven Tests, wenn man krank ist“ mit „der Wahrscheinlichkeit, krank zu sein, wenn der Test positiv ist“ zu verwechseln, ist der häufigste Fehler, auch unter Ärzten.",
                    tone: .warning
                ),
                .paragraph("Deshalb wird ein positiver Test bei einem Massenscreening immer durch eine zweite, genauere Untersuchung bestätigt. Die Berechnung einer „umgekehrten“ Wahrscheinlichkeit aus dem Baumdiagramm heißt **Satz von Bayes**, nach dem englischen Pfarrer, der ihn im 18. Jahrhundert formulierte."),
            ]),
            DemoChapter(title: "Die Unabhängigkeit", blocks: [
                .paragraph("Zwei Ereignisse sind unabhängig, wenn das Wissen, dass eines eingetreten ist, ==nichts an der Wahrscheinlichkeit des anderen ändert==. Das Ergebnis eines Münzwurfs hängt nicht vom vorigen ab; die Augenfarbe hängt nicht vom Wochentag der Geburt ab."),
                .formula("A \\text{ und } B \\text{ unabhängig} \\Leftrightarrow P(A \\cap B) = P(A) \\times P(B)", caption: "Die Definition, gleichwertig mit P(B | A) = P(B), wenn P(A) ≠ 0"),
                .paragraph("Unabhängigkeit prüft man durch Rechnung, nie nach Gefühl. Werfen wir einen Würfel: Sei $A$ = „gerade“ = {2, 4, 6} und $B$ = „höchstens 2“ = {1, 2}. Es gilt $P(A) = 1/2$, $P(B) = 1/3$ und $A \\cap B$ = {2}, also $P(A \\cap B) = 1/6$. Da $\\frac{1}{2} \\times \\frac{1}{3} = \\frac{1}{6}$, sind die beiden Ereignisse unabhängig — was man mit bloßem Auge nicht sah."),
                .figure(.split(
                    title: "Zwei Begriffe, die man nicht verwechseln darf",
                    left: DemoColumn(title: "Unvereinbar", items: ["Können nicht zusammen eintreten", "A ∩ B = ∅", "P(A ∩ B) = 0", "Mengentheoretischer Begriff"]),
                    right: DemoColumn(title: "Unabhängig", items: ["Das eine sagt nichts über das andere", "P(A ∩ B) = P(A) × P(B)", "Wird durch Rechnung geprüft", "Stochastischer Begriff"])
                )),
                .paragraph("Die beiden Begriffe sind sogar fast gegensätzlich: Sind $A$ und $B$ unvereinbar und haben Wahrscheinlichkeiten ungleich null, so sagt das Wissen, dass $A$ eingetreten ist, mit Sicherheit, dass $B$ nicht eingetreten ist. Sie sind also ==stark abhängig==. „Kopf“ und „Zahl“ beim selben Wurf sind unvereinbar; „Kopf“ beim ersten und „Zahl“ beim zweiten Wurf sind unabhängig."),
                .heading("Ein Experiment wiederholen"),
                .paragraph("Wiederholt man ein Experiment unter gleichen Bedingungen — mehrmals eine Münze werfen, mit Zurücklegen ziehen —, so sind die aufeinanderfolgenden Ergebnisse unabhängig, und die Wahrscheinlichkeit einer Folge von Ergebnissen ist das Produkt der Einzelwahrscheinlichkeiten. Dreimal „Kopf“ mit einer fairen Münze: $\\left(\\frac{1}{2}\\right)^3 = \\frac{1}{8}$."),
                .callout(
                    title: "Der Spielerfehlschluss",
                    text: "Nach zehnmal „Rot“ in Folge beim Roulette ist „Schwarz“ nicht „fällig“: Die Ziehungen sind unabhängig, das Rad hat kein Gedächtnis, und die Wahrscheinlichkeit für Schwarz beim nächsten Wurf ist genau dieselbe wie beim ersten.",
                    tone: .warning
                ),
                .paragraph("Und doch gibt dies der Intuition der Häufigkeiten auf lange Sicht recht. Das **Gesetz der großen Zahlen**, 1713 von Jakob Bernoulli bewiesen, besagt, dass sich bei sehr vielen unabhängigen Wiederholungen die relative Häufigkeit eines Ereignisses seiner Wahrscheinlichkeit annähert. Nicht weil sich Abweichungen „ausgleichen“, sondern weil sie gegenüber der Gesamtzahl der Versuche vernachlässigbar werden."),
                .timeline(title: "Eine kurze Geschichte der Wahrscheinlichkeitsrechnung", events: [
                    DemoEvent(date: "1654", label: "Pascal und Fermat lösen das Teilungsproblem"),
                    DemoEvent(date: "1713", label: "Jakob Bernoulli: das Gesetz der großen Zahlen"),
                    DemoEvent(date: "1763", label: "Postume Veröffentlichung des Satzes von Bayes"),
                    DemoEvent(date: "1812", label: "Laplace, Théorie analytique des probabilités"),
                    DemoEvent(date: "1933", label: "Kolmogorow begründet die Wahrscheinlichkeitsrechnung axiomatisch"),
                ]),
                .paragraph("Die Disziplin entstand aus einer Frage von Spielern: Wie teilt man die Einsätze einer abgebrochenen Partie gerecht auf? Drei Jahrhunderte später dient sie dazu, ein Medikament zu bewerten, eine Versicherungsprämie festzulegen, ein Signal fehlerfrei zu übertragen. Die Methode aber hat sich nicht geändert: ==zählen, bedingen, multiplizieren, addieren==."),
            ]),
            DemoChapter(title: "Zufallsgrößen und Binomialverteilung", blocks: [
                .paragraph("Oft interessiert nicht das Ergebnis selbst, sondern eine Zahl, die davon abhängt: der Gewinn bei einem Spiel, die Zahl richtiger Antworten, die Zahl fehlerhafter Teile. Eine **Zufallsgröße** ordnet jedem Ergebnis eine reelle Zahl zu, und ihre **Wahrscheinlichkeitsverteilung** gibt die Wahrscheinlichkeit jedes ihrer Werte an."),
                .heading("Der Erwartungswert"),
                .paragraph("Ein Spiel: Man setzt 2 €, wirft einen Würfel und erhält 10 €, wenn man eine 6 würfelt. Sei $X$ der Nettogewinn. Fällt die 6, ist $X = 10 - 2 = 8$; sonst $X = -2$. Die Verteilung von $X$ passt in eine Tabelle mit zwei Spalten."),
                .table(title: "Verteilung des Nettogewinns X", headers: ["Wert von X", "−2 €", "8 €"], rows: [
                    ["Wahrscheinlichkeit", "5/6", "1/6"],
                ]),
                .paragraph("Der **Erwartungswert** ist der mit den Wahrscheinlichkeiten gewichtete Mittelwert der Werte: der durchschnittliche Gewinn pro Spiel, wenn man sehr oft spielen würde. Hier ist $E(X) = -2 \\times \\frac{5}{6} + 8 \\times \\frac{1}{6} = \\frac{-10 + 8}{6} = -\\frac{1}{3}$. Der Spieler verliert im Mittel etwa 33 Cent pro Spiel: Das Spiel ist ==ungünstig==."),
                .formula("E(X) = \\sum_{i} x_i \\, P(X = x_i) \\;\\;\\;\\; V(X) = \\sum_{i} P(X = x_i)\\,(x_i - E(X))^2", caption: "Der Erwartungswert misst die Mitte, die Varianz die Streuung um sie herum"),
                .paragraph("Die **Varianz** misst, wie stark die Werte vom Erwartungswert abweichen, und die **Standardabweichung** $\\sigma(X) = \\sqrt{V(X)}$ bringt dieses Maß zurück in die Einheit von $X$. Zwei Spiele mit gleichem Erwartungswert können sehr verschieden sein: Das eine bringt fast immer denselben kleinen Betrag, das andere meistens nichts und selten viel."),
                .heading("Die Binomialverteilung"),
                .callout(
                    title: "Bernoulli-Kette",
                    text: "Man wiederholt $n$-mal **unabhängig** ein Experiment mit zwei Ausgängen: Treffer mit der Wahrscheinlichkeit $p$ oder Niete. Die Anzahl $X$ der Treffer ist **binomialverteilt** mit $B(n, p)$.",
                    tone: .definition
                ),
                .formula("P(X = k) = \\binom{n}{k}\\, p^k \\,(1-p)^{n-k}", caption: "Der Binomialkoeffizient zählt die Pfade des Baumdiagramms, die zu k Treffern führen"),
                .paragraph("Die Formel lässt sich am Baumdiagramm ablesen: Jeder Pfad mit $k$ Treffern und $n - k$ Nieten hat die Wahrscheinlichkeit $p^k (1-p)^{n-k}$, und die Anzahl dieser Pfade ist der Binomialkoeffizient „$n$ über $k$“. Beispiel: ein Multiple-Choice-Test mit 10 Fragen zu je 4 Antworten, rein zufällig ausgefüllt. Die Zahl der richtigen Antworten ist $B(10\\,;\\,0{,}25)$-verteilt; hier ihre Verteilung."),
                .bars(title: "Verteilung von B(10 ; 0,25): Wahrscheinlichkeit für k richtige Antworten", unit: "%", bars: [
                    DemoBar(label: "k = 0", value: 5.6),
                    DemoBar(label: "k = 1", value: 18.8),
                    DemoBar(label: "k = 2", value: 28.2),
                    DemoBar(label: "k = 3", value: 25.0),
                    DemoBar(label: "k = 4", value: 14.6),
                    DemoBar(label: "k = 5", value: 5.8),
                    DemoBar(label: "k = 6", value: 1.6),
                    DemoBar(label: "k = 7", value: 0.3),
                ]),
                .paragraph("Die Verteilung erreicht ihr Maximum bei 2 oder 3 richtigen Antworten und bricht danach ein. Die Hälfte, also 5 von 10, durch Raten zu erreichen, gelingt nur mit einer Wahrscheinlichkeit von etwa ==7,8 %==; gar nichts richtig zu haben, $0{,}75^{10} \\approx 5{,}6\\,\\%$. Für eine Binomialverteilung gibt es für Erwartungswert und Varianz direkte Formeln."),
                .formula("E(X) = np \\;\\;\\;\\; V(X) = np(1-p)", caption: "Hier: E(X) = 10 × 0,25 = 2,5 und V(X) = 2,5 × 0,75 = 1,875"),
                .keyFigure(value: "2,5", label: "richtige Antworten im Mittel bei 10 Fragen mit je vier Auswahlmöglichkeiten, wenn man rät"),
                .paragraph("Die Standardabweichung beträgt $\\sqrt{1{,}875} \\approx 1{,}37$: Die meisten Teilnehmer, die raten, erzielen zwischen 1 und 4 richtige Antworten. Genau das zeigte das Diagramm, und deshalb ziehen manche Multiple-Choice-Tests für jede falsche Antwort Punkte ab — genug, um den Erwartungswert des Ratens auf null zu bringen."),
                .callout(
                    title: "Methode: eine Binomialverteilung begründen",
                    text: "Drei Punkte, die jedes Mal hingeschrieben werden: 1. ein Experiment mit **zwei Ausgängen** (Treffer mit Wahrscheinlichkeit $p$); 2. $n$-mal **gleichartig und unabhängig** wiederholt; 3. $X$ zählt die **Anzahl der Treffer**. Ohne diese drei Sätze ist die Antwort unvollständig.",
                    tone: .insight
                ),
                .paragraph("Den zweiten Punkt vergisst man gern: Ein Ziehen **ohne Zurücklegen** aus einer kleinen Urne ist keine unabhängige Wiederholung, und die Binomialverteilung ist nicht anwendbar. Die Voraussetzungen zu prüfen, bevor man die Formel anwendet, macht ==den ganzen Unterschied== zwischen einer richtigen Rechnung und einer, die nur richtig aussieht."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Wie berechnet man die Wahrscheinlichkeit eines Ereignisses, zu dem mehrere Pfade eines Baumdiagramms führen?",
                back: "Man multipliziert die Wahrscheinlichkeiten entlang jedes Pfades und addiert dann die Ergebnisse der Pfade, die zum Ereignis führen: Das ist der Satz von der totalen Wahrscheinlichkeit.",
                figure: .flow(title: "Ein Baumdiagramm lesen", steps: ["Entlang eines Pfades multiplizieren", "Die Pfade addieren"]),
                chapter: 1
            ),
            DemoCard(
                kind: .choice,
                front: "Man wirft zwei faire Würfel. Wie groß ist die Wahrscheinlichkeit, dass die Augensumme 7 beträgt?",
                back: "1/6: Sechs von 36 Paaren ergeben 7 — (1,6), (2,5), (3,4), (4,3), (5,2), (6,1).",
                choices: ["1/11", "1/12", "1/6", "7/36"],
                answerIndex: 2,
                chapter: 0
            ),
            DemoCard(
                kind: .cloze,
                front: "Zwei Ereignisse A und B sind genau dann unabhängig, wenn $P(A \\cap B) = $ … .",
                back: "$P(A) \\times P(B)$",
                chapter: 2
            ),
            DemoCard(kind: .basic, front: "Wie lautet die Formel für die Wahrscheinlichkeit von B unter der Bedingung A?", back: "$P(B | A) = \\frac{P(A \\cap B)}{P(A)}$, für $P(A) \\neq 0$.", chapter: 1),
            DemoCard(kind: .choice, front: "Eine Krankheit betrifft 1 % der Bevölkerung; ein Test ist bei 99 % der Kranken und bei 2 % der Gesunden positiv. Wie groß ist die Wahrscheinlichkeit, krank zu sein, wenn der Test positiv ist?", back: "Etwa 1/3: $\\frac{0{,}01 \\times 0{,}99}{0{,}01 \\times 0{,}99 + 0{,}99 \\times 0{,}02} = \\frac{0{,}0099}{0{,}0297}$.", hint: "Stellen Sie sich 10 000 getestete Personen vor.", choices: ["99 %", "98 %", "Etwa 33 %", "1 %"], answerIndex: 2, chapter: 1),
            DemoCard(kind: .cloze, front: "Die Wahrscheinlichkeit des Gegenereignisses beträgt $P(Ā) = $ … .", back: "$1 - P(A)$", chapter: 0),
            DemoCard(kind: .basic, front: "Was ist der Unterschied zwischen zwei unvereinbaren und zwei unabhängigen Ereignissen?", back: "Unvereinbar: Sie können nicht zusammen eintreten ($A \\cap B = \\emptyset$). Unabhängig: Das Eintreten des einen ändert die Wahrscheinlichkeit des anderen nicht ($P(A \\cap B) = P(A)P(B)$). Zwei unvereinbare Ereignisse mit Wahrscheinlichkeiten ungleich null sind nie unabhängig.", chapter: 2),
            DemoCard(kind: .choice, front: "Welchen Erwartungswert hat eine Zufallsgröße, die der Binomialverteilung $B(n, p)$ folgt?", back: "$E(X) = np$. Ihre Varianz beträgt $np(1-p)$.", choices: ["$p$", "$np$", "$np(1-p)$", "$n/p$"], answerIndex: 1, chapter: 3),
            DemoCard(kind: .basic, front: "Welche Bedingungen muss man prüfen, um zu behaupten, dass eine Zufallsgröße binomialverteilt ist?", back: "Ein Experiment mit zwei Ausgängen (Treffer mit Wahrscheinlichkeit p), n-mal gleichartig und unabhängig wiederholt, und eine Zufallsgröße X, die die Anzahl der Treffer zählt.", chapter: 3),
            DemoCard(kind: .cloze, front: "Um die Wahrscheinlichkeit für „mindestens einen“ Treffer zu berechnen, geht man über das Gegenereignis: „… Treffer“.", back: "kein", chapter: 0),
            DemoCard(kind: .choice, front: "Man setzt 2 € und erhält 10 €, wenn der Würfel eine 6 zeigt. Wie hoch ist der Erwartungswert des Nettogewinns?", back: "$-2 \\times \\frac{5}{6} + 8 \\times \\frac{1}{6} = -\\frac{1}{3}$, also ein mittlerer Verlust von etwa 0,33 € pro Spiel.", choices: ["$-\\frac{1}{3}$ €", "0 €", "$\\frac{1}{3}$ €", "$\\frac{5}{3}$ €"], answerIndex: 0, chapter: 3),
            DemoCard(kind: .cloze, front: "Das Gesetz der … besagt, dass sich die relative Häufigkeit eines Ereignisses seiner Wahrscheinlichkeit annähert, wenn die Zahl der Wiederholungen sehr groß wird.", back: "großen Zahlen", chapter: 2),
        ]
    )

    // MARK: Wirtschaft: Angebot und Nachfrage

    private static let supplyDemandDE = OnboardingDemoCourse(
        id: "debug-supply-demand",
        emoji: "⚖️",
        subject: "Économie",
        title: "Angebot und Nachfrage",
        summary: "Wie ein Markt einen Preis bildet: Angebots- und Nachfragekurve, das Gleichgewicht, was es verschiebt, die Elastizität und was ein Eingreifen des Staates verändert.",
        accentIndex: 5,
        chapters: [
            DemoChapter(title: "Der Markt und die Nachfrage", blocks: [
                .paragraph("Warum kostet eine Erdbeere im März dreimal so viel wie im Juni? Niemand hat diesen Preis beschlossen: Er ergibt sich aus dem Zusammentreffen von Millionen Kauf- und Verkaufsentscheidungen. Das Modell von Angebot und Nachfrage erklärt, ==wie ein Markt einen Preis bildet==, ohne dass jemand ihn festlegt."),
                .heading("Was ist ein Markt?"),
                .callout(
                    title: "Markt",
                    text: "Der physische oder nicht physische Ort, an dem **Angebot** (was die Verkäufer anbieten) und **Nachfrage** (was die Käufer erwerben möchten) nach einem Gut oder einer Dienstleistung zusammentreffen und an dem sich sein **Preis** bildet.",
                    tone: .definition
                ),
                .paragraph("Ein Markt ist nicht unbedingt ein Ort: Der Arbeitsmarkt, der Devisenmarkt oder der Immobilienmarkt haben keine Markthalle. Um zu argumentieren, gehen Ökonomen von einem Idealfall aus, dem **vollkommenen Wettbewerb**, in dem kein Akteur genug Gewicht hat, um seinen Preis durchzusetzen. Er beruht auf fünf Bedingungen."),
                .list([
                    "Atomistische Marktstruktur: viele Käufer und Verkäufer, jeder zu klein, um den Preis zu beeinflussen",
                    "Homogenität: Alle Verkäufer bieten dasselbe Produkt an",
                    "Markttransparenz: Alle kennen Preise und Qualität",
                    "Freier Marktzutritt: Jeder kann in den Markt eintreten oder ihn verlassen",
                    "Freie Mobilität der Produktionsfaktoren: Arbeit und Kapital gehen dorthin, wo sie am meisten einbringen",
                ]),
                .paragraph("Kein realer Markt erfüllt diese fünf Bedingungen vollkommen, und darum geht es auch nicht: Das Modell dient als ==Vergleichsmaßstab==. Ein Großhandelsmarkt für Agrarprodukte kommt ihm nahe; ein von drei Mobilfunkanbietern beherrschter Markt entfernt sich davon, und genau das misst man, wenn man ihn mit dem Modell vergleicht."),
                .heading("Die Nachfrage"),
                .paragraph("Die **Nachfrage** ist die Menge eines Gutes, die die Käufer zu jedem möglichen Preis erwerben möchten. Sie folgt einem fast universellen Gesetz: Steigt der Preis, sinkt die nachgefragte Menge. Dafür gibt es zwei Gründe. Den **Substitutionseffekt**: Das Gut wird teurer als seine Konkurrenten, man weicht auf diese aus. Den **Einkommenseffekt**: Mit gleichem Budget kann man weniger davon kaufen."),
                .formula("Q_d = 120 - 20\\,p", caption: "Eine lineare Nachfrage: nachgefragte Menge (in Tausend) in Abhängigkeit vom Preis p (in Euro)"),
                .paragraph("Diese Funktion dient im ganzen Kurs als Beispiel: Stellen Sie sich den Wochenmarkt für einen Käse in einer Region vor, in Tausend Stück. Bei 1 € wollen die Käufer 100 000 Stück; bei 5 € nur noch 20 000. Jeder Euro mehr lässt 20 000 Käufer verzichten. Mit dem Preis auf der senkrechten Achse dargestellt, ist das eine **fallende** Gerade: die Nachfragekurve."),
                .callout(
                    title: "Die Begriffsfalle",
                    text: "Ändert sich der Preis eines Gutes, **bewegt man sich entlang** seiner Nachfragekurve: Es ändert sich die *nachgefragte Menge*. Ändert sich etwas anderes — das Einkommen, der Geschmack, der Preis eines anderen Gutes —, **verschiebt sich die ganze Kurve**: Es ändert sich die *Nachfrage*.",
                    tone: .warning
                ),
                .paragraph("Diese Unterscheidung ist die Quelle der meisten Fehler in Aufgaben. „Die Nachfrage sinkt, weil der Preis steigt“ ist falsch: Es sinkt die nachgefragte Menge. Die Nachfrage selbst sinkt, wenn die Einkommen zurückgehen, wenn ein Konkurrenzprodukt billiger wird oder wenn eine Studie eine Gesundheitsgefahr aufdeckt."),
                .timeline(title: "Die Väter des Modells", events: [
                    DemoEvent(date: "1776", label: "Adam Smith, Der Wohlstand der Nationen: die „unsichtbare Hand“"),
                    DemoEvent(date: "1838", label: "Antoine-Augustin Cournot zeichnet die erste Nachfragekurve"),
                    DemoEvent(date: "1874", label: "Léon Walras, die Theorie des allgemeinen Gleichgewichts"),
                    DemoEvent(date: "1890", label: "Alfred Marshall kreuzt Angebot und Nachfrage"),
                ]),
                .paragraph("Marshall verglich Angebot und Nachfrage mit den beiden Klingen einer Schere: Zu fragen, welche das Papier schneidet, ist sinnlos, und ebenso zu fragen, ob Angebot oder Nachfrage den Preis bestimmt. Es ist ==ihr Zusammentreffen==, das ihn festlegt, und das ist Gegenstand des nächsten Kapitels."),
            ]),
            DemoChapter(title: "Das Angebot und das Gleichgewicht", blocks: [
                .paragraph("Den Käufern stehen die Produzenten gegenüber. Das **Angebot** ist die Menge, die sie zu jedem möglichen Preis zu verkaufen bereit sind, und es folgt dem umgekehrten Gesetz der Nachfrage: Je höher der Preis, desto mehr wollen sie verkaufen. Ein höherer Preis macht es rentabel, mehr zu produzieren, und lockt neue Produzenten an."),
                .heading("Die Angebotskurve"),
                .paragraph("Warum braucht es einen höheren Preis, um mehr zu produzieren? Weil jede zusätzliche Einheit kurzfristig immer teurer wird: Überstunden, Maschinen jenseits ihrer normalen Auslastung, schwerer zu beschaffende Rohstoffe. Der Produzent ist nur bereit, eine Einheit mehr herzustellen, wenn der Preis diese steigenden **Grenzkosten** deckt."),
                .formula("Q_s = 20\\,p", caption: "Das Angebot auf demselben Markt: angebotene Menge (in Tausend) in Abhängigkeit vom Preis p"),
                .paragraph("Kurzfristig stößt das Angebot sogar an eine Wand: die Produktionskapazität. Eine Käserei kann nicht mehr herstellen, als ihre Kessel und ihre Milch erlauben, egal zu welchem Preis. Die angebotene Menge steigt mit dem Preis zunächst schnell, dann immer langsamer, bis zu einer Obergrenze."),
                .figure(.plot(title: "Das kurzfristige Angebot stößt an eine Grenze", caption: "Auf der waagrechten Achse der Preis, auf der senkrechten die angebotene Menge: Sie steigt mit dem Preis und stößt dann an die Produktionskapazität.", kind: .saturation)),
                .paragraph("Deshalb treibt ein plötzlicher Anstieg der Nachfrage zunächst eher die Preise als die Mengen nach oben: Die Produzenten können nicht sofort nachziehen. Langfristig investieren sie, neue Produzenten kommen hinzu, und die Obergrenze steigt. In unserem Beispiel bleiben wir in dem Bereich, in dem das Angebot eine Gerade ist."),
                .heading("Das Gleichgewicht"),
                .paragraph("Stellen wir beide Marktseiten einander gegenüber. Für jeden Preis vergleicht man die Menge, die die Käufer wollen, mit der, die die Verkäufer anbieten. Die Tabelle liest sich Zeile für Zeile, und nur in einer Zeile stimmen beide überein."),
                .table(title: "Der Käsemarkt, Preis für Preis", headers: ["Preis", "Nachfrage (Tausend)", "Angebot (Tausend)", "Lage"], rows: [
                    ["1 €", "100", "20", "Knappheit von 80"],
                    ["2 €", "80", "40", "Knappheit von 40"],
                    ["3 €", "60", "60", "Gleichgewicht"],
                    ["4 €", "40", "80", "Überschuss von 40"],
                    ["5 €", "20", "100", "Überschuss von 80"],
                ]),
                .paragraph("Der **Gleichgewichtspreis** ist der Preis, bei dem die angebotene Menge der nachgefragten Menge entspricht. Grafisch ist er der Schnittpunkt der beiden Kurven; algebraisch die Lösung einer linearen Gleichung."),
                .formula("120 - 20\\,p = 20\\,p \\;\\Rightarrow\\; p^* = 3 \\text{ €} \\;\\text{ und }\\; Q^* = 60", caption: "Das Gleichgewicht: Angebot gleich Nachfrage"),
                .paragraph("Zum Preis von 3 € werden jede Woche 60 000 Käse verkauft, und jeder kommt auf seine Kosten: Alle Käufer, die 3 € zu zahlen bereit sind, werden bedient, alle Verkäufer, die zu 3 € verkaufen wollen, haben ihre Produktion abgesetzt. Es gibt ==weder Warteschlangen noch unverkaufte Ware==."),
                .keyFigure(value: "3 €", label: "der Gleichgewichtspreis, der einzige, zu dem 60 000 Käse zugleich einen Verkäufer und einen Käufer finden"),
                .paragraph("Dieser Preis ist nicht nur ein Punkt in einem Diagramm: Der Markt kehrt von selbst zu ihm zurück. Ist der Preis zu niedrig, reißen sich die Käufer um eine knappe Ware und treiben ihn nach oben; ist er zu hoch, bleiben die Verkäufer auf unverkaufter Ware sitzen und senken ihn. Der Mechanismus lässt sich in vier Schritten lesen."),
                .figure(.flow(title: "Die Rückkehr zum Gleichgewicht, ausgehend von einem zu niedrigen Preis", steps: ["Preis bei 2 €: Knappheit von 40 000", "Die Käufer überbieten sich, der Preis steigt", "Die nachgefragte Menge sinkt, das Angebot steigt", "Die Knappheit verschwindet bei 3 €"])),
                .paragraph("Ausgehend von einem zu hohen Preis ist der Mechanismus symmetrisch: Bei 4 € haben die Verkäufer 40 000 Stück übrig, sie senken ihre Preise, um sie abzusetzen, und der Markt sinkt wieder auf 3 €. In beiden Fällen sind es die Abweichungen zwischen Angebot und Nachfrage, die den Preis bewegen, und ihr Verschwinden bringt ihn zum Stillstand."),
                .callout(
                    title: "Die unsichtbare Hand",
                    text: "Der Ausdruck von Adam Smith bezeichnet diesen Mechanismus: Jeder verfolgt sein eigenes Interesse — der Käufer will weniger zahlen, der Verkäufer mehr verdienen —, und der Preis passt sich an, bis er ihre Entscheidungen koordiniert, **ohne dass ein Planer eingreift**. Der Preis ist ein Signal: Er sagt den Produzenten, was sie herstellen, und den Verbrauchern, woran sie sparen sollen.",
                    tone: .insight
                ),
                .paragraph("Der Mechanismus hat eine überraschende Folge: ==Eine Knappheit ist ein Symptom eines zu niedrigen Preises==, nicht einer zu geringen Produktion. Das beobachtet man jedes Mal, wenn ein Preis unterhalb des Gleichgewichts festgeschrieben wird, und das wird das letzte Kapitel untersuchen."),
            ]),
            DemoChapter(title: "Wenn sich das Gleichgewicht verschiebt", blocks: [
                .paragraph("Das Gleichgewicht hält nur so lange, wie sich nichts ändert. Doch alles ändert sich: Einkommen, Geschmack, Kosten, Wetter. Jedes Mal verschiebt sich eine der Kurven, und der Markt findet ==ein neues Gleichgewicht== mit einem anderen Preis und einer anderen Menge."),
                .figure(.split(
                    title: "Was die Kurven verschiebt",
                    left: DemoColumn(title: "Die Nachfrage", items: ["Einkommen der Haushalte", "Preis von Substitutionsgütern", "Preis von Komplementärgütern", "Geschmack, Moden, Informationen", "Größe der Bevölkerung"]),
                    right: DemoColumn(title: "Das Angebot", items: ["Rohstoffkosten", "Löhne, Energie", "Technischer Fortschritt", "Zahl der Produzenten", "Wetter, Steuern, Subventionen"])
                )),
                .paragraph("Die Analysemethode ist immer dieselbe, in drei Fragen: Welche Kurve verschiebt sich? In welche Richtung? Was geschieht mit Gleichgewichtspreis und Gleichgewichtsmenge? Steigt die Nachfrage, steigen Preis und Menge beide. Sinkt das Angebot, steigt der Preis, aber die Menge sinkt."),
                .callout(
                    title: "Ein Frost in Brasilien",
                    text: "Brasilien produziert mehr als ein Drittel des weltweiten Kaffees. Zerstört ein Frost einen Teil der Ernte, sinkt das **Angebot** an Kaffee: Seine Kurve verschiebt sich nach links. Im neuen Gleichgewicht steigt der Kaffeepreis, und die gehandelte Menge sinkt — ohne dass sich die Nachfrage bewegt hat.",
                    tone: .example
                ),
                .paragraph("Manche Märkte finden nicht sanft zu ihrem Gleichgewicht zurück. Braucht die Produktion Zeit — Schweine mästen, Obstplantagen anlegen —, entscheiden die Produzenten über das, was sie morgen verkaufen, anhand des Preises von heute. Ein hoher Preis veranlasst sie alle, mehr zu produzieren; die Produktion kommt gleichzeitig auf den Markt, der Preis bricht ein, und alle drosseln ihre Produktion. Das ist der **Schweinezyklus**, schon in den 1930er-Jahren beschrieben."),
                .figure(.cycle(title: "Der Schweinezyklus", nodes: ["Hoher Preis", "Die Züchter produzieren mehr", "Überproduktion: Der Preis fällt", "Die Züchter produzieren weniger"])),
                .paragraph("Dieser Zyklus zeigt eine Grenze des einfachen Modells: Es unterstellt, dass sich die Mengen sofort anpassen. Er erklärt auch, warum Agrarpreise so instabil sind und warum so viele Länder Maßnahmen zu ihrer Stabilisierung eingeführt haben, wie die europäische **Gemeinsame Agrarpolitik** ab 1962."),
                .heading("Die Preiselastizität"),
                .paragraph("Nicht jede Nachfrage reagiert gleich auf den Preis. Ein Anstieg des Benzinpreises um 10 % lässt die Käufe kurzfristig kaum sinken: Man muss ja zur Arbeit. Derselbe Anstieg bei einer Urlaubsreise kann viele zum Verzicht bewegen. Die **Preiselastizität** misst diese Empfindlichkeit."),
                .formula("e = \\frac{\\Delta Q / Q}{\\Delta p / p}", caption: "Die relative Änderung der nachgefragten Menge, geteilt durch die relative Preisänderung: fast immer negativ"),
                .paragraph("Steigt der Preis um 10 % und sinkt die Menge um 5 %, ist $e = -5 / 10 = -0{,}5$: Die Nachfrage ist **unelastisch**, da $|e| < 1$. Sinkt die Menge um 20 %, ist $e = -2$: Die Nachfrage ist **elastisch**, da $|e| > 1$. Und das ändert für den Verkäufer alles, denn sein **Umsatz** ist der Preis mal der verkauften Menge."),
                .bars(title: "Umsatz der Verkäufer in Abhängigkeit vom Preis (Tausend Euro)", unit: "Tsd. €", bars: [
                    DemoBar(label: "1 €", value: 100),
                    DemoBar(label: "2 €", value: 160),
                    DemoBar(label: "3 €", value: 180),
                    DemoBar(label: "4 €", value: 160),
                    DemoBar(label: "5 €", value: 100),
                ]),
                .paragraph("Das Diagramm zeigt den Umsatz $R = p \\times Q_d$ auf unserem Markt. Er steigt bis 3 € und sinkt dann wieder. Das ist kein Zufall: Entlang einer linearen Nachfrage ändert sich die Elastizität an jedem Punkt, und der Umsatz ist genau ==dort maximal, wo die Elastizität −1 beträgt==."),
                .table(title: "Die Elastizität entlang der Nachfrage Q = 120 − 20p", headers: ["Preis", "Menge", "Elastizität", "Steigt der Preis, dann…"], rows: [
                    ["1 €", "100", "−0,2", "steigt der Umsatz"],
                    ["2 €", "80", "−0,5", "steigt der Umsatz"],
                    ["3 €", "60", "−1", "ist der Umsatz maximal"],
                    ["4 €", "40", "−2", "sinkt der Umsatz"],
                    ["5 €", "20", "−5", "sinkt der Umsatz"],
                ]),
                .paragraph("Die Regel ist allgemein: Bei unelastischer Nachfrage erhöht eine Preissteigerung den Umsatz, weil die Menge prozentual weniger sinkt, als der Preis steigt. Deshalb besteuert der Staat gern Tabak und Kraftstoffe, deren Nachfrage kurzfristig wenig elastisch ist: Die Steuer bringt etwas ein, und der Absatz bricht nicht ein."),
            ]),
            DemoChapter(title: "Der Staat und der Markt", blocks: [
                .paragraph("Der Gleichgewichtspreis wird nicht immer als akzeptabel empfunden: zu hoch für Mieter, zu niedrig für Landwirte oder Beschäftigte. Dann greift der Staat ein, indem er einen Preis festlegt, besteuert oder subventioniert. Das Modell erlaubt es, ==die Wirkungen dieser Eingriffe== vorherzusagen, auch die unerwünschten."),
                .heading("Höchstpreis, Mindestpreis"),
                .callout(
                    title: "Höchstpreis und Mindestpreis",
                    text: "Ein **Höchstpreis** ist ein vom Staat festgesetzter Maximalpreis unterhalb des Gleichgewichts, um die Käufer zu schützen (Mietpreisbegrenzung). Ein **Mindestpreis** ist ein Minimalpreis oberhalb des Gleichgewichts, um die Verkäufer zu schützen (Mindestlohn, garantierte Agrarpreise).",
                    tone: .definition
                ),
                .paragraph("Zurück zu unserem Markt. Ein Höchstpreis von 2 € macht den Käse billiger für die, die welchen finden, doch die Nachfrage steigt auf 80 000 und das Angebot fällt auf 40 000: ==Eine Knappheit von 40 000== entsteht, mit Warteschlangen und Schwarzmarkt. Ein Mindestpreis von 4 € garantiert den Produzenten einen guten Preis, doch sie bieten 80 000 Stück an, während die Käufer nur 40 000 wollen: ein Überschuss von 40 000, der gelagert, vernichtet oder exportiert werden muss."),
                .table(title: "Die Instrumente des Staates", headers: ["Instrument", "Beispiel", "Erwartete Wirkung", "Mögliche Nebenwirkung"], rows: [
                    ["Höchstpreis", "Mietpreisbegrenzung", "Niedrigere Preise", "Knappheit, Wohnungen werden vom Markt genommen"],
                    ["Mindestpreis", "Mindestlohn", "Höhere Einkommen", "Angebotsüberschuss: Arbeitslosigkeit, wenn die Untergrenze zu hoch ist"],
                    ["Steuer", "Tabaksteuer", "Weniger Konsum, Einnahmen", "Schmuggel"],
                    ["Subvention", "Umweltbonus", "Mehr Käufe des geförderten Gutes", "Kosten für die öffentlichen Haushalte"],
                ]),
                .paragraph("Die letzte Spalte ist keine Anklageschrift: Diese Wirkungen hängen vom Abstand zwischen festgesetztem Preis und Gleichgewicht sowie von der Elastizität der Kurven ab. Ein maßvoller Mindestlohn kann eine sehr geringe Wirkung auf die Beschäftigung haben; eine strikte und dauerhafte Mietpreisbegrenzung verringert fast immer das Angebot an Mietwohnungen. Das Modell sagt nicht, ob man eingreifen soll: Es sagt, ==was der Eingriff kostet==."),
                .heading("Wer zahlt eine Steuer?"),
                .paragraph("Der Staat erhebt eine Steuer von 1 € pro Käse, die von den Verkäufern abgeführt wird. Um ein Stück zu verkaufen, verlangt ein Produzent nun 1 € mehr als vorher: Erhält er $p$ von den Käufern, behält er nur $p - 1$. Sein Angebot wird zu $Q_s = 20(p - 1)$, und das Gleichgewicht verschiebt sich."),
                .formula("120 - 20\\,p = 20\\,(p - 1) \\;\\Rightarrow\\; p = 3{,}5 \\text{ €} \\;\\text{ und }\\; Q = 50", caption: "Das neue Gleichgewicht, mit einer Steuer von 1 € pro Stück"),
                .paragraph("Die Käufer zahlen nun 3,50 € statt 3 €: Sie tragen 50 Cent der Steuer. Die Verkäufer erhalten 3,50 €, führen aber 1 € an den Staat ab: Ihnen bleiben 2,50 € statt 3 €, also 50 Cent Verlust. Die Steuer wird ==halb und halb== geteilt, weil die beiden Kurven hier dieselbe Steigung haben. Der Staat nimmt $1 \\times 50\\,000 = 50\\,000$ € pro Woche ein."),
                .callout(
                    title: "Abführen heißt nicht zahlen",
                    text: "Der Verkäufer **führt die Steuer ab**, doch die Elastizität der Kurven entscheidet, wer sie **trägt**. Die am wenigsten elastische Marktseite — die, die nicht ausweichen kann — trägt den größten Teil. Beim Tabak, dessen Nachfrage wenig elastisch ist, sind das vor allem die Raucher.",
                    tone: .warning
                ),
                .paragraph("Die Steuer hat auch versteckte Kosten. Im Gleichgewicht betrugen die **Konsumentenrente** — was die Käufer über den Preis hinaus zu zahlen bereit waren — und die **Produzentenrente** — was die Verkäufer über ihre Kosten hinaus erhalten — je 90 000 €, insgesamt also 180 000 €. Nach der Steuer verteilt sich diese Summe anders, und ein Teil verschwindet."),
                .bars(title: "Die Rente von 180 000 € nach der Steuer (Tausend Euro)", unit: "Tsd. €", bars: [
                    DemoBar(label: "Konsumenten", value: 62.5),
                    DemoBar(label: "Produzenten", value: 62.5),
                    DemoBar(label: "Staat (Steuereinnahmen)", value: 50),
                    DemoBar(label: "Wohlfahrtsverlust", value: 5),
                ]),
                .paragraph("Der **Wohlfahrtsverlust** — 5 000 € pro Woche — entspricht den 10 000 Käsen, die nicht mehr gehandelt werden, obwohl ein Käufer und ein Verkäufer dabei auf ihre Kosten gekommen wären. Er nützt niemandem. Das sind die Effizienzkosten der Steuer, und sie sind umso größer, je elastischer die Kurven sind."),
                .list([
                    "Höchstpreis unter dem Gleichgewicht: Knappheit",
                    "Mindestpreis über dem Gleichgewicht: Überschuss",
                    "Steuer: gezahlter Preis steigt, erhaltener Preis sinkt, Menge sinkt, Wohlfahrtsverlust",
                    "Aufteilung der Steuer: Die am wenigsten elastische Seite trägt den größten Teil",
                ]),
                .paragraph("Diese vier Ergebnisse gelten für jeden Markt, vom Erdöl über die Arbeit bis zu den Wohnungen. Sie sagen nicht, ob ein Eingriff gut oder schlecht ist — der Staat kann den Tabakkonsum senken oder ein Einkommen sichern wollen —, aber sie zwingen dazu, ==seine Wirkungen zu beziffern==, und das ist die erste Aufgabe des Ökonomen."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Was geschieht auf einem Markt, wenn der Preis unter dem Gleichgewichtspreis liegt?",
                back: "Die nachgefragte Menge übersteigt die angebotene Menge: Es herrscht Knappheit. Die Käufer überbieten sich, der Preis steigt, die nachgefragte Menge sinkt und das Angebot steigt, bis das Gleichgewicht wieder erreicht ist.",
                figure: .flow(title: "Rückkehr zum Gleichgewicht", steps: ["Preis zu niedrig", "Knappheit", "Der Preis steigt", "Gleichgewicht"]),
                chapter: 1
            ),
            DemoCard(
                kind: .choice,
                front: "Ein Frost zerstört einen Teil der Kaffeeernte. Was geschieht mit Gleichgewichtspreis und Gleichgewichtsmenge?",
                back: "Das Angebot sinkt (seine Kurve verschiebt sich nach links): Der Gleichgewichtspreis steigt, und die gehandelte Menge sinkt.",
                choices: ["Der Preis steigt, die Menge steigt", "Der Preis steigt, die Menge sinkt", "Der Preis sinkt, die Menge sinkt", "Nichts ändert sich"],
                answerIndex: 1,
                chapter: 2
            ),
            DemoCard(
                kind: .cloze,
                front: "Steigt der Preis eines Gutes, bewegt man sich … seiner Nachfragekurve: Es ändert sich die nachgefragte Menge, nicht die Nachfrage.",
                back: "entlang",
                chapter: 0
            ),
            DemoCard(kind: .basic, front: "Wie lautet das Gleichgewicht bei $Q_d = 120 - 20p$ und $Q_s = 20p$?", back: "$120 - 20p = 20p$ ergibt $p^* = 3$ € und $Q^* = 60$ (Tausend).", hint: "Setzen Sie Angebot und Nachfrage gleich.", chapter: 1),
            DemoCard(kind: .choice, front: "Der Preis steigt um 10 %, und die nachgefragte Menge sinkt um 5 %. Wie groß ist die Preiselastizität der Nachfrage?", back: "$e = -5 / 10 = -0{,}5$: Die Nachfrage ist unelastisch, und eine Preiserhöhung steigert den Umsatz.", choices: ["−2", "−0,5", "0,5", "−5"], answerIndex: 1, chapter: 2),
            DemoCard(kind: .cloze, front: "Ein Höchstpreis unterhalb des Gleichgewichtspreises führt zu einer … .", back: "Knappheit", chapter: 3),
            DemoCard(kind: .basic, front: "Welches sind die fünf Bedingungen des vollkommenen Wettbewerbs?", back: "Atomistische Marktstruktur, Homogenität des Produkts, Markttransparenz, freier Marktzutritt und -austritt, freie Mobilität der Produktionsfaktoren.", chapter: 0),
            DemoCard(kind: .choice, front: "Welches dieser Ereignisse verschiebt die Nachfragekurve nach Elektroautos nach rechts?", back: "Ein Anstieg des Benzinpreises: Das Verbrennerauto, ein Substitutionsgut, wird im Gebrauch teurer. Ein Rückgang des Preises des Elektroautos selbst verschiebt die Kurve nicht: Man bewegt sich entlang der Kurve.", choices: ["Ein Rückgang des Preises von Elektroautos", "Ein Anstieg des Benzinpreises", "Ein Anstieg der Batteriekosten", "Ein Rückgang der Haushaltseinkommen"], answerIndex: 1, chapter: 2),
            DemoCard(kind: .basic, front: "Wer trägt eine auf einem Markt erhobene Steuer?", back: "Käufer und Verkäufer teilen sie sich, unabhängig davon, wer sie abführt. Die am wenigsten elastische Seite trägt den größten Teil.", chapter: 3),
            DemoCard(kind: .cloze, front: "Entlang einer linearen Nachfrage ist der Umsatz der Verkäufer an dem Punkt maximal, an dem die Preiselastizität … beträgt.", back: "−1", chapter: 2),
            DemoCard(kind: .choice, front: "Welche Wirkung hat ein Mindestpreis oberhalb des Gleichgewichts?", back: "Einen Angebotsüberschuss: Die Verkäufer bieten mehr an, als die Käufer zu diesem Preis kaufen wollen.", choices: ["Eine Knappheit", "Einen Angebotsüberschuss", "Keine Wirkung", "Einen Rückgang des gezahlten Preises"], answerIndex: 1, chapter: 3),
            DemoCard(kind: .cloze, front: "Der durch eine Steuer verursachte Verlust an Rente, der niemandem zugutekommt, heißt … .", back: "Wohlfahrtsverlust", chapter: 3),
        ]
    )

    // MARK: Physik: Stromkreise

    private static let circuitsDE = OnboardingDemoCourse(
        id: "debug-circuits",
        emoji: "🔌",
        subject: "Physique",
        title: "Elektrizität: Stromkreise",
        summary: "Stromstärke und Spannung, das ohmsche Gesetz, Reihen- und Parallelschaltung, dann Leistung, Energie und Sicherheitsregeln, mit Schritt für Schritt vorgerechneten Beispielen.",
        accentIndex: 2,
        chapters: [
            DemoChapter(title: "Stromstärke und Spannung", blocks: [
                .paragraph("Drückt man auf einen Schalter, leuchtet die Lampe sofort auf, und doch bewegen sich die Elektronen in den Drähten um weniger als einen Millimeter pro Sekunde. Dieses Paradox sagt das Wesentliche: Ein Stromkreis ist ==eine Schleife, die bereits voller Ladungen ist==, und die Spannungsquelle setzt sie alle gleichzeitig in Bewegung."),
                .heading("Der elektrische Strom"),
                .paragraph("Ein **elektrischer Strom** ist eine gerichtete Bewegung von Ladungsträgern. In Metallen sind das **freie Elektronen**, die sich von Atom zu Atom bewegen; in Lösungen sind es Ionen. Die **Stromstärke** $I$ misst die Ladungsmenge, die pro Sekunde durch einen Querschnitt des Leiters fließt. Sie wird in **Ampere** (A) angegeben."),
                .formula("I = \\frac{Q}{\\Delta t}", caption: "I in Ampere (A), Q in Coulomb (C), Δt in Sekunden (s)"),
                .paragraph("Ein Elektron trägt eine Ladung von $1{,}6 \\times 10^{-19}$ C. Eine Stromstärke von 1 A entspricht also $1 / (1{,}6 \\times 10^{-19}) \\approx 6{,}25 \\times 10^{18}$ Elektronen pro Sekunde: mehr als sechs Trillionen. Deshalb zählt man nie einzelne Elektronen, sondern Coulomb."),
                .callout(
                    title: "Technische Stromrichtung",
                    text: "Vereinbarungsgemäß fließt der Strom außerhalb der Spannungsquelle **vom Pluspol zum Minuspol**. Die negativ geladenen Elektronen bewegen sich **in die entgegengesetzte Richtung**. Die Vereinbarung stammt aus der Zeit vor der Entdeckung des Elektrons, und man hat sie beibehalten.",
                    tone: .warning
                ),
                .paragraph("Damit ein Strom fließt, braucht es einen **geschlossenen Stromkreis**: eine Spannungsquelle, Leitungen, mindestens einen Verbraucher und keine Unterbrechung. Einen Schalter zu öffnen heißt, den Kreis zu unterbrechen, und der Strom stoppt überall gleichzeitig — vor wie hinter dem Schalter."),
                .figure(.cycle(title: "Ein geschlossener Stromkreis", nodes: ["Pluspol der Quelle", "Verbindungsleitung", "Verbraucher (Lampe)", "Zurück zum Minuspol"])),
                .paragraph("In einem einfachen Stromkreis ohne Verzweigung ist die Stromstärke ==an jeder Stelle gleich==: Der Strom wird beim Durchfließen der Lampe nicht verbraucht. Was „verbraucht“ wird, ist die Energie, die die Ladungen transportieren, nicht die Ladungen selbst. Die Lampe frisst keine Elektronen, sie wandelt elektrische Energie in Licht und Wärme um."),
                .heading("Die Spannung"),
                .callout(
                    title: "Elektrische Spannung",
                    text: "Die **Spannung** $U$ zwischen zwei Punkten eines Stromkreises ist die Differenz ihrer elektrischen Potenziale. Sie wird in **Volt** (V) gemessen. Sie setzt die Ladungen in Bewegung: ohne Spannung kein Strom.",
                    tone: .definition
                ),
                .paragraph("Ein Bild hilft, die Vorstellung zu festigen: In einem Wasserkreislauf erzeugt die Pumpe einen Druckunterschied, und das Wasser fließt. Die Spannungsquelle ist die Pumpe, die Spannung der Druckunterschied, die Stromstärke die Durchflussmenge. Eine 1,5-V-Batterie, eine 12-V-Autobatterie und eine 230-V-Steckdose haben nicht denselben „Druck“."),
                .table(title: "Messen im Stromkreis", headers: ["Messgerät", "Misst", "Einheit", "Anschluss"], rows: [
                    ["Amperemeter", "Die Stromstärke", "Ampere (A)", "In Reihe, im Stromkreis"],
                    ["Voltmeter", "Die Spannung", "Volt (V)", "Parallel, an den Anschlüssen des Bauteils"],
                    ["Ohmmeter", "Den Widerstand", "Ohm (Ω)", "An den Anschlüssen des Bauteils, außerhalb des Stromkreises"],
                ]),
                .paragraph("Die Anschlussart folgt aus dem, was das Gerät misst. Ein Amperemeter zählt, was hindurchfließt: Der Strom muss durch es hindurchfließen, es gehört also **in** den Stromkreis. Ein Voltmeter vergleicht zwei Punkte: Es wird **zwischen** sie geschaltet. Ein Amperemeter parallel anzuschließen erzeugt einen Kurzschluss — und lässt oft seine Sicherung durchbrennen."),
                .list([
                    "Knotenregel: Die Summe der Stromstärken, die in einen Knoten hineinfließen, ist gleich der Summe derer, die herausfließen",
                    "Maschenregel: In einer Masche ist die Spannung der Quelle gleich der Summe der Spannungen an den Verbrauchern",
                    "In einem einfachen Stromkreis ist die Stromstärke überall gleich",
                ]),
            ]),
            DemoChapter(title: "Das ohmsche Gesetz", blocks: [
                .paragraph("Ein Kupferdraht lässt den Strom fast ungehindert durch; ein Wolframfaden bremst ihn stark. Der **Widerstand** $R$ eines Bauteils misst, ==wie stark es sich dem Stromfluss widersetzt==. Er wird in Ohm (Ω) angegeben, benannt nach dem deutschen Physiker Georg Ohm."),
                .heading("Ein proportionaler Zusammenhang"),
                .paragraph("Schließen wir einen **ohmschen Widerstand** — einen Widerstand im Sinne des Bauteils — an eine regelbare Spannungsquelle an und messen die Stromstärke bei mehreren Spannungen. Die Ergebnisse für einen Widerstand von 100 Ω liegen auf einer Ursprungsgeraden."),
                .table(title: "Messungen an einem Widerstand von 100 Ω", headers: ["Spannung U (V)", "Stromstärke I (mA)", "U / I (Ω)"], rows: [
                    ["2", "20", "100"],
                    ["4", "40", "100"],
                    ["6", "60", "100"],
                    ["8", "80", "100"],
                    ["10", "100", "100"],
                ]),
                .paragraph("Der Quotient $U / I$ ist konstant: Das ist der Widerstand. Achtung bei den Einheiten: 20 mA sind 0,020 A, und $2 / 0{,}020 = 100$ Ω. Diese Proportionalität zwischen Spannung und Stromstärke ist das **ohmsche Gesetz**, der meistgenutzte Zusammenhang der gesamten Elektrizitätslehre."),
                .formula("U = R \\times I", caption: "U in Volt (V), R in Ohm (Ω), I in Ampere (A)"),
                .paragraph("Die Formel lässt sich in alle drei Richtungen lesen: $U = RI$, $I = U / R$, $R = U / I$. Bei gegebener Spannung gilt: Je größer der Widerstand, desto kleiner die Stromstärke. Beispiel: Durch einen Widerstand von 470 Ω an 12 V fließt $I = 12 / 470 \\approx 0{,}026$ A, also etwa 26 mA."),
                .heading("Nicht alle Bauteile sind ohmsch"),
                .paragraph("Das ohmsche Gesetz gilt nur für ohmsche Leiter. Eine Glühlampe zum Beispiel folgt ihm nicht: Steigt die Spannung, erhitzt sich der Glühfaden, sein Widerstand nimmt zu, und die Stromstärke wächst immer langsamer. Ihre **Kennlinie** — die Stromstärke in Abhängigkeit von der Spannung — ist keine Gerade, sondern eine Kurve, die abflacht."),
                .figure(.plot(title: "Kennlinie einer Glühlampe", caption: "Auf der waagrechten Achse die Spannung, auf der senkrechten die Stromstärke: Je heißer der Glühfaden wird, desto größer sein Widerstand und desto mühsamer folgt die Stromstärke.", kind: .saturation)),
                .paragraph("Vergleichen Sie mit der Geraden eines Widerstands: Bei der Lampe ist der Quotient $U / I$ nicht konstant, er wächst mit der Spannung. Das ist das ==Kennzeichen eines nicht ohmschen Bauteils==. Dioden sind ein weiteres, noch ausgeprägteres Beispiel: Sie lassen den Strom in eine Richtung durch und in die andere fast gar nicht."),
                .keyFigure(value: "× 10", label: "mindestens: der Widerstand eines Wolframfadens bei 2 500 °C, verglichen mit seinem Kaltwiderstand"),
                .paragraph("Deshalb brennt eine Glühbirne meist beim Einschalten durch: Kalt ist ihr Widerstand gering, und für den Bruchteil einer Sekunde fließt ein starker Strom, bevor sich der Faden erhitzt. Ein Ohmmeter, das eine ausgeschaltete Lampe misst, liefert daher einen ganz anderen Wert als ihren Widerstand im Betrieb."),
                .callout(
                    title: "Methode",
                    text: "Um das ohmsche Gesetz anzuwenden: 1. prüfen, ob das Bauteil ohmsch ist; 2. in Basiseinheiten umrechnen — Volt, Ampere, Ohm (1 mA = 0,001 A, 1 kΩ = 1 000 Ω); 3. nach der gesuchten Größe auflösen; 4. das Ergebnis mit Einheit und einer sinnvollen Anzahl von Stellen angeben.",
                    tone: .insight
                ),
                .paragraph("Beim zweiten Schritt gehen die meisten Punkte verloren: $12 / 470$ ergibt 0,026, und das ist ein Ergebnis in Ampere. „0,026 mA“ zu schreiben heißt, sich um den Faktor tausend zu irren. Eine Überschlagsrechnung im Kopf — ==einige zehn Milliampere bei einigen hundert Ohm an 12 V== — genügt, um den Fehler zu erkennen."),
            ]),
            DemoChapter(title: "Reihen- und Parallelschaltung", blocks: [
                .paragraph("Sobald ein Stromkreis mehr als einen Verbraucher enthält, muss man wissen, wie sie verbunden sind. Es gibt nur zwei Grundformen: **in Reihe**, einer nach dem anderen im selben Kreis; **parallel**, auf nebeneinanderliegenden Zweigen zwischen denselben zwei Punkten. Jeder Stromkreis, auch ein komplexer, lässt sich in diese beiden Schaltungen zerlegen."),
                .figure(.split(
                    title: "Zwei Schaltungen",
                    left: DemoColumn(title: "Reihenschaltung", items: ["Ein einziger Stromkreis", "Überall gleiche Stromstärke", "Die Spannungen addieren sich", "Die Widerstände addieren sich", "Ein defektes Bauteil unterbricht alles"]),
                    right: DemoColumn(title: "Parallelschaltung", items: ["Mehrere Zweige", "Gleiche Spannung an allen Zweigen", "Die Stromstärken addieren sich", "Kleinerer Ersatzwiderstand", "Jeder Zweig ist unabhängig"])
                )),
                .paragraph("Jede Zeile der Gegenüberstellung folgt aus den beiden Regeln des ersten Kapitels. In Reihe gibt es keinen Knoten, also ist die Stromstärke überall gleich; die Maschenregel sagt, dass sich die Spannungen addieren. Parallel liegen die Zweige zwischen denselben zwei Punkten, also haben sie dieselbe Spannung; die Knotenregel sagt, dass sich die Stromstärken addieren."),
                .heading("Reihenschaltung"),
                .formula("R_{eq} = R_1 + R_2", caption: "Zwei Widerstände in Reihe entsprechen einem einzigen, der ihrer Summe gleich ist"),
                .callout(
                    title: "Beispiel: zwei Widerstände in Reihe",
                    text: "Eine 12-V-Quelle speist $R_1 = 100$ Ω und $R_2 = 200$ Ω in Reihe. $R_{eq} = 300$ Ω, also $I = 12 / 300 = 0{,}040$ A = 40 mA. Spannungen: $U_1 = 100 \\times 0{,}040 = 4$ V und $U_2 = 200 \\times 0{,}040 = 8$ V. Probe: $4 + 8 = 12$ V.",
                    tone: .example
                ),
                .paragraph("Die Spannung teilt sich ==im Verhältnis der Widerstände== auf: Der doppelt so große Widerstand erhält die doppelte Spannung. Diese Schaltung heißt **Spannungsteiler**, und sie ist in der Elektronik allgegenwärtig, um aus einer festen Versorgung eine kleinere Spannung zu gewinnen."),
                .heading("Parallelschaltung"),
                .formula("\\frac{1}{R_{eq}} = \\frac{1}{R_1} + \\frac{1}{R_2} \\;\\;\\Leftrightarrow\\;\\; R_{eq} = \\frac{R_1 R_2}{R_1 + R_2}", caption: "Bei der Parallelschaltung addieren sich die Kehrwerte der Widerstände"),
                .paragraph("Schalten wir nun dieselben Widerstände parallel an dieselbe Quelle. Jeder erhält die 12 V: $I_1 = 12 / 100 = 0{,}12$ A und $I_2 = 12 / 200 = 0{,}06$ A. Die Quelle liefert ihre Summe, $0{,}18$ A. Der Ersatzwiderstand beträgt $\\frac{100 \\times 200}{300} \\approx 66{,}7$ Ω, und man prüft, dass $12 / 66{,}7 \\approx 0{,}18$ A."),
                .table(title: "Dieselben Widerstände, zwei Schaltungen (12-V-Quelle)", headers: ["", "Reihe", "Parallel"], rows: [
                    ["Ersatzwiderstand", "300 Ω", "≈ 66,7 Ω"],
                    ["Gelieferte Stromstärke", "40 mA", "180 mA"],
                    ["Spannung an R₁", "4 V", "12 V"],
                    ["Spannung an R₂", "8 V", "12 V"],
                    ["Gesamtleistung", "0,48 W", "2,16 W"],
                ]),
                .paragraph("Das Ergebnis widerspricht der Intuition: Ein zusätzlicher Widerstand **in Parallelschaltung verringert** den Ersatzwiderstand, weil man dem Strom einen zusätzlichen Weg bietet. Der Ersatzwiderstand ist immer kleiner als der kleinste der parallel geschalteten Widerstände — hier 66,7 Ω, weniger als 100 Ω."),
                .callout(
                    title: "Warum Steckdosen parallel geschaltet sind",
                    text: "Im Haus sind alle Geräte parallel geschaltet: Jedes erhält die 230 V, und man kann eines ausschalten, ohne die anderen zu unterbrechen. Doch jedes zusätzliche Gerät erhöht die Gesamtstromstärke im Stromkreis: So lässt eine überlastete Mehrfachsteckdose **die Sicherung auslösen**.",
                    tone: .warning
                ),
                .paragraph("Merken Sie sich die goldene Regel: ==In Reihe ist die Stromstärke gemeinsam, parallel die Spannung==. Alles Übrige — die Addition der Spannungen oder der Stromstärken, die Berechnung der Ersatzwiderstände — folgt daraus, und das ist das Erste, was man bei einem Schaltplan erkennen muss."),
            ]),
            DemoChapter(title: "Leistung, Energie und Sicherheit", blocks: [
                .paragraph("Ein Elektrogerät wählt man zuerst nach seiner **Leistung**: 8 W für eine LED-Lampe, 2 000 W für einen Wasserkocher. Die elektrische Leistung, die ein Bauteil aufnimmt, ist das Produkt aus der Spannung an ihm und der Stromstärke, die es durchfließt. Sie misst ==den Energiestrom==, den es erhält."),
                .formula("P = U \\times I", caption: "P in Watt (W), U in Volt (V), I in Ampere (A)"),
                .paragraph("Kombiniert mit dem ohmschen Gesetz nimmt die Formel für einen ohmschen Leiter zwei weitere Formen an: $P = R I^2$ und $P = U^2 / R$. Die erste erklärt die **Joulesche Wärme**: Ein stromdurchflossener Leiter erwärmt sich, umso stärker, je größer die Stromstärke ist. In einem Heizkörper oder Toaster ist das nützlich, überall sonst ein Verlust."),
                .table(title: "Leistung und Stromstärke einiger Geräte an 230 V", headers: ["Gerät", "Leistung", "Stromstärke (I = P / U)"], rows: [
                    ["LED-Lampe", "8 W", "≈ 0,035 A"],
                    ["Handyladegerät", "20 W", "≈ 0,09 A"],
                    ["Fernseher", "100 W", "≈ 0,43 A"],
                    ["Wasserkocher", "2 000 W", "≈ 8,7 A"],
                    ["Backofen", "3 000 W", "≈ 13 A"],
                ]),
                .paragraph("Eine Standardsteckdose ist für 16 A ausgelegt, also für höchstens $230 \\times 16 \\approx 3\\,700$ W. Einen Wasserkocher und einen Backofen an dieselbe Mehrfachsteckdose anzuschließen bedeutet, mehr als 21 A zu verlangen: Die Leitungen erhitzen sich durch Joulesche Wärme, und so beginnen viele Wohnungsbrände."),
                .heading("Die umgesetzte Energie"),
                .formula("E = P \\times \\Delta t", caption: "E in Joule, wenn P in Watt und Δt in Sekunden; in kWh, wenn P in kW und Δt in Stunden"),
                .callout(
                    title: "Was kostet ein Tee?",
                    text: "Ein Wasserkocher mit 2 000 W erhitzt das Wasser in 3 Minuten: $E = 2 \\text{ kW} \\times 0{,}05 \\text{ h} = 0{,}1$ kWh. Bei etwa 0,20 € pro kWh kostet das **zwei Cent**. In Joule: $2000 \\times 180 = 360\\,000$ J.",
                    tone: .example
                ),
                .paragraph("Die Kilowattstunde ist die Einheit der Stromrechnung, weil das Joule für einen Haushalt viel zu klein ist: 1 kWh sind $3{,}6 \\times 10^6$ J. Teuer sind nicht die leistungsstarken Geräte, die ein paar Minuten laufen, sondern die, die lange in Betrieb sind: Ein Heizlüfter mit 1 500 W, zehn Stunden eingeschaltet, verbraucht 15 kWh, hundertfünfzigmal so viel wie der Tee."),
                .heading("Elektrizität und der menschliche Körper"),
                .paragraph("Die Gefahr des Stroms liegt in ==der Stromstärke, die durch den Körper fließt==, nicht unmittelbar in der Spannung. Doch die Spannung ruft sie hervor: Der menschliche Körper hat zwischen beiden Händen bei feuchter Haut einen Widerstand in der Größenordnung von 1 000 Ω. Bei 230 V liefert das ohmsche Gesetz $I = 230 / 1000 = 0{,}23$ A, also 230 mA — eine tödliche Stromstärke."),
                .bars(title: "Wirkungen eines Wechselstroms, der durch den Körper fließt", unit: "mA", bars: [
                    DemoBar(label: "Wahrnehmungsschwelle", value: 0.5),
                    DemoBar(label: "Verkrampfung: Loslassen unmöglich", value: 10),
                    DemoBar(label: "Atemlähmung", value: 30),
                    DemoBar(label: "Herzkammerflimmern", value: 75),
                ]),
                .paragraph("Diese Schwellen erklären die Zahl, die man in jedem Sicherungskasten findet: die **30-mA-Fehlerstromschutzschalter** (FI-Schalter). Sie vergleichen den Strom, der zu einem Gerät hinfließt, mit dem, der zurückkommt; übersteigt der Unterschied 30 mA, entweicht ein Teil des Stroms — vielleicht durch einen Menschen —, und sie schalten in wenigen Hundertstelsekunden ab."),
                .list([
                    "Sicherung oder Leitungsschutzschalter: unterbricht den Stromkreis bei Überstrom (Kurzschluss, Überlast), schützt die Anlage",
                    "30-mA-Fehlerstromschutzschalter: schaltet bei Fehlerstrom ab, schützt Menschen",
                    "Schutzleiter (Erdung): leitet den Strom eines defekten Geräts mit Metallgehäuse in den Boden ab",
                    "Nie ein Elektrogerät in der Nähe von Wasser: Nasse Haut teilt den Körperwiderstand",
                ]),
                .paragraph("Diese Schutzvorrichtungen sind das Ergebnis von zwei Jahrhunderten, in denen man die Elektrizität beherrschen lernte. Zuerst musste man sie dauerhaft erzeugen, dann ihre Gesetze verstehen, dann sie in großem Maßstab verteilen — und bei jedem Schritt lernen, sich vor ihr zu schützen."),
                .timeline(title: "Zwei Jahrhunderte Elektrizität", events: [
                    DemoEvent(date: "1800", label: "Alessandro Volta erfindet die Batterie: der erste Gleichstrom"),
                    DemoEvent(date: "1820", label: "Ørsted entdeckt, dass ein Strom eine Kompassnadel ablenkt"),
                    DemoEvent(date: "1827", label: "Georg Ohm veröffentlicht das nach ihm benannte Gesetz"),
                    DemoEvent(date: "1831", label: "Faraday entdeckt die Induktion: Man kann Strom erzeugen"),
                    DemoEvent(date: "1879", label: "Langlebige Glühlampe von Swan und Edison"),
                    DemoEvent(date: "1882", label: "Erstes öffentliches Kraftwerk, in New York"),
                ]),
                .paragraph("Die Einheit der Stromstärke trägt den Namen von Ampère, die der Spannung den von Volta, die des Widerstands den von Ohm: Drei der Buchstaben, die Sie in jeder Aufgabe schreiben, sind ==eine Hommage an die Pioniere== dieser Geschichte. Und jede ihrer Entdeckungen lässt sich heute in einer Formel aus wenigen Zeichen zusammenfassen."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Wie verhalten sich Stromstärke und Spannung in einer Reihenschaltung und in einer Parallelschaltung?",
                back: "In Reihe ist die Stromstärke überall gleich, und die Spannungen addieren sich. Parallel liegt an jedem Zweig dieselbe Spannung, und die Stromstärken addieren sich.",
                figure: .split(
                    title: "Zwei Schaltungen",
                    left: DemoColumn(title: "Reihe", items: ["I gemeinsam", "U addieren sich"]),
                    right: DemoColumn(title: "Parallel", items: ["U gemeinsam", "I addieren sich"])
                ),
                chapter: 2
            ),
            DemoCard(
                kind: .choice,
                front: "An einem Widerstand von 470 Ω liegt eine Spannung von 12 V. Welche Stromstärke fließt hindurch?",
                back: "$I = U / R = 12 / 470 \\approx 0{,}026$ A, also etwa 26 mA.",
                choices: ["≈ 26 mA", "≈ 39 A", "≈ 5,6 A", "≈ 0,26 mA"],
                answerIndex: 0,
                chapter: 1
            ),
            DemoCard(
                kind: .cloze,
                front: "Ein Voltmeter wird … zu dem Bauteil geschaltet, dessen Spannung man messen will.",
                back: "parallel",
                chapter: 0
            ),
            DemoCard(kind: .basic, front: "Formulieren Sie das ohmsche Gesetz.", back: "Bei einem ohmschen Leiter ist die Spannung an ihm proportional zur Stromstärke, die ihn durchfließt: $U = R \\times I$, mit U in Volt, R in Ohm, I in Ampere.", chapter: 1),
            DemoCard(kind: .choice, front: "Zwei Widerstände von 100 Ω und 200 Ω sind in Reihe an eine 12-V-Quelle angeschlossen. Wie groß ist die Spannung am 200-Ω-Widerstand?", back: "$I = 12 / 300 = 0{,}04$ A, also $U_2 = 200 \\times 0{,}04 = 8$ V.", hint: "Berechnen Sie zuerst die gemeinsame Stromstärke.", choices: ["4 V", "6 V", "8 V", "12 V"], answerIndex: 2, chapter: 2),
            DemoCard(kind: .cloze, front: "Vereinbarungsgemäß fließt der Strom außerhalb der Spannungsquelle vom Pol … zum Pol −.", back: "+", chapter: 0),
            DemoCard(kind: .basic, front: "Warum verringert ein parallel hinzugefügter Widerstand den Ersatzwiderstand?", back: "Weil man dem Strom einen zusätzlichen Weg bietet: Die Stromstärken der Zweige addieren sich, die Quelle liefert bei gleicher Spannung mehr Strom, also sinkt $R_{eq} = U / I$.", chapter: 2),
            DemoCard(kind: .choice, front: "Wie viel Energie verbraucht ein Wasserkocher mit 2 000 W, der 3 Minuten läuft?", back: "$E = P \\times \\Delta t = 2 \\text{ kW} \\times 0{,}05 \\text{ h} = 0{,}1$ kWh, also 360 000 J.", choices: ["6 kWh", "0,1 kWh", "6 000 J", "0,6 kWh"], answerIndex: 1, chapter: 3),
            DemoCard(kind: .cloze, front: "Die elektrische Leistung, die ein Bauteil aufnimmt, beträgt $P = U \\times$ … .", back: "$I$", chapter: 3),
            DemoCard(kind: .basic, front: "Wen schützt ein 30-mA-Fehlerstromschutzschalter, und wie?", back: "Menschen: Er vergleicht den Strom, der zu einem Gerät hinfließt, mit dem, der zurückkommt, und schaltet ab, wenn der Unterschied 30 mA übersteigt — ein Zeichen für einen Fehlerstrom, vielleicht durch einen Körper.", chapter: 3),
            DemoCard(kind: .choice, front: "Ab welcher Stromstärke etwa kann ein Strom durch den Körper eine Atemlähmung auslösen?", back: "Etwa 30 mA, daher der Nennwert der Fehlerstromschutzschalter im Haushalt.", choices: ["0,5 mA", "30 mA", "1 A", "10 A"], answerIndex: 1, chapter: 3),
            DemoCard(kind: .cloze, front: "Ein Elektron trägt eine Ladung von $1{,}6 \\times 10^{-19}$ … .", back: "Coulomb", chapter: 0),
        ]
    )

    // MARK: Biologie: die Zelle und die Mitose

    private static let mitosisDE = OnboardingDemoCourse(
        id: "debug-mitosis",
        emoji: "🔬",
        subject: "SVT",
        title: "Die Zelle und die Mitose",
        summary: "Die Zelle und ihre Organellen, der Zellzyklus, die Phasen der Mitose, die Meiose, die die Keimzellen bildet, und Krebs, wenn die Teilung jeder Kontrolle entgleitet.",
        accentIndex: 3,
        chapters: [
            DemoChapter(title: "Die Zelle, Grundeinheit des Lebens", blocks: [
                .paragraph("Jedes Lebewesen besteht aus Zellen: aus einer einzigen bei einem Bakterium, aus rund ==30 000 Milliarden== bei einem Menschen. Und jede Zelle entsteht aus einer anderen Zelle, durch Teilung. Diese beiden Sätze bilden die **Zelltheorie**, einen der Grundpfeiler der Biologie."),
                .heading("Eine Entdeckung über zwei Jahrhunderte"),
                .paragraph("Man musste erst das Mikroskop erfinden, um Zellen zu sehen, und dann zwei Jahrhunderte lang beobachten, um zu verstehen, dass sie allen Lebewesen gemeinsam sind. Der Zeitstrahl fasst diesen langen Weg zusammen, der endet, als man endlich eine Zelle bei der Teilung beobachtet."),
                .timeline(title: "Die Zelltheorie", events: [
                    DemoEvent(date: "1665", label: "Robert Hooke beobachtet „Zellen“ im Kork"),
                    DemoEvent(date: "1674", label: "Van Leeuwenhoek entdeckt mikroskopisch kleine Lebewesen"),
                    DemoEvent(date: "1838–1839", label: "Schleiden und Schwann: Pflanzen und Tiere bestehen aus Zellen"),
                    DemoEvent(date: "1855", label: "Virchow: Jede Zelle stammt von einer Zelle ab"),
                    DemoEvent(date: "1882", label: "Flemming beschreibt und benennt die Mitose"),
                ]),
                .paragraph("Virchows Satz, *omnis cellula e cellula*, hat eine schwindelerregende Folge: Jede Ihrer Zellen stammt über eine ununterbrochene Kette von Teilungen von der allerersten lebenden Zelle ab. Die Zellteilung ist kein Detail im Funktionieren des Lebendigen, sie ist ==das, was es fortbestehen lässt==."),
                .callout(
                    title: "Zelle",
                    text: "Die kleinste strukturelle und funktionelle Einheit des Lebendigen: ein von einer **Zellmembran** begrenzter Raum mit **Cytoplasma** und Erbinformation in Form von **DNA**, der sich ernähren, Energie gewinnen und sich vermehren kann.",
                    tone: .definition
                ),
                .paragraph("Es gibt zwei große Zelltypen. **Prokaryoten** — die Bakterien — haben keinen Zellkern: Ihre DNA liegt frei im Cytoplasma. **Eukaryoten** — Tiere, Pflanzen, Pilze, Protisten — haben einen Zellkern, der die DNA umschließt, und spezialisierte Kompartimente, die **Organellen**."),
                .heading("Die Organellen"),
                .table(title: "Die wichtigsten Organellen einer eukaryotischen Zelle", headers: ["Organell", "Aufgabe"], rows: [
                    ["Zellkern", "Enthält die DNA, Ort der Replikation und der Transkription"],
                    ["Mitochondrium", "Zellatmung: stellt ATP her"],
                    ["Ribosom", "Translation: stellt die Proteine her"],
                    ["Endoplasmatisches Retikulum", "Synthese und Transport von Proteinen und Lipiden"],
                    ["Golgi-Apparat", "Verändert, sortiert und versendet die Proteine"],
                    ["Chloroplast", "Fotosynthese, nur bei Pflanzen"],
                ]),
                .paragraph("Die Pflanzenzelle besitzt zusätzlich eine starre **Zellwand** aus Cellulose um ihre Membran, eine große, mit Wasser gefüllte **Vakuole**, die sie prall hält, und Chloroplasten. Die Tierzelle hat weder Zellwand noch Chloroplasten, dafür aber **Zentrosomen**, die bei der Teilung eine zentrale Rolle spielen werden."),
                .keyFigure(value: "10 bis 100 µm", label: "die typische Größe einer eukaryotischen Zelle, etwa zehnmal so groß wie ein Bakterium: mit bloßem Auge unsichtbar"),
                .paragraph("Diese Größe ist kein Zufall. Eine Zelle tauscht alles — Nahrung, Sauerstoff, Abfallstoffe — über ihre Membran aus, und wenn ihr Volumen zunimmt, wächst ihre Oberfläche langsamer. Ab einer bestimmten Größe ==reicht die Membran nicht mehr aus==, um das Innere zu versorgen: Die Zelle muss sich teilen oder sterben."),
            ]),
            DemoChapter(title: "Der Zellzyklus", blocks: [
                .paragraph("Eine Zelle, die sich teilt, durchläuft eine Abfolge von Phasen, die sich in jeder Generation wiederholen: den **Zellzyklus**. Er umfasst eine lange **Interphase**, in der die Zelle wächst und ihre DNA kopiert, und eine kurze **Mitose**, in der sie sich in zwei Zellen teilt."),
                .figure(.cycle(title: "Der Zellzyklus", nodes: ["G1: Wachstum", "S: DNA-Replikation", "G2: Vorbereitung", "M: Mitose und Cytokinese"])),
                .paragraph("In der **G1**-Phase (vom englischen *gap*, Lücke) wächst die Zelle und arbeitet normal. In der **S**-Phase (Synthese) repliziert sie ihre gesamte DNA. In der **G2**-Phase prüft sie die Kopie und bereitet die Teilung vor. Die **M**-Phase ist die Mitose selbst, gefolgt von der **Cytokinese**, die das Cytoplasma aufteilt."),
                .bars(title: "Dauer der Phasen bei einer menschlichen Zelle in Kultur", unit: "h", bars: [
                    DemoBar(label: "G1", value: 11),
                    DemoBar(label: "S", value: 8),
                    DemoBar(label: "G2", value: 4),
                    DemoBar(label: "M", value: 1),
                ]),
                .paragraph("Von einem Zyklus von etwa 24 Stunden nimmt die Mitose nur eine Stunde ein. Deshalb befindet sich auf einem Mikroskoppräparat die überwältigende Mehrheit der Zellen in der Interphase: Der Anteil der in jeder Phase beobachteten Zellen ==spiegelt die Dauer dieser Phase wider==. Viele Zellen, etwa Nervenzellen, verlassen den Zyklus sogar für eine Ruhephase, G0 genannt, und teilen sich nicht mehr."),
                .heading("Chromosomen und Chromatiden"),
                .callout(
                    title: "Chromosom und Chromatide",
                    text: "Ein **Chromosom** ist ein DNA-Molekül mit daran gebundenen Proteinen. Nach der S-Phase besteht jedes Chromosom aus **zwei Schwesterchromatiden**, zwei identischen Kopien, die durch ein **Zentromer** verbunden sind. Es bleibt **ein einziges** Chromosom, aber mit zwei Chromatiden.",
                    tone: .definition
                ),
                .paragraph("Die DNA-Menge einer Zelle folgt also dem Zyklus. Nennen wir $Q$ die DNA-Menge einer Zelle in G1. Während der S-Phase verdoppelt sie sich allmählich auf $2Q$. Am Ende der Mitose startet jede Tochterzelle mit $Q$. Die Kurve der DNA-Menge in Abhängigkeit von der Zeit hat die Form einer Treppe, die in S ansteigt und bei der Teilung auf einen Schlag abfällt."),
                .formula("Q \\;\\to\\; 2Q \\;\\to\\; Q", caption: "Die DNA-Menge pro Zelle: in der S-Phase verdoppelt, bei der Mitose geteilt"),
                .paragraph("Die Zahl der Chromosomen dagegen ändert sich in der S-Phase nicht: Eine menschliche Zelle hat in G1 46 Chromosomen und in G2 immer noch 46 — aber jeweils mit zwei Chromatiden. Man schreibt ==2n = 46==: $n$ ist die Zahl der Chromosomen eines Satzes, 23 beim Menschen, und die Körperzellen haben zwei Sätze, einen mütterlichen und einen väterlichen."),
                .callout(
                    title: "Der klassische Fehler",
                    text: "Zu glauben, die Replikation verdopple die Zahl der Chromosomen. Sie verdoppelt **die DNA-Menge**, nicht die Zahl der Chromosomen: Aus 46 Ein-Chromatid-Chromosomen werden 46 Zwei-Chromatid-Chromosomen. Die Zahl verdoppelt sich nur für einen Augenblick, in der Anaphase, wenn sich die Chromatiden trennen.",
                    tone: .warning
                ),
                .list([
                    "G1: Wachstum, Ein-Chromatid-Chromosomen, DNA-Menge Q",
                    "S: Replikation, die DNA-Menge steigt von Q auf 2Q",
                    "G2: Zwei-Chromatid-Chromosomen, Prüfung der Kopie",
                    "M: Mitose, jede Tochterzelle erhält Q",
                ]),
                .paragraph("Der Übergang von einer Phase zur nächsten geschieht nicht automatisch: Er wird durch **Kontrollpunkte** gesteuert, an denen die Zelle prüft, ob alles in Ordnung ist, bevor sie weitermacht — ob die DNA vor der S-Phase intakt ist, ob sie vor der Mitose vollständig kopiert ist. Ihre Entdeckung brachte Hartwell, Hunt und Nurse 2001 den Nobelpreis ein, und ihr Versagen öffnet dem Krebs die Tür."),
            ]),
            DemoChapter(title: "Die Phasen der Mitose", blocks: [
                .paragraph("Die Mitose ist die Teilung einer Zelle in ==zwei Tochterzellen, die mit der Mutterzelle genetisch identisch sind==. Ihre Aufgabe ist einfach zu formulieren und schwierig umzusetzen: genau eine Kopie jedes der 46 Chromosomen auf jede der beiden Zellen zu verteilen, ohne eines zu verlieren oder zu verdoppeln."),
                .figure(.flow(title: "Die Schritte der Mitose", steps: ["Prophase: Die Chromosomen kondensieren", "Metaphase: Sie ordnen sich in der Äquatorialebene an", "Anaphase: Die Schwesterchromatiden trennen sich", "Telophase: Zwei Zellkerne bilden sich neu", "Cytokinese: zwei Tochterzellen"])),
                .paragraph("Jede Phase hat ihre unter dem Mikroskop sichtbaren Merkmale, und genau diese sollen Sie auf einem Foto erkennen. Die Tabelle fasst sie zusammen; die Metaphase ist am leichtesten zu erkennen, mit ihren Chromosomen, die wie eine Reihe Soldaten in der Mitte der Zelle aufgereiht sind."),
                .table(title: "Was man in jeder Phase sieht", headers: ["Phase", "Was geschieht"], rows: [
                    ["Prophase", "Die Chromosomen kondensieren und werden sichtbar; die Kernhülle löst sich auf; der Spindelapparat bildet sich"],
                    ["Metaphase", "Die Zwei-Chromatid-Chromosomen ordnen sich in der Äquatorialebene an, mit ihrem Zentromer am Spindelapparat befestigt"],
                    ["Anaphase", "Die Schwesterchromatiden trennen sich und wandern zu den entgegengesetzten Polen: Jeder Pol erhält 46 Ein-Chromatid-Chromosomen"],
                    ["Telophase", "Die Chromosomen dekondensieren; um jeden Satz bildet sich eine neue Kernhülle"],
                ]),
                .paragraph("Der **Spindelapparat** ist die Maschine, die all das möglich macht: ein Netz aus Proteinfasern, den Mikrotubuli, die zwischen den beiden Polen der Zelle gespannt sind. Sie heften sich an die Zentromere, ordnen die Chromosomen an und verkürzen sich dann, um die Chromatiden zu den Polen zu ziehen. Ein Kontrollpunkt blockiert die Anaphase, solange auch nur ein Chromosom nicht korrekt angeheftet ist."),
                .callout(
                    title: "Die Bilanz der Mitose",
                    text: "Aus einer Mutterzelle mit 2n = 46 Chromosomen entstehen **zwei Tochterzellen mit 2n = 46 Chromosomen**, die genau dieselbe Erbinformation tragen. Die Mitose ist eine **erbgleiche Teilung**: Sie ermöglicht Wachstum, Gewebeerneuerung und Wundheilung.",
                    tone: .insight
                ),
                .paragraph("Die Cytokinese unterscheidet sich je nach Zelltyp. Die Tierzelle schnürt sich in der Mitte ein, wie ein Ballon, den man zusammendrückt, dank eines Rings aus kontraktilen Proteinen. Die Pflanzenzelle, gefangen in ihrer starren Zellwand, kann sich nicht einschnüren: Sie baut in der Mitte eine neue Zellwand auf, von innen nach außen."),
                .figure(.split(
                    title: "Zwei Arten, sich zu teilen",
                    left: DemoColumn(title: "Tierzelle", items: ["Zentrosomen an den Polen", "Kontraktiler Ring", "Einschnürung des Cytoplasmas"]),
                    right: DemoColumn(title: "Pflanzenzelle", items: ["Kein Zentrosom", "Starre Zellwand", "Neue Zellwand in der Mitte aufgebaut"])
                )),
                .paragraph("Jede Teilung verdoppelt die Zahl der Zellen. Ausgehend von einer Zelle hat man nach einer Teilung 2, nach zwei 4, nach drei 8: Das Wachstum ist **exponentiell**. Nach $k$ Teilungen zählt eine Population von $N_0$ Zellen $N_0 \\times 2^k$ Zellen."),
                .formula("N = N_0 \\times 2^k", caption: "Die Zahl der Zellen nach k aufeinanderfolgenden Teilungen, wenn sich alle teilen"),
                .paragraph("Zehn Teilungen ergeben bereits $2^{10} = 1\\,024$ Zellen; fünfundvierzig Teilungen etwa 35 000 Milliarden — die Größenordnung eines menschlichen Körpers. In Wirklichkeit teilen sich nicht alle Zellen eines Organismus, und viele sterben: Das Wachstum eines gesunden Gewebes ist ein ==Gleichgewicht zwischen Zellteilung und Zelltod==, das der Organismus ständig regelt."),
            ]),
            DemoChapter(title: "Meiose, Mitose und Krebs", blocks: [
                .paragraph("Die Mitose erzeugt exakte Kopien. Für die geschlechtliche Fortpflanzung braucht es aber etwas anderes: Zellen mit nur einem Chromosomensatz, damit Eizelle und Spermium bei der Befruchtung wieder eine Zelle mit zwei Sätzen bilden. Das ist die Aufgabe der **Meiose**, die nur in den Keimdrüsen (Gonaden) stattfindet."),
                .table(title: "Mitose und Meiose im Vergleich", headers: ["", "Mitose", "Meiose"], rows: [
                    ["Wo", "Fast alle Körperzellen", "Die Keimzellen der Gonaden"],
                    ["Teilungen", "Eine", "Zwei aufeinanderfolgende"],
                    ["Entstehende Zellen", "2", "4"],
                    ["Chromosomen", "2n = 46, wie die Mutterzelle", "n = 23, halb so viele"],
                    ["Erbinformation", "Identisch mit der Mutterzelle", "Von Zelle zu Zelle verschieden"],
                    ["Aufgabe", "Wachstum, Erneuerung", "Bildung der Keimzellen"],
                ]),
                .paragraph("Die erste Reifeteilung der Meiose trennt die **homologen** Chromosomen — das mütterliche und das väterliche Chromosom jedes Paares —; sie halbiert die Zahl der Chromosomen. Die zweite trennt die Schwesterchromatiden, wie eine Mitose. Dabei ==mischt die Meiose die Erbinformation== auf zwei Arten neu."),
                .formula("2^{23} \\approx 8{,}4 \\times 10^{6}", caption: "Die Zahl der möglichen Chromosomenkombinationen in einer menschlichen Keimzelle, allein durch interchromosomale Rekombination"),
                .paragraph("Die **interchromosomale Rekombination** beruht darauf, dass sich jedes Paar unabhängig von den anderen trennt: Für jedes der 23 Paare erhält die Keimzelle das mütterliche oder das väterliche Homologe, daher $2^{23}$, mehr als acht Millionen Kombinationen. Die **intrachromosomale Rekombination**, durch den Austausch von Stücken zwischen Homologen, das sogenannte *Crossing-over*, vervielfacht diese Zahl noch. Zwei Geschwister, eineiige Zwillinge ausgenommen, erhalten nie dieselbe Kombination."),
                .heading("Wenn die Teilung außer Kontrolle gerät"),
                .paragraph("In einem gesunden Organismus teilt sich jede Zelle nur, wenn sie das Signal dazu erhält, und hört auf, wenn man es von ihr verlangt. Zwei Genfamilien steuern diese Kontrolle. Die **Protoonkogene** wirken wie ein Gaspedal: Sie treiben die Zelle zur Teilung an. Die **Tumorsuppressorgene** wirken wie eine Bremse: Sie halten den Zyklus bei Problemen an."),
                .callout(
                    title: "Krebs",
                    text: "Eine Krankheit, die auf der **unkontrollierten Vermehrung** von Zellen beruht, die Mutationen angehäuft haben: ein klemmendes Gaspedal (ein Protoonkogen, das zum **Onkogen** geworden ist) und defekte Bremsen (inaktivierte Tumorsuppressorgene). Die Zellen bilden einen Tumor, können dann benachbarte Gewebe befallen und sich im Körper ausbreiten: Das sind die **Metastasen**.",
                    tone: .definition
                ),
                .paragraph("Die berühmteste Bremse ist das Protein **p53**, genannt „Wächter des Genoms“: Ist die DNA geschädigt, hält es den Zyklus für die Dauer der Reparatur an oder löst den Selbstmord der Zelle aus, wenn die Schäden zu schwer sind. Das Gen, das für es codiert, ist in etwa der Hälfte aller menschlichen Krebsarten mutiert. In der Regel braucht es ==mehrere aufeinanderfolgende Mutationen==, über Jahre angehäuft, bis eine Zelle zur Krebszelle wird — was erklärt, dass das Risiko mit dem Alter steigt."),
                .keyFigure(value: "≈ 30", label: "Verdopplungen, bis aus einer einzigen Zelle ein Tumor von einem Zentimeter wird, also etwa eine Milliarde Zellen (2³⁰ ≈ 1,07 × 10⁹)"),
                .paragraph("Ein Tumor ist also erst nach einer langen, stillen Vorgeschichte nachweisbar: dreißig Verdopplungen, um einen Zentimeter zu erreichen, während zehn weitere genügen würden, um ihn zu vertausendfachen. Darum geht es bei der **Früherkennung**: den Tumor so früh wie möglich auf dieser Exponentialkurve zu entdecken, solange er noch klein und begrenzt ist."),
                .callout(
                    title: "Warum man bei einer Chemotherapie die Haare verliert",
                    text: "Die meisten Chemotherapien zielen auf **sich teilende** Zellen, indem sie die DNA-Replikation oder den Spindelapparat blockieren. Sie treffen daher auch gesunde Zellen, die sich schnell teilen: Haarwurzeln, Darmschleimhaut, Knochenmark. Die Nebenwirkungen sind die direkte Folge des Angriffsziels.",
                    tone: .warning
                ),
                .list([
                    "Tabak: die häufigste vermeidbare Krebsursache in Frankreich",
                    "Alkohol, Übergewicht, Bewegungsmangel: bedeutende Risikofaktoren",
                    "UV-Strahlung: Sonnenbrände, vor allem in der Kindheit, begünstigen Melanome",
                    "Bestimmte Viren: das Papillomavirus, gegen das es eine Impfung gibt",
                ]),
                .paragraph("Alle diese Faktoren wirken auf dieselbe Weise: Sie erhöhen die Zahl der Mutationen in sich teilenden Zellen. Die Mitose zu verstehen heißt also zugleich zu verstehen, ==wie der Körper sich aufbaut und repariert==, und wie dieselbe Maschine manchmal außer Kontrolle gerät."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Welches sind die Phasen des Zellzyklus?",
                back: "Die Interphase, bestehend aus G1 (Wachstum), S (DNA-Replikation) und G2 (Vorbereitung), dann die M-Phase: die Mitose, gefolgt von der Cytokinese.",
                figure: .cycle(title: "Der Zellzyklus", nodes: ["G1", "S", "G2", "M"]),
                chapter: 1
            ),
            DemoCard(
                kind: .choice,
                front: "In welcher Phase der Mitose trennen sich die Schwesterchromatiden?",
                back: "In der Anaphase: Die Schwesterchromatiden wandern zu den entgegengesetzten Polen, und jeder Pol erhält von jeder Sorte ein Ein-Chromatid-Chromosom.",
                choices: ["Prophase", "Metaphase", "Anaphase", "Telophase"],
                answerIndex: 2,
                chapter: 2
            ),
            DemoCard(
                kind: .cloze,
                front: "Die DNA einer Zelle wird in der …-Phase der Interphase repliziert.",
                back: "S",
                chapter: 1
            ),
            DemoCard(kind: .basic, front: "Was ist der Unterschied zwischen einem Prokaryoten und einem Eukaryoten?", back: "Ein Prokaryot (ein Bakterium) hat keinen Zellkern: Seine DNA liegt im Cytoplasma. Ein Eukaryot hat einen Zellkern, der seine DNA umschließt, sowie Organellen.", chapter: 0),
            DemoCard(kind: .choice, front: "Welches Organell stellt den Großteil des ATP der Zelle her?", back: "Das Mitochondrium, der Ort der Zellatmung.", choices: ["Der Zellkern", "Das Mitochondrium", "Das Ribosom", "Der Golgi-Apparat"], answerIndex: 1, chapter: 0),
            DemoCard(kind: .cloze, front: "Nach der S-Phase besteht jedes Chromosom aus zwei …, die durch ein Zentromer verbunden sind.", back: "Schwesterchromatiden", chapter: 1),
            DemoCard(kind: .basic, front: "Wie verändern sich die Zahl der Chromosomen und die DNA-Menge im Laufe des Zellzyklus?", back: "Die DNA-Menge verdoppelt sich in der S-Phase (von Q auf 2Q) und kehrt bei der Teilung zu Q zurück. Die Zahl der Chromosomen bleibt 46: Sie gehen von einer zu zwei Chromatiden über.", hint: "Unterscheiden Sie zwischen DNA-Menge und Chromosomenzahl.", chapter: 1),
            DemoCard(kind: .choice, front: "Wie viele Zellen mit wie vielen Chromosomen erzeugt die Meiose aus einer menschlichen Zelle?", back: "Vier Zellen mit n = 23 Chromosomen, die sich genetisch voneinander unterscheiden.", choices: ["2 Zellen mit 46 Chromosomen", "2 Zellen mit 23 Chromosomen", "4 Zellen mit 23 Chromosomen", "4 Zellen mit 46 Chromosomen"], answerIndex: 2, chapter: 3),
            DemoCard(kind: .cloze, front: "In der … ordnen sich die Chromosomen in der Äquatorialebene an.", back: "Metaphase", chapter: 2),
            DemoCard(kind: .basic, front: "Was ist Krebs auf der Ebene der Zelle?", back: "Die unkontrollierte Vermehrung von Zellen, die Mutationen angehäuft haben: Protoonkogene, die zu Onkogenen geworden sind (klemmendes Gaspedal), und inaktivierte Tumorsuppressorgene (defekte Bremsen).", chapter: 3),
            DemoCard(kind: .choice, front: "Wie viele Chromosomenkombinationen kann eine menschliche Keimzelle allein durch interchromosomale Rekombination erhalten?", back: "$2^{23}$, also etwa 8,4 Millionen: Jedes der 23 Paare trennt sich unabhängig von den anderen.", choices: ["23", "46", "$2^{23}$, etwa 8,4 Millionen", "$23^2$, also 529"], answerIndex: 2, chapter: 3),
            DemoCard(kind: .cloze, front: "Die Mitose erzeugt zwei Tochterzellen, die mit der Mutterzelle genetisch … sind.", back: "identisch", chapter: 2),
        ]
    )
}
#endif
