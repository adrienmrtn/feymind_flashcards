import Foundation

// MARK: - The four courses, in Turkish

/// The demo courses, in Turkish. High-school (lise) level: what a teacher would write on the
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
    static let turkish: [OnboardingDemoCourse] = [
        coldWarTR, photosynthesisTR, derivativesTR, energyTR,
    ]

    // MARK: History: the Cold War

    private static let coldWarTR = OnboardingDemoCourse(
        id: "history-cold-war",
        emoji: "🏛️",
        subject: "Histoire",
        title: "Soğuk Savaş (1947–1991)",
        summary: "İki blok, iki model ve hiçbir zaman doğrudan bir savaş yok: Duvar yıkılana dek kırk dört yıl süren gerginlik, krizler ve yumuşama.",
        accentIndex: 3,
        chapters: [
            DemoChapter(title: "Karşı karşıya iki blok (1947–1953)", blocks: [
                .paragraph("1945'te savaşın galiplerinin artık hiçbir ortak noktası kalmamıştır. Nazi Almanyası'na karşı müttefik olan Amerika Birleşik Devletleri ile SSCB, ikiye bölünen bir dünyanın ==iki süper gücü== hâline gelir. Sonrasında olan her şey — kırk dört yıllık gerginlik — bu kopuştan itibaren anlam kazanır."),
                .heading("İkiye bölünmüş bir dünya"),
                .paragraph("Yalta (Şubat 1945) ve Potsdam (Temmuz 1945) konferanslarının amacı barışı düzenlemekti. Oysa bu konferanslar paylaşımı düzenler: Kızıl Ordu'nun kurtardığı Doğu Avrupa Sovyet denetiminde kalır; Anglo-Amerikalıların kurtardığı Batı Avrupa ise Washington'ın yörüngesine girer. Daha Mart 1946'da Churchill, kıtanın üzerine inen bir **demir perde**den söz eder."),
                .callout(
                    title: "Soğuk Savaş",
                    text: "1947'den 1991'e kadar Amerika Birleşik Devletleri ile SSCB arasında **doğrudan savaşa varmadan** süren; ekonomik baskı, propaganda, silahlanma yarışı ve vekâlet savaşlarıyla yürütülen çatışma.",
                    tone: .definition
                ),
                .paragraph("“Soğuk” sözcüğü özü anlatır: iki dev birbiriyle hiçbir zaman savaşmaz. Başka her yerde, başka her yolla çatışırlar. Onları ayıran yalnızca bir güç rekabeti değil, birbiriyle bağdaşmayan ==bir toplumu örgütlemenin iki ayrı yolu==dur."),
                .figure(.split(
                    title: "İki model",
                    left: DemoColumn(title: "Batı Bloku", items: ["Amerika Birleşik Devletleri", "Liberal demokrasi", "Piyasa ekonomisi", "Marshall Planı (1947)", "NATO (1949)"]),
                    right: DemoColumn(title: "Doğu Bloku", items: ["SSCB", "Tek parti", "Planlı ekonomi", "Kominform (1947)", "Varşova Paktı (1955)"])
                )),
                .paragraph("Batı'da serbest seçimler, birden fazla parti, bağımsız bir basın ve şirketlerin özel, fiyatların serbest olduğu bir ekonomi vardır. Doğu'da ise devleti, basını ve ekonomiyi denetleyen tek bir parti, Komünist Parti vardır: Moskova'da kararlaştırılan plan neyin, hangi fiyata üretileceğini belirler. Her kamp kendini özgür dünya olarak sunar, ötekini ise bir tehdit olarak tanımlar."),
                .heading("Çevreleme"),
                .paragraph("Mart 1947'de Başkan Truman, komünizmin tehdit ettiği her ülkeye yardım sözü verir: Bu, ==bleu|Truman Doktrini== ya da *çevreleme* politikasıdır — komünizmi hüküm sürdüğü yerde devirmeye çalışmadan, bulunduğu yerde tutmak. Üç ay sonra Marshall Planı, Batı Avrupa'nın yeniden inşasını 13 milyar dolarla finanse eder ve onu Amerikan kampına bağlar. SSCB buna uydularının planı kabul etmesini yasaklayarak karşılık verir ve komünist partileri eşgüdümlemek için Kominform'u kurar."),
                .timeline(title: "İlk yıllar", events: [
                    DemoEvent(date: "1947", label: "Truman Doktrini ve Marshall Planı"),
                    DemoEvent(date: "1948", label: "Berlin Ablukası"),
                    DemoEvent(date: "1949", label: "NATO'nun kuruluşu, ilk Sovyet atom bombası"),
                    DemoEvent(date: "1950", label: "Kore Savaşı başlıyor"),
                ]),
                .paragraph("Berlin ilk güç sınavıdır. Sovyet bölgesinin derinliklerinde kalan kent de dört sektöre bölünmüştür. Batılı güçler Haziran 1948'de kendi bölgeleri için ortak bir para birimi oluşturunca Stalin, Batı Berlin'e giden tüm karayollarını ve demiryollarını keser: İki milyon kişi kendini kuşatma altında bulur."),
                .callout(
                    title: "Unutma",
                    text: "Berlin Ablukası (Haziran 1948 – Mayıs 1949) ilk krizdir: SSCB Batı Berlin'e giden yolları keser, Müttefikler on bir ay süren bir ==hava köprüsü==yle karşılık verir — her iki dakikada bir uçak. Tek bir kurşun atılmaz, ama her şey söylenmiş olur.",
                    tone: .insight
                ),
                .paragraph("Abluka başarısız olur ve kırk yıl boyunca geçerli olacak oyunun kurallarını belirler: Her kamp ötekini sınar, ama hiçbiri savaşa götürecek çizgiyi aşmaz. 1949'da SSCB, Hiroşima'dan dört yıl sonra ilk atom bombasını patlatır. Artık iki kamp da nihai silaha sahiptir ve **dehşet dengesi** kurulur."),
                .list([
                    "Demir Perde: Avrupa'yı Baltık'tan Adriyatik'e ikiye bölen sınır",
                    "Çevreleme: Amerikan stratejisi, saldırmadan tutmak",
                    "Uydu devlet: Moskova'ya bağlı bir komünist partinin yönettiği Doğu Avrupa ülkesi",
                ]),
                .paragraph("Haziran 1950'deki Kore Savaşı, bir çatışmanın bu çerçevede neye dönüştüğünü gösterir: Komünist Kuzey Güney'i işgal eder, Amerikalılar BM bayrağı altında müdahale eder, Çin “gönüllülerini” gönderir. Üç yıllık çatışma, iki milyon ölü ve tam olarak eski yerine dönen bir sınır. Her kamp aynı kurala uyar: Asla bir karış toprak vermemek, asla öteki süper güce ateş etmemek."),
            ]),
            DemoChapter(title: "Krizler ve dehşet dengesi (1953–1975)", blocks: [
                .paragraph("Stalin'in ölümünden (1953) sonra Kruşçev “barış içinde bir arada yaşama”yı önerir: İki sistem yan yana yaşayabilir, hangisinin daha iyi olduğunu ekonomi gösterecektir. Ama bir arada yaşama ne krizleri ne de silahlanma yarışını önler. Her kamp müttefiklerini silahlandırır ve Kore'den Vietnam'a **vekâleten** savaşır."),
                .paragraph("Bir arada yaşamanın sınırları vardır ve Budapeşte bunu daha 1956'da gösterir: Macaristan Varşova Paktı'ndan çıkmaya çalışınca Sovyet tankları ayaklanmayı birkaç günde ezer. Batı protesto eder, ama kıpırdamaz. Her taraf kendi alanında efendi olarak kalır: Soğuk Savaş'ın yazılı olmayan kuralı budur."),
                .table(title: "Büyük krizler", headers: ["Kriz", "Tarih", "Ne söz konusu"], rows: [
                    ["Kore Savaşı", "1950–1953", "38. paralel, ikiye bölünmüş bir Kore"],
                    ["Berlin Duvarı", "1961", "Doğu, Batı'ya kaçışı durdurmak için halkını duvarla çevirir"],
                    ["Küba Füze Krizi", "1962", "Florida'ya 150 km uzaklıkta Sovyet füzeleri"],
                    ["Vietnam Savaşı", "1955–1975", "ABD bataklığa saplanır, sonra çekilir"],
                ]),
                .heading("Yine Berlin"),
                .paragraph("1949 ile 1961 arasında yaklaşık üç milyon Doğu Alman Batı'ya geçer; çoğu, metroya binmenin yettiği Berlin üzerinden. Doğu Almanya doktorlarını, mühendislerini, gençlerini kaybetmektedir. 12'yi 13 Ağustos 1961'e bağlayan gece sınırı kapatır: önce dikenli tel, sonra beton bir duvar, gözetleme kuleleri, bir ölüm şeridi. ==Duvar==, bütün Soğuk Savaş'ın ve her kampın ötekinin gözündeki değerinin simgesi olur."),
                .keyFigure(value: "13 gün", label: "Ekim 1962'deki Küba Füze Krizi'nin, füzeler geri çekilmeden önceki süresi"),
                .paragraph("Ekim 1962'de Amerikan casus uçakları, Florida'ya yüz elli kilometre uzaklıktaki Küba'da Sovyet füze rampalarını fotoğraflar. Kennedy adaya deniz ablukası uygular ve füzelerin sökülmesini ister; on üç gün boyunca dünya nefesini tutar. Kruşçev sonunda Küba'yı işgal etmeme sözü karşılığında füzeleri geri çeker — ve Amerikan füzeleri de sessizce Türkiye'den kaldırılır. ==Caydırıcılık işe yaradı==: Bütün Soğuk Savaş'ın en sıcak anı."),
                .figure(.flow(title: "Caydırıcılığın mantığı", steps: ["İki kampın da bombası var", "Vuran vurulur", "Kimse vurmaz", "Savaş başka yerde yapılır"])),
                .paragraph("Bu mantığın bir adı vardır: **karşılıklı garantili imha**. Hiçbir kamp kendisi de yok edilmeden ötekini yok edemez; bu yüzden hiçbiri ilk vuran olmaz. Bomba, paradoks biçimde, iki dev arasında barışın güvencesi olur — ve savaşın tam da bu yüzden başka yere, müttefiklere, konvansiyonel kalabileceği yerlere kaymasının nedeni budur."),
                .callout(
                    title: "Vekâlet savaşı",
                    text: "Vietnam bunun örneğidir: ABD Güney'i, SSCB ile Çin ise Kuzey'i destekler. Gerçek bir savaş, milyonlarca ölü, ama hiçbir zaman bir Sovyet askerinin karşısında bir Amerikan askeri yok.",
                    tone: .example
                ),
                .paragraph("ABD 1965'ten itibaren Vietnam'a girer: 1968'de beş yüz binden fazla asker, yoğun bombardımanlar ve görüntüler televizyona ulaşınca tersine dönen bir kamuoyu. 1973'te çekilirler; Saygon 1975'te düşer. Bu, Amerika'nın kaybettiği ilk savaştır ve onu ==SSCB ile hiç karşı karşıya gelmeden== kaybeder."),
                .heading("Her alanda yarış"),
                .paragraph("Çatışma gökyüzünde, laboratuvarlarda ve stadyumlarda da sürer. Her uydu, her madalya, her rekor bir sistemin ötekinden üstün olduğunun kanıtı olarak sunulur. Uzay yarışı bunun vitrinidir: SSCB öne geçer, Amerika kendine on yıl vererek arayı kapatır."),
                .list([
                    "1957: İlk uydu Sputnik uzay yarışını başlatır",
                    "1961: Gagarin, uzaya çıkan ilk insan",
                    "1963: Kırmızı telefon Washington ile Moskova'yı birbirine bağlar, Küba'nın dersi",
                    "1969: Apollo 11, Amerika Ay'da yürür",
                ]),
                .paragraph("Küba'dan sonra kurulan kırmızı telefon dönemi özetler: Birbirine güvenmeyen, ama bir yanlış anlamanın her şeyi havaya uçurabileceğini bilen iki hasım. Savaşmamak için konuşurlar. 1970'lerin yumuşaması işte bu temkinden doğar."),
            ]),
            DemoChapter(title: "Yumuşamadan Duvar'ın yıkılışına (1975–1991)", blocks: [
                .paragraph("1970'ler kıskacı gevşetir. İki kamp da kazanamayacaklarını ve silahlanma yarışının bir servete mal olduğunu anlamıştır: Müzakere ederler. Ama SSCB 1979'da Afganistan'ı işgal edip Reagan silahlanma yarışını yeniden başlatınca ==rose|yeni Soğuk Savaş== geri döner."),
                .heading("Yumuşama"),
                .paragraph("SALT anlaşmaları (1972) nükleer füze sayısını ilk kez sınırlar. Helsinki Konferansı (1975), savaştan kalan sınırları tanır — Moskova'nın istediği buydu — ve karşılığında insan hakları konusunda bir taahhüt alınır; Doğu'daki muhalifler bu taahhüdü on beş yıl boyunca dile getirecektir. Nixon Pekin'e ve Moskova'ya gider; ticaret yeniden başlar; iki Almanya birbirini tanır."),
                .paragraph("Bu soluklanma kısa sürer. Aralık 1979'da Kızıl Ordu, sallantıdaki bir komünist rejimi ayakta tutmak için Afganistan'a girer: On yıllık savaş, bir milyon ölü ve kendi Vietnam'ına saplanan bir SSCB. ABD Moskova Olimpiyatları'nı boykot eder, Afgan direnişini silahlandırır ve 1980'de seçilen Ronald Reagan SSCB'yi bir “şeytan imparatorluğu” olarak nitelendirir. Onun uzay kalkanı projesi SDI, Moskova'nın artık yetişemeyeceği bir teknoloji yarışı başlatır."),
                .paragraph("1985'te Mihail Gorbaçov tükenmiş bir SSCB'de iktidara gelir: Dükkân rafları boştur, sanayi eskimiştir, ordu zenginliğin muazzam bir bölümünü yutmaktadır. **Perestroyka**yı (ekonominin yeniden yapılandırılması) ve **glasnost**u (kamusal yaşamda açıklık) başlatır, Reagan ile silahsızlanmayı müzakere eder ve Doğu Avrupa'daki komünist rejimleri ayakta tutmayı bırakır: Artık her biri kendi kaderinden sorumlu olacaktır."),
                .timeline(title: "Son", events: [
                    DemoEvent(date: "1985", label: "Gorbaçov iktidara gelir"),
                    DemoEvent(date: "1987", label: "Washington Antlaşması: Avrupa füzelerinin sonu"),
                    DemoEvent(date: "9 Kasım 1989", label: "Berlin Duvarı'nın yıkılışı"),
                    DemoEvent(date: "1990", label: "Almanya'nın yeniden birleşmesi"),
                    DemoEvent(date: "25 Aralık 1991", label: "SSCB'nin dağılması"),
                ]),
                .paragraph("1989 yılı her şeyi silip süpürür. Polonya'da Dayanışma (Solidarność) sendikası haziranda serbest seçimleri kazanır. Macaristan'da hükûmet eylülde Avusturya sınırını açar: Doğu Almanlar binlercesi birden oradan geçer. Doğu Almanya'da Leipzig'deki Pazartesi gösterileri yüz binlerce kişiyi bir araya getirir ve Moskova'nın desteğinden yoksun rejim artık ateş açamaz."),
                .heading("SSCB neden kaybetti"),
                .paragraph("Soğuk Savaş silahlarla olduğu kadar ekonomiyle de yürütüldü. SSCB, yarı büyüklükteki bir ekonomiyle, ordusuna ABD'nin hiçbir zaman ulaşması gerekmeyen bir zenginlik payı ayırdı. Fazladan her füze bir hastane ya da bir fabrika eksik demekti ve halk bunu biliyordu."),
                .bars(title: "Askerî harcamaların GSYH içindeki payı, 1985 civarı (tahmini)", unit: "%", bars: [
                    DemoBar(label: "ABD", value: 6),
                    DemoBar(label: "SSCB", value: 15),
                    DemoBar(label: "Fransa", value: 4),
                ]),
                .paragraph("Grafik bir bakışta okunur: Benzer bir askerî çaba için SSCB, ABD'nin bu işe ayırdığının iki katından fazlasını feda eder. Gorbaçov'un durdurmaya çalıştığı işte bu tükenmişliktir — ve kıskacı gevşeterek sistemi dağıtacak güçleri serbest bırakan da odur."),
                .callout(
                    title: "Duvar neden yıkılıyor",
                    text: "Moskova'nın desteğinden yoksun kalan Doğu rejimleri 1989'da birbiri ardına çöker. 9 Kasım'da bir Doğu Alman sözcü, yanlışlıkla sınırların “derhâl” açık olduğunu duyurur: Bir gecede on binlerce Berlinli karşıya geçer ve bölünmenin simgesi ortadan kalkar.",
                    tone: .insight
                ),
                .paragraph("Almanya Ekim 1990'da NATO'nun koruması altında yeniden birleşir — Moskova'nın beş yıl önce reddedeceği bir şey. SSCB'nin içinde cumhuriyetler bağımsızlıklarını talep eder; Ağustos 1991'deki başarısız bir darbe partinin itibarını tamamen yok eder. 25 Aralık 1991'de Sovyet bayrağı Kremlin'den indirilir. Soğuk Savaş, iki kamptan birinin tükenmesiyle ==tek bir muharebe olmadan== sona erer."),
            ]),
            DemoChapter(title: "Soğuk Savaş'ı anlamlandırmak", blocks: [
                .paragraph("Kırk dört yıl, onlarca kriz, yüzlerce tarih: Soğuk Savaş tarih tarih ezberlenmez, mekanizmalarıyla anlaşılır. Bu bölüm, sınavda onun hakkında yazmak için ==kavramları, mantığı ve yöntemi== bir araya getiriyor."),
                .heading("Kavramlar"),
                .paragraph("Aşağıdaki her sözcük belirli bir mekanizmayı adlandırır ve birini ötekinin yerine kullanmak bir sözcük hatası değil, bir kavrama hatasıdır. “Yumuşama” “barış” değildir, “çevreleme” “saldırı” değildir, “uydu devlet” “müttefik” değildir."),
                .table(title: "Bilinmesi gereken kavramlar", headers: ["Kavram", "Anlamı"], rows: [
                    ["Demir Perde", "Avrupa'yı ikiye bölen kapalı sınır"],
                    ["Çevreleme", "Komünizmi, hüküm sürdüğü yerde ona saldırmadan tutmak"],
                    ["Caydırıcılık", "Karşılık olarak vurulacağın için vurmamak"],
                    ["Vekâlet savaşı", "İki devin değil, müttefiklerin yürüttüğü savaş"],
                    ["Yumuşama", "1970'lerde gerginliklerin azalması"],
                    ["Uydu devlet", "Moskova'ya bağlı bir partinin yönettiği Doğu ülkesi"],
                ]),
                .paragraph("Bu sözcükler 1947'den 1991'e kadar tekrarlanan tek bir döngüyü anlatır. Gerginlik artar, bir kriz patlak verir, iki kamp da savaş istemediği için müzakere eder, gerginlik azalır — sonra başka bir yerde yeni bir kriz başlar. Berlin, Küba, Vietnam, Afganistan: Hep aynı döngü."),
                .figure(.cycle(title: "Krizler döngüsü", nodes: ["Gerginlik artar", "Bir kriz patlak verir", "Müzakere edilir", "Gerginlik azalır"])),
                .paragraph("Bu döngüyü anlamak, ezberlemeden herhangi bir krizi açıklayabilmek demektir: Kim kimi, ne kadar ileri giderek sınıyor ve neden savaşın eşiğinde duruyor? Yanıt neredeyse her zaman aynıdır — **nükleer caydırıcılık** — ve Soğuk Savaş'ı kendisinden önceki bütün rekabetlerden ayıran da budur."),
                .heading("Sınavda"),
                .callout(
                    title: "Yöntem",
                    text: "Bir kompozisyon için: 1. Üç bölümlü bir plan — blokların oluşumu, krizler ve bir arada yaşama, yumuşama ve son. 2. Her fikir için bir tarih ve somut bir örnek. 3. Soruyu yanıtlayan bir sonuç: Neden “soğuk” ve neden savaşsız bitiyor.",
                    tone: .insight
                ),
                .paragraph("Bir belge çözümlemesinde sorulacak ilk soru bakış açısıdır: Kim, hangi kamptan, döngünün hangi anında konuşuyor? 1950 tarihli bir Sovyet afişi ile Kennedy'nin 1963 tarihli bir konuşması aynı şeyi söylemez ve senden açıklaman beklenen tam da bu farktır."),
                .callout(
                    title: "Klasik hata",
                    text: "ABD ile SSCB'nin birbiriyle savaştığını yazmak. **Hiçbir zaman** doğrudan çatışmadılar: Soğuk Savaş'ın tanımı tam olarak budur ve bunu açıklayan da caydırıcılıktır.",
                    tone: .warning
                ),
                .list([
                    "1947: Truman Doktrini, Marshall Planı — bloklar oluşur",
                    "1949: NATO, Sovyet bombası — dehşet dengesi başlar",
                    "1961: Duvar — bölünme somutlaşır",
                    "1962: Küba — caydırıcılık işe yarar",
                    "1975: Helsinki — yumuşama",
                    "1989: Duvar yıkılır — son",
                    "1991: SSCB ortadan kalkar",
                ]),
                .paragraph("Her birinin neyi başlattığını ya da neyi kapattığını bildiğin sürece, bütün dönemi kavramak için yedi tarih yeter. Onları yalnızca olaylarıyla değil, mekanizmalarıyla birlikte öğren: Bir kronolojiyi ezbere okumakla ==bir dönemi açıklamak== arasındaki farkı yaratan bu bağdır."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Soğuk Savaş'ın iki bloku hangileridir ve onlara kim önderlik eder?",
                back: "ABD'nin önderlik ettiği Batı Bloku (liberal demokrasi, piyasa ekonomisi) ve SSCB'nin önderlik ettiği Doğu Bloku (tek parti, planlı ekonomi).",
                figure: .split(
                    title: "İki model",
                    left: DemoColumn(title: "Batı", items: ["ABD", "NATO"]),
                    right: DemoColumn(title: "Doğu", items: ["SSCB", "Varşova Paktı"])
                ),
                chapter: 0
            ),
            DemoCard(
                kind: .choice,
                front: "1962'de dünyayı nükleer savaşın eşiğine getiren kriz hangisidir?",
                back: "Küba Füze Krizi: Küba'ya yerleştirilen Sovyet füzeleri, on üç günlük bir restleşme, ardından adayı işgal etmeme sözü karşılığında geri çekilme.",
                choices: ["Berlin Ablukası", "Küba Füze Krizi", "Kore Savaşı", "Afganistan'ın işgali"],
                answerIndex: 1,
                chapter: 1
            ),
            DemoCard(
                kind: .cloze,
                front: "Berlin Duvarı, SSCB'nin dağılmasından iki yıl önce, 9 Kasım … tarihinde yıkılır.",
                back: "1989",
                chapter: 2
            ),
            DemoCard(kind: .basic, front: "Truman Doktrini nedir?", back: "ABD'nin Mart 1947'de komünizmin tehdit ettiği her ülkeye yardım etme taahhüdü: çevreleme politikası.", chapter: 0),
            DemoCard(kind: .cloze, front: "… Planı (1947), Batı Avrupa'nın yeniden inşasını finanse eder.", back: "Marshall", chapter: 0),
            DemoCard(kind: .choice, front: "Perestroyka ve glasnostu kim başlattı?", back: "1985'ten itibaren iktidarda olan Mihail Gorbaçov, SSCB'yi içeriden reforma uğratmaya çalıştı.", choices: ["Stalin", "Kruşçev", "Gorbaçov", "Brejnev"], answerIndex: 2, chapter: 2),
            DemoCard(kind: .basic, front: "ABD ile SSCB neden hiçbir zaman doğrudan savaşmadı?", back: "Nükleer caydırıcılık yüzünden: Her kamp ötekini yok edebildiği için ilk vuran olmak, karşılık olarak vurulmak demekti. Bu yüzden savaş vekâleten, müttefikler aracılığıyla yürütülür.", chapter: 3),
            DemoCard(kind: .cloze, front: "1970'lerde iki blok arasındaki gerginliğin azalmasına … denir.", back: "yumuşama", chapter: 3),
        ]
    )

    // MARK: Biology: photosynthesis

    private static let photosynthesisTR = OnboardingDemoCourse(
        id: "biology-photosynthesis",
        emoji: "🌿",
        subject: "SVT",
        title: "Fotosentez",
        summary: "Bir yaprağın ışıktan, sudan ve karbondioksitten nasıl şeker ürettiği ve neredeyse bütün yaşamın neden buna bağlı olduğu.",
        accentIndex: 4,
        chapters: [
            DemoChapter(title: "Işığı yakalamak", blocks: [
                .paragraph("Yaprak bir fabrikadır: Işığı, suyu ve karbondioksiti alır ve onları ==şekere ve oksijene== dönüştürür. Bu süreç fotosentezdir ve Dünya'daki neredeyse bütün yaşamı besler — bitkileri ya da bitkileri yiyen hayvanları yiyen bizler de dahil."),
                .heading("Yakından bir yaprak"),
                .paragraph("Yaprak bu iş için tasarlanmıştır. Işığa olabildiğince geniş bir yüzey sunmak için yassı ve incedir. Alt yüzeyi, gündüz açılarak havadaki CO₂'nin içeri girmesini ve oksijenin dışarı çıkmasını sağlayan binlerce **stoma**, yani minik gözenekle delinmiştir. İki yüz arasında kloroplastlarla dolu hücreler; kökten suyu getiren ve şekeri taşıyan damarlar bulunur."),
                .callout(
                    title: "Fotosentez",
                    text: "Yeşil bitkilerin, ışık enerjisini kullanarak inorganik maddeden (CO₂ ve su) organik madde (glikoz) sentezlemesi.",
                    tone: .definition
                ),
                .paragraph("Tanım tek bir denkleme sığar. Altı karbondioksit molekülü ile altı su molekülü, bir glikoz molekülü ve altı oksijen molekülü verir. Hiçbir şey yoktan var olmaz: Şekerin karbon atomları havadaki CO₂'den, açığa çıkan oksijen ise sudan gelir. Bu birleşmeyi mümkün kılan ==ışığın enerjisi==dir."),
                .formula("6\\,CO_2 + 6\\,H_2O \\rightarrow C_6H_{12}O_6 + 6\\,O_2", caption: "Işıkla yürüyen genel denklem"),
                .paragraph("Her şey, yaprağın parankima dokusundaki her hücrede onlarcası bulunan yeşil organeller olan **kloroplastlarda** gerçekleşir. Renklerini kırmızı ve mavi ışığı soğurup yeşili yansıtan pigment ==menthe|klorofil==den alırlar. Hücrede ışığın yakalandığı tek yer burasıdır: Kloroplast yoksa fotosentez de yoktur."),
                .heading("Fotondan şekere"),
                .paragraph("İçeride olanlar, saniyenin çok küçük bir kesrinde art arda gelen dört adımda özetlenebilir. Işık klorofile çarpar; alınan enerji su moleküllerini parçalamak için kullanılır ve bu, oksijen açığa çıkarır; bu enerji hücrenin kullanabildiği bir biçimde, ATP olarak depolanır; ve son olarak ATP, CO₂'yi glikoza bağlamak için kullanılır."),
                .figure(.flow(title: "Fotondan şekere", steps: ["Klorofil ışığı soğurur", "Su parçalanır: O₂ açığa çıkar", "Enerji depolanır (ATP)", "CO₂ glikoza bağlanır"])),
                .paragraph("Işığın bütün renkleri yaprak için eşit değildir. Güneş'in beyaz ışığı bir karışımdır; klorofil çoğunlukla tayfın iki ucunu — maviyi ve kırmızıyı — yakalar ve ortasını geçirir. Bu, bir klorofil çözeltisini her seferinde tek bir renkle aydınlatıp neyin geçtiğine bakarak ölçülür."),
                .bars(title: "Klorofilin renklere göre soğurduğu ışık", unit: "%", bars: [
                    DemoBar(label: "Mavi", value: 90),
                    DemoBar(label: "Yeşil", value: 15),
                    DemoBar(label: "Kırmızı", value: 80),
                ]),
                .paragraph("Grafik bir bakışta okunur: On mavi fotondan dokuzu, on kırmızı fotondan sekizi yakalanır; yeşilde ise altı fotondan ancak biri. Yeşil tamamen kaybolmaz — karotenoitler denen birkaç yardımcı pigment bir kısmını alır — ama çoğu geldiği yere geri döner."),
                .callout(
                    title: "Yapraklar neden yeşil",
                    text: "Çünkü yeşil, klorofilin **soğurmadığı** renktir: Onu gözümüze geri yansıtır. Yaprak, kırmızı bir kumaşın kırmızı olmasıyla aynı nedenle yeşildir — reddettiği renktir.",
                    tone: .insight
                ),
                .paragraph("Basit bir deney bunu gösterir: Yeşil ışık altında yetiştirilen bir bitki kötü büyür, kırmızı ya da mavi ışık altındaki bir bitki ise iyi büyür. Modern seraların ürünlerini pembe, yani kırmızı ile mavinin karışımı bir ışıkla aydınlatmasının nedeni budur — bitkinin kullanmayacağı yeşile tek bir foton bile harcanmaz."),
                .paragraph("Yaprağın gerçekten şeker ürettiğini de doğrulayabilirsin. Işıkta bırakılmış, rengi giderilmiş ve ardından iyot çözeltisine batırılmış bir yaprak mavi-siyah olur: Bitkinin glikozunu depoladığı biçim olan nişastayı içerir. Karanlıkta tutulan bir yaprak ise sarı kalır: ==Işık yoksa şeker de yok==."),
            ]),
            DemoChapter(title: "Glikoz üretmek", blocks: [
                .paragraph("Fotosentez, kloroplastın içinde iki farklı yerde, iki aşamada gerçekleşir. **Işık evresi** ışığa ihtiyaç duyar: Suyu parçalar, oksijen açığa çıkarır ve enerji depolar. **Karanlık evre** ise ışığa doğrudan ihtiyaç duymaz: Bu enerjiyi CO₂'yi bağlamak ve glikoz oluşturmak için kullanır. Birincisi yakıtı üretir, ikincisi onu harcar."),
                .heading("Işık evresi"),
                .paragraph("Kloroplastın içinde üst üste dizilmiş, klorofilin tutunduğu zar keseler olan **tilakoitlerde** gerçekleşir. Bir foton bir klorofil molekülüne çarptığında bir elektron koparır ve bu elektronun yerini, bir su molekülü parçalanarak doldurur: Bu, **suyun fotolizi**dir. Suyun oksijeni O₂ olarak açığa çıkar — soluduğumuz oksijen budur — ve elektronun enerjisi, bütün canlı hücrelerin enerji birimi olan ATP'yi üretmek için kullanılır."),
                .table(title: "İki evre", headers: ["", "Işık evresi", "Karanlık evre"], rows: [
                    ["Nerede", "Tilakoit zarları", "Kloroplast stroması"],
                    ["Işık", "Zorunlu", "Doğrudan değil"],
                    ["Girenler", "Su, ışık", "CO₂, ATP"],
                    ["Çıkanlar", "O₂, ATP", "Glikoz"],
                ]),
                .paragraph("Tablo sütunlar hâlinde okunur: Işık evresinden çıkan — ATP — tam olarak karanlık evrenin ihtiyaç duyduğu şeydir. Dolayısıyla iki evre birbirine bağlıdır: Birincisi ikincisini beslemeyi bıraktığı anda ikincisi de durur; bu da gün batımından birkaç dakika sonra olur."),
                .heading("Calvin döngüsü"),
                .paragraph("Karanlık evre, tilakoitleri çevreleyen sıvı olan **stromada** gerçekleşir. Adını, onu 1950'de radyoaktif karbonu izleyerek tanımlayan kimyacı Melvin Calvin'den alır. Bu bir döngüdür, yani yol boyunca şeker üreterek başlangıç noktasına geri dönen bir tepkimeler dizisidir."),
                .figure(.cycle(title: "Calvin döngüsü", nodes: ["CO₂ bağlanması", "ATP ile indirgenme", "Şeker oluşumu", "Alıcının yenilenmesi"])),
                .paragraph("Her turda bir CO₂ molekülü, gezegendeki en bol protein olan RuBisCO adlı bir enzim tarafından alıcı denen bir taşıyıcı moleküle bağlanır. Elde edilen bileşik ışık evresinden gelen ATP ile indirgenir; ürünün bir kısmı ==glikoz== yapmak üzere döngüden çıkar, geri kalanı ise bir sonraki tur için alıcıyı yeniler. Bir glikoz molekülü için **altı tur** gerekir: her karbon atomu için bir tur."),
                .keyFigure(value: "6 tur", label: "tek bir glikoz molekülü oluşturmak için gereken Calvin döngüsü sayısı"),
                .paragraph("Üretilen glikoz uzun süre glikoz olarak kalmaz. Bitki onu, yaprakta ya da bir yumruda depolamak için **nişasta**ya — patatesteki nişasta budur —, öz su aracılığıyla köklere ve meyvelere taşımak için **sakkaroz**a ya da çeperlerini oluşturmak için **selüloz**a dönüştürür. Bir ağacın odunu, on yıllar boyunca üst üste yığılmış şekerdir."),
                .callout(
                    title: "Klasik tuzak",
                    text: "Karanlık evre “gece” gerçekleşmez: Işık evresi enerji sağladığı anda gündüz de işler. “Karanlık”, ışığı doğrudan kullanmadığı anlamına gelir — karanlığı beklediği anlamına değil.",
                    tone: .warning
                ),
                .list([
                    "Işık evresi: tilakoitler, ışık, suyun parçalanması, O₂ açığa çıkması, ATP üretimi",
                    "Karanlık evre: stroma, Calvin döngüsü, CO₂ bağlanması, glikoz üretimi",
                    "Bir glikoz molekülü için döngünün altı turu, her karbon atomu için bir tur",
                ]),
                .paragraph("Adlardan çok akışı hatırla: Işık kimyasal enerjiye, kimyasal enerji şekere, şeker de bitkideki diğer her şeye dönüşür. Her adımın kendi yeri ve kendi yakıtı vardır ve ==hiçbiri bir öncekisiz işlemez==."),
            ]),
            DemoChapter(title: "Fotosentez ve gezegen", blocks: [
                .paragraph("Bitkiler her yıl yaklaşık ==120 milyar ton karbon== bağlar. Fotosentez, organik maddenin besin zincirlerine giriş kapısı ve soluduğumuz bütün oksijenin kaynağıdır. Gezegen ölçeğinde karbon döngüsünü yürüten süreçtir."),
                .heading("Karbon döngüsü"),
                .paragraph("Karbon hava, canlılar ve toprak arasında dolaşır ve fotosentez bu döngünün iki motorundan biridir. CO₂'yi atmosferden alır ve bitkilerin maddesine hapseder. Solunum ve ayrışma ters yönde işler: Bu maddeyi yakar ve CO₂'yi havaya geri verir. İkisi dengede kaldığı sürece atmosferdeki CO₂ miktarı sabit kalır."),
                .figure(.cycle(title: "Karbon döngüsü", nodes: ["Atmosferdeki CO₂", "Fotosentez: bitkilerde bağlanır", "Solunum, ayrışma", "Atmosfere geri dönüş"])),
                .paragraph("Bitkiler **birincil üreticilerdir**: Diğer her şeyin geçindiği organik maddeyi onlar üretir. Bir otçul bitkiyi yer, bir etçil otçulu yer ve her basamakta karbon bir canlıdan ötekine geçer. Fotosentez olmasaydı zincirin ilk halkası olmazdı."),
                .heading("Onu ne denetler"),
                .paragraph("Fotosentezin hızını üç etken denetler: ışık, CO₂ derişimi ve sıcaklık. Biri eksik olduğunda ötekileri artırmak hiçbir şeyi değiştirmez: Bu, bir montaj hattındaki en yavaş istasyon gibi, geri kalan her şeyin hızını belirleyen **sınırlayıcı faktör**dür."),
                .figure(.plot(title: "Işık, bir tavana kadar", caption: "Daha fazla ışık fotosentezi bir platoya kadar hızlandırır: Onun ötesinde sınırı CO₂ ya da sıcaklık belirler.", kind: .saturation)),
                .paragraph("Eğri iki bölümde okunur. Başta yükselir: Fazladan her foton kullanılır, sınırlayıcı faktör ışıktır. Sonra düzleşir: Bitki kullanabileceğinden fazla ışık alır ve hızı frenleyen artık mevcut CO₂ — ya da sıcaklığa bağlı olan enzimlerin hızı — olur. Platoda ışık eklemek artık hiçbir şeyi değiştirmez."),
                .list([
                    "Işık: Ne kadar çok olursa fotosentez doygunluğa kadar o kadar hızlı işler",
                    "CO₂: Havanın %0,04'ü kadar; tam gün ışığında çoğu zaman sınırlayıcı faktördür",
                    "Sıcaklık: 25–30 °C civarında bir optimum; bunun ötesinde enzimler durur",
                ]),
                .callout(
                    title: "Serada",
                    text: "Üreticiler bazen havayı CO₂ ile doğal derişiminin üç katına kadar zenginleştirir: Güçlü ışık altında büyümeyi frenleyen odur ve onu eklemek domateslerin daha hızlı büyümesini sağlar.",
                    tone: .example
                ),
                .paragraph("Aynı akıl yürütme, bitkilerin kışın hava güzel olsa bile neden az büyüdüğünü açıklar: Işık vardır, ama sıcaklık enzimleri frenler. Pencereden uzak bir saksı bitkisinin neden solup gittiğini de açıklar: Sıcaklık uygundur, ama ışık yetersizdir. ==Sınırlayıcı faktörü belirlemek==, neyi değiştirmen gerektiğini bilmek demektir."),
                .heading("Gezegenin akciğerleri"),
                .paragraph("Ormanlara çoğu zaman Dünya'nın akciğerleri denir. Bu yarı yarıya doğrudur: Ormanlar gerçekten karbon bağlar, ama dünyadaki fotosentezin neredeyse yarısı okyanuslarda, suda asılı duran mikroskobik algler olan **fitoplankton** aracılığıyla gerçekleşir. Bir litre deniz suyunda milyonlarcası bulunur ve aldığımız her iki nefesten birini onlara borçluyuz."),
                .keyFigure(value: "≈ %50", label: "Dünya'da her yıl üretilen oksijenin okyanuslardaki fitoplanktondan gelen payı"),
                .paragraph("Fotosentezin iklim sorununun merkezinde yer almasının nedeni de budur. İki yüzyıldır kömür ve petrol yakarak, fotosentezin milyonlarca yıl önce yeraltına hapsettiği karbonu havaya geri veriyoruz. Bitkiler ve okyanuslar bunun bir kısmını yeniden emer, ama hepsini değil: Döngünün dengesi bozulmuştur ve CO₂ birikir."),
            ]),
            DemoChapter(title: "Fotosentez ve solunum", blocks: [
                .paragraph("Fotosentez şeker üretir; **solunum** onu yakar. İki süreç ==birbirinin tersidir== ve bir bitki ikisini de yapar — güpegündüz bile. İkisini karıştırmak bu konudaki en yaygın hatadır ve bu bölüm senin başına gelmesin diye var."),
                .heading("Ters yol"),
                .paragraph("Hücresel solunum glikozu ve oksijeni alır; CO₂, su ve her şeyden önce ATP biçiminde enerji açığa çıkarır. Hücrelerimizin her biri bunu sürekli yapar ve her bitki hücresi de aynısını yapar: Bitkinin büyümek, özsuyunu taşımak, stomalarını açmak için enerjiye ihtiyacı vardır — ve bu enerjiyi kendi şekerinden alır."),
                .formula("C_6H_{12}O_6 + 6\\,O_2 \\rightarrow 6\\,CO_2 + 6\\,H_2O + \\text{enerji}", caption: "Solunum: tersten okunan fotosentez denklemi"),
                .paragraph("İki denklem simetriktir, ama ne aynı yerde ne de aynı hızda gerçekleşir. Fotosentez kloroplastlarda ve yalnızca ışıkta olur; solunum ise **mitokondrilerde** ve her zaman olur. Tablo ikisini karşı karşıya koyuyor."),
                .table(title: "Karşı karşıya", headers: ["", "Fotosentez", "Solunum"], rows: [
                    ["Nerede", "Kloroplastlar", "Mitokondriler"],
                    ["Ne zaman", "Işıkta", "Gece gündüz"],
                    ["Kullandıkları", "CO₂, su, ışık", "Glikoz, O₂"],
                    ["Ürettikleri", "Glikoz, O₂", "CO₂, su, ATP"],
                    ["Kim", "Bitkiler, algler", "Bütün canlılar"],
                ]),
                .paragraph("Gündüz bir bitki ikisini aynı anda yapar, ama fotosentez açık ara üstün gelir: Solunumun açığa çıkardığından çok daha fazla CO₂ bağlar ve sonuç, madde kazancıdır. Gece yalnızca solunum sürer: Bitki şekerinin birazını tüketir ve biraz CO₂ açığa çıkarır. Yirmi dört saat boyunca bilanço güçlü biçimde pozitif kalır — bitkiyi büyüten budur."),
                .callout(
                    title: "Klasik tuzak",
                    text: "“Bitkiler gece solunum, gündüz fotosentez yapar.” Yanlış: **Her zaman** solunum yaparlar. Gündüz fotosentez, çok daha yoğun olduğu için solunumu yalnızca gölgede bırakır.",
                    tone: .warning
                ),
                .heading("Enerji nereden gelir"),
                .paragraph("Uç uca eklendiğinde iki süreç, enerjinin canlılar dünyasındaki yolculuğunu anlatır. Enerji Güneş'ten gelir; fotosentez onu glikozun bağlarında depolar; solunum onu ATP olarak serbest bırakır; ATP de hücrenin bütün işlerinin bedelini öder. Harcadığın her kalori, bir gün bir yaprağın yakaladığı bir fotondu."),
                .figure(.flow(title: "Enerjinin yolculuğu", steps: ["Güneş ışığı", "Glikoz (fotosentez)", "ATP (solunum)", "Hücrenin işi"])),
                .paragraph("Bu yolculuk canlıları iki aileye ayırır. **Ototroflar** — bitkiler, algler, bazı bakteriler — kendi organik maddelerini inorganik maddeden üretir: Yalnızca ışığa, suya ve CO₂'ye ihtiyaç duyarlar. **Heterotroflar** — hayvanlar, mantarlar, biz — bunu yapamaz: Doğrudan ya da dolaylı olarak bir ototrofun önceden ürettiği organik maddeyi yemek zorundadırlar."),
                .callout(
                    title: "Ototrof, heterotrof",
                    text: "**Ototrof** bir canlı organik maddesini inorganik maddeden üretir; **heterotrof** bir canlı ise onu başka canlılardan almak zorundadır. Her besin zinciri bir ototrofla başlar.",
                    tone: .definition
                ),
                .list([
                    "Fotosentez: glikoz üretir, ışıkta, kloroplastlarda",
                    "Solunum: glikozu yakar, her zaman, mitokondrilerde",
                    "Gündüz fotosentez üstün gelir; gece yalnızca solunum sürer",
                    "Zincirin başında ototroflar, arkasında heterotroflar",
                ]),
                .paragraph("Bu son nokta hem bütün bölümün hem de daha birçok konunun anahtarıdır: Dünya'daki yaşam, fotosentezle ==bir kez dönüştürülen== ve ardından besin zincirleri boyunca ağızdan ağıza aktarılan güneş enerjisiyle işler. Geri kalan her şey — solumak, koşmak, düşünmek — bu enerjiyi harcamanın bir yoludur."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Fotosentezin girenleri ve ürünleri nelerdir?",
                back: "Girenler: ışık enerjisiyle birlikte karbondioksit (CO₂) ve su (H₂O). Ürünler: glikoz (C₆H₁₂O₆) ve oksijen (O₂).",
                figure: .flow(title: "Fotondan şekere", steps: ["Işık", "Suyun parçalanması, O₂", "ATP", "Glikoz"]),
                chapter: 0
            ),
            DemoCard(
                kind: .choice,
                front: "Fotosentezin ışık evresi nerede gerçekleşir?",
                back: "Kloroplastın içindeki tilakoit zarlarında. Stroma ise Calvin döngüsüne ev sahipliği yapar.",
                choices: ["Stromada", "Tilakoit zarlarında", "Çekirdekte", "Mitokondrilerde"],
                answerIndex: 1,
                chapter: 1
            ),
            DemoCard(
                kind: .cloze,
                front: "Klorofil çoğunlukla maviyi ve kırmızıyı soğurur ve … yansıtır; yaprakların rengi buradan gelir.",
                back: "yeşili",
                chapter: 0
            ),
            DemoCard(kind: .basic, front: "Sınırlayıcı faktör nedir?", back: "Eksikliği fotosentezi frenleyen etken (ışık, CO₂ ya da sıcaklık): O eksik kaldıkça ötekileri artırmak hiçbir şeyi değiştirmez.", chapter: 2),
            DemoCard(kind: .cloze, front: "Bir glikoz molekülü oluşturmak için Calvin döngüsünün … tur dönmesi gerekir.", back: "altı", chapter: 1),
            DemoCard(kind: .choice, front: "Fotosentez hangi gazı açığa çıkarır?", back: "Işık evresi sırasında su moleküllerinin parçalanmasından gelen oksijeni (O₂).", choices: ["Karbondioksit", "Oksijen", "Azot", "Hidrojen"], answerIndex: 1, chapter: 0),
            DemoCard(kind: .basic, front: "Fotosentez ile solunum arasındaki fark nedir?", back: "Fotosentez, ışıkta ve kloroplastlarda, CO₂ ve sudan glikoz üretir. Solunum ise bu glikozu oksijenle yakarak her zaman ve mitokondrilerde enerji (ATP) açığa çıkarır.", chapter: 3),
            DemoCard(kind: .cloze, front: "Kendi organik maddesini inorganik maddeden üreten canlıya … canlı denir.", back: "ototrof", chapter: 3),
        ]
    )

    // MARK: Maths: derivatives

    private static let derivativesTR = OnboardingDemoCourse(
        id: "maths-derivatives",
        emoji: "📐",
        subject: "Mathématiques",
        title: "Türev",
        summary: "Bir noktadaki türev, teğet, temel türevler ve hesaplama kuralları, değişimi veren türevin işareti ve optimizasyon problemleri.",
        accentIndex: 0,
        chapters: [
            DemoChapter(title: "Türev ve teğet", blocks: [
                .paragraph("Türev almak, ==bir fonksiyonun ne kadar hızlı değiştiğini== ölçmek demektir. Bir eğri üzerinde bu hız görülebilir: Baktığın noktadaki teğetin eğimidir. Bütün bölüm bu fikre sığar, geri kalanı yalnızca hesaptır."),
                .heading("Değişim oranı"),
                .paragraph("Anlık hızdan önce ortalama hız gelir. Apsisleri $a$ ve $a+h$ olan iki nokta arasında, $x$ değeri $h$ kadar değişirken fonksiyon $f(a+h) - f(a)$ kadar değişmiştir. Bu ikisinin oranı **değişim oranı**dır: Eğrinin iki noktasını birleştiren doğrunun, yani kesenin eğimidir."),
                .formula("\\frac{f(a+h) - f(a)}{h}", caption: "f'nin a ile a + h arasındaki değişim oranı: kesenin eğimi"),
                .paragraph("Bu oran $h$'ye bağlıdır: İki nokta ne kadar yakınsa, kesen $a$ civarında eğrinin kendisine o kadar benzer. Türev fikri, $h$'yi sıfıra yaklaştırmak — iki noktayı üst üste gelene kadar birbirine yaklaştırmak — ve eğimin neye yaklaştığına bakmaktır."),
                .callout(
                    title: "Bir noktadaki türev",
                    text: "$f$'nin $a$ noktasındaki türevi, $f'(a)$ ile gösterilir; $h$ sıfıra yaklaşırken $a$ ile $a+h$ arasındaki değişim oranının limitidir. Bu limit varsa $f$'ye $a$ noktasında **türevlenebilir** denir.",
                    tone: .definition
                ),
                .formula("f'(a) = \\lim_{h \\to 0} \\frac{f(a+h) - f(a)}{h}", caption: "h sonsuz küçük olurken değişim oranı"),
                .paragraph("Geometrik olarak, iki nokta birleştiğinde kesen ==teğet== olur: Eğriye $a$ noktasında dokunan ve onun doğrultusunu izleyen doğru. Türev onun eğimidir. Dik ve pozitif bir eğim eğrinin hızla yükseldiğini; sıfır eğim ise eğrinin orada yatay olduğunu söyler."),
                .figure(.plot(title: "Bir noktadaki teğet", caption: "Eğriyi $a$ noktasında “saran” doğru: eğimi $f'(a)$'dır.", kind: .tangent)),
                .paragraph("Doğruyu yazmak için eğimi ve bir noktayı bilmek yeterlidir. $a$ noktasındaki teğetin denklemi $y = f'(a)(x - a) + f(a)$ olur: $(a, f(a))$ noktasından geçen ve eğimi $f'(a)$ olan doğru. Bu formül ezbere bilinmelidir, çünkü neredeyse her sınavda karşına çıkar."),
                .callout(
                    title: "Örnek",
                    text: "$a = 1$ noktasında $f(x) = x^2$ için: Değişim oranı $\\frac{(1+h)^2 - 1}{h} = 2 + h$ olur ve bu $2$'ye yaklaşır. Dolayısıyla $f'(1) = 2$ ve teğet $y = 2(x - 1) + 1 = 2x - 1$ olur.",
                    tone: .example
                ),
                .paragraph("Türevin işareti doğrudan eğri üzerinde okunur ve üçüncü bölümün tamamı bunun üzerinedir. Soldan sağa yükselen bir teğetin eğimi pozitif; alçalan bir teğetin eğimi negatif; yatay bir teğetin eğimi sıfırdır — ve çoğu zaman bir şeyin olduğu yer de burasıdır."),
                .list([
                    "$f'(a) > 0$: Eğri $a$ noktasında yükselir",
                    "$f'(a) < 0$: Alçalır",
                    "$f'(a) = 0$: Yatay teğet, çoğu zaman bir tepe ya da bir çukur",
                ]),
                .heading("Neden önemli"),
                .paragraph("Türev yalnızca bir ders nesnesi değildir: Bir şeyin değiştiği her yerdedir. Hız, konumun zamana göre türevidir; ivme, hızın türevidir. Ekonomide marjinal maliyet, toplam maliyetin türevidir. Bir fizikçi ya da bir ekonomist “hangi hızla?” diye sorduğunda, bir türev soruyordur."),
                .paragraph("Bu kavramın on yedinci yüzyılda iki kez icat edilmesinin nedeni de budur: Newton tarafından gezegenlerin hareketini betimlemek için, Leibniz tarafından eğrilerin geometrisi için. İki problem, tek fikir: ==bir noktaya sonsuz yakında ne olduğuna bakmak==."),
            ]),
            DemoChapter(title: "Türev hesaplamak", blocks: [
                .paragraph("Limiti neredeyse hiçbir zaman elle hesaplamazsın: **Temel türevleri** ve onları birleştiren kuralları öğrenirsin. Sekiz satırlık bir tablo ve üç kuralla müfredattaki her fonksiyonun türevini alabilirsin — ve bu, bir refleks hâline gelmesi gereken bir alıştırmadır."),
                .heading("Temel türevler"),
                .paragraph("Tablonun her satırı önceki bölümdeki tanımla kanıtlanabilir ve bunu en az bir kez $x^2$ için yapmış olmak faydalıdır. Ama pratikte onları ezbere bilirsin. En önemli satır $x^n$ satırıdır: Üs katsayı olarak aşağı iner ve üs bir azalır."),
                .table(title: "Temel türevler", headers: ["f(x)", "f′(x)"], rows: [
                    ["k (sabit)", "0"],
                    ["x", "1"],
                    ["x²", "2x"],
                    ["xⁿ", "n · xⁿ⁻¹"],
                    ["1/x", "−1/x²"],
                    ["√x", "1/(2√x)"],
                    ["eˣ", "eˣ"],
                    ["ln x", "1/x"],
                ]),
                .paragraph("İki satır ayrıca dikkat hak eder. Bir sabitin türevi sıfırdır: Değişmeyen bir fonksiyonun hızı sıfırdır, bu da mantıklıdır. $e^x$'in türevi ise $e^x$'in kendisidir: Kendi türevi olan ==tek fonksiyon== odur ve üstel fonksiyonun fizikte her yerde karşımıza çıkmasının nedeni tam olarak budur — büyüklüğüyle orantılı bir hızla büyüyen her şeyi betimler."),
                .heading("Kurallar"),
                .callout(
                    title: "Üç kural",
                    text: "**Toplam**: $(u+v)' = u' + v'$. **Çarpım**: $(uv)' = u'v + uv'$. **Bölüm**: $(u/v)' = (u'v - uv')/v^2$. Bir $k$ sabiti için de: $(ku)' = ku'$.",
                    tone: .insight
                ),
                .paragraph("Toplam kuralı en doğal olanıdır: Terim terim türev alınır. Örnek: $f(x) = 3x^2 - 5x + 2$ ifadesi $f'(x) = 6x - 5$ verir. Sabitler kaybolur, ==üsler bir azalır==, katsayılar çarpan olarak kalır. Bir polinomun türevi böylece tek satırda alınır."),
                .formula("(uv)' = u'v + uv'", caption: "Çarpımın türevi: Her çarpanın sırayla türevi alınır, sonra toplanır"),
                .paragraph("Çarpım kuralı biraz daha dikkat ister. $f(x) = x^2 e^x$ için $u = x^2$ ve $v = e^x$ alalım; böylece $u' = 2x$ ve $v' = e^x$: $f'(x) = 2x\\,e^x + x^2 e^x = (2x + x^2)\\,e^x$. İkinciyi koruyarak birincinin türevini al, sonra tersini yap ve topla. Sondaki çarpanlara ayırma bir incelik değildir: İşareti incelemeni sağlayacak olan odur."),
                .callout(
                    title: "Kaçınılması gereken hata",
                    text: "$(uv)' \\neq u'v'$. Çarpımın türevi, türevlerin çarpımı **değildir**: $(x \\cdot x)' = 2x$ olur, $1 \\cdot 1$ değil. Bölüm için de aynısı geçerlidir.",
                    tone: .warning
                ),
                .paragraph("Bölüm de aynı mantığı izler; bir eksi işareti ve paydada bir kare ile. $f(x) = \\frac{x}{x+1}$ için: $u = x$, $v = x + 1$, dolayısıyla $f'(x) = \\frac{1 \\cdot (x+1) - x \\cdot 1}{(x+1)^2} = \\frac{1}{(x+1)^2}$. Pay çoğu zaman epeyce sadeleşir — sadeleşmiyorsa hesabı kontrol et."),
                .heading("İç içe fonksiyonlar"),
                .paragraph("Geriye bir fonksiyonun bir başkasının içine yerleştiği durum kalır: $(2x+1)^3$, $\\sqrt{x^2+1}$, $e^{-x}$. İçi koruyarak dışın türevini al, sonra içteki fonksiyonun türeviyle çarp. Bir kuvvet için bu aşağıdaki formülü verir; üstel fonksiyon için $(e^{u})' = u'\\,e^{u}$ olur."),
                .formula("(u^n)' = n\\,u'\\,u^{n-1}", caption: "Bir fonksiyonun kuvvetinin türevi: dışın türevi çarpı içteki fonksiyonun türevi"),
                .paragraph("Örnek: $f(x) = (2x+1)^3$. İçteki fonksiyon $u = 2x+1$, türevi $u' = 2$; dolayısıyla $f'(x) = 3 \\cdot 2 \\cdot (2x+1)^2 = 6(2x+1)^2$. $u'$ çarpanını unutmak bütün bölümdeki en sık hatadır: İçteki fonksiyonun türevi ==asla atlanmaz==."),
                .list([
                    "Biçimi belirle: toplam, çarpım, bölüm ya da iç içe fonksiyon",
                    "Her parçanın türevini tabloyla al",
                    "Doğru kuralla birleştir",
                    "Sadeleştir ve çarpanlara ayır, sonra işareti kontrol et",
                ], ordered: true),
                .paragraph("Bu dört adım her fonksiyon için aynı rutindir. Pratikle kafanda gerçekleşirler; pratik olmadan müsvedde kâğıdında. Her iki durumda da sonuncusu — çarpanlara ayırma — bir sonraki bölümü hazırlayan adımdır."),
            ]),
            DemoChapter(title: "Türev ve değişim", blocks: [
                .paragraph("Türevin işareti sana ==fonksiyonun hangi yöne gittiğini== söyler: Pozitifse artar, negatifse azalır. Bu, her değişim tablosunun anahtarı ve türev almayı öğrenmenin nedenidir."),
                .heading("Teorem"),
                .paragraph("Bir aralıkta $f'$ pozitifse $f$ o aralıkta artandır; $f'$ negatifse $f$ azalandır; $f'$ bütün aralıkta sıfırsa $f$ sabittir. Sezgi birinci bölümdekiyle aynıdır: Her yerde pozitif bir eğim, her yerde yükselen bir eğridir."),
                .figure(.plot(title: "f′ işareti ve f'nin yönü", caption: "$f'$ pozitif olduğu yerde $f$ yükselir; işaret değiştirerek sıfır olduğu yerde $f$ bir ekstremuma ulaşır.", kind: .variation)),
                .paragraph("Grafik iki eğriyi alt alta gösterir. $f'$ eksenin üstünde kaldığı sürece $f$ tırmanır; $f'$ ekseni aşağı doğru kestiği anda $f$ bir tepeye ulaşır ve yeniden iner. $f'$ türevinin **işaret değiştirerek** sıfır olduğu nokta bir **yerel ekstremum**dur: $f'$ pozitiften negatife geçiyorsa maksimum, tersi durumda minimum."),
                .heading("Eksiksiz bir örnek"),
                .paragraph("$f(x) = x^3 - 3x$ için: $f'(x) = 3x^2 - 3 = 3(x-1)(x+1)$. Türev $-1$ ve $1$ noktalarında sıfır olur. İki çarpanın çarpımı için bir işaret tablosu şunu verir: $-1$'den önce pozitif, $-1$ ile $1$ arasında negatif, $1$'den sonra pozitif. Buradan $-1$'de $f(-1) = 2$ olan bir **yerel maksimum** ve $1$'de $f(1) = -2$ olan bir **yerel minimum** elde ederiz."),
                .table(title: "f(x) = x³ − 3x fonksiyonunun değişimi", headers: ["Aralık", "f′ işareti", "f'nin yönü"], rows: [
                    ["]−∞ ; −1[", "+", "artan"],
                    ["]−1 ; 1[", "−", "azalan"],
                    ["]1 ; +∞[", "+", "artan"],
                ]),
                .paragraph("Bu tablo, “$f$'nin değişimini inceleyiniz” sorusuna beklenen yanıttır: Üstte aralıklar, ortada türevin işareti, altta oklar ve fonksiyonun yön değiştirdiği noktalardaki $f$ değerleri. Standart bir nesnedir ve tam olarak bu sırayla düzenlenmelidir."),
                .callout(
                    title: "Yöntem",
                    text: "1. Türevi al. 2. $f'$ türevinin işaretini incele (çarpanlara ayır!). 3. Değişimi çıkar. 4. Uç noktalardaki ve ekstremumlardaki değerleri hesapla. 5. Tabloyu oluştur.",
                    tone: .insight
                ),
                .paragraph("İşlerin ters gittiği yer ikinci adımdır. Bir türevin işareti $6x - 5$ ya da $3x^2 - 3$ olduğu gibi bırakılarak okunamaz: ==$f'(x) = 0$ denklemini çözmeli== ve ardından bir işaret tablosu çizmeli ya da her çarpanın işaretini okumak için çarpanlara ayırmalısın. Çarpanlara ayrılmamış bir türev, hakkında hiçbir şey bilmediğin bir türevdir."),
                .keyFigure(value: "f′ = 0", label: "eğrinin yatay teğete sahip olduğu yer: bir tepe, bir çukur ya da bir düzlük"),
                .paragraph("Dolayısıyla yatay bir teğet bir kanıt değil, bir işarettir: Fonksiyonun bir an için yükselmeyi ya da alçalmayı bıraktığını söyler, ama ters yönde yeniden yola çıkıp çıkmadığını söylemez. Karar veren işaret tablosudur, yalnızca o."),
                .callout(
                    title: "Dikkat",
                    text: "Bir ekstremum için $f'(a) = 0$ yeterli değildir: $x^3$'ün türevi 0'da sıfırdır, ama yön değiştirmez — bu bir düzlüktür. $f'$ türevinin $a$ noktasında **işaret değiştirmesi** gerekir.",
                    tone: .warning
                ),
                .heading("Bir eğriyi okumak"),
                .paragraph("Bağlantı tersine de işler: $f$'nin eğrisinden $f'$ türevinin işaretini, $f'$ türevinin eğrisinden de $f$'nin değişimini tahmin edebilirsin. Bu klasik bir alıştırmadır: Sana türevin grafiği verilir ve fonksiyonun nerede artan olduğu sorulur. Yanıt şudur: $f'$ eğrisinin yatay eksenin üstünde olduğu yerde."),
                .list([
                    "$f$ eğrisi yükseliyor ⇔ $f'$ pozitif",
                    "$f$'nin tepesi ya da çukuru ⇔ $f'$ işaret değiştirerek sıfır olur",
                    "$f'$ eğrisi eksenin üstünde ⇔ $f$ artan",
                ]),
                .paragraph("Bu çapraz okuma, bir tarifi uygulayan öğrenciyi anlayan öğrenciden ayırır: Türev fazladan bir hesap değil, ==eğriye başka bir gözle bakmaktır==. Ve çizmediğimiz bir eğrinin en iyi noktasını aradığımız bir sonraki bölümü mümkün kılan da budur."),
            ]),
            DemoChapter(title: "Bir optimizasyon problemi çözmek", blocks: [
                .paragraph("Optimizasyon, bir büyüklüğün alabileceği ==en büyük ya da en küçük değeri== bulmak demektir: bir ağılın en büyük alanı, bir kutunun en düşük maliyeti, en yüksek kâr. Türevin somut bir iş yaptığı problemler bunlardır ve en çok puan getirenler de bunlardır."),
                .heading("Duvara dayalı bir ağıl"),
                .paragraph("Bir duvara dayalı dikdörtgen bir ağıl çevirmek için 40 metre çitin var: Bir kenarı duvar, diğer üç kenarı çit oluşturuyor. Hangi boyutlar en büyük alanı verir? Duvara dik olan genişliğe $x$ diyelim. İki genişlik $2x$ metre çit alır; uzunluk için $40 - 2x$ metre kalır. Alan bu ikisinin çarpımıdır."),
                .formula("A(x) = x\\,(40 - 2x) = 40x - 2x^2", caption: "x, 0 ile 20 arasındayken ağılın alanı"),
                .paragraph("Problem bir fonksiyon incelemesine dönüştü: $A$'nın $[0 ; 20]$ aralığındaki maksimumunu arıyoruz — 20'nin ötesinde uzunluk negatif olurdu. Türevi alalım: $A'(x) = 40 - 4x$; bu, $x = 10$ için sıfır olur, öncesinde pozitif, sonrasında negatiftir. Yanıtı değişim tablosu verir."),
                .table(title: "A(x) = 40x − 2x² fonksiyonunun değişimi", headers: ["x", "A′ işareti", "A'nın yönü"], rows: [
                    ["[0 ; 10[", "+", "artan, 0'dan 200'e"],
                    ["x = 10", "0", "maksimum: A(10) = 200"],
                    ["]10 ; 20]", "−", "azalan, 200'den 0'a"],
                ]),
                .paragraph("En büyük alan, $10$ m genişlik ve $20$ m uzunluk için $200$ m²'dir. Bunun bir kare olmadığına dikkat et: Duvar bir kenarın yerini tuttuğu için en iyi dikdörtgen, genişliğinin iki katı uzunluktadır. Türev olmadan rastgele değerler deneyebilirdik; türevle ise bunun en iyisi olduğundan ==eminiz==."),
                .callout(
                    title: "Yöntem",
                    text: "1. Değişkeni ve onun anlamlı olduğu aralığı seç. 2. Optimize edilecek büyüklüğü bu tek değişkenin fonksiyonu olarak ifade et. 3. Türevi al, işaretini incele, tabloyu oluştur. 4. Ekstremumu oku ve **sorulan soruyu yanıtla** — birimiyle birlikte.",
                    tone: .insight
                ),
                .heading("İkinci bir örnek"),
                .paragraph("Bir şirket günde $x$ yüz ürün üretiyor; $x$ 1 ile 10 arasındayken toplam maliyet $C(x) = x^2 + 4x + 16$ (yüz avro cinsinden). Yüz ürün başına ortalama maliyet $M(x) = C(x)/x = x + 4 + 16/x$ olur. Bu ortalama maliyet hangi üretim miktarında en düşüktür?"),
                .formula("M'(x) = 1 - \\frac{16}{x^2} = \\frac{x^2 - 16}{x^2} = \\frac{(x-4)(x+4)}{x^2}", caption: "İşaretini okumak için çarpanlarına ayrılmış türev"),
                .paragraph("$[1 ; 10]$ aralığında payda ve $x + 4$ pozitiftir: $M'$ türevinin işareti $x - 4$'ün işaretidir; 4'ten önce negatif, sonra pozitif. Ortalama maliyet $x = 4$'e kadar azalır, sonra yeniden artar: Minimum $x = 4$'tedir ve $M(4) = 4 + 4 + 4 = 12$, yani yüz ürün başına 1.200 avrodur. Günde dört yüz ürün üretmek **en ekonomik üretim hızıdır**."),
                .figure(.flow(title: "İzlenecek yol", steps: ["Bir değişken", "Bir fonksiyon", "Türevi", "Tablosu", "Yanıt"])),
                .paragraph("İki örnek de tam olarak aynı yolu izler ve bu yol hep aynıdır: Bir optimizasyon probleminin zorluğu neredeyse hiçbir zaman türevde değil, **kurulumdadır** — doğru değişkeni bulmak ve büyüklüğü onun fonksiyonu olarak yazmak. Fonksiyon bir kez kurulduğunda geri kalanı üçüncü bölümdür."),
                .callout(
                    title: "Tuzaklar",
                    text: "Aralığı unutmak (negatif bir uzunluk olmaz); yanlış büyüklüğün türevini almak (ortalama maliyet yerine toplam maliyet); alanın $200$ m² olduğunu söylemeden $x = 10$'da durmak. Sınavı değerlendiren kişi yalnızca tabloyu değil, **sorunun yanıtını** bekler.",
                    tone: .warning
                ),
                .list([
                    "Ağıl, kutu, silindir: bir serbest boyut, bir uzunluk ya da hacim kısıtı",
                    "Maliyet, kâr, gelir: üretilen bir miktar, bir ekonomik fonksiyon",
                    "Yolculuk, hız, zaman: seçilecek bir konum ya da bir an",
                ]),
                .paragraph("Bu üç aile neredeyse bütün sınav sorularını kapsar. Her seferinde gizli soru aynıdır: ==$x$'in hangi değeri için türev işaret değiştirerek sıfır olur?== Onu her kılıkta tanıyabildiğinde, bu bölüm senindir."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "$f'(a)$ türevi geometrik olarak neyi temsil eder?",
                back: "$f$'nin eğrisine apsisi $a$ olan noktada çizilen teğetin eğimini.",
                figure: .plot(title: "a noktasındaki teğet", caption: "", kind: .tangent),
                chapter: 0
            ),
            DemoCard(
                kind: .choice,
                front: "$f(x) = 3x^2 - 5x + 2$ fonksiyonunun türevi nedir?",
                back: "$f'(x) = 6x - 5$: Üs bir azalır, $x$'li terim kendi katsayısına dönüşür, sabit kaybolur.",
                choices: ["$6x - 5$", "$3x - 5$", "$6x + 2$", "$x^2 - 5$"],
                answerIndex: 0,
                chapter: 1
            ),
            DemoCard(
                kind: .cloze,
                front: "$f'$ türevinin … olduğu bir aralıkta $f$ fonksiyonu artandır.",
                back: "pozitif",
                chapter: 2
            ),
            DemoCard(kind: .basic, front: "Çarpımın türevinin formülü nedir?", back: "$(uv)' = u'v + uv'$: Her çarpanın sırayla türevi alınır ve toplanır.", chapter: 1),
            DemoCard(kind: .cloze, front: "$e^x$ fonksiyonunun türevi … fonksiyonudur.", back: "$e^x$", chapter: 1),
            DemoCard(kind: .choice, front: "$f(x) = x^3 - 3x$ fonksiyonunun hangi noktalarda yerel ekstremumu vardır?", back: "$x = -1$ (maksimum, değeri 2) ve $x = 1$ (minimum, değeri $-2$) noktalarında: $f'(x) = 3(x-1)(x+1)$ türevinin işaret değiştirerek sıfır olduğu yerlerde.", choices: ["$x = 0$", "$x = -1$ ve $x = 1$", "$x = 3$", "Hiçbiri"], answerIndex: 1, chapter: 2),
            DemoCard(kind: .basic, front: "Bir optimizasyon probleminde bir büyüklüğün maksimumu nasıl bulunur?", back: "Büyüklüğü, anlamlı olduğu aralıkta tek bir değişkenin fonksiyonu olarak ifade et, türevini al, türevin işaretini incele ve maksimumu, değişim tablosunda türevin pozitiften negatife geçerek sıfır olduğu yerde oku.", chapter: 3),
            DemoCard(kind: .cloze, front: "Bir duvara dayalı 40 m çitle, ağılın alanı … m genişlik için en büyüktür.", back: "10", chapter: 3),
        ]
    )

    // MARK: Physics: energy

    private static let energyTR = OnboardingDemoCourse(
        id: "physics-energy",
        emoji: "⚡️",
        subject: "Physique",
        title: "Enerji",
        summary: "Enerjinin biçimleri, bir biçimden ötekine geçerken korunumu, güç ve verim, ardından enerji zincirleri; müfredattaki formüller ve büyüklük mertebeleriyle.",
        accentIndex: 6,
        chapters: [
            DemoChapter(title: "Enerjinin biçimleri", blocks: [
                .paragraph("Enerji görülmez, **dönüşür**: Düşen bir elma, bir motorun ısısı, bir lambanın ışığı farklı biçimlerdeki aynı büyüklüktür. ==Joule (J)== ile ölçülür ve bir joule, kabaca bir elmayı bir metre kaldırmak için gereken enerjidir."),
                .heading("Tek büyüklük, birçok biçim"),
                .paragraph("Fizikçilerin ısının, hareketin, ışığın ve elektriğin farklı kılıklara bürünmüş tek ve aynı şey olduğunu anlaması iki yüzyıl sürdü. Onları birbirine bağlayan, her birinin bir başkasına dönüştürülebilmesi — bir motor ısıyı harekete, bir dinamo hareketi elektriğe dönüştürür — ve toplam miktarın hiçbir zaman değişmemesidir. Aşağıdaki tablo müfredattaki biçimleri sıralıyor."),
                .table(title: "Başlıca biçimler", headers: ["Biçim", "Neye bağlı", "Örnek"], rows: [
                    ["Kinetik", "kütle ve hız", "hareket hâlindeki bir araba"],
                    ["Yer çekimi potansiyel", "kütle ve yükseklik", "ağaçtaki bir elma"],
                    ["Isıl", "moleküllerin hareketliliği", "sıcak bir tencere"],
                    ["Elektrik", "akım", "bir pil"],
                    ["Kimyasal", "bağlar", "benzin, glikoz"],
                ]),
                .paragraph("Bu biçimlerden ikisinin ezbere bilinmesi gereken bir formülü vardır. **Kinetik enerji**, hareket eden bir cismin enerjisidir: Kütleyle ve hızın karesiyle artar. Kütleyi iki katına çıkarmak onu iki katına çıkarır; hızı iki katına çıkarmak onu dört katına çıkarır. Yüksek hızdaki kazaları bu kadar ağır yapan o karedir."),
                .formula("E_k = \\frac{1}{2} m v^2", caption: "Kinetik enerji: m kg, v m/s, E J cinsinden"),
                .paragraph("**Yer çekimi potansiyel enerjisi**, belli bir yükseklikteki bir cismin enerjisidir: Bıraktığında harekete dönüşecek “yedekteki” enerji. Kütleyle, yükseklikle ve yer çekimi alanı şiddeti $g$ ile orantılıdır; $g$ Dünya'da yaklaşık $9.8$ N/kg'dır — Ay'da ise altı kat daha azdır."),
                .formula("E_p = m g h", caption: "Yer çekimi potansiyel enerjisi: g ≈ 9,8 N/kg, h m cinsinden"),
                .callout(
                    title: "Büyüklük mertebesi",
                    text: "50 km/h (≈ 14 m/s) hızla giden 1.000 kg'lık bir araba $E_k = \\frac{1}{2} \\times 1000 \\times 14^2 \\approx 98\\,000$ J, yani yaklaşık 100 kJ taşır. 100 km/h hızda **dört kat fazlası**: 400 kJ, yani onu kırk metre yukarı kaldırmak için gereken enerji.",
                    tone: .example
                ),
                .paragraph("Bu örnek birimlerin tuzağını gösterir: Hız kilometre bölü saat değil, metre bölü saniye cinsinden olmalıdır; yoksa sonuç on üç kat yanlış çıkar. Dönüştürmek için km/h değeri 3,6'ya bölünür. Her kinetik enerji hesabında ==kontrol edilecek ilk şey== budur."),
                .keyFigure(value: "× 4", label: "hız iki katına çıkınca kinetik enerji dört katına çıkar: formüldeki kare budur"),
                .heading("Birimler"),
                .paragraph("Joule gündelik yaşamın ölçeğinde küçüktür ve katları kullanılır: besinler için kilojoule (1 kJ = 1.000 J), yakıtlar için megajoule, elektrik için kilovatsaat. Bir gram şeker yaklaşık 17 kJ; bir litre benzin 35 MJ; bir çikolata 1.000 kJ açığa çıkarır — kayıpsız dönüştürebilseydik bir arabayı Eyfel Kulesi'nin tepesine çıkarmaya yeterdi."),
                .callout(
                    title: "Birim",
                    text: "Enerji hiçbir zaman watt ile değil, joule ile ifade edilir. Watt **gücü**, yani saniye başına enerjiyi ölçer. İkisini karıştırmak, litreyle dakikada litreyi karıştırmaktır.",
                    tone: .warning
                ),
                .list([
                    "1 kJ = 1.000 J: Bir besinin enerjisi ambalajında kJ olarak verilir",
                    "1 kWh = 3.600.000 J: Elektrik faturasındaki birim",
                    "1 kalori ≈ 4,18 J: Eski birim, etiketlerde hâlâ var",
                ]),
                .paragraph("Rakamlardan çok mantığı hatırla: Enerji her zaman bir hacim gibi bir miktardır ve hiç kaybolmadan bir biçimden ötekine dönüşür. Bütün fiziğin en önemli ilkesi olan bu ilkeyi bir sonraki bölüm ortaya koyuyor."),
            ]),
            DemoChapter(title: "Korunum ve aktarımlar", blocks: [
                .paragraph("==bleu|Enerji yoktan var edilemez, var olan enerji yok edilemez==: Bir biçimden ötekine, bir sistemden ötekine geçer. Bu, korunum ilkesidir ve atomdan galaksiye kadar her şey için geçerlidir. Hiçbir deney onu bugüne dek yanlışlayamamıştır."),
                .heading("Bir düşüş"),
                .paragraph("Yerden iki metre yukarıda tutulan bir top düşün. Potansiyel enerjisi vardır, kinetik enerjisi yoktur. Onu bırak: Düşerken yüksekliği azalır, hızı artar — potansiyel enerji tam olarak aynı oranlarda kinetik enerjiye dönüşür. Yerde her şey kinetiktir; çarpma anında her şey ısıya ve sese dönüşür."),
                .figure(.flow(title: "Bir düşüşün enerji zinciri", steps: ["Tepede potansiyel enerji", "Kinetik enerjiye dönüşür", "Çarpma: ısı ve ses", "Toplam değişmez"])),
                .paragraph("Bu akıl yürütme, kuvvetleri bilmeden hesap yapmanı sağlar. 2 m'den bırakılan bir top, sürtünme ihmal edildiği sürece potansiyel enerji kaybeder ve tam olarak o kadar kinetik enerji kazanır: $mgh = \\frac{1}{2}mv^2$; dolayısıyla kütle sadeleşir ve yerdeki hız $v = \\sqrt{2gh}$ olur."),
                .formula("v = \\sqrt{2 g h} \\approx \\sqrt{2 \\times 9{,}8 \\times 2} \\approx 6{,}3 \\text{ m/s}", caption: "Sürtünmesiz ortamda yerdeki hız: bir bilye için de bir bowling topu için de aynı"),
                .paragraph("Sonuç kütleye bağlı değildir: Aynı yükseklikten bırakılan bir bilye ile bir bowling topu yere aynı hızla ulaşır. Galileo bunu Pisa Kulesi'nin tepesinden gözlemledi; enerjinin korunumu ise tek satırda açıklar. ==Bu ilkenin gücü== buradadır: Hareket denklemlerinin zahmetli olacağı yerde yanıt verir."),
                .callout(
                    title: "Mekanik enerji",
                    text: "Kinetik ve potansiyel enerjinin toplamı: $E_m = E_k + E_p$. Sürtünme yoksa korunur: Birinin kaybettiğini öteki kazanır.",
                    tone: .definition
                ),
                .formula("E_m = E_k + E_p = \\text{sabit}", caption: "Sürtünme olmadığında"),
                .paragraph("Sarkaç kusursuz bir örnektir. Salınımının en üst noktasında bir an durur: Her şey potansiyeldir. En alt noktada en hızlı hareket eder: Her şey kinetiktir. Arada enerji durmaksızın bir biçimden ötekine geçer ve sarkaç — hava olmasaydı — tam olarak başladığı yüksekliğe geri tırmanırdı."),
                .heading("Peki ya sürtünme?"),
                .paragraph("Gerçek hayatta sarkaç sonunda durur, top giderek daha alçağa sıçrar, motor kapatılınca araba durur. Mekanik enerji azalır. Yok olmamıştır: Sürtünme onu havada, yerde, frenlerde — ki bunlar ısınır, bazen epeyce — **ısıl enerjiye** dönüştürmüştür."),
                .callout(
                    title: "Sürtünme ne yapar",
                    text: "Hiçbir şeyi “yok etmez”: Kaybedilen mekanik enerji ısıl enerjiye dönüşür. Toplam her zaman korunur, yalnızca **daha az yararlıdır** — dağınık ısı artık hiçbir şeyi hareket ettirmez.",
                    tone: .insight
                ),
                .paragraph("Bu yararlılık kaybı derin bir fikirdir. Enerji korunur ama **niteliği düşer**: Her dönüşüm, bir kısmını artık geri kazanılamayan ılık ısı olarak bırakır. Devridaim makinesinin imkânsız olmasının ve bir motorun sürekli beslenmesi gerekmesinin nedeni budur."),
                .list([
                    "İş: bir şeyi hareket ettiren bir kuvvetin aktardığı enerji — itmek, kaldırmak, frenlemek",
                    "Isı: sıcaklık farkıyla aktarım — ocaktaki bir tencere",
                    "Işıma: ışıkla aktarım — tenini ısıtan Güneş",
                ]),
                .paragraph("Bu üç yol, enerjinin bir sistemden ötekine geçebildiği tek yollardır. Bir **enerji bilançosu** çıkarmak; bir sistem seçmek, bu üç yoldan girenleri ve çıkanları listelemek ve hesabın tuttuğunu kontrol etmek demektir: ==Girenden çıkan çıkarılınca kalan, sistemde kalandır==."),
            ]),
            DemoChapter(title: "Güç ve verim", blocks: [
                .paragraph("**Güç**, enerjinin ne kadar hızlı aktarıldığını söyler. 2.000 W'lık bir ısıtıcı her saniye 2.000 joule aktarır. İki cihaz aynı enerjiyi, biri bir dakikada, öteki bir saatte kullanabilir: Birincisi altmış kat daha güçlüdür."),
                .heading("Güç"),
                .formula("P = \\frac{E}{\\Delta t}", caption: "P watt (W), E joule, Δt saniye cinsinden"),
                .paragraph("Formül iki yönde de okunur. Gücü ve süreyi bilirsen enerjiyi bulursun: $E = P \\times \\Delta t$. Bir saat açık kalan 2.000 W'lık bir fırın $2000 \\times 3600 = 7.2 \\times 10^6$ J, yani 7,2 MJ kullanır. Tablodaki büyüklük mertebelerini akılda tutmaya değer."),
                .table(title: "Birkaç güç değeri", headers: ["Ne", "Güç"], rows: [
                    ["Dinlenen bir insan", "≈ 100 W"],
                    ["Tüm gücüyle pedal çeviren bir bisikletçi", "≈ 300 W"],
                    ["Bir fırın", "2.000 W"],
                    ["Bir araba", "≈ 100 kW"],
                    ["Bir rüzgâr türbini", "≈ 3 MW"],
                    ["Bir nükleer reaktör", "≈ 1.000 MW"],
                ]),
                .paragraph("Dinlenen bir insan kabaca eski tip bir ampulün gücünü yayar: Kalabalık bir odanın çabucak ısınmasının nedeni budur. Bir nükleer reaktör ise on milyon kat daha fazlasını üretir — bir milyon konutu beslemeye yetecek kadar. Güç, bir musluğun debisinin suyun akış hızı olması gibi, ==enerjinin akış hızıdır==."),
                .callout(
                    title: "Kilovatsaat",
                    text: "1 kWh, bir saat boyunca 1.000 W demektir: $1000 \\times 3600 = 3.6 \\times 10^6$ J. Elektrik faturasındaki birimdir ve yaklaşık yirmi sent tutar.",
                    tone: .example
                ),
                .paragraph("Kilovatsaat bir güç değil, bir enerjidir — “saat” bunu hatırlatmak için oradadır: bir zamanla çarpılmış bir güç. Fransa'da bir hane yılda yaklaşık 4.700 kWh elektrik kullanır; bu, gece gündüz ortalama 500 W'ın biraz üzerindedir. Sekiz saatlik bir gece boyunca açık bırakılan 2.000 W'lık bir radyatör tek başına bunlardan 16 tanesini kullanır."),
                .heading("Verim"),
                .paragraph("Hiçbir dönüştürücü kusursuz değildir: Alınan enerjinin bir kısmı ısı olarak çıkar ve hiçbir işe yaramamıştır. ==Verim==, yararlı olanı sağlanan enerjiyle karşılaştırır. Bir benzinli motor yakıtın kimyasal enerjisini alır ve ancak üçte birini hareket olarak geri verir: Geri kalanı motoru, egzozu ve çevredeki havayı ısıtır."),
                .formula("\\eta = \\frac{E_{\\text{yararlı}}}{E_{\\text{sağlanan}}}", caption: "Her zaman 1'e (%100) eşit ya da ondan küçüktür"),
                .paragraph("Verim çoğu zaman yüzde olarak verilir ve bir zincir boyunca çarpılır: Bir santralin verimi %35, şebekeninki %90 ise bütünün verimi $0.35 \\times 0.9 \\approx 0.32$ olur. Fazladan her halka bir şey kaybettirir; bu yüzden olabildiğince az halka olmasına çalışılır."),
                .bars(title: "Birkaç dönüştürücünün verimi", unit: "%", bars: [
                    DemoBar(label: "Benzinli motor", value: 35),
                    DemoBar(label: "LED ampul", value: 40),
                    DemoBar(label: "Elektrik motoru", value: 90),
                    DemoBar(label: "Elektrikli ısıtıcı", value: 100),
                ]),
                .paragraph("Grafik enerji dönüşümünün önemli bir kısmını açıklar. Bir elektrik motoru aldığının onda dokuzunu harekete dönüştürür, bir benzinli motor ise üçte birini: Başlangıçta aynı enerjiyle elektrikli araba neredeyse üç kat daha uzağa gider. Akkor ampulün verimi ise %5'ti — biraz ışık da veren bir ısıtıcıydı."),
                .callout(
                    title: "%100 verim mi?",
                    text: "Elektrikli bir ısıtıcı her şeyi ısıya dönüştürür, ama istediğimiz tam da ısıdır: Verimi %100'dür. Bir motor içinse aynı ısı bir kayıptır. **Yararlı** olan, cihazdan ne yapmasını istediğine bağlıdır.",
                    tone: .warning
                ),
                .list([
                    "Güç: saniye başına enerji, watt cinsinden",
                    "Enerji: güç çarpı süre — joule ya da faturada kWh cinsinden",
                    "Verim: yararlı bölü sağlanan, asla 1'den büyük değil ve bir zincir boyunca çarpılır",
                ]),
                .paragraph("Bu üç kavram her teknik belgeyi okumanı ve her vaadi kontrol etmeni sağlar. Aldığından fazla yararlı enerji verdiğini iddia eden bir cihaz birinci ilkeyi çiğnemiş olurdu; reklamlar ne derse desin, birden büyük bir verim ==yoktur==."),
            ]),
            DemoChapter(title: "Enerji zincirleri", blocks: [
                .paragraph("**Enerji zinciri**, enerjinin yolculuğunu anlatan şemadır: nereden geldiği, hangi dönüştürücülerden geçtiği, hangi biçimde çıktığı ve yolda neyin kaybolduğu. ==Enerji bilançosunun aracıdır== ve sınavda çizmen istenen şey neredeyse her zaman budur."),
                .heading("Bir zinciri okumak"),
                .paragraph("Şema soldan sağa okunur. İki uçta **depolar** bulunur: enerjinin başlangıçta depolandığı yer ve sonunda vardığı yer. Aralarında **dönüştürücüler**: enerjinin biçim değiştirmesini sağlayan cihazlar. Her ok bir enerji biçimi taşır ve her dönüştürücüden bir ısı oku çıkar — kayıplar. Bir hidroelektrik santrali en kolay okunan örnektir."),
                .figure(.flow(title: "Bir hidroelektrik santrali", steps: ["Depolanan su: potansiyel", "Düşüş: kinetik", "Türbin: mekanik", "Alternatör: elektrik", "Şebeke"])),
                .paragraph("Barajdaki su, yüksekliği nedeniyle potansiyel enerjiye sahiptir. Borulardan düşerken bunu kinetik enerjiye dönüştürür. Türbin bu hareketli suyu dönme hareketine, alternatör dönme hareketini akıma dönüştürür; hatlar da akımı uzaklara taşır. Her adımda biraz ısı kaçar — ama çok az: Bir hidroelektrik santralinin verimi %90'a yakındır, hepsinin en iyisi."),
                .paragraph("Aynı mantık, insan vücudu da dahil her sistemi betimler. Bir bisikletçi besinlerin kimyasal enerjisini kaslarında yaklaşık %25 verimle mekanik enerjiye dönüştürür: Dörtte üçü ısı olarak çıkar ve terlemenin nedeni budur."),
                .figure(.flow(title: "Bir bisikletçi", steps: ["Besin: kimyasal", "Kaslar: mekanik", "Tekerlekler: kinetik", "Sürtünme: ısı"])),
                .heading("Dönüştürücüler"),
                .paragraph("Bir dönüştürücü, aldığı ve geri verdiği enerjiyle tanımlanır. Tablo müfredattakileri bir araya getiriyor; her biri için son sütun, kullanılmayan kısmın hangi biçimde çıktığını söylüyor. Bunun **her zaman ısı** olduğuna dikkat et: Niteliği düşmüş bütün enerjinin son biçimidir."),
                .table(title: "Birkaç dönüştürücü", headers: ["Dönüştürücü", "Aldığı", "Verdiği", "Kaybettiği"], rows: [
                    ["Elektrik motoru", "Elektrik", "Mekanik", "Isı"],
                    ["Güneş paneli", "Işıma", "Elektrik", "Isı"],
                    ["Pil", "Kimyasal", "Elektrik", "Isı"],
                    ["LED lamba", "Elektrik", "Işık", "Isı"],
                    ["Benzinli motor", "Kimyasal", "Mekanik", "Isı, gazlar"],
                ]),
                .paragraph("Bir cihazın zincirini çizmek, onun nasıl çalıştığını — ve çoğu zaman neden ısındığını — anlamak demektir. Bir bilgisayar elektrik enerjisi alır ve sonunda ısıdan başka hiçbir şey vermez: Hesaplamanın kendisi hiçbir şey depolamaz. Isınan bir telefon şarj aleti, yolda yüzde birkaç kaybeden bir dönüştürücüdür."),
                .callout(
                    title: "Ekmek kızartma makinesi",
                    text: "1.000 W elektrik enerjisi alır ve 1.000 W ısı verir: verim %100. Ama elektrik %35 verimli bir termik santralden geliyorsa, ekmeği kızartmak için yaklaşık 3.000 W'lık gaz yakmak gerekmiştir. Yalnızca son halka değil, **zincirin tamamı** önemlidir.",
                    tone: .example
                ),
                .heading("Elektrik nereden gelir"),
                .paragraph("Zinciri geriye doğru sonuna kadar izlemek, enerjinin **kaynaklarına** götürür: yaktığımız, düşmesine izin verdiğimiz, yakaladığımız şeyler. Bazıları insan ölçeğinde bir sürede kendini yeniler — güneş, rüzgâr, su, biyokütle —, bazılarıysa tükenir — kömür, petrol, gaz, uranyum. Grafik, 1980'lerden beri nükleerin baskın olduğu Fransa'da elektriğin nereden geldiğini gösteriyor."),
                .bars(title: "Fransa'da elektriğin kaynakları (büyüklük mertebeleri)", unit: "%", bars: [
                    DemoBar(label: "Nükleer", value: 65),
                    DemoBar(label: "Hidroelektrik", value: 12),
                    DemoBar(label: "Rüzgâr", value: 10),
                    DemoBar(label: "Güneş", value: 5),
                    DemoBar(label: "Gaz, kömür", value: 8),
                ]),
                .paragraph("Bu paylar yıldan yıla değişir — kurak bir kış barajları boşaltır, rüzgârlı bir yıl rüzgâr enerjisini artırır — ama sıralama aynı kalır: üçte iki nükleer, dörtte bir yenilenebilir ve daha çok talep zirvelerinde kullanılan bir fosil payı. Avrupa'nın başka yerlerinde gaz ve kömür çok daha ağır basar ve oradaki elektrik birkaç kat daha fazla CO₂ salar."),
                .callout(
                    title: "Yenilenebilir, ama bedava değil",
                    text: "Yenilenebilir bir kaynak kendini yeniler, ama onu yakalamanın bir bedeli vardır: malzemeler, arazi, zincir boyunca kayıplar. Üstelik “yenilenebilir”, “etkisiz” demek değildir: Bir baraj bir vadiyi sular altında bırakır, bir rüzgâr türbini bakır gerektirir. **Kayıpsız zincir, sonuçsuz kaynak yoktur.**",
                    tone: .warning
                ),
                .list([
                    "İki uçta depolar, aralarında dönüştürücüler, her okta tek bir enerji biçimi",
                    "Her dönüştürücü ısı kaybeder: bunu verim ölçer",
                    "Verimler zincir boyunca çarpılır",
                    "En baştaki kaynak, enerjinin neye mal olduğunu — ve ne saldığını — belirler",
                ]),
                .paragraph("Bu dört kuralla her zinciri çizebilir ve yorumlayabilirsin: bir telefonun, bir trenin, bir santralin zincirini. Fiziği haberlerde okuduklarına bağlayan bölüm budur ve etrafındaki dünyayı anlamak için dördü arasında ==en yararlısıdır==."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Düşen bir topun potansiyel enerjisine ne olur?",
                back: "Düşüş sırasında kinetik enerjiye dönüşür (hız artar), ardından çarpma anında ısıl enerjiye ve ses enerjisine dönüşür. Toplam korunur.",
                figure: .flow(title: "Enerji zinciri", steps: ["Potansiyel", "Kinetik", "Isı ve ses"]),
                chapter: 1
            ),
            DemoCard(
                kind: .choice,
                front: "Bir arabanın hızı iki katına çıkarsa kinetik enerjisi…",
                back: "Dört katına çıkar: $E_k = \\frac{1}{2} m v^2$ hızın karesine bağlıdır.",
                choices: ["iki katına çıkar", "dört katına çıkar", "değişmez", "yarıya iner"],
                answerIndex: 1,
                chapter: 0
            ),
            DemoCard(
                kind: .cloze,
                front: "Güç, birim … başına aktarılan enerjidir: watt ile ifade edilir.",
                back: "zaman",
                chapter: 2
            ),
            DemoCard(kind: .basic, front: "Yer çekimi potansiyel enerjisinin formülü nedir?", back: "$E_p = m g h$; m kg, g ≈ 9,8 N/kg ve h metre cinsinden.", chapter: 0),
            DemoCard(kind: .cloze, front: "Verim, … enerjinin sağlanan enerjiye oranıdır.", back: "yararlı", chapter: 2),
            DemoCard(kind: .choice, front: "Enerjinin birimi nedir?", back: "Joule (J). Watt ise gücü, yani saniye başına enerjiyi ölçer.", choices: ["Watt", "Joule", "Newton", "Volt"], answerIndex: 1, chapter: 0),
            DemoCard(kind: .basic, front: "Enerji zinciri nedir?", back: "Enerjiyi bir depodan ötekine, dönüştürücüler üzerinden izleyen şema: Her okta tek bir enerji biçimi ve her dönüştürücüde ısı biçiminde bir kayıp oku.", chapter: 3),
            DemoCard(kind: .cloze, front: "Bir hidroelektrik santralinde depolanan suyun … enerjisi, düşüş sırasında kinetik enerjiye dönüşür.", back: "potansiyel", chapter: 3),
        ]
    )
}
