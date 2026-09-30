import Foundation

#if DEBUG
// MARK: - Les six cours de debug, en turc

/// Six cours complets, écrits d'avance, **réservés aux builds de debug** : de quoi remplir
/// la bibliothèque en un geste pour tester les fiches, le plan, les cartes et la révision
/// sans rien générer. Ils suivent la même règle que les cours de démonstration — quatre
/// chapitres, du texte entre chaque objet riche, aucun objet qui en touche un autre — et
/// le même niveau d'exigence : lycée ou début de licence, des faits exacts, des chiffres
/// justes et des calculs vérifiés.
///
/// Les identifiants sont stables d'une langue à l'autre ; les matières sont les noms
/// canoniques de `SubjectCatalog`.
extension DebugCourseCatalog {
    static let turkish: [OnboardingDemoCourse] = [
        revolutionTR, geneticsTR, probabilityTR, supplyDemandTR, circuitsTR, mitosisTR,
    ]

    // MARK: Histoire : la Révolution française

    private static let revolutionTR = OnboardingDemoCourse(
        id: "debug-revolution",
        emoji: "🇫🇷",
        subject: "Histoire",
        title: "Fransız İhtilali (1789–1799)",
        summary: "Fransa'yı mutlak monarşiden Cumhuriyet'e taşıyan on yıl: 1789 krizi, meşruti monarşi, Terör Dönemi, ardından Bonaparte'ın darbesine kadar Direktuvar.",
        accentIndex: 1,
        chapters: [
            DemoChapter(title: "Eski Rejim'in krizi (1787–1789)", blocks: [
                .paragraph("1789'da Fransa, Avrupa'nın en kalabalık krallığıdır: yaklaşık ==28 milyon kişi==, gücünü Tanrı'dan aldığına inanan ve onu kimseyle paylaşmayan bir kral tarafından yönetilir. On yıl içinde, yüzyıllardır süren bu rejim çöker. Bunun nasıl olduğunu anlamak için, sonradan **Eski Rejim** (Ancien Régime) adı verilecek düzenden yola çıkmak gerekir."),
                .heading("Zümrelere dayalı bir toplum"),
                .paragraph("Toplum, hukuken eşit olmayan üç zümreye ayrılmıştır. **Ruhban sınıfı** dua eder, **soylular** savaşır, **Üçüncü Zümre** çalışır: en azından teori böyle der. İlk iki zümre **ayrıcalıklara** sahiptir — örneğin başlıca doğrudan vergi olan taille'dan muafiyet ya da köylülerden çeşitli bedeller toplama hakkı gibi özel haklar."),
                .callout(
                    title: "Ayrıcalık",
                    text: "Kelimenin tam anlamıyla bir “özel yasa”: herkese değil, bir gruba ya da bir kişiye tanınan hak veya muafiyet. Eski Rejim'de yasa ve vergi karşısında eşitsizlik istisna değil, **kuraldır**.",
                    tone: .definition
                ),
                .paragraph("Üçüncü Zümre, ne rahip ne de soylu olan herkesi, yani neredeyse bütün halkı kapsar: büyük çoğunluğu oluşturan köylüler, kentlerdeki zanaatkârlar ve işçiler, ama aynı zamanda zengin ve eğitimli bir **burjuvazi** — tüccarlar, avukatlar, bankerler — ki bu kesim, doğuştan gelen ayrıcalıklara ayrılmış onurlardan dışlanmaya giderek daha az katlanır."),
                .bars(title: "Üç zümrenin nüfus içindeki payı (1789 dolayları)", unit: "%", bars: [
                    DemoBar(label: "Ruhban sınıfı", value: 0.5),
                    DemoBar(label: "Soylular", value: 1.5),
                    DemoBar(label: "Üçüncü Zümre", value: 98),
                ]),
                .paragraph("Grafik, sorunun özünü gösterir: nüfusun yüzde ikisi ayrıcalıkların çoğunu, toprağın büyük bölümünü ve neredeyse bütün yüksek görevleri elinde tutar. Ocak 1789'da Rahip Sieyès durumu ünlü bir broşürde özetler: “Üçüncü Zümre nedir? Her şey. Şimdiye kadar ne oldu? Hiçbir şey. Ne istiyor? Bir şey olmak.”"),
                .heading("Aynı anda üç kriz"),
                .paragraph("İhtilal, üç krizin bir araya gelmesinden doğar. Önce bir **mali kriz**: savaşlar, özellikle de Amerikan bağımsızlığına verilen destek borcu büyütmüş, borcun geri ödenmesi ==devlet harcamalarının neredeyse yarısını== yutar hâle gelmiştir. Birbirini izleyen bakanlar ayrıcalıklıları vergilendirmeyi önerir; ayrıcalıklılar reddeder."),
                .paragraph("Ardından bir **ekonomik kriz**: 1788 hasadı dolu yüzünden felakete dönüşür ve ekmek fiyatı fırlar. 14 Temmuz 1789'da Paris'te yüzyılın en yüksek düzeyine ulaşır. Son olarak bir **düşünce krizi**: Aydınlanma filozofları — kuvvetler ayrılığıyla Montesquieu, halk egemenliğiyle Rousseau, hoşgörüyle Voltaire — seçkinlere iktidarı akıl adına yargılamayı öğretmiştir."),
                .figure(.flow(title: "Krizden İhtilale", steps: ["Borç ve iflas tehdidi", "Ayrıcalıklılar vergiyi reddeder", "Kral Etats Généraux'yu toplar", "Üçüncü Zümre kişi başı oy ister", "Üçüncü Zümre kendini Ulusal Meclis ilan eder"])),
                .paragraph("Köşeye sıkışan XVI. Louis, 1614'ten beri toplanmamış olan üç zümrenin meclisi **Etats Généraux**'yu toplantıya çağırır. Krallığın her yerinde, krala neyin yolunda gitmediğini anlatmak için **şikâyet defterleri** yazılır: yaklaşık altmış bin defter, özellikle vergi karşısında eşitlik ve suistimallerin sona ermesini ister, ama neredeyse hiçbiri monarşinin kaldırılmasını talep etmez."),
                .callout(
                    title: "Zümre başına oy",
                    text: "Etats Généraux'da her zümre ayrı oy kullanır ve **tek bir oya** sahiptir: birleşen ruhban sınıfı ve soylular, Üçüncü Zümre'yi her zaman iki oya karşı bir oyla yener. Üçüncü Zümre, diğer iki zümrenin toplamı kadar milletvekiline sahip olmayı elde etmiştir — ama bu sayının bir anlamı olması için oylamanın **kişi başı** yapılması gerekir.",
                    tone: .insight
                ),
                .paragraph("Her şey bu usul sorununda düğümlenir. 17 Haziran 1789'da, uzlaşma sağlanamayınca Üçüncü Zümre milletvekilleri kendilerini ==bleu|Ulusal Meclis== ilan eder: artık bir zümreyi değil, bütün ulusu temsil etmektedirler. 20 Haziran'da salonlarını kapalı bulunca Tenis Kortu salonunda toplanır ve Fransa'ya bir anayasa vermeden dağılmayacaklarına yemin ederler. Egemenlik taraf değiştirmiştir."),
            ]),
            DemoChapter(title: "1789: mutlakiyetin sonu", blocks: [
                .paragraph("1789 yazı, yüzyılların inşa ettiğini birkaç hafta içinde yıkar. Versailles'daki milletvekillerinin devrimini ==Parislilerin devrimi==, ardından da kırsalın devrimi izler: onu geri döndürülemez kılan, bu birleşmedir."),
                .timeline(title: "1789 yazı ve sonbaharı", events: [
                    DemoEvent(date: "5 Mayıs", label: "Etats Généraux Versailles'da açılır"),
                    DemoEvent(date: "20 Haziran", label: "Tenis Kortu Yemini"),
                    DemoEvent(date: "14 Temmuz", label: "Bastille'in alınması"),
                    DemoEvent(date: "4 Ağustos", label: "Ayrıcalıkların kaldırılması"),
                    DemoEvent(date: "26 Ağustos", label: "İnsan ve Yurttaş Hakları Bildirgesi"),
                    DemoEvent(date: "5–6 Ekim", label: "Kral Versailles'dan Paris'e getirilir"),
                ]),
                .paragraph("Temmuz başında kral, Paris çevresine asker yığar ve halkın sevdiği bakan Necker'i görevden alır. Parisliler bunu Meclis'e karşı bir zor kullanma hazırlığı olarak görür. 14 Temmuz'da, Invalides'den alınan tüfekler için barut arayan kalabalık, kraliyet kalesi ve devlet hapishanesi olan **Bastille**'e saldırır. İçeride yalnızca yedi mahkûm vardır, ama düşüşü bir semboldür: halk kralı boyun eğmeye zorlamıştır."),
                .heading("4 Ağustos gecesi"),
                .paragraph("Kırsalda, bir aristokrat komplosu söylentisi **Büyük Korku**'yu başlatır: silahlı köylüler şatolara saldırır ve senyörlük haklarının kayıtlı olduğu defterleri yakar. Sükûneti sağlamak için Meclis, 4 Ağustos gecesi ==ayrıcalıkların kaldırılmasını== oylar: feodal haklara, öşre ve memuriyetlerin satılmasına son verilir; herkes vergi ve kamu görevleri karşısında eşit olur."),
                .callout(
                    title: "İnsan ve Yurttaş Hakları Bildirgesi",
                    text: "26 Ağustos 1789'da kabul edilen bildirge, yeni rejimin ilkelerini on yedi maddede ortaya koyar. Madde 1: “İnsanlar hak bakımından özgür ve eşit doğar ve öyle yaşarlar.” Madde 3: egemenlik **ulusa** aittir. Madde 16: kuvvetler ayrılığı olmadan anayasa olmaz.",
                    tone: .definition
                ),
                .paragraph("Bildirge evrensel bir metindir — Fransızdan değil, insandan söz eder — ve Fransa dışında bu kadar etkili olmasının nedeni budur. Ama kör noktaları da vardır: kadınlar hakkında hiçbir şey söylemez ve sömürgelerdeki köleliği sorgulamaz. 1791'de Olympe de Gouges ona bir *Kadın ve Kadın Yurttaş Hakları Bildirgesi* ile yanıt verir."),
                .figure(.split(
                    title: "İktidarın iki kaynağı",
                    left: DemoColumn(title: "Eski Rejim", items: ["İlahi hakka dayalı monarşi", "Zümrelere dayalı toplum", "Ayrıcalıklar", "Yasayı kral yapar", "Tebaa"]),
                    right: DemoColumn(title: "1789 ilkeleri", items: ["Ulusal egemenlik", "Haklarda eşitlik", "Herkes için ortak yasa", "Kuvvetler ayrılığı", "Yurttaşlar"])
                )),
                .paragraph("Bu karşılaştırma 1789'da neyin değiştiğini özetler: iktidar artık Tanrı'dan değil ulustan gelir ve yasa artık tek bir kişinin iradesi değil, ==genel iradenin ifadesidir==. Kral yerinde kalır, ama artık egemenliğine sahip olmadığı bir devletin birinci memurundan başka bir şey değildir."),
                .heading("Meşruti monarşi"),
                .paragraph("1789'dan 1791'e kadar Kurucu Meclis Fransa'yı yeniden düzenler. **Departmanları** kurar (1790), borcu ödemek için kilise mallarını devletleştirir ve ruhban sınıfına, rahipleri seçilmiş memurlara dönüştüren bir **Ruhban Sınıfının Medeni Anayasası**'nı dayatır. 1791 Anayasası meşruti bir monarşi kurar: kral yürütme yetkisini ve erteleyici veto hakkını korur; yasaları bir Yasama Meclisi oylar."),
                .callout(
                    title: "Servete dayalı oy hakkı",
                    text: "1791'de yalnızca **aktif yurttaşlar** oy kullanır: en az üç günlük emek karşılığı kadar vergi ödeyen 25 yaşından büyük erkekler, yani yaklaşık 4,3 milyon Fransız. Diğerleri “pasif” yurttaştır: haklarda eşittirler, ama siyasi haklarda değil.",
                    tone: .warning
                ),
                .paragraph("Bu uzlaşma kralın iyi niyetine dayanır ve kralın iyi niyeti yoktur. 20 Haziran'ı 21 Haziran 1791'e bağlayan gece XVI. Louis ailesiyle birlikte doğu sınırına doğru kaçar; tanınır ve **Varennes**'de yakalanır. Güven bağı kopmuştur: Parislilerin bir kısmı için ulusundan kaçan bir kral artık onu temsil edemez."),
            ]),
            DemoChapter(title: "Cumhuriyet ve Terör Dönemi (1792–1794)", blocks: [
                .paragraph("Nisan 1792'de Fransa Avusturya'ya savaş ilan eder. Devrimciler özgürlüğü ihraç etmeyi umar; kral ise gizlice kendisini yeniden güçlendirecek bir yenilgiyi umar. Savaş ==İhtilali radikalleştirecektir==: yenilgiler, gerçek ya da varsayılan ihanetler, iç ayaklanmalar ve ne pahasına olursa olsun kazanmak gerektiği inancı."),
                .heading("Monarşinin çöküşü"),
                .paragraph("10 Ağustos 1792'de Parisli sankülotlar ve taşradan gelen federeler Tuileries Sarayı'na saldırır. Kral görevden uzaklaştırılır, ardından hapsedilir. Yeni bir meclis olan **Konvansiyon**, ilk kez **erkeklere tanınan genel oy** ile seçilir. 20 Eylül'de Fransız ordusu Prusyalıları Valmy'de durdurur; 21 Eylül'de Konvansiyon krallığı kaldırır. Cumhuriyet doğmuştur."),
                .keyFigure(value: "21 Ocak 1793", label: "Konvansiyon tarafından yargılanıp vatana ihanetten suçlu bulunan XVI. Louis, Devrim Meydanı'nda giyotinle idam edilir"),
                .paragraph("Kralın idamı Fransa'yı Avrupa'nın bütün monarşilerinin düşmanı yapar: İngiltere, İspanya ve Birleşik Eyaletler koalisyona katılır. Asker toplamak için Konvansiyon 300 000 kişilik bir asker alımı kararı verir ve Batı alevlenir: bu, iki tarafta yaklaşık iki yüz bin kişinin ölümüne yol açacak olan **Vendée Savaşı**'nın başlangıcıdır."),
                .figure(.split(
                    title: "Konvansiyon'da iki kamp",
                    left: DemoColumn(title: "Jirondenler", items: ["Brissot, Vergniaud", "Taşranın desteği", "Paris'e karşı güvensizlik", "Ekonomik liberalizm", "Olağanüstü önlemlere karşı çıkış"]),
                    right: DemoColumn(title: "Montanyarlar", items: ["Robespierre, Danton, Marat", "Sankülotların desteği", "Güçlü merkezî iktidar", "Fiyat denetimi", "Olağanüstü önlemler"])
                )),
                .paragraph("İki grup arasında, milletvekillerinin çoğunluğunu oluşturan **Ova** (la Plaine) oyların yönünü belirler. 2 Haziran 1793'te Konvansiyon'u kuşatan sankülotların baskısıyla Jirondenlerin önderleri tutuklanır. Montanyarlar artık tek başlarına, Robespierre'in baskın figürü hâline geldiği **Kamu Selameti Komitesi** aracılığıyla yönetir."),
                .heading("Terör Dönemi"),
                .callout(
                    title: "Terör Dönemi",
                    text: "Dış savaş ve iç savaşla tehdit edilen Cumhuriyet'i kurtarmak için özgürlükleri askıya alan 1793–1794 olağanüstü hükümeti. Araçları: **şüpheliler yasası** (Eylül 1793), Devrim Mahkemesi, görevli temsilciler ve giyotin.",
                    tone: .definition
                ),
                .paragraph("Terör Dönemi aynı zamanda bir ekonomik ve sosyal politikadır: **genel azami fiyat** temel ihtiyaç maddelerinin fiyatını sabitler, **toplu seferberlik** 18–25 yaş arası bütün erkekleri silah altına alır ve Konvansiyon 4 Şubat 1794'te sömürgelerde köleliği kaldırır. Zamanı özgürlüğün I. yılı olan 22 Eylül 1792'den başlatan bir cumhuriyet takvimi uygular."),
                .paragraph("İnsan bilançosu ağırdır. Mahkemeler yaklaşık ==rose|17 000 ölüm cezası== verir; buna yargısız infazlar ve iç savaş katliamları dahil değildir. Yaygın kanının aksine kurbanlar çoğunlukla soylular değildir: büyük kısmı isyan, hile ya da gönülsüzlükle suçlanan halktan insanlardır."),
                .bars(title: "Terör Dönemi'nde ölüme mahkûm edilenler, toplumsal kökenlerine göre", unit: "%", bars: [
                    DemoBar(label: "İşçiler, zanaatkârlar", value: 31),
                    DemoBar(label: "Köylüler", value: 28),
                    DemoBar(label: "Burjuvazi", value: 25),
                    DemoBar(label: "Soylular", value: 8.5),
                    DemoBar(label: "Ruhban sınıfı", value: 6.5),
                ]),
                .paragraph("Tarihçi Donald Greer'in 1935'te ortaya koyduğu bu rakamlar, Terör'ün önce Cumhuriyet'in kendini tehdit altında hissettiği yerleri — Vendée, Lyon, Marsilya, Toulon — ve dolayısıyla insanların çoğunun yaşadığı yerleri vurduğunu gösterir. 1794 baharında askerî zaferler olağanüstü önlemleri daha az savunulur kılar; ama 22 Prairial yasası (Haziran 1794) yargılamaları daha da hızlandırır: bu, **Büyük Terör**'dür."),
                .callout(
                    title: "9 Termidor",
                    text: "27 Temmuz 1794'te (II. yıl 9 Termidor), kendi canlarından korkan milletvekilleri Robespierre'i ve yakınlarını tutuklatır. Ertesi gün giyotinle idam edilirler. Terör sona erer; ama muhalifleri onu dışarıdan yendiği için değil, ==kendi aktörleri== ona sırt çevirdiği için.",
                    tone: .insight
                ),
            ]),
            DemoChapter(title: "Direktuvar'dan Bonaparte'a (1795–1799) ve geriye kalanlar", blocks: [
                .paragraph("Termidor'dan sonra ılımlı cumhuriyetçiler ==İhtilali bitirmek== ister: ne kralın dönüşü ne de Terör'ün dönüşü. III. yıl Anayasası (1795), hem tek bir adamın hem de bir meclisin diktatörlüğünü önlemek üzere tasarlanır."),
                .heading("Kırılgan bir rejim"),
                .paragraph("Yürütme yetkisi beş **direktöre**, yasama yetkisi iki meclise verilir — yasaları öneren Beş Yüzler Meclisi ve onları oylayan Yaşlılar Meclisi. Oy hakkı yeniden servete bağlanır. Rejim, 1797 seçimlerini kazanan kralcılar ile 1798 seçimlerini kazanan yeni Jakobenler arasında sıkışır: Direktuvar her seferinde sonucu bir zor kullanımıyla iptal eder ve giderek daha fazla orduya dayanır."),
                .table(title: "On yılın rejimleri", headers: ["Rejim", "Tarihler", "Kim yönetir", "Oy hakkı"], rows: [
                    ["Mutlak monarşi", "1789'a kadar", "Yalnızca kral", "Yok"],
                    ["Meşruti monarşi", "1791–1792", "Kral ve Yasama Meclisi", "Servete dayalı"],
                    ["Cumhuriyet: Konvansiyon", "1792–1795", "Konvansiyon, Kamu Selameti Komitesi", "Erkeklere genel oy"],
                    ["Cumhuriyet: Direktuvar", "1795–1799", "Beş direktör, iki meclis", "Servete dayalı"],
                    ["Konsüllük", "1799'dan itibaren", "Birinci Konsül Bonaparte", "Plebisitler"],
                ]),
                .paragraph("Tablo bir eğri gibi okunur: iktidar 1793'e kadar genişler, sonra daralır. Ve her aşamada oy hakkı da aynı hareketi izler. İhtilal ulusal egemenlik ilkesini ortaya koymuştur, ama ==ulus adına konuşma hakkının kime ait olduğu== konusunda tartışmayı hiç bırakmamıştır."),
                .paragraph("Bu arada genç bir general öne çıkar. Napolyon Bonaparte 1795'te Paris'te bir kralcı ayaklanmayı ezmiş, 1796–1797'de İtalya'yı fethetmiş, ardından Mısır Seferi'ni yönetmiştir. Zaferlerinin şanıyla Fransa'ya dönünce, Anayasa'yı değiştirmek için “bir kılıç” arayan ve direktör olmuş olan Sieyès ile ittifak kurar."),
                .callout(
                    title: "18 Brümer darbesi",
                    text: "9 Kasım 1799'da (VIII. yıl 18 Brümer) Bonaparte ve Sieyès Direktuvar'ı devirir; ertesi gün grenadiyeler Beş Yüzler Meclisi'ni dağıtır. Ardından gelen Konsüllük, iktidarı Birinci Konsül'ün elinde toplar. Geleneksel olarak **İhtilalin sonu** bu güne tarihlenir.",
                    tone: .example
                ),
                .heading("İhtilalden geriye kalanlar"),
                .paragraph("Bonaparte mirasın büyük bir bölümünü korur: 1804 Medeni Kanunu yasa önünde eşitliği, mülkiyeti ve feodalitenin sonunu güvence altına alır. Başka kazanımları ise siler: 1802'de köleliği yeniden getirir ve meclislerin egemenliğinin yerine kendi egemenliğini koyar. Devrimci miras bu yüzden iki sütunda okunur: kalıcı olarak kazanılmış ilkeler ve bütün XIX. yüzyıl boyunca sürecek mücadeleler."),
                .list([
                    "Kalıcı kazanımlar: ayrıcalıkların ve zümre toplumunun sonu, yasa ve vergi önünde eşitlik, departmanlar, metrik sistem, laik nüfus kayıtları",
                    "Konan ilkeler: ulusal egemenlik, insan hakları, kuvvetler ayrılığı",
                    "Tamamlanmamış mücadeleler: genel oy (1848), köleliğin kesin olarak kaldırılması (1848), kadınlara oy hakkı (1944)",
                ]),
                .paragraph("Son satırdaki tarihler, 1789'un bütün vaatlerini yerine getirmenin bir buçuk yüzyıl aldığını gösterir. İhtilali kurucu bir an yapan, ==ilan edilen ilkeler ile uygulanmaları== arasındaki bu mesafedir: sonraki kuşaklara, kendisinin tanımadığı şeyleri talep edecekleri kelimeleri vermiştir."),
                .figure(.flow(title: "On yılın dinamiği", steps: ["1789: ulus egemenliği ele alır", "1791: kralla uzlaşma", "1792: savaş ve Cumhuriyet", "1793–1794: Terör", "1795–1799: istikrar arayışı, ardından ordu"])),
                .paragraph("Bu şema, dönem üzerine yazılacak bir kompozisyonun omurgasıdır. Her aşama bir öncekinin başarısızlığına bir yanıttır: 1791 uzlaşması kral yüzünden, ılımlı Cumhuriyet savaş yüzünden, Terör aşırılıkları yüzünden, Direktuvar ise meşruiyet eksikliği yüzünden başarısız olur. ==Her aşamanın neden bir sonrakine yol açtığını== açıklamak, İhtilali ezberlemek değil anlamaktır."),
                .callout(
                    title: "Klasik hata",
                    text: "İhtilalin 1789'da monarşiyi kaldırdığını yazmak. 1789'da **mutlakiyeti** ve ayrıcalıkları kaldırır; meşruti monarşi 10 Ağustos 1792'ye kadar sürer ve Cumhuriyet ancak Eylül 1792'de ilan edilir.",
                    tone: .warning
                ),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Eski Rejim toplumunun üç zümresi hangileridir?",
                back: "Ayrıcalıklı zümreler olan ruhban sınıfı ve soylular (nüfusun yaklaşık %2'si) ile vergilerin büyük kısmını ödeyen Üçüncü Zümre (yaklaşık %98).",
                figure: .split(
                    title: "Zümrelere dayalı bir toplum",
                    left: DemoColumn(title: "Ayrıcalıklılar", items: ["Ruhban sınıfı", "Soylular"]),
                    right: DemoColumn(title: "Ayrıcalıksızlar", items: ["Üçüncü Zümre"])
                ),
                chapter: 0
            ),
            DemoCard(
                kind: .choice,
                front: "Meclis 4 Ağustos 1789 gecesi neyi oylar?",
                back: "Ayrıcalıkların kaldırılmasını: feodal haklara, öşre ve memuriyetlerin satılmasına son verilir, vergi karşısında eşitlik sağlanır.",
                choices: ["İnsan Hakları Bildirgesi", "Ayrıcalıkların kaldırılması", "Krallığın kaldırılması", "Ruhban Sınıfının Medeni Anayasası"],
                answerIndex: 1,
                chapter: 1
            ),
            DemoCard(
                kind: .cloze,
                front: "XVI. Louis, Haziran 1791'de doğu sınırına kaçarken … kasabasında yakalanır.",
                back: "Varennes",
                chapter: 1
            ),
            DemoCard(kind: .basic, front: "1789'da zümre başına mı kişi başına mı oy kullanılacağı sorusu neden belirleyicidir?", back: "Zümre başına oylamada ruhban sınıfı ve soylular her zaman iki oya karşı bir oyla kazanır. Kişi başına oylamada ise diğer iki zümrenin toplamı kadar milletvekili olan Üçüncü Zümre, birkaç müttefikle çoğunluğu sağlayabilir.", hint: "Her iki durumda oyları sayın.", chapter: 0),
            DemoCard(kind: .cloze, front: "17 Haziran 1789'da Üçüncü Zümre milletvekilleri kendilerini … ilan eder.", back: "Ulusal Meclis", chapter: 0),
            DemoCard(kind: .choice, front: "Fransa'da Cumhuriyet ne zaman ilan edilir?", back: "Eylül 1792'de: Konvansiyon, Valmy'nin ertesi günü, 21 Eylül'de krallığı kaldırır.", choices: ["Temmuz 1789", "Haziran 1791", "Eylül 1792", "Temmuz 1794"], answerIndex: 2, chapter: 2),
            DemoCard(kind: .basic, front: "Terör Dönemi nedir?", back: "Savaştaki Cumhuriyet'i kurtarmak için özgürlükleri askıya alan 1793–1794 olağanüstü hükümeti: şüpheliler yasası, Devrim Mahkemesi, yaklaşık 17 000 ölüm cezası. II. yıl 9 Termidor'da (27 Temmuz 1794) Robespierre'in düşüşüyle sona erer.", chapter: 2),
            DemoCard(kind: .cloze, front: "1789 Bildirgesi'nin 1. maddesi şöyle der: “İnsanlar hak bakımından özgür ve … doğar ve öyle yaşarlar.”", back: "eşit", chapter: 1),
            DemoCard(kind: .choice, front: "Terör Dönemi'nde en çok ölüme mahkûm edilen toplumsal grup hangisidir?", back: "Halktan insanlar: işçiler, zanaatkârlar ve köylüler mahkûmların yaklaşık onda altısını oluşturur; soylular ise yaklaşık %8.", choices: ["Soylular", "Ruhban sınıfı", "İşçiler, zanaatkârlar ve köylüler", "Ordu subayları"], answerIndex: 2, chapter: 2),
            DemoCard(kind: .basic, front: "Servete dayalı oy hakkı nedir?", back: "Belirli bir miktarda vergi (cens) ödeyenlere ayrılmış oy hakkı. 1791'de yalnızca yaklaşık 4,3 milyon erkekten oluşan “aktif” yurttaşlar oy kullanır.", chapter: 1),
            DemoCard(kind: .cloze, front: "VIII. yıl 18 … darbesi (9 Kasım 1799) Bonaparte'ı iktidara getirir.", back: "Brümer", chapter: 3),
            DemoCard(kind: .choice, front: "Direktuvar döneminde yürütme yetkisini kaç direktör kullanır?", back: "Beş; karşılarında iki meclis vardır: Beş Yüzler ve Yaşlılar.", choices: ["Bir", "Üç", "Beş", "Yedi"], answerIndex: 2, chapter: 3),
        ]
    )

    // MARK: SVT : génétique et ADN

    private static let geneticsTR = OnboardingDemoCourse(
        id: "debug-genetics",
        emoji: "🧬",
        subject: "SVT",
        title: "Genetik ve DNA",
        summary: "DNA molekülü, eşlenmesi, genden proteine geçiş, çeşitliliği yaratan mutasyonlar ve bunların aktarımını açıklayan Mendel yasaları.",
        accentIndex: 4,
        chapters: [
            DemoChapter(title: "DNA molekülü", blocks: [
                .paragraph("Vücudunuzdaki her hücrenin çekirdeğinde, birkaç mikrometreye sıkıştırılmış yaklaşık ==iki metre DNA== bulunur. Bu molekül bir canlıyı oluşturmayı ve çalıştırmayı sağlayan bilgiyi taşır ve onu bir hücreden yavru hücrelerine, bir ebeveynden çocuklarına aktarır."),
                .heading("Çift sarmal"),
                .paragraph("DNA — deoksiribonükleik asit — uzun bir **nükleotit** zinciridir. Her nükleotit üç bileşenden oluşur: bir fosfat grubu, bir şeker (deoksiriboz) ve bir **azotlu baz**. Dört baz vardır: adenin (A), timin (T), guanin (G) ve sitozin (C). Genetik bilgiyi oluşturan, bu bazların molekül boyunca diziliş sırasıdır."),
                .callout(
                    title: "Bazların tamamlayıcılığı",
                    text: "DNA'nın iki zinciri bazları aracılığıyla birbirine bağlanır ve bazlar her zaman aynı şekilde eşleşir: **A ile T** (iki hidrojen bağı), **G ile C** (üç hidrojen bağı). Dolayısıyla bir zinciri bilmek, diğerini de bilmek demektir.",
                    tone: .definition
                ),
                .paragraph("Bu kural, yapı anlaşılmadan önce fark edilmişti: 1950'de Erwin Chargaff, bütün türlerin DNA'sında adenin kadar timin, guanin kadar da sitozin bulunduğunu gösterir. Buna karşılık A ve G oranları türden türe değişir."),
                .formula("A = T \\;\\;\\;\\; G = C \\;\\;\\;\\; A + G = T + C", caption: "Baz oranları cinsinden Chargaff kuralları: eşleşmenin bir sonucu"),
                .paragraph("1953'te James Watson ve Francis Crick, Rosalind Franklin'in elde ettiği X ışını kırınım görüntülerine dayanarak **çift sarmal** modelini önerir. İki zincir, burulmuş bir merdiven gibi birbirinin etrafına sarılır: merdivenin kenarları şeker-fosfat zincirleri, basamakları ise baz çiftleridir. İki zincir ==antiparaleldir==: zıt yönlerde uzanır."),
                .heading("Genler, kromozomlar, genom"),
                .paragraph("Bir insan hücresinde DNA, 23'ü anneden 23'ü babadan kalıtılan **46 kromozoma** bölünmüştür. **Gen**, bir proteinin yapımı için gereken bilgiyi taşıyan DNA parçasıdır; bir kromozom üzerinde belirli bir yeri, yani **lokusu** vardır. Bir organizmanın DNA'sının tamamı onun **genomudur**: insanda her kromozom takımı için yaklaşık 3,2 milyar baz çifti."),
                .bars(title: "Protein kodlayan gen sayısı (büyüklük mertebeleri)", unit: "bin", bars: [
                    DemoBar(label: "E. coli bakterisi", value: 4.3),
                    DemoBar(label: "Maya", value: 6),
                    DemoBar(label: "Sirke sineği", value: 14),
                    DemoBar(label: "C. elegans solucanı", value: 20),
                    DemoBar(label: "İnsan", value: 20),
                ]),
                .paragraph("Grafik bir sürpriz barındırır: bir milimetrelik bir solucanın gen sayısı aşağı yukarı bizimkiyle aynıdır. Demek ki bir organizmanın karmaşıklığı gen sayısına değil, ==genlerin nasıl kullanıldığına== — ne zaman, nerede ve ne kadar — bağlıdır. Üstelik insanda protein kodlayan genler genomun yalnızca yaklaşık %1,5'ini kaplar."),
                .table(title: "Temel kavramlar", headers: ["Kavram", "Tanım"], rows: [
                    ["Gen", "Bir proteini kodlayan DNA parçası"],
                    ["Alel", "Bir genin, dizisiyle farklılaşan bir versiyonu"],
                    ["Lokus", "Bir genin kromozom üzerindeki yeri"],
                    ["Genotip", "Bir bireyin sahip olduğu aleller"],
                    ["Fenotip", "Bunlardan kaynaklanan gözlenebilir özellikler"],
                ]),
                .paragraph("Bu beş kavram konunun geri kalanında sürekli geçer ve her biri farklı bir düzeyi gösterir: molekül, onun varyantı, yeri, bireyin sahip olduğu ve bireyde görülen. Fenotip genotipe, ama aynı zamanda çevreye de bağlıdır: iki tek yumurta ikizinin genotipi aynıdır, boyları ise aynı olmayabilir."),
            ]),
            DemoChapter(title: "DNA eşlenmesi", blocks: [
                .paragraph("Her bölünmeden önce bir hücre, 3,2 milyar baz çiftini — iki takımı olduğu için iki kez — kopyalamalıdır ki yavru hücrelerinin her birine eksiksiz bir kopya verebilsin. Bu kopyalamaya **eşlenme** (replikasyon) denir ve ==neredeyse kusursuz== bir doğrulukla gerçekleşir."),
                .heading("Yarı korunumlu bir mekanizma"),
                .paragraph("İlke doğrudan tamamlayıcılıktan çıkar. Çift sarmalın iki zinciri, açılan bir fermuar gibi birbirinden ayrılır; ardından her zincir, her bazın karşısına tamamlayıcı bazı yerleştirerek yeni bir zincir yapmak için **kalıp** görevi görür. Başlangıçtaki molekülle aynı iki molekül elde edilir."),
                .figure(.flow(title: "Eşlenmenin aşamaları", steps: ["Helikaz çift sarmalı açar", "Her zincir kalıp görevi görür", "DNA polimeraz tamamlayıcı nükleotitleri ekler", "Her birinde bir eski ve bir yeni zincir bulunan iki özdeş molekül"])),
                .paragraph("Dolayısıyla her yavru molekül, ana molekülden kalıtılmış bir zincir ile yeni sentezlenmiş bir zincir içerir: eşlenmenin **yarı korunumlu** olduğu söylenir. DNA polimeraz yalnızca tek yönde çalışır, yeni zinciri 5′ ucundan 3′ ucuna doğru uzatır ve eşlenme her kromozom boyunca aynı anda birçok noktada başlar."),
                .callout(
                    title: "Meselson ve Stahl deneyi (1958)",
                    text: "Ağır azot (¹⁵N) içeren ortamda üretilen bakteriler hafif azot (¹⁴N) içeren ortama aktarılır. Bir bölünmeden sonra bütün DNA'ları **orta** yoğunluktadır; iki bölünmeden sonra yarısı orta, yarısı hafiftir. Bu sonucu tam olarak yalnızca yarı korunumlu model öngörür.",
                    tone: .example
                ),
                .paragraph("Bu deney bilimsel yöntemin bir örneğidir: üç hipotez mümkündü — korunumlu, yarı korunumlu, dağınık —, her biri farklı bir sonuç öngörüyordu ve karar vermek için tek bir ölçüm yetti. Sonuç kadar akıl yürütmeyi de aklınızda tutun: sınavda sizden uygulamanız istenecek olan budur."),
                .keyFigure(value: "1 / 10⁹", label: "düzeltme sistemlerinden geçtikten sonra, kopyalanan nükleotit başına hata oranının büyüklük mertebesi"),
                .paragraph("Milyarda bir hata, kopyalanan her bin kitapta aşağı yukarı bir yazım hatası demektir. Bu olağanüstü oran iki aşamada elde edilir: DNA polimeraz az önce yazdığını yeniden okur ve kendi hatalarını düzeltir, ardından başka enzimler onun ardından gelerek bu okumadan kaçanları onarır. Ama altı milyar bazda milyarda bir hata, yine de ==her bölünmede birkaç hata== demektir."),
                .callout(
                    title: "Karıştırmayın",
                    text: "Eşlenme, bir bölünmeden önce çekirdekte **DNA'yı DNA'ya** kopyalar. Bir sonraki bölümde göreceğimiz transkripsiyon ise hücrenin yaşamının herhangi bir anında **bir geni RNA'ya** kopyalar. Aynı tamamlayıcılık ilkesi, iki farklı işlev.",
                    tone: .warning
                ),
                .list([
                    "Eşlenme: her bölünmeden önce, hücre döngüsünün S evresinde",
                    "Yarı korunumlu: her yavru molekül ana molekülün bir zincirini korur",
                    "Anahtar enzim: nükleotitleri birleştiren ve kontrol eden DNA polimeraz",
                    "Doğruluk: yaklaşık milyar nükleotitte bir hata",
                ]),
                .paragraph("Bu kalan hatalar yalnızca bir kusur değildir. Kuşaklar boyunca birikerek yeni aleller, dolayısıyla evrimin üzerinde işlediği çeşitliliği üreten onlardır. Kusursuz bir kopyalama sistemi donmuş türler ortaya çıkarırdı: evrimi mümkün kılan, ==eşlenmenin kusurluluğudur==."),
            ]),
            DemoChapter(title: "Genden proteine", blocks: [
                .paragraph("DNA çekirdekte kalır, ama proteinler sitoplazmada üretilir. Bu yüzden bilgiyi kopyalayıp taşıyan bir aracıya ihtiyaç vardır: bu, **mesajcı RNA**'dır. Bir genin ifadesi iki aşamada gerçekleşir: ==menthe|transkripsiyon== ve ardından ==bleu|translasyon==."),
                .figure(.flow(title: "Bir genin ifadesi", steps: ["DNA (çekirdekteki gen)", "Transkripsiyon: mesajcı RNA", "mRNA çekirdekten çıkar", "Ribozomlarda translasyon", "Protein"])),
                .paragraph("**Transkripsiyon** çekirdekte gerçekleşir. RNA polimeraz çift sarmalı bir genin bulunduğu bölgede açar ve iki zincirden yalnızca birinin, kalıp zincirin, tamamlayıcılık yoluyla bir kopyasını üretir. Elde edilen molekül bir RNA'dır: DNA'ya benzer, ama üç farkı vardır."),
                .figure(.split(
                    title: "DNA ve RNA",
                    left: DemoColumn(title: "DNA", items: ["İki zincir", "Şeker: deoksiriboz", "A, T, G, C bazları", "Çok uzun, çekirdekte", "Kararlı, korunur"]),
                    right: DemoColumn(title: "Mesajcı RNA", items: ["Tek zincir", "Şeker: riboz", "A, U, G, C bazları", "Kısa: tek bir gen", "Geçici, kullanıldıktan sonra yıkılır"])
                )),
                .paragraph("Alıştırmalarda en işe yarayan fark bazlardaki farktır: RNA'da **urasil (U) timinin yerini alır**. Böylece RNA polimeraz kalıp zincirdeki bir A'nın karşısına bir U yerleştirir. mRNA dizisi bu nedenle DNA'nın kalıp olmayan zincirinin, yani kodlayan zincirin dizisiyle aynıdır; tek fark oradaki T'lerin U'ya dönüşmesidir."),
                .heading("Genetik şifre"),
                .paragraph("**Translasyon** sitoplazmada, ribozomlar üzerinde gerçekleşir. mRNA burada üçer nükleotitlik gruplar, yani **kodonlar** hâlinde okunur; her kodon bir amino aside karşılık gelir ve amino asitler art arda bağlanarak proteini oluşturur. Kodonlarla amino asitler arasındaki bu karşılık, **genetik şifredir**."),
                .formula("4^3 = 64 \\text{ kodon} \\;\\; \\text{için} \\;\\; 20 \\text{ amino asit}", caption: "Dört baz, üç konum: yirmi amino asit için fazlasıyla yeterli"),
                .paragraph("Demek ki amino asitten daha fazla kodon vardır: 61 kodon bir amino asidi belirtir, 3'ü ise translasyonu bitiren **stop** kodonlarıdır. Birden fazla kodon aynı amino asidi kodlayabilir — şifrenin **dejenere** (fazlalıklı) olduğu söylenir —, ama bir kodon hiçbir zaman birden fazla amino asidi kodlamaz. Translasyon her zaman metiyonini kodlayan AUG kodonuyla başlar."),
                .table(title: "mRNA'nın bazı kodonları", headers: ["Kodon", "Amino asit"], rows: [
                    ["AUG", "Metiyonin (başlangıç kodonu)"],
                    ["GCA", "Alanin"],
                    ["UGG", "Triptofan"],
                    ["GAG", "Glutamik asit"],
                    ["GUG", "Valin"],
                    ["UAA, UAG, UGA", "Stop"],
                ]),
                .paragraph("Tablo fazlalığı şimdiden gösterir: GAG ve GAA'nın ikisi de glutamik asidi kodlar ve son bölümde göreceğimiz gibi tek bir harf değişikliği — GAG'ın GUG olması — bu amino asidin yerine valin gelmesine yeter. Bir mesajcı RNA'yı çevirmek için her zaman aynı sırayı izleriz: AUG kodonunu bul, üçlülere ayır, ardından ilk stop kodonuna kadar tabloyu oku."),
                .callout(
                    title: "Tam örnek",
                    text: "DNA'nın kodlayan zinciri: 5′-ATG GCA TGG-3′. Mesajcı RNA: 5′-AUG GCA UGG-3′ (T yerine U yazılır). Protein: **Met – Ala – Trp**. Her zaman başlangıç kodonundan itibaren, kodon kodon ve örtüşme olmadan okunur.",
                    tone: .example
                ),
                .paragraph("Genetik şifre ==evrenseldir==: nadir istisnalar dışında aynı kodon bir bakteride, bir meşe ağacında ve bir insanda aynı amino asidi belirtir. Bu, bütün canlıların ortak bir kökenden geldiğini gösteren güçlü bir kanıttır — ve bakterilere yalnızca geni vererek insan insülini ürettirmeyi mümkün kılan da budur."),
            ]),
            DemoChapter(title: "Mutasyonlar ve kalıtım", blocks: [
                .paragraph("**Mutasyon**, DNA dizisindeki bir değişikliktir. Kendiliğinden — düzeltilmemiş bir eşlenme hatası — olabileceği gibi bir **mutajen etken** tarafından da tetiklenebilir: UV ışınları, X ışınları, tütün dumanındakiler gibi bazı kimyasal maddeler. Bütün mutasyonlar eşdeğer değildir ve etkileri ==nereye denk geldiklerine== bağlıdır."),
                .heading("Mutasyon türleri"),
                .table(title: "Nokta mutasyonları ve sonuçları", headers: ["Tür", "Ne değişir", "Protein üzerindeki etki"], rows: [
                    ["Sessiz yer değiştirme", "Bir baz, ama aynı amino asit", "Yok, şifrenin fazlalığı sayesinde"],
                    ["Yanlış anlamlı yer değiştirme", "Bir baz, farklı bir amino asit", "Değişken: etkisizden ağıra"],
                    ["Anlamsız yer değiştirme", "Bir kodon stop kodonuna dönüşür", "Kısalmış, çoğu zaman işlevsiz protein"],
                    ["Ekleme veya eksilme", "Bir baz fazla veya eksik", "Okuma çerçevesi kayması: çok değişmiş protein"],
                ]),
                .paragraph("Orak hücre anemisi en çok incelenen örnektir. Hemoglobin geninde altıncı kodon GAG'dan GTG'ye dönüşür: tek bir baz değişir ve glutamik asidin yerini bir valin alır. Bu anormal hemoglobin oksijen yetersizliğinde polimerleşir ve alyuvarları orak biçiminde bozar."),
                .callout(
                    title: "Bir mutasyon, iki etki",
                    text: "İki mutant alel taşıyan kişiler hastadır; yalnızca birini taşıyanlar ise sağlıklıdır ve üstelik **sıtmaya karşı daha iyi korunur**. Alelin Sahra altı Afrika'da yaygın olmasının nedeni budur: sıtmanın yaygın olduğu yerlerde taşıyıcılarına avantaj sağlar.",
                    tone: .insight
                ),
                .paragraph("Yalnızca üreme hücrelerini etkileyen mutasyonlar — **eşey hücresi (germ hattı) mutasyonları** — yavrulara aktarılır. Bir deri hücresindeki **somatik** mutasyon yalnızca bireyi ve mutasyona uğrayan hücreden türeyen hücreleri ilgilendirir: kansere yol açabilir, ama kalıtsal bir hastalığa yol açmaz."),
                .heading("Mendel yasaları"),
                .paragraph("1865'te keşiş Gregor Mendel, bezelyeler üzerinde sekiz yıl süren çaprazlamalarının sonuçlarını yayımlar. Saf döl yuvarlak tohumlu bezelyeleri saf döl buruşuk tohumlu bezelyelerle çaprazlar: birinci kuşağın (F1) tamamı yuvarlak tohumludur. Ardından bu melezleri kendi aralarında çaprazlar: ikinci kuşakta (F2) buruşuk özellik, dikkat çekici derecede sabit bir oranda yeniden ortaya çıkar."),
                .bars(title: "Mendel'in ikinci kuşaktaki tohumları", unit: "tohum", bars: [
                    DemoBar(label: "Yuvarlak", value: 5474),
                    DemoBar(label: "Buruşuk", value: 1850),
                ]),
                .paragraph("Oran $5474 / 1850 \\approx 2{,}96$, yani neredeyse tam olarak **üçe bir**dir. Mendel bunu dönemine göre cesur bir hipotezle açıklar: her birey bir özellik için iki “faktör” — bizim deyişimizle iki ==alel== — taşır, her gamete bunlardan yalnızca birini aktarır ve yuvarlak alel (R), **çekinik** olan buruşuk alele (r) **baskındır**."),
                .table(title: "Çaprazlama tablosu: Rr × Rr", headers: ["", "R gameti", "r gameti"], rows: [
                    ["R gameti", "RR (yuvarlak)", "Rr (yuvarlak)"],
                    ["r gameti", "Rr (yuvarlak)", "rr (buruşuk)"],
                ]),
                .paragraph("Her kutunun olasılığı dörtte birdir. RR, Rr ve rr genotipleri 1/4, 1/2 ve 1/4 oranlarında, dolayısıyla yuvarlak ve buruşuk fenotipleri 3/4 ve 1/4 oranlarında elde edilir. Çekinik özelliği yalnızca **homozigot** rr bireyler gösterir; **heterozigot** Rr bireyler onu taşır ama göstermez."),
                .formula("P(rr) = \\frac{1}{2} \\times \\frac{1}{2} = \\frac{1}{4}", caption: "Heterozigot ebeveynlerin her biri, diğerinden bağımsız olarak r'yi 1/2 olasılıkla aktarır"),
                .paragraph("Aynı akıl yürütme, **kistik fibrozis** gibi çekinik insan hastalıkları için de geçerlidir: heterozigot, sağlıklı taşıyıcı iki ebeveynin her gebelikte hasta bir çocuk sahibi olma olasılığı 1/4'tür. “Her gebelikte” ifadesi çok önemlidir: ==şansın hafızası yoktur== ve hasta bir çocuk sahibi olmuş olmak sonrakini korumaz."),
                .timeline(title: "Genetiğin büyük aşamaları", events: [
                    DemoEvent(date: "1865", label: "Mendel kalıtım yasalarını yayımlar"),
                    DemoEvent(date: "1944", label: "Avery kalıtsal bilgiyi DNA'nın taşıdığını gösterir"),
                    DemoEvent(date: "1953", label: "Watson, Crick ve Franklin: çift sarmal"),
                    DemoEvent(date: "1966", label: "Genetik şifre tamamen çözülür"),
                    DemoEvent(date: "2003", label: "İnsan genomunun tam dizisi"),
                    DemoEvent(date: "2012", label: "Charpentier ve Doudna: CRISPR-Cas9 aracı"),
                ]),
                .paragraph("Mendel'in bezelyeleri ile bugün belirli bir geni değiştirmeyi sağlayan moleküler makaslar arasında yüz elli yıl vardır. Her aşama bir öncekinin açık bıraktığı bir soruyu yanıtlamıştır: ne aktarılıyor, neden yapılmış, nasıl kopyalanıyor, nasıl okunuyor — ve şimdi, ==nasıl düzeltilir==."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "DNA'nın bazları iki zincir arasında nasıl eşleşir?",
                back: "Adenin timinle (A–T, iki hidrojen bağı), guanin sitozinle (G–C, üç hidrojen bağı). Dolayısıyla bir zincir diğerini tamamen belirler.",
                figure: .split(
                    title: "Tamamlayıcılık",
                    left: DemoColumn(title: "Zincir 1", items: ["A", "G", "T", "C"]),
                    right: DemoColumn(title: "Zincir 2", items: ["T", "C", "A", "G"])
                ),
                chapter: 0
            ),
            DemoCard(
                kind: .choice,
                front: "5′-ATG GCA TGG-3′ kodlayan zincirinden transkripsiyonla oluşan mesajcı RNA hangisidir?",
                back: "5′-AUG GCA UGG-3′: mRNA, T yerine U olmak üzere kodlayan zincirin dizisine sahiptir. Met – Ala – Trp olarak çevrilir.",
                choices: ["5′-UAC CGU ACC-3′", "5′-AUG GCA UGG-3′", "5′-TAC CGT ACC-3′", "5′-ATG GCA TGG-3′"],
                answerIndex: 1,
                chapter: 2
            ),
            DemoCard(
                kind: .cloze,
                front: "Her yavru molekül ana molekülün bir zincirini koruduğu için DNA eşlenmesine … eşlenme denir.",
                back: "yarı korunumlu",
                chapter: 1
            ),
            DemoCard(kind: .basic, front: "Gen ile alel arasındaki fark nedir?", back: "Gen, belirli bir lokusta bulunan ve bir proteini kodlayan DNA parçasıdır. Alel ise bu genin, dizisiyle diğerlerinden farklılaşan versiyonlarından biridir.", chapter: 0),
            DemoCard(kind: .choice, front: "Kaç farklı kodon vardır?", back: "64 = 4³: üç konumun her birinde dört olası baz. 61'i bir amino asidi kodlar, 3'ü stop kodonudur.", choices: ["20", "46", "61", "64"], answerIndex: 3, chapter: 2),
            DemoCard(kind: .cloze, front: "RNA'da timinin yerini … alır.", back: "urasil", chapter: 2),
            DemoCard(kind: .basic, front: "Meselson ve Stahl deneyi neyi gösterir?", back: "Eşlenmenin yarı korunumlu olduğunu: ¹⁴N ortamında bir bölünmeden sonra bütün DNA orta yoğunluktadır; iki bölünmeden sonra yarısı orta, yarısı hafiftir.", hint: "Bir ve iki bölünme sonrasındaki yoğunlukları düşünün.", chapter: 1),
            DemoCard(kind: .choice, front: "Hangi mutasyon okuma çerçevesini kaydırır?", back: "Bir bazın eklenmesi veya eksilmesi: sonrasındaki bütün kodonlar değişir ve protein çok bozulur.", choices: ["Sessiz bir yer değiştirme", "Yanlış anlamlı bir yer değiştirme", "Bir bazın eksilmesi", "Anlamsız bir yer değiştirme"], answerIndex: 2, chapter: 3),
            DemoCard(kind: .cloze, front: "Heterozigot Rr iki ebeveyn, her doğumda … olasılıkla rr bir çocuk sahibi olur.", back: "1/4", chapter: 3),
            DemoCard(kind: .basic, front: "Orak hücre anemisi aleli sıtmanın yaygın olduğu yerlerde neden sık görülür?", back: "Çünkü tek bir mutant alel taşıyan heterozigotlar sağlıklıdır ve sıtmaya karşı daha iyi korunur: doğal seçilim aleli korur.", chapter: 3),
            DemoCard(kind: .cloze, front: "Chargaff kurallarına göre çift zincirli bir DNA'da guanin yüzdesi … yüzdesine eşittir.", back: "sitozin", chapter: 0),
            DemoCard(kind: .choice, front: "Translasyon nerede gerçekleşir?", back: "Sitoplazmada, mesajcı RNA'yı kodon kodon okuyan ribozomlar üzerinde.", choices: ["Çekirdekte", "Sitoplazmadaki ribozomlarda", "Mitokondrilerde", "Hücre zarında"], answerIndex: 1, chapter: 2),
        ]
    )

    // MARK: Mathématiques : les probabilités

    private static let probabilityTR = OnboardingDemoCourse(
        id: "debug-probability",
        emoji: "🎲",
        subject: "Mathématiques",
        title: "Olasılık",
        summary: "Olaylarla ilgili temel kavramlar, koşullu olasılık ve olasılık ağaçları, bağımsızlık, ardından rastgele değişkenler, beklenen değer ve binom dağılımı.",
        accentIndex: 0,
        chapters: [
            DemoChapter(title: "Olasılığın dili", blocks: [
                .paragraph("Olasılık, sonucu önceden bilinmeyen bir olayın ==kesinlik derecesini== ölçer: bir zar atışı, bir çekiliş, bir testin sonucu. Ne olacağını öngörmez; her sonucun ne kadar olası olduğunu kesin bir biçimde söyler."),
                .heading("Deney, örnek uzay, olay"),
                .paragraph("**Rastgele deney**, bütün olası sonuçları bilinen ama hangisinin gerçekleşeceği önceden kestirilemeyen bir deneydir. Her sonuç bir **çıktıdır**; çıktıların kümesi $\\Omega$ ile gösterilen **örnek uzaydır**. Altı yüzlü bir zar için $\\Omega$ = {1, 2, 3, 4, 5, 6}."),
                .callout(
                    title: "Olay",
                    text: "**Olay**, örnek uzayın bir alt kümesi, yani çıktılardan oluşan bir kümedir. “Çift sayı gelmesi” $A$ = {2, 4, 6} olayıdır. Elde edilen çıktı bu kümeye aitse olay gerçekleşmiş olur.",
                    tone: .definition
                ),
                .paragraph("Olaylar kümeler gibi birleştirilir. **Kesişim** $A \\cap B$ (“A ve B”) ikisi birden gerçekleştiğinde; **birleşim** $A \\cup B$ (“A veya B”) en az biri gerçekleştiğinde; **tümleyen** $Ā$ ise $A$ gerçekleşmediğinde gerçekleşir. Birlikte gerçekleşemeyen iki olaya **ayrık olaylar** denir: $A \\cap B = \\emptyset$."),
                .heading("Olasılık hesaplamak"),
                .paragraph("Bütün çıktıların gerçekleşme şansı aynı olduğunda — buna **eşolasılık** denir —, bir olayın olasılığı istenen çıktı sayısının tüm çıktı sayısına bölümüdür. Bu Laplace formülüdür ve ==yalnızca bu durumda== geçerlidir: hileli bir zar ya da eşit bölünmemiş bir çark başka bir yöntem gerektirir."),
                .formula("P(A) = \\frac{\\text{istenen çıktı sayısı}}{\\text{tüm çıktı sayısı}}", caption: "Yalnızca eşolasılık durumunda"),
                .paragraph("İki zar atıp toplamlarına bakalım. $6 \\times 6 = 36$ eşolasılıklı ikili vardır, ama toplamlar eşolasılıklı değildir: 2 elde etmenin tek bir yolu vardır (1 ve 1), 7 elde etmenin altı yolu. Grafik her toplam için onu veren ikililerin sayısını gösterir."),
                .bars(title: "İki zarın toplamı: 36 ikili içinden sayı", unit: nil, bars: [
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
                .paragraph("Buradan $P(\\text{toplam} = 7) = 6/36 = 1/6$ ve $P(\\text{toplam} = 2) = 1/36$ okunur. Klasik hata, on bir olası toplamı eşolasılıklıymış gibi düşünüp her birine 1/11 vermektir. ==Her zaman eşolasılıklı çıktılar üzerinden saymak gerekir==: burada ikililer; asla eşolasılıklı olmayan sonuçlar üzerinden değil."),
                .table(title: "Bilinmesi gereken özellikler", headers: ["Özellik", "Formül"], rows: [
                    ["Sınırlar", "0 ≤ P(A) ≤ 1"],
                    ["Örnek uzay", "P(Ω) = 1"],
                    ["Tümleyen", "P(Ā) = 1 − P(A)"],
                    ["Birleşim", "P(A ∪ B) = P(A) + P(B) − P(A ∩ B)"],
                    ["Ayrık olaylar", "P(A ∪ B) = P(A) + P(B)"],
                ]),
                .paragraph("Birleşim formülü $P(A \\cap B)$'yi çıkarır, çünkü ortak çıktılar iki kez sayılmıştır. Tümleyene geçmek ise çoğu zaman en etkili kısayoldur: “dört atışta en az bir altı” için “hiç altı gelmemesi” olasılığını, yani $(5/6)^4 \\approx 0{,}48$'i hesaplayıp tümleyenini almak çok daha kolaydır: $1 - 0{,}48 \\approx 0{,}52$."),
                .callout(
                    title: "“En az bir” refleksi",
                    text: "Bir soru “en az bir” dediği anda tümleyeni düşünün: “hiç”. Uzun bir durumlar toplamı yerine neredeyse her zaman tek bir çarpım hesaplamak yeter.",
                    tone: .insight
                ),
            ]),
            DemoChapter(title: "Koşullu olasılık ve ağaçlar", blocks: [
                .paragraph("Yeni bir bilgi olasılıkları değiştirir. Bir testin pozitif çıktığını bilmek hasta olma olasılığını değiştirir; zarın çift sayı geldiğini bilmek 2 gelmiş olma olasılığını değiştirir. **Koşullu olasılık**, bir olayın olasılığını ==başka bir olayın gerçekleştiği bilindiğinde== ölçer."),
                .callout(
                    title: "Koşullu olasılık",
                    text: "$P(A) \\neq 0$ ise, $A$ bilindiğinde $B$'nin olasılığı $P(B | A) = \\frac{P(A \\cap B)}{P(A)}$'dır; ders kitaplarında P_A(B) olarak da yazılır. Örnek uzay yalnızca $A$'nın çıktılarına daraltılır ve bunların ne kadarının $B$'yi de gerçekleştirdiğine bakılır.",
                    tone: .definition
                ),
                .paragraph("Örnek: bir zar atılıyor ve sonucun çift olduğu öğreniliyor. 2 gelmiş olma olasılığı artık 1/6 değil, $\\frac{1/6}{1/2} = \\frac{1}{3}$'tür: geriye yalnızca üç olası çıktı kalır, 2, 4 ve 6. Formül ters çevrilebilir de ve ağaçlarda kullanılan biçim budur: $P(A \\cap B) = P(A) \\times P(B | A)$."),
                .heading("Olasılık ağacı"),
                .paragraph("**Olasılık ağacı**, birkaç aşamalı bir deneyi gösterir. Her dalın üzerinde bir olasılık yazar; aynı düğümden çıkan dalların toplamı 1'dir; bir yolun olasılığı, dallarının olasılıklarının çarpımıdır. Bir olay birkaç yolun sonunda yer alıyorsa, olasılıklar toplanır."),
                .figure(.flow(title: "Olasılık ağacını okumak", steps: ["Birinci aşama: A veya Ā", "İkinci aşama: birinciye bağlı olarak B veya B̄", "Bir yol: dallar çarpılır", "B'ye giden birkaç yol: toplanır"])),
                .paragraph("Son adımın bir adı vardır: **tam olasılık formülü**. $A$ ve $Ā$ örnek uzayı ikiye ayırıyorsa, $B$ ya $A$ ile ya da $Ā$ ile gerçekleşir ve bu iki durum ayrıktır. Bu yüzden $B$'ye giden iki yol toplanır."),
                .formula("P(B) = P(A) \\times P(B | A) + P(Ā) \\times P(B | Ā)", caption: "A ve Ā şeklindeki bir parçalanış için tam olasılık formülü"),
                .heading("Bir tarama testi"),
                .paragraph("Bir hastalık nüfusun %1'ini etkiliyor. Bir test hastaların %99'unda hastalığı saptıyor, ama sağlıklı kişilerin %2'sinde de pozitif çıkıyor. Bir kişinin testi pozitif çıkıyor: hasta olma olasılığı nedir? Sezgi “%99” der. Hesap bambaşka bir şey söyler. Test edilen 10 000 kişi düşünelim."),
                .table(title: "Test edilen 10 000 kişi", headers: ["", "Pozitif test", "Negatif test", "Toplam"], rows: [
                    ["Hasta", "99", "1", "100"],
                    ["Sağlıklı", "198", "9 702", "9 900"],
                    ["Toplam", "297", "9 703", "10 000"],
                ]),
                .paragraph("297 pozitiften yalnızca 99'u hastadır. Ağaç ve formüllerle: $P(+) = 0{,}01 \\times 0{,}99 + 0{,}99 \\times 0{,}02 = 0{,}0297$, ardından $P(M | +) = \\frac{0{,}0099}{0{,}0297} = \\frac{1}{3}$. Yüz kat daha kalabalık olan sağlıklı nüfustan gelen yanlış pozitifler, ==gerçek pozitifleri boğar==."),
                .keyFigure(value: "%33", label: "hastalarda %99 güvenilir bir teste rağmen, test pozitif çıktığında hasta olma olasılığı"),
                .paragraph("Sonuç, testin kalitesinden çok hastalığın ne kadar nadir olduğuna bağlıdır. Hastalık nüfusun %10'unu etkileseydi aynı test $P(M | +) = \\frac{0{,}099}{0{,}099 + 0{,}018} \\approx 0{,}85$ verirdi. Koşullu olasılık her zaman ==başlangıç olasılığıyla birlikte== hesaplanır: yaygınlığı unutmak, ağacın ilk dalını unutmaktır."),
                .callout(
                    title: "Ters çevirmeyin",
                    text: "$P(+ | M)$ ile $P(M | +)$ aynı şey değildir: birincisi 0,99, ikincisi yaklaşık 0,33'tür. “Hasta olunduğu bilindiğinde testin pozitif çıkma olasılığı” ile “test pozitif çıktığında hasta olma olasılığı”nı karıştırmak, doktorlar dahil en yaygın hatadır.",
                    tone: .warning
                ),
                .paragraph("Toplu taramalarda pozitif çıkan bir testin her zaman daha kesin ikinci bir tetkikle doğrulanmasının nedeni budur. Ağaçtan yola çıkarak “ters çevrilmiş” bir olasılığı hesaplamaya, onu XVIII. yüzyılda ortaya koyan İngiliz papazın adıyla **Bayes formülü** denir."),
            ]),
            DemoChapter(title: "Bağımsızlık", blocks: [
                .paragraph("Birinin gerçekleştiğini bilmek diğerinin olasılığını ==hiç değiştirmiyorsa== iki olay bağımsızdır. Bir madeni paranın sonucu bir önceki atışın sonucuna bağlı değildir; göz rengi doğum gününe bağlı değildir."),
                .formula("A \\text{ ve } B \\text{ bağımsız} \\Leftrightarrow P(A \\cap B) = P(A) \\times P(B)", caption: "Tanım; P(A) ≠ 0 olduğunda P(B | A) = P(B) ile denktir"),
                .paragraph("Bağımsızlık sezgiyle değil, her zaman hesapla doğrulanır. Bir zar atalım: $A$ = “çift” = {2, 4, 6} ve $B$ = “en çok 2” = {1, 2} olsun. $P(A) = 1/2$, $P(B) = 1/3$ ve $A \\cap B$ = {2}, dolayısıyla $P(A \\cap B) = 1/6$. $\\frac{1}{2} \\times \\frac{1}{3} = \\frac{1}{6}$ olduğundan iki olay bağımsızdır — bu, çıplak gözle görülmüyordu."),
                .figure(.split(
                    title: "Karıştırılmaması gereken iki kavram",
                    left: DemoColumn(title: "Ayrık", items: ["Birlikte gerçekleşemez", "A ∩ B = ∅", "P(A ∩ B) = 0", "Küme kavramı"]),
                    right: DemoColumn(title: "Bağımsız", items: ["Biri diğeri hakkında bilgi vermez", "P(A ∩ B) = P(A) × P(B)", "Hesapla doğrulanır", "Olasılık kavramı"])
                )),
                .paragraph("İki kavram neredeyse birbirinin zıddıdır: $A$ ve $B$ ayrıksa ve olasılıkları sıfırdan farklıysa, $A$'nın gerçekleştiğini bilmek $B$'nin gerçekleşmediğini kesin olarak söyler. Yani ==birbirine çok bağımlıdırlar==. Aynı atışta “yazı” ve “tura” ayrıktır; birinci atışta “yazı” ile ikinci atışta “tura” bağımsızdır."),
                .heading("Bir deneyi tekrarlamak"),
                .paragraph("Bir deney aynı koşullarda tekrarlandığında — bir parayı birkaç kez atmak, iadeli çekiliş yapmak —, art arda gelen sonuçlar bağımsızdır ve bir sonuç dizisinin olasılığı her birinin olasılıklarının çarpımıdır. Hilesiz bir parayla üç kez “yazı” gelmesi: $\\left(\\frac{1}{2}\\right)^3 = \\frac{1}{8}$."),
                .callout(
                    title: "Kumarbaz yanılgısı",
                    text: "Rulette art arda on “kırmızı”dan sonra “siyah”ın gelmesi “gerekmez”: çekilişler bağımsızdır, çarkın hafızası yoktur ve bir sonraki turda siyahın olasılığı ilk turdakiyle tam olarak aynıdır.",
                    tone: .warning
                ),
                .paragraph("Yine de uzun vadede sıklık sezgisini haklı çıkaran budur. 1713'te Jacob Bernoulli tarafından kanıtlanan **büyük sayılar yasası**, çok sayıda bağımsız tekrarda bir olayın sıklığının olasılığına yaklaştığını söyler. Sapmalar “telafi edildiği” için değil, toplam deneme sayısının yanında önemsizleştiği için."),
                .timeline(title: "Olasılığın kısa tarihi", events: [
                    DemoEvent(date: "1654", label: "Pascal ve Fermat pay problemini çözer"),
                    DemoEvent(date: "1713", label: "Jacob Bernoulli: büyük sayılar yasası"),
                    DemoEvent(date: "1763", label: "Bayes formülünün ölümünden sonra yayımlanması"),
                    DemoEvent(date: "1812", label: "Laplace, Olasılıkların Analitik Kuramı"),
                    DemoEvent(date: "1933", label: "Kolmogorov olasılığı aksiyomlar üzerine kurar"),
                ]),
                .paragraph("Bu disiplin kumarbazların bir sorusundan doğmuştur: yarıda kesilen bir oyunun bahisleri adil biçimde nasıl paylaşılır? Üç yüzyıl sonra bir ilacı değerlendirmeye, bir sigorta primini belirlemeye, bir sinyali hatasız iletmeye yarar. Yöntem ise değişmemiştir: ==saymak, koşullandırmak, çarpmak, toplamak==."),
            ]),
            DemoChapter(title: "Rastgele değişkenler ve binom dağılımı", blocks: [
                .paragraph("Çoğu zaman ilgilendiğimiz şey çıktının kendisi değil, ona bağlı bir sayıdır: bir oyundaki kazanç, doğru cevap sayısı, kusurlu parça sayısı. **Rastgele değişken** her çıktıya bir gerçek sayı karşılık getirir ve **olasılık dağılımı** değerlerinin her birinin olasılığını verir."),
                .heading("Beklenen değer"),
                .paragraph("Bir oyun: 2 € yatırılır, bir zar atılır ve 6 gelirse 10 € kazanılır. $X$ net kazanç olsun. 6 gelirse $X = 10 - 2 = 8$; gelmezse $X = -2$. $X$'in dağılımı iki sütunluk bir tabloya sığar."),
                .table(title: "Net kazanç X'in dağılımı", headers: ["X'in değeri", "−2 €", "8 €"], rows: [
                    ["Olasılık", "5/6", "1/6"],
                ]),
                .paragraph("**Beklenen değer**, değerlerin olasılıklarıyla ağırlıklandırılmış ortalamasıdır: çok sayıda oynansaydı oyun başına ortalama kazanç budur. Burada $E(X) = -2 \\times \\frac{5}{6} + 8 \\times \\frac{1}{6} = \\frac{-10 + 8}{6} = -\\frac{1}{3}$. Oyuncu oyun başına ortalama yaklaşık 33 sent kaybeder: oyun ==oyuncunun aleyhinedir==."),
                .formula("E(X) = \\sum_{i} x_i \\, P(X = x_i) \\;\\;\\;\\; V(X) = \\sum_{i} P(X = x_i)\\,(x_i - E(X))^2", caption: "Beklenen değer merkezi, varyans ise onun etrafındaki yayılımı ölçer"),
                .paragraph("**Varyans**, değerlerin beklenen değerden ne kadar uzaklaştığını ölçer; **standart sapma** $\\sigma(X) = \\sqrt{V(X)}$ ise bu ölçüyü $X$'in birimine geri getirir. Beklenen değeri aynı olan iki oyun çok farklı olabilir: biri neredeyse her zaman aynı küçük tutarı kazandırır, diğeri çoğu zaman hiçbir şey, nadiren de çok şey."),
                .heading("Binom dağılımı"),
                .callout(
                    title: "Bernoulli şeması",
                    text: "İki sonuçlu bir deney — $p$ olasılıklı başarı ya da başarısızlık — $n$ kez **bağımsız** olarak tekrarlanır. Başarı sayısı $X$, $B(n, p)$ **binom dağılımına** uyar.",
                    tone: .definition
                ),
                .formula("P(X = k) = \\binom{n}{k}\\, p^k \\,(1-p)^{n-k}", caption: "Binom katsayısı, ağaçta k başarıya giden yolları sayar"),
                .paragraph("Formül ağaç üzerinde okunur: $k$ başarı ve $n - k$ başarısızlık içeren her yolun olasılığı $p^k (1-p)^{n-k}$'dir ve bu yolların sayısı “$n$'nin $k$'lı kombinasyonu” olan binom katsayısıdır. Örnek: tamamen rastgele doldurulmuş, 4 seçenekli 10 soruluk bir test. Doğru cevap sayısı $B(10\\,;\\,0{,}25)$'e uyar; dağılımı aşağıdadır."),
                .bars(title: "B(10 ; 0,25) dağılımı: k doğru cevap olasılığı", unit: "%", bars: [
                    DemoBar(label: "k = 0", value: 5.6),
                    DemoBar(label: "k = 1", value: 18.8),
                    DemoBar(label: "k = 2", value: 28.2),
                    DemoBar(label: "k = 3", value: 25.0),
                    DemoBar(label: "k = 4", value: 14.6),
                    DemoBar(label: "k = 5", value: 5.8),
                    DemoBar(label: "k = 6", value: 1.6),
                    DemoBar(label: "k = 7", value: 0.3),
                ]),
                .paragraph("Dağılım 2 ya da 3 doğru cevap civarında zirve yapar ve ötesinde çöker. Rastgele cevaplayarak ortalamayı, yani 10 üzerinden 5'i tutturmanın olasılığı yalnızca yaklaşık ==%7,8== kadardır; hiç doğru yapmamanın olasılığı ise $0{,}75^{10} \\approx 5{,}6\\,\\%$. Binom dağılımı için beklenen değer ve varyansın doğrudan formülleri vardır."),
                .formula("E(X) = np \\;\\;\\;\\; V(X) = np(1-p)", caption: "Burada: E(X) = 10 × 0,25 = 2,5 ve V(X) = 2,5 × 0,75 = 1,875"),
                .keyFigure(value: "2,5", label: "rastgele cevaplandığında, dört seçenekli 10 sorudan ortalama doğru cevap sayısı"),
                .paragraph("Standart sapma $\\sqrt{1{,}875} \\approx 1{,}37$'dir: rastgele cevaplayan adayların çoğu 1 ile 4 arasında doğru cevap alır. Grafiğin gösterdiği tam olarak budur ve bazı çoktan seçmeli sınavların her yanlış cevap için puan düşmesinin nedeni de budur — böylece rastgeleliğin beklenen değeri sıfıra indirilir."),
                .callout(
                    title: "Yöntem: binom dağılımını gerekçelendirmek",
                    text: "Her seferinde yazılacak üç nokta: 1. **iki sonuçlu** bir deney ($p$ olasılıklı başarı); 2. $n$ kez **özdeş ve bağımsız** biçimde tekrarlanıyor; 3. $X$ **başarı sayısını** sayıyor. Bu üç cümle olmadan cevap eksiktir.",
                    tone: .insight
                ),
                .paragraph("Unutulan genellikle ikinci noktadır: küçük bir torbadan **iadesiz** çekiliş bağımsız bir tekrar değildir ve binom dağılımı uygulanamaz. Formülü uygulamadan önce varsayımları doğrulamak, doğru bir hesapla yalnızca doğru görünen bir hesap arasındaki ==bütün farktır==."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Olasılık ağacında birkaç yolun sonunda yer alan bir olayın olasılığı nasıl hesaplanır?",
                back: "Her yol boyunca olasılıklar çarpılır, ardından olaya giden yolların sonuçları toplanır: bu, tam olasılık formülüdür.",
                figure: .flow(title: "Ağaç okumak", steps: ["Bir yol boyunca çarp", "Yolları topla"]),
                chapter: 1
            ),
            DemoCard(
                kind: .choice,
                front: "Hilesiz iki zar atılıyor. Toplamın 7 olma olasılığı nedir?",
                back: "1/6: 36 ikiliden altısı 7 verir — (1,6), (2,5), (3,4), (4,3), (5,2), (6,1).",
                choices: ["1/11", "1/12", "1/6", "7/36"],
                answerIndex: 2,
                chapter: 0
            ),
            DemoCard(
                kind: .cloze,
                front: "A ve B olaylarının bağımsız olması için gerek ve yeter koşul $P(A \\cap B) = $ … olmasıdır.",
                back: "$P(A) \\times P(B)$",
                chapter: 2
            ),
            DemoCard(kind: .basic, front: "A bilindiğinde B'nin olasılığının formülü nedir?", back: "$P(A) \\neq 0$ için $P(B | A) = \\frac{P(A \\cap B)}{P(A)}$.", chapter: 1),
            DemoCard(kind: .choice, front: "Bir hastalık nüfusun %1'ini etkiliyor; bir test hastaların %99'unda ve sağlıklı kişilerin %2'sinde pozitif çıkıyor. Test pozitifse hasta olma olasılığı nedir?", back: "Yaklaşık 1/3: $\\frac{0{,}01 \\times 0{,}99}{0{,}01 \\times 0{,}99 + 0{,}99 \\times 0{,}02} = \\frac{0{,}0099}{0{,}0297}$.", hint: "Test edilen 10 000 kişi düşünün.", choices: ["%99", "%98", "Yaklaşık %33", "%1"], answerIndex: 2, chapter: 1),
            DemoCard(kind: .cloze, front: "Tümleyen olayın olasılığı $P(Ā) = $ … olur.", back: "$1 - P(A)$", chapter: 0),
            DemoCard(kind: .basic, front: "Ayrık iki olay ile bağımsız iki olay arasındaki fark nedir?", back: "Ayrık: birlikte gerçekleşemezler ($A \\cap B = \\emptyset$). Bağımsız: birinin gerçekleşmesi diğerinin olasılığını değiştirmez ($P(A \\cap B) = P(A)P(B)$). Olasılıkları sıfırdan farklı iki ayrık olay asla bağımsız değildir.", chapter: 2),
            DemoCard(kind: .choice, front: "$B(n, p)$ binom dağılımına uyan bir rastgele değişkenin beklenen değeri nedir?", back: "$E(X) = np$. Varyansı $np(1-p)$'dir.", choices: ["$p$", "$np$", "$np(1-p)$", "$n/p$"], answerIndex: 1, chapter: 3),
            DemoCard(kind: .basic, front: "Bir değişkenin binom dağılımına uyduğunu söylemek için hangi koşullar doğrulanmalıdır?", back: "İki sonuçlu bir deney (p olasılıklı başarı), n kez özdeş ve bağımsız biçimde tekrarlanmalı ve X değişkeni başarı sayısını saymalıdır.", chapter: 3),
            DemoCard(kind: .cloze, front: "“En az bir” başarı olasılığını hesaplamak için tümleyen olaydan geçilir: “… başarı olmaması”.", back: "hiç", chapter: 0),
            DemoCard(kind: .choice, front: "2 € yatırılıyor ve zar 6 gelirse 10 € kazanılıyor. Net kazancın beklenen değeri nedir?", back: "$-2 \\times \\frac{5}{6} + 8 \\times \\frac{1}{6} = -\\frac{1}{3}$, yani oyun başına ortalama yaklaşık 0,33 € kayıp.", choices: ["$-\\frac{1}{3}$ €", "0 €", "$\\frac{1}{3}$ €", "$\\frac{5}{3}$ €"], answerIndex: 0, chapter: 3),
            DemoCard(kind: .cloze, front: "… yasası, tekrar sayısı çok büyüdüğünde bir olayın sıklığının olasılığına yaklaştığını söyler.", back: "Büyük sayılar", chapter: 2),
        ]
    )

    // MARK: Économie : l'offre et la demande

    private static let supplyDemandTR = OnboardingDemoCourse(
        id: "debug-supply-demand",
        emoji: "⚖️",
        subject: "Économie",
        title: "Arz ve talep",
        summary: "Bir piyasa fiyatı nasıl belirler: arz ve talep eğrileri, denge, dengeyi kaydıran etkenler, esneklik ve devlet müdahalesinin neleri değiştirdiği.",
        accentIndex: 5,
        chapters: [
            DemoChapter(title: "Piyasa ve talep", blocks: [
                .paragraph("Bir çilek neden martta hazirana göre üç kat daha pahalıdır? Bu fiyata kimse karar vermemiştir: fiyat, milyonlarca alım ve satım kararının buluşmasından doğar. Arz ve talep modeli, kimse belirlemeden ==bir piyasanın fiyatı nasıl belirlediğini== açıklar."),
                .heading("Piyasa nedir?"),
                .callout(
                    title: "Piyasa",
                    text: "Bir mal ya da hizmetin **arzının** (satıcıların sunduğu) ve **talebinin** (alıcıların edinmek istediği) buluştuğu ve **fiyatının** oluştuğu, fiziksel olan ya da olmayan yer.",
                    tone: .definition
                ),
                .paragraph("Bir piyasanın mutlaka bir yer olması gerekmez: emek piyasasının, döviz piyasasının ya da konut piyasasının bir çarşısı yoktur. Ekonomistler akıl yürütmek için ideal bir durumdan, hiçbir aktörün fiyatını dayatacak kadar ağırlığa sahip olmadığı **tam rekabet piyasasından** yola çıkar. Bu piyasa beş koşula dayanır."),
                .list([
                    "Çok sayıda alıcı ve satıcı: her biri fiyatı etkileyemeyecek kadar küçük",
                    "Homojenlik: bütün satıcılar aynı ürünü sunar",
                    "Şeffaflık: herkes fiyatları ve kaliteyi bilir",
                    "Serbest giriş: herkes piyasaya girebilir ya da piyasadan çıkabilir",
                    "Üretim faktörlerinin serbest dolaşımı: emek ve sermaye en çok kazandırdıkları yere gider",
                ]),
                .paragraph("Hiçbir gerçek piyasa bu beş koşulu tam olarak karşılamaz ve amaç da bu değildir: model bir ==karşılaştırma noktası== işlevi görür. Toptan tarım ürünleri piyasası modele yaklaşır; üç telefon operatörünün hâkim olduğu bir piyasa ise ondan uzaklaşır ve modelle karşılaştırarak ölçtüğümüz şey tam olarak budur."),
                .heading("Talep"),
                .paragraph("**Talep**, alıcıların olası her fiyatta edinmek istedikleri mal miktarıdır. Neredeyse evrensel bir yasaya uyar: fiyat yükseldiğinde talep edilen miktar düşer. Bunun iki nedeni vardır. **İkame etkisi**: mal rakiplerinden daha pahalı hâle gelir ve tüketiciler rakiplere yönelir. **Gelir etkisi**: aynı bütçeyle daha az satın alınabilir."),
                .formula("Q_d = 120 - 20\\,p", caption: "Doğrusal bir talep: fiyat p'ye (avro) bağlı olarak talep edilen miktar (bin adet)"),
                .paragraph("Bu fonksiyon ders boyunca örnek olarak kullanılacak: bir bölgedeki bir peynirin haftalık piyasasını, bin adet cinsinden düşünün. 1 €'da alıcılar 100 000 adet ister; 5 €'da ise yalnızca 20 000. Fiyattaki her bir avroluk artış 20 000 alıcıyı vazgeçirir. Fiyat dikey eksende gösterildiğinde bu, **azalan** bir doğrudur: talep eğrisi."),
                .callout(
                    title: "Kavram tuzağı",
                    text: "Bir malın fiyatı değiştiğinde talep eğrisi **boyunca hareket edilir**: değişen *talep edilen miktardır*. Başka bir şey — gelir, zevkler, başka bir malın fiyatı — değiştiğinde ise **eğrinin tamamı kayar**: değişen *taleptir*.",
                    tone: .warning
                ),
                .paragraph("Bu ayrım, alıştırmalardaki hataların çoğunun kaynağıdır. “Fiyat yükseldiği için talep düşer” ifadesi yanlıştır: düşen, talep edilen miktardır. Talep ise gelirler azaldığında, rakip bir ürün ucuzladığında ya da bir araştırma sağlık açısından bir tehlikeyi ortaya koyduğunda düşer."),
                .timeline(title: "Modelin kurucuları", events: [
                    DemoEvent(date: "1776", label: "Adam Smith, Ulusların Zenginliği: “görünmez el”"),
                    DemoEvent(date: "1838", label: "Antoine-Augustin Cournot ilk talep eğrisini çizer"),
                    DemoEvent(date: "1874", label: "Léon Walras, genel denge kuramı"),
                    DemoEvent(date: "1890", label: "Alfred Marshall arz ile talebi kesiştirir"),
                ]),
                .paragraph("Marshall arz ve talebi bir makasın iki ağzına benzetirdi: kâğıdı hangisinin kestiğini sormak anlamsızdır, fiyatı arzın mı talebin mi belirlediğini sormak da öyle. Fiyatı belirleyen ==ikisinin buluşmasıdır== ve bir sonraki bölümün konusu budur."),
            ]),
            DemoChapter(title: "Arz ve denge", blocks: [
                .paragraph("Alıcıların karşısında üreticiler vardır. **Arz**, üreticilerin olası her fiyatta satmaya hazır oldukları miktardır ve talebin tersi bir yasaya uyar: fiyat ne kadar yüksekse o kadar çok satmak isterler. Daha yüksek bir fiyat daha fazla üretmeyi kârlı kılar ve yeni üreticileri çeker."),
                .heading("Arz eğrisi"),
                .paragraph("Daha fazla üretmek için neden daha yüksek bir fiyat gerekir? Çünkü kısa vadede her ek birimi üretmek giderek daha pahalıya mal olur: fazla mesailer, kapasitelerinin ötesinde zorlanan makineler, elde edilmesi daha zor hammaddeler. Üretici bir birim daha üretmeyi ancak fiyat bu artan **marjinal maliyeti** karşılıyorsa kabul eder."),
                .formula("Q_s = 20\\,p", caption: "Aynı piyasanın arzı: fiyat p'ye bağlı olarak arz edilen miktar (bin adet)"),
                .paragraph("Kısa vadede arz sonunda bir duvara bile dayanır: üretim kapasitesi. Bir mandıra, fiyat ne olursa olsun, kazanlarının ve sütünün izin verdiğinden fazlasını üretemez. Arz edilen miktar önce fiyatla birlikte hızla artar, sonra giderek daha yavaş artar ve bir tavana ulaşır."),
                .figure(.plot(title: "Kısa vadeli arz bir tavana ulaşır", caption: "Yatay eksende fiyat, dikey eksende arz edilen miktar: miktar fiyatla birlikte artar, sonra üretim kapasitesine dayanır.", kind: .saturation)),
                .paragraph("Talepte ani bir artışın önce miktarlardan çok fiyatları yükseltmesinin nedeni budur: üreticiler hemen yetişemez. Uzun vadede yatırım yaparlar, yeni üreticiler gelir ve tavan yükselir. Örneğimizde arzın bir doğru olduğu bölgede kalıyoruz."),
                .heading("Denge"),
                .paragraph("Piyasanın iki tarafını karşı karşıya getirelim. Her fiyat için alıcıların istediği miktarı satıcıların sunduğu miktarla karşılaştırırız. Tablo satır satır okunur ve ikisini yalnızca tek bir satır eşitler."),
                .table(title: "Peynir piyasası, fiyat fiyat", headers: ["Fiyat", "Talep (bin)", "Arz (bin)", "Durum"], rows: [
                    ["1 €", "100", "20", "80 kıtlık"],
                    ["2 €", "80", "40", "40 kıtlık"],
                    ["3 €", "60", "60", "Denge"],
                    ["4 €", "40", "80", "40 arz fazlası"],
                    ["5 €", "20", "100", "80 arz fazlası"],
                ]),
                .paragraph("**Denge fiyatı**, arz edilen miktarın talep edilen miktara eşit olduğu fiyattır. Grafikte iki eğrinin kesişim noktasıdır; cebirsel olarak ise birinci dereceden bir denklemin çözümüdür."),
                .formula("120 - 20\\,p = 20\\,p \\;\\Rightarrow\\; p^* = 3 \\text{ €} \\;\\text{ ve }\\; Q^* = 60", caption: "Denge: arz talebe eşittir"),
                .paragraph("3 € fiyatla her hafta 60 000 peynir satılır ve herkes memnun kalır: 3 € ödemeye hazır bütün alıcılar ürünü alır, 3 €'dan satmaya hazır bütün satıcılar üretimlerini satar. ==Ne kuyruk ne de satılmayan mal== vardır."),
                .keyFigure(value: "3 €", label: "denge fiyatı: 60 000 peynirin hem bir satıcı hem de bir alıcı bulduğu tek fiyat"),
                .paragraph("Bu fiyat bir grafikteki nokta olmaktan ibaret değildir: piyasanın kendiliğinden geri döndüğü fiyattır. Fiyat çok düşükse alıcılar kıt bir mal için yarışır ve fiyatı yükseltir; çok yüksekse satıcıların elinde satılmayan mal kalır ve fiyatı düşürürler. Mekanizma dört adımda okunur."),
                .figure(.flow(title: "Çok düşük bir fiyattan dengeye dönüş", steps: ["Fiyat 2 €: 40 000 kıtlık", "Alıcılar daha fazla teklif verir, fiyat yükselir", "Talep edilen miktar düşer, arz artar", "Kıtlık 3 €'da ortadan kalkar"])),
                .paragraph("Çok yüksek bir fiyattan başlandığında mekanizma simetriktir: 4 €'da satıcıların elinde 40 000 adet satılmayan mal vardır, bunları satmak için fiyatlarını düşürürler ve piyasa 3 €'ya doğru iner. Her iki durumda da fiyatı hareket ettiren arz ile talep arasındaki farklar, onu durduran ise bu farkların ortadan kalkmasıdır."),
                .callout(
                    title: "Görünmez el",
                    text: "Adam Smith'in bu ifadesi şu mekanizmayı anlatır: herkes kendi çıkarını gözetir — alıcı daha az ödemeyi, satıcı daha çok kazanmayı —, fiyat ise **hiçbir planlamacı müdahale etmeden** kararlarını eşgüdümleyene kadar ayarlanır. Fiyat bir sinyaldir: üreticilere ne üreteceklerini, tüketicilere neyden tasarruf edeceklerini söyler.",
                    tone: .insight
                ),
                .paragraph("Mekanizmanın şaşırtıcı bir sonucu vardır: ==kıtlık, üretimin yetersizliğinin değil, fiyatın çok düşük olmasının belirtisidir==. Bir fiyat dengenin altında sabitlendiğinde her seferinde gözlenen budur ve son bölümde bu incelenecek."),
            ]),
            DemoChapter(title: "Denge kaydığında", blocks: [
                .paragraph("Denge ancak hiçbir şey değişmediği sürece sürer. Oysa her şey değişir: gelirler, zevkler, maliyetler, hava durumu. Her seferinde eğrilerden biri kayar ve piyasa başka bir fiyat ve başka bir miktarla ==yeni bir dengeye== ulaşır."),
                .figure(.split(
                    title: "Eğrileri kaydıran etkenler",
                    left: DemoColumn(title: "Talep", items: ["Hane halkı geliri", "İkame malların fiyatı", "Tamamlayıcı malların fiyatı", "Zevkler, modalar, bilgiler", "Nüfus büyüklüğü"]),
                    right: DemoColumn(title: "Arz", items: ["Hammadde maliyeti", "Ücretler, enerji", "Teknik ilerleme", "Üretici sayısı", "Hava durumu, vergiler, sübvansiyonlar"])
                )),
                .paragraph("Analiz yöntemi her zaman aynıdır ve üç sorudan oluşur: hangi eğri kayıyor? Hangi yönde? Denge fiyatı ve miktarı ne oluyor? Talep artarsa fiyat da miktar da yükselir. Arz azalırsa fiyat yükselir ama miktar düşer."),
                .callout(
                    title: "Brezilya'da bir don",
                    text: "Brezilya dünya kahvesinin üçte birinden fazlasını üretir. Bir don hasadın bir kısmını yok ettiğinde kahve **arzı** azalır: arz eğrisi sola kayar. Yeni dengede kahvenin fiyatı yükselir ve el değiştiren miktar düşer — talep hiç kıpırdamadan.",
                    tone: .example
                ),
                .paragraph("Bazı piyasalar dengelerine yumuşak bir şekilde dönemez. Üretim zaman gerektirdiğinde — domuz yetiştirmek, meyve bahçesi dikmek —, üreticiler yarın ne satacaklarına bugünkü fiyata bakarak karar verir. Yüksek bir fiyat hepsini daha fazla üretmeye iter; üretim aynı anda piyasaya gelir, fiyat çöker ve hepsi üretimlerini azaltır. Bu, 1930'lu yıllardan beri tanımlanan **domuz döngüsüdür**."),
                .figure(.cycle(title: "Domuz döngüsü", nodes: ["Yüksek fiyat", "Yetiştiriciler daha çok üretir", "Aşırı üretim: fiyat düşer", "Yetiştiriciler daha az üretir"])),
                .paragraph("Bu döngü basit modelin bir sınırıdır: model miktarların anında ayarlandığını varsayar. Döngü aynı zamanda tarım fiyatlarının neden bu kadar istikrarsız olduğunu ve pek çok ülkenin, 1962'den itibaren Avrupa'nın **Ortak Tarım Politikası** gibi, bunları istikrara kavuşturmak için neden politikalar geliştirdiğini açıklar."),
                .heading("Fiyat esnekliği"),
                .paragraph("Bütün talepler fiyata aynı biçimde tepki vermez. Benzin fiyatındaki %10'luk bir artış kısa vadede alımları çok az düşürür: işe gitmek gerekir. Aynı artış bir tatil yolculuğunda pek çok kişiyi vazgeçirebilir. **Fiyat esnekliği** bu duyarlılığı ölçer."),
                .formula("e = \\frac{\\Delta Q / Q}{\\Delta p / p}", caption: "Talep edilen miktardaki göreli değişimin fiyattaki göreli değişime bölümü: neredeyse her zaman negatif"),
                .paragraph("Fiyat %10 artar ve miktar %5 düşerse $e = -5 / 10 = -0{,}5$ olur: $|e| < 1$ olduğu için talep **inelastiktir**. Miktar %20 düşerse $e = -2$ olur: $|e| > 1$ olduğu için talep **esnektir**. Bu da satıcı için her şeyi değiştirir, çünkü **hasılatı** fiyatın satılan miktarla çarpımıdır."),
                .bars(title: "Fiyata göre satıcıların toplam hasılatı (bin avro)", unit: "k€", bars: [
                    DemoBar(label: "1 €", value: 100),
                    DemoBar(label: "2 €", value: 160),
                    DemoBar(label: "3 €", value: 180),
                    DemoBar(label: "4 €", value: 160),
                    DemoBar(label: "5 €", value: 100),
                ]),
                .paragraph("Grafik, piyasamızdaki $R = p \\times Q_d$ hasılatını gösterir. Hasılat 3 €'ya kadar artar, sonra yeniden düşer. Bu bir tesadüf değildir: doğrusal bir talep boyunca esneklik her noktada değişir ve hasılat tam olarak ==esnekliğin −1 olduğu yerde== en yüksektir."),
                .table(title: "Q = 120 − 20p talebi boyunca esneklik", headers: ["Fiyat", "Miktar", "Esneklik", "Fiyat yükselirse hasılat…"], rows: [
                    ["1 €", "100", "−0,2", "artar"],
                    ["2 €", "80", "−0,5", "artar"],
                    ["3 €", "60", "−1", "en yüksektir"],
                    ["4 €", "40", "−2", "azalır"],
                    ["5 €", "20", "−5", "azalır"],
                ]),
                .paragraph("Kural geneldir: talep inelastik olduğunda fiyat artışı hasılatı artırır, çünkü miktar fiyatın arttığı orandan daha az düşer. Devletin, talebi kısa vadede pek esnek olmayan tütün ve akaryakıtı seve seve vergilendirmesinin nedeni budur: vergi gelir getirir ve satışlar çökmez."),
            ]),
            DemoChapter(title: "Devlet ve piyasa", blocks: [
                .paragraph("Denge fiyatı her zaman kabul edilebilir bulunmaz: kiracılar için çok yüksek, çiftçiler ya da çalışanlar için çok düşük olabilir. O zaman devlet bir fiyat belirleyerek, vergilendirerek, sübvansiyon vererek müdahale eder. Model, istenmeyenler dahil ==bu müdahalelerin etkilerini== öngörmeyi sağlar."),
                .heading("Tavan fiyat, taban fiyat"),
                .callout(
                    title: "Tavan fiyat ve taban fiyat",
                    text: "**Tavan fiyat**, alıcıları korumak için devletin dengenin altında belirlediği azami fiyattır (kira sınırlaması). **Taban fiyat** ise satıcıları korumak için dengenin üstünde belirlenen asgari fiyattır (asgari ücret, garantili tarım fiyatları).",
                    tone: .definition
                ),
                .paragraph("Piyasamıza dönelim. 2 €'luk bir tavan fiyat, peynir bulabilenler için onu ucuzlatır, ama talep 80 000'e çıkar ve arz 40 000'e düşer: kuyruklar ve karaborsayla birlikte ==40 000'lik bir kıtlık== yerleşir. 4 €'luk bir taban fiyat üreticilere iyi bir fiyat garanti eder, ama alıcılar yalnızca 40 000 adet isterken üreticiler 80 000 adet sunar: depolanması, imha edilmesi ya da ihraç edilmesi gereken 40 000'lik bir arz fazlası."),
                .table(title: "Devletin araçları", headers: ["Araç", "Örnek", "Beklenen etki", "Olası ters etki"], rows: [
                    ["Tavan fiyat", "Kira sınırlaması", "Daha düşük fiyatlar", "Kıtlık, piyasadan çekilen konutlar"],
                    ["Taban fiyat", "Asgari ücret", "Daha yüksek gelirler", "Arz fazlası: taban çok yüksekse işsizlik"],
                    ["Vergi", "Tütün vergisi", "Daha az tüketim, vergi geliri", "Kaçakçılık"],
                    ["Sübvansiyon", "Çevre dostu araç teşviki", "Desteklenen maldan daha çok alım", "Kamu maliyesine maliyet"],
                ]),
                .paragraph("Son sütun bir iddianame değildir: bu etkiler, belirlenen fiyat ile denge arasındaki farka ve eğrilerin esnekliğine bağlıdır. Ilımlı bir asgari ücretin istihdam üzerindeki etkisi çok küçük olabilir; katı ve kalıcı bir kira sınırlaması ise kiralık konut arzını neredeyse her zaman azaltır. Model müdahale edilmesi gerekip gerekmediğini söylemez: ==müdahalenin neye mal olduğunu== söyler."),
                .heading("Vergiyi kim öder?"),
                .paragraph("Devlet, satıcılar tarafından ödenen, peynir başına 1 €'luk bir vergi koyar. Bir adet satmak için üretici artık eskisinden 1 € fazlasını ister: alıcılardan $p$ alırsa elinde yalnızca $p - 1$ kalır. Arzı $Q_s = 20(p - 1)$ olur ve denge kayar."),
                .formula("120 - 20\\,p = 20\\,(p - 1) \\;\\Rightarrow\\; p = 3{,}5 \\text{ €} \\;\\text{ ve }\\; Q = 50", caption: "Birim başına 1 €'luk vergiyle yeni denge"),
                .paragraph("Alıcılar artık 3 € yerine 3,50 € öder: verginin 50 sentini onlar üstlenir. Satıcılar 3,50 € alır ama bunun 1 €'sunu devlete öder: ellerinde 3 € yerine 2,50 € kalır, yani 50 sent kayıp. Vergi ==yarı yarıya== paylaşılır, çünkü burada iki eğrinin eğimi aynıdır. Devlet haftada $1 \\times 50\\,000 = 50\\,000$ € tahsil eder."),
                .callout(
                    title: "Ödemek, yüklenmek değildir",
                    text: "Satıcı vergiyi devlete **öder**, ama vergiyi kimin **yükleneceğine** eğrilerin esnekliği karar verir. Piyasanın en az esnek tarafı — kaçamayan taraf — en büyük payı öder. Talebi pek esnek olmayan tütünde bu, çoğunlukla sigara içenlerdir.",
                    tone: .warning
                ),
                .paragraph("Verginin gizli bir maliyeti de vardır. Dengede **tüketici artığı** — alıcıların fiyatın ötesinde ödemeye hazır oldukları — ve **üretici artığı** — satıcıların maliyetlerinin ötesinde elde ettikleri — her biri 90 000 €, toplamda 180 000 € ediyordu. Vergiden sonra bu toplam farklı dağılır ve bir kısmı kaybolur."),
                .bars(title: "Vergiden sonra 180 000 €'luk artık (bin avro)", unit: "k€", bars: [
                    DemoBar(label: "Tüketiciler", value: 62.5),
                    DemoBar(label: "Üreticiler", value: 62.5),
                    DemoBar(label: "Devlet (vergi geliri)", value: 50),
                    DemoBar(label: "Ölü ağırlık kaybı", value: 5),
                ]),
                .paragraph("Haftada 5 000 €'luk **ölü ağırlık kaybı**, bir alıcı ile bir satıcının anlaşabileceği hâlde artık el değiştirmeyen 10 000 peynire karşılık gelir. Kimseye yarar sağlamaz. Bu, verginin etkinlik maliyetidir ve eğriler ne kadar esnekse o kadar büyüktür."),
                .list([
                    "Dengenin altında tavan fiyat: kıtlık",
                    "Dengenin üstünde taban fiyat: arz fazlası",
                    "Vergi: ödenen fiyat artar, alınan fiyat düşer, miktar düşer, ölü ağırlık kaybı",
                    "Verginin paylaşımı: en az esnek taraf en büyük payı üstlenir",
                ]),
                .paragraph("Bu dört sonuç, petrolden emeğe ve konuta kadar her piyasa için geçerlidir. Bir müdahalenin iyi ya da kötü olduğunu söylemezler — devlet tütün tüketimini azaltmak ya da bir gelir güvence altına almak isteyebilir —, ama ==etkilerini sayılarla ortaya koymayı== zorunlu kılarlar; bu da ekonomistin ilk işidir."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Fiyat denge fiyatının altında olduğunda bir piyasada ne olur?",
                back: "Talep edilen miktar arz edilen miktarı aşar: kıtlık oluşur. Alıcılar daha fazla teklif verir, fiyat yükselir, talep edilen miktar düşer ve denge yeniden kurulana kadar arz artar.",
                figure: .flow(title: "Dengeye dönüş", steps: ["Fiyat çok düşük", "Kıtlık", "Fiyat yükselir", "Denge"]),
                chapter: 1
            ),
            DemoCard(
                kind: .choice,
                front: "Bir don kahve hasadının bir kısmını yok ediyor. Denge fiyatı ve miktarı ne olur?",
                back: "Arz azalır (arz eğrisi sola kayar): denge fiyatı yükselir ve el değiştiren miktar düşer.",
                choices: ["Fiyat yükselir, miktar artar", "Fiyat yükselir, miktar düşer", "Fiyat düşer, miktar düşer", "Hiçbir şey değişmez"],
                answerIndex: 1,
                chapter: 2
            ),
            DemoCard(
                kind: .cloze,
                front: "Bir malın fiyatı arttığında talep eğrisi … hareket edilir: değişen talep değil, talep edilen miktardır.",
                back: "boyunca",
                chapter: 0
            ),
            DemoCard(kind: .basic, front: "$Q_d = 120 - 20p$ ve $Q_s = 20p$ ise denge nedir?", back: "$120 - 20p = 20p$ eşitliğinden $p^* = 3$ € ve $Q^* = 60$ (bin) bulunur.", hint: "Arzı talebe eşitleyin.", chapter: 1),
            DemoCard(kind: .choice, front: "Fiyat %10 artıyor ve talep edilen miktar %5 düşüyor. Talebin fiyat esnekliği nedir?", back: "$e = -5 / 10 = -0{,}5$: talep inelastiktir ve fiyat artışı hasılatı artırır.", choices: ["−2", "−0,5", "0,5", "−5"], answerIndex: 1, chapter: 2),
            DemoCard(kind: .cloze, front: "Denge fiyatının altında belirlenen bir tavan fiyatın sonucunda … ortaya çıkar.", back: "kıtlık", chapter: 3),
            DemoCard(kind: .basic, front: "Tam rekabet piyasasının beş koşulu nelerdir?", back: "Çok sayıda alıcı ve satıcı, ürünün homojenliği, bilginin şeffaflığı, piyasaya serbest giriş ve çıkış, üretim faktörlerinin serbest dolaşımı.", chapter: 0),
            DemoCard(kind: .choice, front: "Aşağıdaki olaylardan hangisi elektrikli otomobil talep eğrisini sağa kaydırır?", back: "Benzin fiyatındaki bir artış: ikame bir mal olan benzinli otomobilin kullanımı pahalılaşır. Elektrikli otomobilin kendi fiyatındaki bir düşüş eğriyi kaydırmaz: eğri boyunca hareket edilir.", choices: ["Elektrikli otomobil fiyatlarında bir düşüş", "Benzin fiyatında bir artış", "Batarya maliyetinde bir artış", "Hane halkı gelirlerinde bir düşüş"], answerIndex: 1, chapter: 2),
            DemoCard(kind: .basic, front: "Bir piyasaya konan vergiyi kim yüklenir?", back: "Vergiyi kim öderse ödesin, alıcılar ve satıcılar onu paylaşır. En az esnek taraf en büyük payı üstlenir.", chapter: 3),
            DemoCard(kind: .cloze, front: "Doğrusal bir talep boyunca satıcıların hasılatı, fiyat esnekliğinin … olduğu noktada en yüksektir.", back: "−1", chapter: 2),
            DemoCard(kind: .choice, front: "Dengenin üstünde belirlenen bir taban fiyatın etkisi nedir?", back: "Arz fazlası: satıcılar, alıcıların bu fiyattan almak istediğinden fazlasını sunar.", choices: ["Kıtlık", "Arz fazlası", "Hiçbir etki", "Ödenen fiyatta düşüş"], answerIndex: 1, chapter: 3),
            DemoCard(kind: .cloze, front: "Bir verginin yol açtığı ve kimseye yarar sağlamayan artık kaybına … kaybı denir.", back: "ölü ağırlık", chapter: 3),
        ]
    )

    // MARK: Physique : les circuits électriques

    private static let circuitsTR = OnboardingDemoCourse(
        id: "debug-circuits",
        emoji: "🔌",
        subject: "Physique",
        title: "Elektrik: devreler",
        summary: "Akım ve gerilim, Ohm yasası, seri ve paralel bağlama, ardından güç, enerji ve güvenlik kuralları; hesaplar adım adım yapılarak.",
        accentIndex: 2,
        chapters: [
            DemoChapter(title: "Akım ve gerilim", blocks: [
                .paragraph("Bir anahtara bastığınızda lamba anında yanar, oysa tellerdeki elektronlar saniyede bir milimetreden daha az ilerler. Bu paradoks işin özünü anlatır: bir elektrik devresi, üretecin hepsini aynı anda harekete geçirdiği ==zaten yüklerle dolu bir halkadır==."),
                .heading("Elektrik akımı"),
                .paragraph("**Elektrik akımı**, yük taşıyıcılarının toplu bir hareketidir. Metallerde bunlar atomdan atoma hareket eden **serbest elektronlardır**; çözeltilerde ise iyonlardır. Akımın **şiddeti** $I$, her saniye telin bir kesitinden geçen yük miktarını ölçer. Birimi **amperdir** (A)."),
                .formula("I = \\frac{Q}{\\Delta t}", caption: "I amper (A), Q coulomb (C), Δt saniye (s) cinsinden"),
                .paragraph("Bir elektron $1{,}6 \\times 10^{-19}$ C yük taşır. Dolayısıyla 1 A'lik bir akım, saniyede $1 / (1{,}6 \\times 10^{-19}) \\approx 6{,}25 \\times 10^{18}$ elektronun geçişine karşılık gelir: altı milyar milyardan fazla. Elektronların hiçbir zaman tek tek değil, coulomb cinsinden sayılmasının nedeni budur."),
                .callout(
                    title: "Geleneksel akım yönü",
                    text: "Geleneksel olarak akım, üretecin dışında **+ kutbundan − kutbuna** doğru akar. Negatif yüklü elektronlar ise **ters yönde** hareket eder. Bu kabul elektronun keşfinden öncesine dayanır ve korunmuştur.",
                    tone: .warning
                ),
                .paragraph("Bir akımın geçmesi için **kapalı bir devre** gerekir: bir üreteç, teller, en az bir alıcı ve hiçbir kopukluk olmaması. Bir anahtarı açmak devreyi kesmek demektir ve akım her yerde aynı anda durur — anahtardan önce de sonra da."),
                .figure(.cycle(title: "Kapalı bir devre", nodes: ["Üretecin + kutbu", "Bağlantı teli", "Alıcı (lamba)", "− kutbuna dönüş"])),
                .paragraph("Kolsuz, basit bir devrede akım şiddeti ==her noktada aynıdır==: akım lambadan geçerken tükenmez. “Tüketilen”, yüklerin kendisi değil, taşıdıkları enerjidir. Lamba elektron yemez; elektrik enerjisini ışığa ve ısıya dönüştürür."),
                .heading("Gerilim"),
                .callout(
                    title: "Elektrik gerilimi",
                    text: "Bir devrenin iki noktası arasındaki **gerilim** $U$, bu noktaların elektrik potansiyelleri arasındaki farktır. **Volt** (V) ile ölçülür. Yükleri harekete geçiren odur: gerilim yoksa akım da yoktur.",
                    tone: .definition
                ),
                .paragraph("Bir benzetme kavramları yerine oturtmaya yardım eder: bir su devresinde pompa bir basınç farkı yaratır ve su akar. Üreteç pompadır, gerilim basınç farkıdır, akım şiddeti ise debidir. 1,5 V'luk bir pil, 12 V'luk bir araba aküsü ve 230 V'luk bir prizin “basıncı” aynı değildir."),
                .table(title: "Bir devrede ölçüm yapmak", headers: ["Alet", "Ölçtüğü", "Birim", "Bağlantı"], rows: [
                    ["Ampermetre", "Akım şiddeti", "Amper (A)", "Seri, devrenin içine"],
                    ["Voltmetre", "Gerilim", "Volt (V)", "Paralel, devre elemanının uçlarına"],
                    ["Ohmmetre", "Direnç", "Ohm (Ω)", "Devre elemanının uçlarına, devre dışındayken"],
                ]),
                .paragraph("Bağlantı biçimi aletin ölçtüğü şeyden çıkar. Ampermetre geçeni sayar: akımın içinden geçmesi, yani devrenin **içine** yerleştirilmesi gerekir. Voltmetre iki noktayı karşılaştırır: bu noktaların **arasına** bağlanır. Ampermetreyi paralel bağlamak kısa devre yaratmak — ve çoğu zaman sigortasını yakmak — demektir."),
                .list([
                    "Düğüm kuralı: bir düğüme gelen akımların toplamı, düğümden çıkan akımların toplamına eşittir",
                    "Göz (ilmek) kuralı: bir devre gözünde üretecin gerilimi, alıcıların uçlarındaki gerilimlerin toplamına eşittir",
                    "Basit bir devrede akım şiddeti her yerde aynıdır",
                ]),
            ]),
            DemoChapter(title: "Ohm yasası", blocks: [
                .paragraph("Bir bakır tel akımı neredeyse hiç direnç göstermeden geçirir; bir tungsten flaman ise onu güçlü biçimde yavaşlatır. Bir devre elemanının **direnci** $R$, ==akımın geçişine ne kadar karşı koyduğunu== ölçer. Birimi, Alman fizikçi Georg Ohm'un adını taşıyan ohmdur (Ω)."),
                .heading("Bir doğru orantı ilişkisi"),
                .paragraph("Bir **omik iletkeni** — bileşen anlamında bir direnci — ayarlanabilir bir üretece bağlayalım ve farklı gerilimler için akım şiddetini ölçelim. 100 Ω'luk bir direnç için sonuçlar orijinden geçen bir doğru üzerine düşer."),
                .table(title: "100 Ω'luk bir direncin uçlarında ölçümler", headers: ["Gerilim U (V)", "Akım I (mA)", "U / I (Ω)"], rows: [
                    ["2", "20", "100"],
                    ["4", "40", "100"],
                    ["6", "60", "100"],
                    ["8", "80", "100"],
                    ["10", "100", "100"],
                ]),
                .paragraph("$U / I$ oranı sabittir: bu, dirençtir. Birimlere dikkat: 20 mA, 0,020 A eder ve $2 / 0{,}020 = 100$ Ω. Gerilim ile akım şiddeti arasındaki bu doğru orantı, bütün elektrikte en çok kullanılan ilişki olan **Ohm yasasıdır**."),
                .formula("U = R \\times I", caption: "U volt (V), R ohm (Ω), I amper (A) cinsinden"),
                .paragraph("Formül üç yönde okunur: $U = RI$, $I = U / R$, $R = U / I$. Belirli bir gerilimde direnç ne kadar büyükse akım o kadar küçüktür. Örnek: 12 V altındaki 470 Ω'luk bir dirençten $I = 12 / 470 \\approx 0{,}026$ A, yani yaklaşık 26 mA akım geçer."),
                .heading("Her devre elemanı omik değildir"),
                .paragraph("Ohm yasası yalnızca omik iletkenler için geçerlidir. Örneğin bir akkor lamba bu yasaya uymaz: gerilim arttığında flaman ısınır, direnci artar ve akım giderek daha yavaş artar. **Karakteristik eğrisi** — akımın gerilime göre değişimini gösteren eğri — bir doğru değil, bükülen bir eğridir."),
                .figure(.plot(title: "Bir akkor lambanın karakteristik eğrisi", caption: "Yatay eksende gerilim, dikey eksende akım: flaman ısındıkça direnci artar ve akım gerilime ayak uydurmakta zorlanır.", kind: .saturation)),
                .paragraph("Bir direncin doğrusuyla karşılaştırın: lambada $U / I$ oranı sabit değildir, gerilimle birlikte artar. Bu, ==omik olmayan bir devre elemanının imzasıdır==. Diyotlar daha da belirgin bir başka örnektir: akımı bir yönde geçirir, diğer yönde neredeyse hiç geçirmezler."),
                .keyFigure(value: "× 10", label: "en az: 2 500 °C'deki bir tungsten flamanın direncinin soğukken ölçülen direncine oranı"),
                .paragraph("Akkor bir ampulün çoğunlukla açılırken yanmasının nedeni budur: soğukken direnci düşüktür ve flaman ısınmadan önceki saniyenin küçük bir kesrinde içinden güçlü bir akım geçer. Bu yüzden sönük bir lambayı ölçen bir ohmmetre, çalışma sırasındaki direncinden çok farklı bir değer verir."),
                .callout(
                    title: "Yöntem",
                    text: "Ohm yasasını uygulamak için: 1. devre elemanının omik olduğunu doğrulayın; 2. temel birimlere çevirin — volt, amper, ohm (1 mA = 0,001 A, 1 kΩ = 1 000 Ω); 3. aranan büyüklüğü yalnız bırakın; 4. sonucu birimiyle ve makul sayıda basamakla verin.",
                    tone: .insight
                ),
                .paragraph("En çok puan kaybettiren ikinci adımdır: $12 / 470$ işlemi 0,026 verir ve bu amper cinsinden bir sonuçtur. “0,026 mA” yazmak bin kat yanılmak demektir. Kafadan bir büyüklük mertebesi tahmini — ==12 V altında birkaç yüz ohm için birkaç on miliamper== — hatayı fark etmeye yeter."),
            ]),
            DemoChapter(title: "Seri ve paralel bağlama", blocks: [
                .paragraph("Bir devrede birden fazla alıcı olduğu anda, bunların nasıl bağlandığını bilmek gerekir. Yalnızca iki temel yol vardır: **seri**, aynı devre üzerinde art arda; **paralel**, aynı iki nokta arasındaki paralel kollar üzerinde. Her devre, karmaşık olsa bile, bu iki bağlama biçimine ayrıştırılabilir."),
                .figure(.split(
                    title: "İki bağlama biçimi",
                    left: DemoColumn(title: "Seri", items: ["Tek bir devre yolu", "Her yerde aynı akım", "Gerilimler toplanır", "Dirençler toplanır", "Yanan bir eleman her şeyi keser"]),
                    right: DemoColumn(title: "Paralel", items: ["Birkaç kol", "Uçlarda aynı gerilim", "Akımlar toplanır", "Eşdeğer direnç daha küçük", "Her kol bağımsızdır"])
                )),
                .paragraph("Tablodaki her satır, ilk bölümdeki iki kuraldan çıkar. Seri bağlamada düğüm yoktur, dolayısıyla akım her yerde aynıdır; göz kuralı gerilimlerin toplandığını söyler. Paralel bağlamada kollar aynı iki nokta arasına bağlıdır, dolayısıyla gerilimleri aynıdır; düğüm kuralı akımların toplandığını söyler."),
                .heading("Seri bağlama"),
                .formula("R_{eq} = R_1 + R_2", caption: "Seri bağlı iki direnç, toplamlarına eşit tek bir dirence eşdeğerdir"),
                .callout(
                    title: "Örnek: seri bağlı iki direnç",
                    text: "12 V'luk bir üreteç, seri bağlı $R_1 = 100$ Ω ve $R_2 = 200$ Ω dirençlerini besliyor. $R_{eq} = 300$ Ω, dolayısıyla $I = 12 / 300 = 0{,}040$ A = 40 mA. Gerilimler: $U_1 = 100 \\times 0{,}040 = 4$ V ve $U_2 = 200 \\times 0{,}040 = 8$ V. Doğrulama: $4 + 8 = 12$ V.",
                    tone: .example
                ),
                .paragraph("Gerilim ==dirençlerle orantılı olarak== paylaşılır: iki kat büyük direnç iki kat büyük gerilim alır. Bu bağlamaya **gerilim bölücü** denir ve sabit bir kaynaktan daha düşük bir gerilim elde etmek için elektronikte her yerde kullanılır."),
                .heading("Paralel bağlama"),
                .formula("\\frac{1}{R_{eq}} = \\frac{1}{R_1} + \\frac{1}{R_2} \\;\\;\\Leftrightarrow\\;\\; R_{eq} = \\frac{R_1 R_2}{R_1 + R_2}", caption: "Paralel bağlamada dirençlerin tersleri toplanır"),
                .paragraph("Şimdi aynı dirençleri aynı üretece paralel bağlayalım. Her biri 12 V alır: $I_1 = 12 / 100 = 0{,}12$ A ve $I_2 = 12 / 200 = 0{,}06$ A. Üreteç bunların toplamını, $0{,}18$ A verir. Eşdeğer direnç $\\frac{100 \\times 200}{300} \\approx 66{,}7$ Ω'dur ve $12 / 66{,}7 \\approx 0{,}18$ A olduğu doğrulanır."),
                .table(title: "Aynı dirençler, iki bağlama (12 V'luk üreteç)", headers: ["", "Seri", "Paralel"], rows: [
                    ["Eşdeğer direnç", "300 Ω", "≈ 66,7 Ω"],
                    ["Üretecin verdiği akım", "40 mA", "180 mA"],
                    ["R₁ uçlarındaki gerilim", "4 V", "12 V"],
                    ["R₂ uçlarındaki gerilim", "8 V", "12 V"],
                    ["Toplam güç", "0,48 W", "2,16 W"],
                ]),
                .paragraph("Sonuç sezgiye aykırıdır: bir direnci **paralel eklemek**, akıma bir yol daha sunduğu için eşdeğer direnci **azaltır**. Eşdeğer direnç her zaman paralel bağlı dirençlerin en küçüğünden daha küçüktür — burada 66,7 Ω, yani 100 Ω'dan az."),
                .callout(
                    title: "Prizler neden paralel bağlıdır",
                    text: "Bir evde bütün cihazlar paralel bağlıdır: her biri 230 V alır ve biri kapatıldığında diğerleri kesilmez. Ama eklenen her cihaz devredeki toplam akımı artırır: aşırı yüklenmiş bir çoklu prizin **sigortayı attırması** böyle olur.",
                    tone: .warning
                ),
                .paragraph("Altın kuralı aklınızda tutun: ==seri bağlamada akım ortaktır; paralel bağlamada ise gerilim==. Geri kalan her şey — gerilimlerin ya da akımların toplanması, eşdeğer dirençlerin hesabı — buradan çıkar ve bir devre şemasının karşısında ilk belirlenmesi gereken şey budur."),
            ]),
            DemoChapter(title: "Güç, enerji ve güvenlik", blocks: [
                .paragraph("Bir elektrikli cihaz önce **gücüne** göre seçilir: bir LED ampul için 8 W, bir su ısıtıcısı için 2 000 W. Bir devre elemanının aldığı elektrik gücü, uçlarındaki gerilim ile içinden geçen akımın çarpımıdır. Aldığı ==enerjinin akış hızını== ölçer."),
                .formula("P = U \\times I", caption: "P watt (W), U volt (V), I amper (A) cinsinden"),
                .paragraph("Ohm yasasıyla birleştirildiğinde formül, omik bir iletken için iki başka biçim alır: $P = R I^2$ ve $P = U^2 / R$. Birincisi **Joule etkisini** açıklar: içinden akım geçen bir iletken ısınır ve akım ne kadar güçlüyse o kadar çok ısınır. Bu bir radyatörde ya da ekmek kızartma makinesinde işe yarar, başka her yerde ise bir kayıptır."),
                .table(title: "230 V altında bazı cihazların gücü ve akımı", headers: ["Cihaz", "Güç", "Akım (I = P / U)"], rows: [
                    ["LED ampul", "8 W", "≈ 0,035 A"],
                    ["Telefon şarj cihazı", "20 W", "≈ 0,09 A"],
                    ["Televizyon", "100 W", "≈ 0,43 A"],
                    ["Su ısıtıcısı", "2 000 W", "≈ 8,7 A"],
                    ["Fırın", "3 000 W", "≈ 13 A"],
                ]),
                .paragraph("Standart bir priz 16 A için, yani en fazla $230 \\times 16 \\approx 3\\,700$ W için tasarlanmıştır. Bir su ısıtıcısını ve bir fırını aynı çoklu prize takmak 21 A'den fazlasını istemek demektir: teller Joule etkisiyle ısınır ve pek çok ev yangını böyle başlar."),
                .heading("Tüketilen enerji"),
                .formula("E = P \\times \\Delta t", caption: "P watt ve Δt saniye cinsindense E joule; P kW ve Δt saat cinsindense kWh cinsindendir"),
                .callout(
                    title: "Bir çay kaça mal olur?",
                    text: "2 000 W'lık bir su ısıtıcısı suyu 3 dakikada ısıtır: $E = 2 \\text{ kW} \\times 0{,}05 \\text{ sa} = 0{,}1$ kWh. kWh başına yaklaşık 0,20 € ile bu **iki sent** tutar. Joule cinsinden: $2000 \\times 180 = 360\\,000$ J.",
                    tone: .example
                ),
                .paragraph("Faturanın birimi kilovatsaattir, çünkü joule bir hane ölçeğinde çok küçüktür: 1 kWh, $3{,}6 \\times 10^6$ J eder. Pahalıya mal olan, birkaç dakika kullanılan güçlü cihazlar değil, uzun süre çalışanlardır: on saat açık kalan 1 500 W'lık bir radyatör 15 kWh, yani çayın yüz elli katını tüketir."),
                .heading("Elektrik ve insan vücudu"),
                .paragraph("Elektriğin tehlikesi doğrudan gerilimden değil, ==vücuttan geçen akım şiddetinden== kaynaklanır. Ama bu akımı yaratan gerilimdir: insan vücudunun iki eli arasındaki direnç, deri nemliyken 1 000 Ω mertebesindedir. 230 V altında Ohm yasası $I = 230 / 1000 = 0{,}23$ A, yani 230 mA verir — öldürücü bir akım şiddeti."),
                .bars(title: "Vücuttan geçen alternatif akımın etkileri", unit: "mA", bars: [
                    DemoBar(label: "Algılama eşiği", value: 0.5),
                    DemoBar(label: "Kasılma: artık bırakılamaz", value: 10),
                    DemoBar(label: "Solunum felci", value: 30),
                    DemoBar(label: "Kalp fibrilasyonu", value: 75),
                ]),
                .paragraph("Bu eşikler, bütün elektrik panolarında bulunan sayıyı açıklar: **30 mA kaçak akım koruma şalterleri**. Bir cihaza giden akımla ondan dönen akımı karşılaştırırlar; fark 30 mA'i aşarsa akımın bir kısmı — belki birinin vücudu üzerinden — kaçıyor demektir ve saniyenin birkaç yüzde birinde devreyi keserler."),
                .list([
                    "Sigorta veya otomatik sigorta: aşırı akımda (kısa devre, aşırı yük) devreyi keser, tesisatı korur",
                    "30 mA kaçak akım koruma şalteri: akım kaçağında devreyi keser, insanları korur",
                    "Topraklama: metal gövdeli arızalı bir cihazın akımını toprağa iletir",
                    "Suyun yakınında asla elektrikli cihaz kullanmayın: ıslak deri vücudun direncini kat kat düşürür",
                ]),
                .paragraph("Bu korumalar, elektriği iki yüzyıl boyunca denetim altına almanın sonucudur. Önce onu sürekli olarak üretmek, sonra yasalarını anlamak, sonra büyük ölçekte dağıtmak gerekti — ve her aşamada ondan korunmayı öğrenmek."),
                .timeline(title: "Elektriğin iki yüzyılı", events: [
                    DemoEvent(date: "1800", label: "Alessandro Volta pili icat eder: ilk doğru akım"),
                    DemoEvent(date: "1820", label: "Ørsted bir akımın pusulayı saptırdığını keşfeder"),
                    DemoEvent(date: "1827", label: "Georg Ohm kendi adını taşıyan yasayı yayımlar"),
                    DemoEvent(date: "1831", label: "Faraday indüksiyonu keşfeder: akım üretmeyi öğreniriz"),
                    DemoEvent(date: "1879", label: "Swan ve Edison'un uzun ömürlü akkor lambası"),
                    DemoEvent(date: "1882", label: "New York'ta ilk kamu elektrik santrali"),
                ]),
                .paragraph("Akım şiddetinin birimi Ampère'in, gerilimin birimi Volta'nın, direncin birimi Ohm'un adını taşır: her alıştırmada yazdığınız harflerden üçü bu hikâyenin ==öncülerine bir saygı duruşudur==. Ve her birinin keşfi bugün birkaç karakterlik bir formülde özetlenir."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Seri bağlı bir devrede ve paralel bağlı bir devrede akım ve gerilim nasıl davranır?",
                back: "Seri bağlamada akım her yerde aynıdır ve gerilimler toplanır. Paralel bağlamada her kolun uçlarındaki gerilim aynıdır ve akımlar toplanır.",
                figure: .split(
                    title: "İki bağlama biçimi",
                    left: DemoColumn(title: "Seri", items: ["I ortak", "U'lar toplanır"]),
                    right: DemoColumn(title: "Paralel", items: ["U ortak", "I'lar toplanır"])
                ),
                chapter: 2
            ),
            DemoCard(
                kind: .choice,
                front: "470 Ω'luk bir direnç 12 V'luk bir gerilime maruz kalıyor. İçinden hangi akım geçer?",
                back: "$I = U / R = 12 / 470 \\approx 0{,}026$ A, yani yaklaşık 26 mA.",
                choices: ["≈ 26 mA", "≈ 39 A", "≈ 5,6 A", "≈ 0,26 mA"],
                answerIndex: 0,
                chapter: 1
            ),
            DemoCard(
                kind: .cloze,
                front: "Voltmetre, gerilimi ölçülecek devre elemanının uçlarına … bağlanır.",
                back: "paralel",
                chapter: 0
            ),
            DemoCard(kind: .basic, front: "Ohm yasasını ifade edin.", back: "Omik bir iletkenin uçlarındaki gerilim, içinden geçen akımla doğru orantılıdır: $U = R \\times I$; U volt, R ohm, I amper cinsinden.", chapter: 1),
            DemoCard(kind: .choice, front: "100 Ω ve 200 Ω'luk iki direnç 12 V'luk bir üretece seri bağlanmış. 200 Ω'luk direncin uçlarındaki gerilim nedir?", back: "$I = 12 / 300 = 0{,}04$ A, dolayısıyla $U_2 = 200 \\times 0{,}04 = 8$ V.", hint: "Önce ortak akımı hesaplayın.", choices: ["4 V", "6 V", "8 V", "12 V"], answerIndex: 2, chapter: 2),
            DemoCard(kind: .cloze, front: "Geleneksel olarak akım, üretecin dışında, … kutbundan − kutbuna doğru akar.", back: "+", chapter: 0),
            DemoCard(kind: .basic, front: "Paralel bir direnç eklemek eşdeğer direnci neden azaltır?", back: "Çünkü akıma ek bir yol sunulur: kolların akımları toplanır, üreteç aynı gerilim altında daha fazla akım verir, dolayısıyla $R_{eq} = U / I$ azalır.", chapter: 2),
            DemoCard(kind: .choice, front: "2 000 W'lık bir su ısıtıcısı 3 dakika çalıştığında ne kadar enerji tüketir?", back: "$E = P \\times \\Delta t = 2 \\text{ kW} \\times 0{,}05 \\text{ sa} = 0{,}1$ kWh, yani 360 000 J.", choices: ["6 kWh", "0,1 kWh", "6 000 J", "0,6 kWh"], answerIndex: 1, chapter: 3),
            DemoCard(kind: .cloze, front: "Bir devre elemanının aldığı elektrik gücü $P = U \\times$ … olur.", back: "$I$", chapter: 3),
            DemoCard(kind: .basic, front: "30 mA kaçak akım koruma şalteri neyi ve nasıl korur?", back: "İnsanları: bir cihaza giden akımla ondan dönen akımı karşılaştırır ve fark 30 mA'i aşarsa, yani belki bir vücut üzerinden bir akım kaçağı varsa, devreyi keser.", chapter: 3),
            DemoCard(kind: .choice, front: "Vücuttan geçen bir akım yaklaşık hangi şiddetten itibaren solunum felcine yol açabilir?", back: "Yaklaşık 30 mA; ev tipi kaçak akım koruma şalterlerinin değeri de buradan gelir.", choices: ["0,5 mA", "30 mA", "1 A", "10 A"], answerIndex: 1, chapter: 3),
            DemoCard(kind: .cloze, front: "Bir elektron $1{,}6 \\times 10^{-19}$ … yük taşır.", back: "coulomb", chapter: 0),
        ]
    )

    // MARK: SVT : la cellule et la mitose

    private static let mitosisTR = OnboardingDemoCourse(
        id: "debug-mitosis",
        emoji: "🔬",
        subject: "SVT",
        title: "Hücre ve mitoz",
        summary: "Hücre ve organelleri, hücre döngüsü, mitozun evreleri, gametleri oluşturan mayoz ve bölünme her türlü denetimden çıktığında ortaya çıkan kanser.",
        accentIndex: 3,
        chapters: [
            DemoChapter(title: "Hücre, canlılığın birimi", blocks: [
                .paragraph("Her canlı hücrelerden oluşur: bir bakteri tek bir hücreden, bir insan ise yaklaşık ==30 000 milyar== hücreden. Ve her hücre, bölünme yoluyla başka bir hücreden doğar. Bu iki cümle, biyolojinin temel direklerinden biri olan **hücre teorisini** oluşturur."),
                .heading("İki yüzyıla yayılan bir keşif"),
                .paragraph("Hücreleri görmek için mikroskobu icat etmek, ardından onların bütün canlıların ortak noktası olduğunu anlamak için iki yüzyıl boyunca gözlem yapmak gerekti. Zaman çizelgesi, sonunda bölünmekte olan bir hücrenin gözlemlenmesiyle tamamlanan bu uzun yolu özetler."),
                .timeline(title: "Hücre teorisi", events: [
                    DemoEvent(date: "1665", label: "Robert Hooke mantarda “hücreler” gözlemler"),
                    DemoEvent(date: "1674", label: "Van Leeuwenhoek mikroskobik canlıları keşfeder"),
                    DemoEvent(date: "1838–1839", label: "Schleiden ve Schwann: bitkiler ve hayvanlar hücrelerden oluşur"),
                    DemoEvent(date: "1855", label: "Virchow: her hücre bir hücreden gelir"),
                    DemoEvent(date: "1882", label: "Flemming mitozu tanımlar ve adlandırır"),
                ]),
                .paragraph("Virchow'un *omnis cellula e cellula* cümlesinin baş döndürücü bir sonucu vardır: hücrelerinizin her biri, kesintisiz bir bölünmeler zinciriyle, ilk canlı hücreden gelir. Hücre bölünmesi canlılığın işleyişinde bir ayrıntı değil, ==onu sürdüren şeydir==."),
                .callout(
                    title: "Hücre",
                    text: "Canlılığın en küçük yapısal ve işlevsel birimi: bir **hücre zarı** ile sınırlanmış, **sitoplazma** ve **DNA** biçiminde bir genetik bilgi içeren, beslenebilen, enerji üretebilen ve çoğalabilen bir yapı.",
                    tone: .definition
                ),
                .paragraph("İki büyük hücre tipi vardır. **Prokaryotların** — bakterilerin — çekirdeği yoktur: DNA'ları sitoplazmada serbestçe bulunur. **Ökaryotların** — hayvanlar, bitkiler, mantarlar, protistler — ise DNA'yı çevreleyen bir çekirdeği ve **organel** adı verilen özelleşmiş bölmeleri vardır."),
                .heading("Organeller"),
                .table(title: "Bir ökaryot hücrenin başlıca organelleri", headers: ["Organel", "Görevi"], rows: [
                    ["Çekirdek", "DNA'yı içerir; eşlenme ve transkripsiyonun gerçekleştiği yer"],
                    ["Mitokondri", "Hücresel solunum: ATP üretir"],
                    ["Ribozom", "Translasyon: proteinleri üretir"],
                    ["Endoplazmik retikulum", "Proteinlerin ve lipitlerin sentezi ve taşınması"],
                    ["Golgi aygıtı", "Proteinleri değiştirir, sınıflandırır ve gönderir"],
                    ["Kloroplast", "Fotosentez, yalnızca bitkilerde"],
                ]),
                .paragraph("Bitki hücresi ayrıca zarının çevresinde selülozdan sert bir **hücre duvarına**, onu şişkin tutan suyla dolu büyük bir **kofula** ve kloroplastlara sahiptir. Hayvan hücresinde ne hücre duvarı ne de kloroplast bulunur, ama bölünme sırasında merkezi bir rol oynayacak **sentrozomlar** vardır."),
                .keyFigure(value: "10 ila 100 µm", label: "bir ökaryot hücrenin tipik büyüklüğü; bir bakterinin yaklaşık on katı: çıplak gözle görülmez"),
                .paragraph("Bu büyüklük tesadüf değildir. Bir hücre her şeyi — besin, oksijen, atık — zarı aracılığıyla alıp verir ve hacmi arttığında yüzeyi daha yavaş artar. Belirli bir büyüklüğün ötesinde ==zar artık yetmez== ve içeriyi besleyemez: hücre ya bölünmeli ya da ölmelidir."),
            ]),
            DemoChapter(title: "Hücre döngüsü", blocks: [
                .paragraph("Bölünen bir hücre, her kuşakta yinelenen bir dizi aşamadan geçer: bu, **hücre döngüsüdür**. Hücrenin büyüdüğü ve DNA'sını kopyaladığı uzun bir **interfaz** ile ikiye bölündüğü kısa bir **mitozdan** oluşur."),
                .figure(.cycle(title: "Hücre döngüsü", nodes: ["G1: büyüme", "S: DNA eşlenmesi", "G2: hazırlık", "M: mitoz ve sitokinez"])),
                .paragraph("**G1** evresi (İngilizce *gap*, yani ara) hücrenin büyüdüğü ve normal işlevlerini sürdürdüğü evredir. **S** (sentez) evresinde bütün DNA'sını eşler. **G2** evresinde kopyayı denetler ve bölünmeye hazırlanır. **M** evresi mitozun kendisidir; ardından sitoplazmayı paylaştıran **sitokinez** gelir."),
                .bars(title: "Kültürdeki bir insan hücresinde evrelerin süresi", unit: "sa", bars: [
                    DemoBar(label: "G1", value: 11),
                    DemoBar(label: "S", value: 8),
                    DemoBar(label: "G2", value: 4),
                    DemoBar(label: "M", value: 1),
                ]),
                .paragraph("Yaklaşık 24 saatlik bir döngüde mitoz yalnızca bir saat sürer. Bu yüzden bir mikroskop preparatında hücrelerin büyük çoğunluğu interfazdadır: her evrede gözlenen hücrelerin oranı ==o evrenin süresini yansıtır==. Nöronlar gibi pek çok hücre döngüden çıkarak G0 denen bir dinlenme evresine bile geçer ve artık bölünmez."),
                .heading("Kromozomlar ve kromatitler"),
                .callout(
                    title: "Kromozom ve kromatit",
                    text: "**Kromozom**, proteinlerle birleşmiş bir DNA molekülüdür. S evresinden sonra her kromozom, bir **sentromerle** birbirine bağlı iki özdeş kopyadan, yani **iki kardeş kromatitten** oluşur. Kromozom yine **tek** bir kromozomdur, ama iki kromatitlidir.",
                    tone: .definition
                ),
                .paragraph("Dolayısıyla bir hücrenin DNA miktarı döngüyü izler. G1'deki bir hücrenin DNA miktarına $Q$ diyelim. S evresi boyunca bu miktar giderek iki katına çıkar ve $2Q$'ya ulaşır. Mitozun sonunda her yavru hücre $Q$ ile yola devam eder. DNA miktarının zamana göre eğrisi, S evresinde yükselen ve bölünmede birden inen bir merdiven biçimindedir."),
                .formula("Q \\;\\to\\; 2Q \\;\\to\\; Q", caption: "Hücre başına DNA miktarı: S evresinde iki katına çıkar, mitozda paylaştırılır"),
                .paragraph("Kromozom sayısı ise S evresinde değişmez: bir insan hücresinde G1'de 46 kromozom vardır, G2'de de yine 46 — ama her biri iki kromatitlidir. Bu ==2n = 46== olarak gösterilir: $n$ bir takımdaki kromozom sayısıdır (insanda 23) ve vücut hücrelerinde biri anneden, diğeri babadan gelen iki takım bulunur."),
                .callout(
                    title: "Klasik hata",
                    text: "Eşlenmenin kromozom sayısını iki katına çıkardığını sanmak. Eşlenme kromozom sayısını değil, **DNA miktarını** iki katına çıkarır: tek kromatitli 46 kromozom, iki kromatitli 46 kromozoma dönüşür. Sayı yalnızca bir anlığına, anafazda kromatitler ayrıldığında iki katına çıkar.",
                    tone: .warning
                ),
                .list([
                    "G1: büyüme, tek kromatitli kromozomlar, DNA miktarı Q",
                    "S: eşlenme, DNA miktarı Q'dan 2Q'ya çıkar",
                    "G2: iki kromatitli kromozomlar, kopyanın denetlenmesi",
                    "M: mitoz, her yavru hücre Q alır",
                ]),
                .paragraph("Bir evreden diğerine geçiş otomatik değildir: hücrenin devam etmeden önce her şeyin yolunda olduğunu denetlediği **kontrol noktaları** tarafından yönetilir — S evresinden önce DNA'nın sağlam olduğunu, mitozdan önce tamamen kopyalandığını. Bu noktaların keşfi 2001'de Hartwell, Hunt ve Nurse'e Nobel Ödülü kazandırmıştır ve kansere kapıyı açan, onların işlev bozukluğudur."),
            ]),
            DemoChapter(title: "Mitozun evreleri", blocks: [
                .paragraph("Mitoz, bir hücrenin ana hücreyle ==genetik olarak özdeş iki yavru hücreye== bölünmesidir. Amacını söylemek kolay, gerçekleştirmek ise zordur: 46 kromozomun her birinin tam olarak bir kopyasını, hiçbirini kaybetmeden ya da çoğaltmadan, iki hücrenin her birine dağıtmak."),
                .figure(.flow(title: "Mitozun aşamaları", steps: ["Profaz: kromozomlar yoğunlaşır", "Metafaz: ekvator düzleminde dizilirler", "Anafaz: kardeş kromatitler ayrılır", "Telofaz: iki çekirdek yeniden oluşur", "Sitokinez: iki yavru hücre"])),
                .paragraph("Her evrenin mikroskopta görülebilen işaretleri vardır ve sizden bir fotoğraf üzerinde tanımanız istenecek olan bunlardır. Tablo bunları bir araya getirir; kromozomları hücrenin ortasında bir asker sırası gibi dizilmiş olan metafaz, tanınması en kolay evredir."),
                .table(title: "Her evrede görülenler", headers: ["Evre", "Ne olur"], rows: [
                    ["Profaz", "Kromozomlar yoğunlaşır ve görünür hâle gelir; çekirdek zarı kaybolur; iğ iplikleri oluşur"],
                    ["Metafaz", "İki kromatitli kromozomlar, sentromerleriyle iğ ipliklerine tutunarak ekvator düzleminde dizilir"],
                    ["Anafaz", "Kardeş kromatitler ayrılır ve zıt kutuplara göç eder: her kutup tek kromatitli 46 kromozom alır"],
                    ["Telofaz", "Kromozomlar gevşer; her grubun çevresinde yeniden bir çekirdek zarı oluşur"],
                ]),
                .paragraph("**İğ iplikleri** bütün bunları mümkün kılan makinedir: hücrenin iki kutbu arasında gerilmiş, mikrotübül adı verilen protein liflerinden oluşan bir ağ. Sentromerlere tutunur, kromozomları dizer, ardından kısalarak kromatitleri kutuplara çeker. Bir kontrol noktası, tek bir kromozom bile doğru biçimde tutunmadıkça anafazı engeller."),
                .callout(
                    title: "Mitozun sonucu",
                    text: "2n = 46 kromozomlu bir ana hücre, tam olarak aynı genetik bilgiyi taşıyan **2n = 46 kromozomlu iki yavru hücre** oluşturur. Mitoz **eşeysiz, aynısını üreten bir çoğalmadır**: büyümeyi, dokuların yenilenmesini ve yaraların iyileşmesini sağlayan odur.",
                    tone: .insight
                ),
                .paragraph("Sitokinez hücre tipine göre farklılık gösterir. Hayvan hücresi, kasılabilen proteinlerden oluşan bir halka sayesinde, sıkıştırılan bir balon gibi ortasından boğumlanır. Sert duvarının içinde tutsak olan bitki hücresi boğumlanamaz: ortada, içeriden dışarıya doğru yeni bir duvar inşa eder."),
                .figure(.split(
                    title: "Bölünmenin iki yolu",
                    left: DemoColumn(title: "Hayvan hücresi", items: ["Kutuplarda sentrozomlar", "Kasılabilen halka", "Sitoplazmanın boğumlanması"]),
                    right: DemoColumn(title: "Bitki hücresi", items: ["Sentrozom yok", "Sert duvar", "Ortada inşa edilen yeni duvar"])
                )),
                .paragraph("Her bölünme hücre sayısını iki katına çıkarır. Bir hücreden başlayarak bir bölünmeden sonra 2, iki bölünmeden sonra 4, üç bölünmeden sonra 8 hücre olur: büyüme **üsteldir**. $k$ bölünmeden sonra $N_0$ hücrelik bir topluluk $N_0 \\times 2^k$ hücreye ulaşır."),
                .formula("N = N_0 \\times 2^k", caption: "Hepsi bölünürse, art arda k bölünmeden sonraki hücre sayısı"),
                .paragraph("On bölünme şimdiden $2^{10} = 1\\,024$ hücre verir; kırk beş bölünme ise yaklaşık 35 000 milyar — bir insan vücudunun büyüklük mertebesi. Gerçekte bir organizmanın hücrelerinin hepsi bölünmez ve pek çoğu ölür: sağlıklı bir dokunun büyümesi, organizmanın sürekli düzenlediği bir ==bölünmeler ile hücre ölümleri arasındaki dengedir==."),
            ]),
            DemoChapter(title: "Mayoz, mitoz ve kanser", blocks: [
                .paragraph("Mitoz aynı kopyalar üretir. Ama eşeyli üreme için başka bir şey gerekir: döllenmede yumurta ve spermin iki takımlı bir hücreyi yeniden oluşturabilmesi için yalnızca tek bir kromozom takımına sahip hücreler. Bu, yalnızca üreme organlarında (gonadlarda) gerçekleşen **mayozun** görevidir."),
                .table(title: "Mitoz ve mayoz karşı karşıya", headers: ["", "Mitoz", "Mayoz"], rows: [
                    ["Nerede", "Vücudun neredeyse bütün hücrelerinde", "Gonadlardaki üreme hücrelerinde"],
                    ["Bölünme", "Bir", "Art arda iki"],
                    ["Oluşan hücre", "2", "4"],
                    ["Kromozom", "2n = 46, ana hücre gibi", "n = 23, yarısı kadar"],
                    ["Genetik bilgi", "Ana hücreyle özdeş", "Hücreden hücreye farklı"],
                    ["Görevi", "Büyüme, yenilenme", "Gamet oluşumu"],
                ]),
                .paragraph("Mayozun birinci bölünmesi **homolog** kromozomları — her çiftin anneden ve babadan gelen kromozomlarını — birbirinden ayırır; kromozom sayısını yarıya indirir. İkinci bölünme ise bir mitoz gibi kardeş kromatitleri ayırır. Bu sırada mayoz ==genetik bilgiyi iki yolla karıştırır==."),
                .formula("2^{23} \\approx 8{,}4 \\times 10^{6}", caption: "Yalnızca kromozomlar arası karışımla bir insan gametinde mümkün olan kromozom kombinasyonlarının sayısı"),
                .paragraph("**Kromozomlar arası karışım**, her çiftin diğerlerinden bağımsız olarak ayrılmasından kaynaklanır: 23 çiftin her biri için gamet anneden ya da babadan gelen homoloğu alır; buradan $2^{23}$, yani sekiz milyondan fazla kombinasyon çıkar. Homologlar arasında *krossing-over* denen parça değişimleriyle gerçekleşen **kromozom içi karışım** bu sayıyı daha da artırır. Tek yumurta ikizleri dışında iki kardeş asla aynı kombinasyonu almaz."),
                .heading("Bölünme denetimden çıktığında"),
                .paragraph("Sağlıklı bir organizmada her hücre yalnızca bir sinyal aldığında bölünür ve kendisinden istendiğinde durur. Bu denetimi iki gen ailesi düzenler. **Proto-onkogenler** bir gaz pedalı gibi çalışır: hücreyi bölünmeye iter. **Tümör baskılayıcı genler** ise bir fren gibi çalışır: bir sorun olduğunda döngüyü durdurur."),
                .callout(
                    title: "Kanser",
                    text: "Mutasyon biriktirmiş hücrelerin **denetimsiz çoğalmasından** kaynaklanan bir hastalık: takılı kalmış bir gaz pedalı (**onkogene** dönüşmüş bir proto-onkogen) ve bozuk frenler (etkisizleşmiş baskılayıcı genler). Hücreler bir tümör oluşturur, ardından komşu dokuları istila edip uzak bölgelere yayılabilir: bunlar **metastazlardır**.",
                    tone: .definition
                ),
                .paragraph("Frenlerin en ünlüsü, “genomun koruyucusu” lakaplı **p53** proteinidir: DNA hasar gördüğünde onarım süresince döngüyü durdurur ya da hasar çok ağırsa hücrenin intiharını başlatır. Onu kodlayan gen, insan kanserlerinin yaklaşık yarısında mutasyona uğramıştır. Bir hücrenin kanserleşmesi için genellikle yıllar içinde biriken ==art arda birkaç mutasyon== gerekir — riskin yaşla birlikte artmasının nedeni budur."),
                .keyFigure(value: "≈ 30", label: "tek bir hücrenin bir santimetrelik bir tümöre, yani yaklaşık bir milyar hücreye dönüşmesi için gereken ikiye katlanma sayısı (2³⁰ ≈ 1,07 × 10⁹)"),
                .paragraph("Demek ki bir tümör ancak uzun ve sessiz bir geçmişin ardından saptanabilir: bir santimetreye ulaşmak için otuz ikiye katlanma gerekirken on tane daha onu bin katına çıkarmaya yeter. **Taramanın** bütün amacı budur: tümörü bu üstel eğri üzerinde mümkün olduğunca erken, henüz küçük ve sınırlıyken yakalamak."),
                .callout(
                    title: "Kemoterapi neden saç döktürür",
                    text: "Kemoterapilerin çoğu DNA eşlenmesini ya da iğ ipliklerini engelleyerek **bölünen** hücreleri hedef alır. Dolayısıyla hızla bölünen sağlıklı hücreleri de etkiler: saç kökleri, bağırsak mukozası, kemik iliği. Yan etkiler, hedefin doğrudan sonucudur.",
                    tone: .warning
                ),
                .list([
                    "Tütün: Fransa'da önlenebilir kanserlerin birinci nedeni",
                    "Alkol, fazla kilo, hareketsizlik: başlıca risk etkenleri",
                    "UV ışınları: özellikle çocuklukta yaşanan güneş yanıkları melanoma zemin hazırlar",
                    "Bazı virüsler: aşısı bulunan insan papilloma virüsü",
                ]),
                .paragraph("Bütün bu etkenler aynı biçimde işler: bölünen hücrelerdeki mutasyon sayısını artırır. Dolayısıyla mitozu anlamak, hem ==vücudun nasıl inşa edildiğini ve kendini nasıl onardığını==, hem de aynı makinenin bazen nasıl bozulduğunu anlamaktır."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Hücre döngüsünün evreleri nelerdir?",
                back: "G1 (büyüme), S (DNA eşlenmesi) ve G2'den (hazırlık) oluşan interfaz, ardından M evresi: mitoz ve onu izleyen sitokinez.",
                figure: .cycle(title: "Hücre döngüsü", nodes: ["G1", "S", "G2", "M"]),
                chapter: 1
            ),
            DemoCard(
                kind: .choice,
                front: "Mitozun hangi evresinde kardeş kromatitler birbirinden ayrılır?",
                back: "Anafaz: kardeş kromatitler zıt kutuplara göç eder ve her kutup her türden tek kromatitli bir kromozom alır.",
                choices: ["Profaz", "Metafaz", "Anafaz", "Telofaz"],
                answerIndex: 2,
                chapter: 2
            ),
            DemoCard(
                kind: .cloze,
                front: "Bir hücrenin DNA'sı interfazın … evresinde eşlenir.",
                back: "S",
                chapter: 1
            ),
            DemoCard(kind: .basic, front: "Prokaryot ile ökaryot arasındaki fark nedir?", back: "Prokaryotun (bir bakteri) çekirdeği yoktur: DNA'sı sitoplazmadadır. Ökaryotun ise DNA'sını çevreleyen bir çekirdeği ve organelleri vardır.", chapter: 0),
            DemoCard(kind: .choice, front: "Hücrenin ATP'sinin büyük kısmını hangi organel üretir?", back: "Hücresel solunumun gerçekleştiği mitokondri.", choices: ["Çekirdek", "Mitokondri", "Ribozom", "Golgi aygıtı"], answerIndex: 1, chapter: 0),
            DemoCard(kind: .cloze, front: "S evresinden sonra her kromozom, bir sentromerle birbirine bağlı iki kardeş … içerir.", back: "kromatit", chapter: 1),
            DemoCard(kind: .basic, front: "Hücre döngüsü boyunca kromozom sayısı ve DNA miktarı nasıl değişir?", back: "DNA miktarı S evresinde iki katına çıkar (Q'dan 2Q'ya) ve bölünmede yeniden Q'ya iner. Kromozom sayısı 46 olarak kalır: kromozomlar tek kromatitliden iki kromatitliye geçer.", hint: "DNA miktarını ve kromozom sayısını birbirinden ayırın.", chapter: 1),
            DemoCard(kind: .choice, front: "Mayoz bir insan hücresinden kaç hücre ve kaçar kromozomlu hücre oluşturur?", back: "n = 23 kromozomlu, birbirinden genetik olarak farklı dört hücre.", choices: ["46 kromozomlu 2 hücre", "23 kromozomlu 2 hücre", "23 kromozomlu 4 hücre", "46 kromozomlu 4 hücre"], answerIndex: 2, chapter: 3),
            DemoCard(kind: .cloze, front: "… evresinde kromozomlar ekvator düzleminde dizilir.", back: "Metafaz", chapter: 2),
            DemoCard(kind: .basic, front: "Hücre ölçeğinde kanser nedir?", back: "Mutasyon biriktirmiş hücrelerin denetimsiz çoğalması: onkogene dönüşmüş proto-onkogenler (takılı kalmış gaz pedalı) ve etkisizleşmiş tümör baskılayıcı genler (bozuk frenler).", chapter: 3),
            DemoCard(kind: .choice, front: "Bir insan gameti yalnızca kromozomlar arası karışımla kaç farklı kromozom kombinasyonu alabilir?", back: "$2^{23}$, yani yaklaşık 8,4 milyon: 23 çiftin her biri diğerlerinden bağımsız olarak ayrılır.", choices: ["23", "46", "$2^{23}$, yaklaşık 8,4 milyon", "$23^2$, yani 529"], answerIndex: 2, chapter: 3),
            DemoCard(kind: .cloze, front: "Mitoz, ana hücreyle genetik olarak … iki yavru hücre oluşturur.", back: "özdeş", chapter: 2),
        ]
    )
}
#endif
