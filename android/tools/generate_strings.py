#!/usr/bin/env python3
"""
**Les textes de l'app Android, tirés des catalogues de l'app iPhone.**

Le script lit les noms `R.string.*` utilisés par le code Kotlin, retrouve chaque phrase dans les
catalogues Swift (`Micabo/Services/I18n` : `SharedI18nCatalogs`, `IosI18nCatalogs`,
`LessonI18nCatalogs` et les 21 langues régionales de `Locales/`), et écrit un
`res/values-*/strings.xml` par langue. `lesson.notes.callout.why` devient
`lesson_notes_callout_why` ; les phrases propres à Android (préfixe `x_`) sont dans `CUSTOM`
ci-dessous. Les variables `{n}` deviennent `%1$s`, dans l'ordre de la phrase anglaise.
Une clé du catalogue que l'iPhone ne traduit pas encore dans une langue prend sa phrase dans
`FILL`, et les pluriels que l'iPhone ne sait pas dire (`few`, `two`…) dans `PLURALS_ANDROID`.

Relancer après avoir ajouté un `R.string.…` dans le code :

    python3 android/tools/generate_strings.py
"""
from __future__ import annotations

import pathlib
import re
import sys
from xml.sax.saxutils import escape

ROOT = pathlib.Path(__file__).resolve().parents[2]
I18N = ROOT / "Micabo" / "Services" / "I18n"
SOURCES = ROOT / "android" / "app" / "src" / "main" / "java"
RES = ROOT / "android" / "app" / "src" / "main" / "res"

# Le nom de la table Swift → le dossier Android.
LOCALES = {
    "en": "values",
    "fr": "values-fr",
    "de": "values-de",
    "es": "values-es",
    "es419": "values-b+es+419",
    "it": "values-it",
    "pt": "values-pt",
    "ptBR": "values-pt-rBR",
    "nl": "values-nl",
    "pl": "values-pl",
    "ro": "values-ro",
    "sv": "values-sv",
    "da": "values-da",
    "fi": "values-fi",
    "et": "values-et",
    "cs": "values-cs",
    "sk": "values-sk",
    "hu": "values-hu",
    "hr": "values-hr",
    "sl": "values-sl",
    "sr": "values-sr",
    "bg": "values-bg",
    "el": "values-el",
    "ru": "values-ru",
    "tr": "values-tr",
    "ar": "values-ar",
}

# Les phrases propres à Android. L'anglais est la langue de base ; une langue absente lit l'anglais.
CUSTOM: dict[str, dict[str, str]] = {
    "x_onb_language": {
        "en": "Which language do you study in?",
        "fr": "Dans quelle langue tu étudies ?",
        "de": "In welcher Sprache lernst du?",
        "es": "¿En qué idioma estudias?",
        "es419": "¿En qué idioma estudias?",
        "it": "In che lingua studi?",
        "pt": "Em que língua estudas?",
        "ptBR": "Em que idioma você estuda?",
        "nl": "In welke taal studeer je?",
        "pl": "W jakim języku się uczysz?",
        "ro": "În ce limbă înveți?",
        "sv": "Vilket språk pluggar du på?",
        "da": "Hvilket sprog studerer du på?",
        "fi": "Millä kielellä opiskelet?",
        "et": "Mis keeles sa õpid?",
        "cs": "V jakém jazyce studuješ?",
        "sk": "V akom jazyku študuješ?",
        "hu": "Milyen nyelven tanulsz?",
        "hr": "Na kojem jeziku učiš?",
        "sl": "V katerem jeziku se učiš?",
        "sr": "Na kom jeziku učiš?",
        "bg": "На какъв език учиш?",
        "el": "Σε ποια γλώσσα διαβάζεις;",
        "ru": "На каком языке ты учишься?",
        "tr": "Hangi dilde çalışıyorsun?",
        "ar": "بأي لغة تدرس؟",
    },
    "x_onb_language_sub": {
        "en": "Mika writes your lessons, quizzes and flashcards in this language.",
        "fr": "Mika écrit tes leçons, tes quiz et tes flashcards dans cette langue.",
        "de": "Mika schreibt deine Lektionen, Quizze und Karteikarten in dieser Sprache.",
        "es": "Mika escribe tus lecciones, quizzes y tarjetas en este idioma.",
        "es419": "Mika escribe tus lecciones, quizzes y tarjetas en este idioma.",
        "it": "Mika scrive lezioni, quiz e flashcard in questa lingua.",
        "pt": "O Mika escreve as tuas lições, quizzes e flashcards nesta língua.",
        "ptBR": "O Mika escreve suas aulas, quizzes e flashcards neste idioma.",
        "nl": "Mika schrijft je lessen, quizzen en flashcards in deze taal.",
        "pl": "Mika pisze twoje lekcje, quizy i fiszki w tym języku.",
        "ro": "Mika îți scrie lecțiile, quizurile și cardurile în această limbă.",
        "sv": "Mika skriver dina lektioner, quizzar och kort på det här språket.",
        "da": "Mika skriver dine lektioner, quizzer og kort på dette sprog.",
        "fi": "Mika kirjoittaa oppituntisi, visasi ja korttisi tällä kielellä.",
        "et": "Mika kirjutab sinu tunnid, viktoriinid ja mälukaardid selles keeles.",
        "cs": "Mika ti v tomto jazyce napíše lekce, kvízy a kartičky.",
        "sk": "Mika ti v tomto jazyku napíše lekcie, kvízy a kartičky.",
        "hu": "Mika ezen a nyelven írja meg a leckéidet, kvízeidet és kártyáidat.",
        "hr": "Mika na ovom jeziku piše tvoje lekcije, kvizove i kartice.",
        "sl": "Mika v tem jeziku napiše tvoje lekcije, kvize in kartice.",
        "sr": "Mika na ovom jeziku piše tvoje lekcije, kvizove i kartice.",
        "bg": "Mika пише уроците, тестовете и флашкартите ти на този език.",
        "el": "Ο Mika γράφει τα μαθήματα, τα κουίζ και τις κάρτες σου σε αυτή τη γλώσσα.",
        "ru": "Mika пишет твои уроки, тесты и карточки на этом языке.",
        "tr": "Mika derslerini, testlerini ve kartlarını bu dilde yazar.",
        "ar": "يكتب Mika دروسك واختباراتك وبطاقاتك بهذه اللغة.",
    },
    "x_onb_start": {
        "en": "Let's go!",
        "fr": "C'est parti !",
        "de": "Los geht's!",
        "es": "¡Vamos!",
        "es419": "¡Vamos!",
        "it": "Si parte!",
        "pt": "Vamos!",
        "ptBR": "Vamos lá!",
        "nl": "Aan de slag!",
        "pl": "Zaczynamy!",
        "tr": "Hadi başlayalım!",
    },
    "x_score_1": {
        "en": "I'm struggling",
        "fr": "J'ai du mal",
        "de": "Ich tue mich schwer",
        "es": "Me cuesta",
        "es419": "Me cuesta",
        "it": "Faccio fatica",
        "pt": "Tenho dificuldades",
        "ptBR": "Tenho dificuldade",
        "nl": "Ik heb het moeilijk",
        "pl": "Mam trudności",
        "ro": "Mi-e greu",
        "sv": "Jag kämpar",
        "da": "Jeg har det svært",
        "fi": "Minulla on vaikeaa",
        "et": "Mul on raske",
        "cs": "Moc mi to nejde",
        "sk": "Veľmi mi to nejde",
        "hu": "Nehezen megy",
        "hr": "Teško mi ide",
        "sl": "Težko mi gre",
        "sr": "Teško mi ide",
        "bg": "Трудно ми е",
        "el": "Δυσκολεύομαι",
        "ru": "Мне тяжело",
        "tr": "Zorlanıyorum",
        "ar": "أواجه صعوبة",
    },
    "x_score_2": {
        "en": "Just below average",
        "fr": "Un peu en dessous de la moyenne",
        "de": "Knapp unter dem Durchschnitt",
        "es": "Un poco por debajo de la media",
        "es419": "Un poco por debajo del promedio",
        "it": "Poco sotto la media",
        "pt": "Um pouco abaixo da média",
        "ptBR": "Um pouco abaixo da média",
        "nl": "Net onder het gemiddelde",
        "pl": "Trochę poniżej średniej",
        "ro": "Puțin sub medie",
        "sv": "Strax under snittet",
        "da": "Lige under gennemsnittet",
        "fi": "Vähän keskiarvon alapuolella",
        "et": "Veidi alla keskmise",
        "cs": "Trochu pod průměrem",
        "sk": "Trochu pod priemerom",
        "hu": "Kicsit átlag alatt",
        "hr": "Malo ispod prosjeka",
        "sl": "Malo pod povprečjem",
        "sr": "Malo ispod proseka",
        "bg": "Малко под средното",
        "el": "Λίγο κάτω από τον μέσο όρο",
        "ru": "Чуть ниже среднего",
        "tr": "Ortalamanın biraz altında",
        "ar": "أقل قليلًا من المتوسط",
    },
    "x_score_3": {
        "en": "Average",
        "fr": "Dans la moyenne",
        "de": "Durchschnittlich",
        "es": "En la media",
        "es419": "En el promedio",
        "it": "Nella media",
        "pt": "Na média",
        "ptBR": "Na média",
        "nl": "Gemiddeld",
        "pl": "Średnio",
        "ro": "În medie",
        "sv": "Medel",
        "da": "Gennemsnitlig",
        "fi": "Keskitasoa",
        "et": "Keskmine",
        "cs": "Průměr",
        "sk": "Priemer",
        "hu": "Átlagos",
        "hr": "Prosječno",
        "sl": "Povprečno",
        "sr": "Prosečno",
        "bg": "Средно",
        "el": "Στον μέσο όρο",
        "ru": "Средне",
        "tr": "Ortalama",
        "ar": "متوسط",
    },
    "x_score_4": {
        "en": "Good",
        "fr": "Bien",
        "de": "Gut",
        "es": "Bien",
        "es419": "Bien",
        "it": "Bene",
        "pt": "Bom",
        "ptBR": "Bom",
        "nl": "Goed",
        "pl": "Dobrze",
        "ro": "Bine",
        "sv": "Bra",
        "da": "God",
        "fi": "Hyvä",
        "et": "Hea",
        "cs": "Dobře",
        "sk": "Dobre",
        "hu": "Jó",
        "hr": "Dobro",
        "sl": "Dobro",
        "sr": "Dobro",
        "bg": "Добре",
        "el": "Καλά",
        "ru": "Хорошо",
        "tr": "İyi",
        "ar": "جيد",
    },
    "x_score_5": {
        "en": "Top of the class",
        "fr": "Parmi les meilleurs",
        "de": "Unter den Besten",
        "es": "Entre los mejores",
        "es419": "Entre los mejores",
        "it": "Tra i migliori",
        "pt": "Entre os melhores",
        "ptBR": "Entre os melhores",
        "nl": "Bij de besten",
        "pl": "W czołówce",
        "ro": "Printre cei mai buni",
        "sv": "Bland de bästa",
        "da": "Blandt de bedste",
        "fi": "Parhaiden joukossa",
        "et": "Parimate seas",
        "cs": "Mezi nejlepšími",
        "sk": "Medzi najlepšími",
        "hu": "A legjobbak között",
        "hr": "Među najboljima",
        "sl": "Med najboljšimi",
        "sr": "Među najboljima",
        "bg": "Сред най-добрите",
        "el": "Στους καλύτερους",
        "ru": "Среди лучших",
        "tr": "En iyiler arasında",
        "ar": "من الأوائل",
    },
    "x_lessons_emptyBody": {
        "en": "Type a topic above, or paste your notes: Mika turns it into a path.",
        "fr": "Tape un sujet plus haut, ou colle tes notes : Mika en fait un parcours.",
        "de": "Gib oben ein Thema ein oder füge deine Notizen ein: Mika macht daraus einen Lernpfad.",
        "es": "Escribe un tema arriba o pega tus apuntes: Mika lo convierte en un recorrido.",
        "es419": "Escribe un tema arriba o pega tus apuntes: Mika lo convierte en un recorrido.",
        "it": "Scrivi un argomento qui sopra o incolla i tuoi appunti: Mika lo trasforma in un percorso.",
        "pt": "Escreve um tema acima ou cola os teus apontamentos: o Mika transforma-o num percurso.",
        "ptBR": "Digite um tema acima ou cole suas anotações: o Mika transforma em uma trilha.",
        "tr": "Yukarıya bir konu yaz ya da notlarını yapıştır: Mika onu bir yola dönüştürür.",
    },
    "x_paste_tooShort": {
        "en": "A few more lines, and Mika can work with it.",
        "fr": "Encore quelques lignes, et Mika pourra s'en servir.",
        "de": "Noch ein paar Zeilen, dann kann Mika damit arbeiten.",
        "es": "Unas líneas más y Mika podrá trabajar con ello.",
        "es419": "Unas líneas más y Mika podrá trabajar con eso.",
        "it": "Ancora qualche riga e Mika potrà usarlo.",
        "pt": "Mais umas linhas e o Mika já consegue trabalhar.",
        "ptBR": "Mais algumas linhas e o Mika consegue trabalhar.",
        "nl": "Nog een paar regels, dan kan Mika ermee aan de slag.",
        "pl": "Jeszcze kilka linijek i Mika się tym zajmie.",
        "ro": "Încă câteva rânduri și Mika se poate apuca de treabă.",
        "sv": "Några rader till, så kan Mika jobba med det.",
        "da": "Et par linjer mere, så kan Mika arbejde med det.",
        "fi": "Vielä muutama rivi, niin Mika voi työstää sitä.",
        "et": "Veel paar rida ja Mika saab sellega tööle hakata.",
        "cs": "Ještě pár řádků a Mika s tím bude moct pracovat.",
        "sk": "Ešte pár riadkov a Mika s tým bude môcť pracovať.",
        "hu": "Még néhány sor, és Mika már tud vele dolgozni.",
        "hr": "Još nekoliko redaka i Mika će moći raditi s tim.",
        "sl": "Še nekaj vrstic in Mika bo lahko delal s tem.",
        "sr": "Još nekoliko redova i Mika će moći da radi s tim.",
        "bg": "Още няколко реда и Mika ще може да работи с тях.",
        "el": "Λίγες γραμμές ακόμα και ο Mika θα μπορεί να δουλέψει με αυτό.",
        "ru": "Ещё пара строк, и Mika сможет с этим работать.",
        "tr": "Birkaç satır daha, Mika bununla çalışabilir.",
        "ar": "بضعة أسطر أخرى، وسيتمكن Mika من العمل عليها.",
    },
    "x_error_network": {
        "en": "No connection. Check your internet and try again.",
        "fr": "Pas de connexion. Vérifie ton internet et réessaie.",
        "de": "Keine Verbindung. Prüfe dein Internet und versuch es noch einmal.",
        "es": "Sin conexión. Revisa tu internet e inténtalo de nuevo.",
        "es419": "Sin conexión. Revisa tu internet e inténtalo de nuevo.",
        "it": "Nessuna connessione. Controlla internet e riprova.",
        "pt": "Sem ligação. Verifica a internet e tenta de novo.",
        "ptBR": "Sem conexão. Verifique sua internet e tente de novo.",
        "nl": "Geen verbinding. Controleer je internet en probeer het opnieuw.",
        "pl": "Brak połączenia. Sprawdź internet i spróbuj ponownie.",
        "ro": "Nu există conexiune. Verifică internetul și încearcă din nou.",
        "sv": "Ingen anslutning. Kolla ditt internet och försök igen.",
        "da": "Ingen forbindelse. Tjek dit internet, og prøv igen.",
        "fi": "Ei yhteyttä. Tarkista nettiyhteys ja yritä uudelleen.",
        "et": "Ühendus puudub. Kontrolli internetti ja proovi uuesti.",
        "cs": "Žádné připojení. Zkontroluj internet a zkus to znovu.",
        "sk": "Žiadne pripojenie. Skontroluj internet a skús to znova.",
        "hu": "Nincs kapcsolat. Ellenőrizd az internetet, és próbáld újra.",
        "hr": "Nema veze. Provjeri internet i pokušaj ponovno.",
        "sl": "Ni povezave. Preveri internet in poskusi znova.",
        "sr": "Nema veze. Proveri internet i pokušaj ponovo.",
        "bg": "Няма връзка. Провери интернета си и опитай пак.",
        "el": "Δεν υπάρχει σύνδεση. Έλεγξε το ίντερνετ και δοκίμασε ξανά.",
        "ru": "Нет соединения. Проверь интернет и попробуй ещё раз.",
        "tr": "Bağlantı yok. İnternetini kontrol edip tekrar dene.",
        "ar": "لا يوجد اتصال. تحقّق من الإنترنت وحاول مجددًا.",
    },
    "x_paywall_soon": {
        "en": "Coming soon on Android",
        "fr": "Bientôt disponible sur Android",
        "de": "Bald auf Android verfügbar",
        "es": "Muy pronto en Android",
        "es419": "Muy pronto en Android",
        "it": "Presto disponibile su Android",
        "pt": "Brevemente no Android",
        "ptBR": "Em breve no Android",
        "nl": "Binnenkort op Android",
        "pl": "Wkrótce na Androidzie",
        "ro": "În curând pe Android",
        "sv": "Kommer snart till Android",
        "da": "Kommer snart på Android",
        "fi": "Tulossa pian Androidille",
        "et": "Varsti Androidis",
        "cs": "Brzy na Androidu",
        "sk": "Čoskoro na Androide",
        "hu": "Hamarosan Androidon",
        "hr": "Uskoro na Androidu",
        "sl": "Kmalu na Androidu",
        "sr": "Uskoro na Androidu",
        "bg": "Скоро на Android",
        "el": "Σύντομα στο Android",
        "ru": "Скоро на Android",
        "tr": "Yakında Android'de",
        "ar": "قريبًا على Android",
    },
    "x_paywall_soonBody": {
        "en": "Subscriptions open on Android very soon. Your free lesson is waiting for you in the meantime.",
        "fr": "Les abonnements arrivent très bientôt sur Android. En attendant, ta leçon offerte t'attend.",
        "de": "Abos gibt es sehr bald auf Android. Bis dahin wartet deine kostenlose Lektion auf dich.",
        "es": "Las suscripciones llegan muy pronto a Android. Mientras tanto, tu lección gratis te espera.",
        "es419": "Las suscripciones llegan muy pronto a Android. Mientras tanto, tu lección gratis te espera.",
        "it": "Gli abbonamenti arrivano prestissimo su Android. Intanto, la tua lezione gratuita ti aspetta.",
        "pt": "As subscrições chegam muito em breve ao Android. Até lá, a tua lição grátis espera por ti.",
        "ptBR": "As assinaturas chegam muito em breve ao Android. Enquanto isso, sua aula grátis te espera.",
        "nl": "Abonnementen komen heel binnenkort naar Android. Je gratis les wacht intussen op je.",
        "pl": "Subskrypcje już wkrótce na Androidzie. W międzyczasie czeka na ciebie darmowa lekcja.",
        "ro": "Abonamentele ajung foarte curând pe Android. Între timp, lecția ta gratuită te așteaptă.",
        "sv": "Prenumerationer kommer till Android väldigt snart. Under tiden väntar din gratislektion på dig.",
        "da": "Abonnementer kommer til Android meget snart. Indtil da venter din gratis lektion på dig.",
        "fi": "Tilaukset tulevat Androidille aivan pian. Sillä välin ilmainen oppituntisi odottaa sinua.",
        "et": "Tellimused jõuavad Androidi väga varsti. Seni ootab sind sinu tasuta tund.",
        "cs": "Předplatné bude na Androidu už brzy. Mezitím na tebe čeká tvoje lekce zdarma.",
        "sk": "Predplatné bude na Androide už čoskoro. Medzitým na teba čaká tvoja lekcia zadarmo.",
        "hu": "Az előfizetés hamarosan elérhető Androidon. Addig is vár az ingyenes leckéd.",
        "hr": "Pretplate na Androidu stižu vrlo brzo. U međuvremenu te čeka tvoja besplatna lekcija.",
        "sl": "Naročnine bodo na Androidu na voljo zelo kmalu. Medtem te čaka tvoja brezplačna lekcija.",
        "sr": "Pretplate na Androidu stižu vrlo brzo. U međuvremenu te čeka tvoja besplatna lekcija.",
        "bg": "Абонаментите идват съвсем скоро на Android. Дотогава безплатният ти урок те чака.",
        "el": "Οι συνδρομές έρχονται πολύ σύντομα στο Android. Μέχρι τότε, το δωρεάν μάθημά σου σε περιμένει.",
        "ru": "Подписки совсем скоро появятся на Android. А пока тебя ждёт бесплатный урок.",
        "tr": "Abonelikler çok yakında Android'de. Bu arada ücretsiz dersin seni bekliyor.",
        "ar": "الاشتراكات قادمة قريبًا جدًا على Android. وفي الأثناء، درسك المجاني بانتظارك.",
    },
    "x_paywall_finePrint": {
        "en": "{n} days free, then {price} per {unit}. Renews automatically, cancel anytime in Google Play.",
        "fr": "{n} jours offerts, puis {price} par {unit}. Renouvellement automatique, résiliable à tout moment dans Google Play.",
        "de": "{n} Tage gratis, danach {price} pro {unit}. Verlängert sich automatisch, jederzeit in Google Play kündbar.",
        "es": "{n} días gratis, luego {price} por {unit}. Se renueva automáticamente, cancela cuando quieras en Google Play.",
        "es419": "{n} días gratis, luego {price} por {unit}. Se renueva automáticamente, cancela cuando quieras en Google Play.",
        "it": "{n} giorni gratis, poi {price} ogni {unit}. Rinnovo automatico, disdici quando vuoi su Google Play.",
        "pt": "{n} dias grátis, depois {price} por {unit}. Renova automaticamente, cancela quando quiseres no Google Play.",
        "ptBR": "{n} dias grátis, depois {price} por {unit}. Renova automaticamente, cancele quando quiser no Google Play.",
        "nl": "{n} dagen gratis, daarna {price} per {unit}. Wordt automatisch verlengd, altijd op te zeggen in Google Play.",
        "pl": "{n} dni za darmo, potem {price} / {unit}. Odnawia się automatycznie, anulujesz w dowolnej chwili w Google Play.",
        "ro": "{n} zile gratuite, apoi {price} pe {unit}. Se reînnoiește automat, anulezi oricând din Google Play.",
        "sv": "{n} dagar gratis, sedan {price} per {unit}. Förnyas automatiskt, avsluta när du vill i Google Play.",
        "da": "{n} dage gratis, derefter {price} pr. {unit}. Fornyes automatisk, opsig når som helst i Google Play.",
        "fi": "{n} päivää ilmaiseksi, sitten {price} / {unit}. Uusiutuu automaattisesti, peru milloin tahansa Google Playssa.",
        "et": "{n} päeva tasuta, seejärel {price} / {unit}. Uueneb automaatselt, tühista igal ajal Google Plays.",
        "cs": "{n}denní zkouška zdarma, potom {price} za {unit}. Obnovuje se automaticky, zrušit můžeš kdykoli v Google Play.",
        "sk": "{n}-dňová skúška zadarmo, potom {price} za {unit}. Obnovuje sa automaticky, zrušiť môžeš kedykoľvek v Google Play.",
        "hu": "{n} nap ingyen, utána {price} / {unit}. Automatikusan megújul, bármikor lemondhatod a Google Playen.",
        "hr": "{n} dana besplatno, zatim {price} / {unit}. Automatski se obnavlja, otkaži bilo kada na Google Playu.",
        "sl": "{n}-dnevni brezplačni preizkus, nato {price} na {unit}. Samodejno se podaljša, prekličeš lahko kadar koli v Google Play.",
        "sr": "{n} dana besplatno, zatim {price} / {unit}. Automatski se obnavlja, otkaži bilo kada na Google Play-u.",
        "bg": "{n} дни безплатно, след това {price} на {unit}. Подновява се автоматично, можеш да се откажеш по всяко време в Google Play.",
        "el": "{n} μέρες δωρεάν, μετά {price} / {unit}. Ανανεώνεται αυτόματα, ακύρωσε όποτε θες στο Google Play.",
        "ru": "{n} дн. бесплатно, затем {price} в {unit}. Продлевается автоматически, отменить можно в любой момент в Google Play.",
        "tr": "{n} gün ücretsiz, ardından {unit} başına {price}. Otomatik yenilenir, Google Play'den istediğin zaman iptal et.",
        "ar": "أيام مجانية: {n}، ثم {price} لكل {unit}. يتجدد تلقائيًا، ويمكنك الإلغاء في أي وقت من Google Play.",
    },
    "x_paywall_finePrintNoTrial": {
        "en": "{price} per {unit}. Renews automatically, cancel anytime in Google Play.",
        "fr": "{price} par {unit}. Renouvellement automatique, résiliable à tout moment dans Google Play.",
        "de": "{price} pro {unit}. Verlängert sich automatisch, jederzeit in Google Play kündbar.",
        "es": "{price} por {unit}. Se renueva automáticamente, cancela cuando quieras en Google Play.",
        "es419": "{price} por {unit}. Se renueva automáticamente, cancela cuando quieras en Google Play.",
        "it": "{price} ogni {unit}. Rinnovo automatico, disdici quando vuoi su Google Play.",
        "pt": "{price} por {unit}. Renova automaticamente, cancela quando quiseres no Google Play.",
        "ptBR": "{price} por {unit}. Renova automaticamente, cancele quando quiser no Google Play.",
        "nl": "{price} per {unit}. Wordt automatisch verlengd, altijd op te zeggen in Google Play.",
        "pl": "{price} / {unit}. Odnawia się automatycznie, anulujesz w dowolnej chwili w Google Play.",
        "ro": "{price} pe {unit}. Se reînnoiește automat, anulezi oricând din Google Play.",
        "sv": "{price} per {unit}. Förnyas automatiskt, avsluta när du vill i Google Play.",
        "da": "{price} pr. {unit}. Fornyes automatisk, opsig når som helst i Google Play.",
        "fi": "{price} / {unit}. Uusiutuu automaattisesti, peru milloin tahansa Google Playssa.",
        "et": "{price} / {unit}. Uueneb automaatselt, tühista igal ajal Google Plays.",
        "cs": "{price} za {unit}. Obnovuje se automaticky, zrušit můžeš kdykoli v Google Play.",
        "sk": "{price} za {unit}. Obnovuje sa automaticky, zrušiť môžeš kedykoľvek v Google Play.",
        "hu": "{price} / {unit}. Automatikusan megújul, bármikor lemondhatod a Google Playen.",
        "hr": "{price} / {unit}. Automatski se obnavlja, otkaži bilo kada na Google Playu.",
        "sl": "{price} na {unit}. Samodejno se podaljša, prekličeš lahko kadar koli v Google Play.",
        "sr": "{price} / {unit}. Automatski se obnavlja, otkaži bilo kada na Google Play-u.",
        "bg": "{price} на {unit}. Подновява се автоматично, можеш да се откажеш по всяко време в Google Play.",
        "el": "{price} / {unit}. Ανανεώνεται αυτόματα, ακύρωσε όποτε θες στο Google Play.",
        "ru": "{price} в {unit}. Продлевается автоматически, отменить можно в любой момент в Google Play.",
        "tr": "{unit} başına {price}. Otomatik yenilenir, Google Play'den istediğin zaman iptal et.",
        "ar": "{price} لكل {unit}. يتجدد تلقائيًا، ويمكنك الإلغاء في أي وقت من Google Play.",
    },
    "x_paywall_subscribe": {
        "en": "Go Pro",
        "fr": "Passer à Pro",
        "de": "Pro holen",
        "es": "Hazte Pro",
        "es419": "Hazte Pro",
        "it": "Passa a Pro",
        "pt": "Passar a Pro",
        "ptBR": "Assinar o Pro",
        "nl": "Word Pro",
        "pl": "Przejdź na Pro",
        "ro": "Treci la Pro",
        "sv": "Skaffa Pro",
        "da": "Få Pro",
        "fi": "Hanki Pro",
        "et": "Võta Pro",
        "cs": "Přejít na Pro",
        "sk": "Prejsť na Pro",
        "hu": "Válts Próra",
        "hr": "Prijeđi na Pro",
        "sl": "Nadgradi na Pro",
        "sr": "Pređi na Pro",
        "bg": "Мини на Pro",
        "el": "Πάρε το Pro",
        "ru": "Перейти на Pro",
        "tr": "Pro'ya geç",
        "ar": "اشترك في Pro",
    },
    "x_record_limit": {
        "en": "Up to 90 minutes. Mika turns your recording into text, then writes your lesson.",
        "fr": "Jusqu'à 90 minutes. Mika met ton enregistrement en texte, puis écrit ta leçon.",
        "de": "Bis zu 90 Minuten. Mika macht aus deiner Aufnahme Text und schreibt dann deine Lektion.",
        "es": "Hasta 90 minutos. Mika convierte tu grabación en texto y luego escribe tu lección.",
        "es419": "Hasta 90 minutos. Mika convierte tu grabación en texto y luego escribe tu lección.",
        "it": "Fino a 90 minuti. Mika trasforma la registrazione in testo, poi scrive la tua lezione.",
        "pt": "Até 90 minutos. O Mika passa a gravação a texto e depois escreve a tua lição.",
        "ptBR": "Até 90 minutos. O Mika transforma a gravação em texto e depois escreve sua aula.",
        "nl": "Tot 90 minuten. Mika zet je opname om in tekst en schrijft dan je les.",
        "pl": "Do 90 minut. Mika zamienia nagranie na tekst, a potem pisze twoją lekcję.",
        "ro": "Până la 90 de minute. Mika transformă înregistrarea ta în text, apoi îți scrie lecția.",
        "sv": "Upp till 90 minuter. Mika gör om din inspelning till text och skriver sedan din lektion.",
        "da": "Op til 90 minutter. Mika laver din optagelse om til tekst og skriver så din lektion.",
        "fi": "Enintään 90 minuuttia. Mika muuttaa nauhoituksesi tekstiksi ja kirjoittaa sitten oppituntisi.",
        "et": "Kuni 90 minutit. Mika teeb sinu salvestisest teksti ja kirjutab siis sinu tunni.",
        "cs": "Až 90 minut. Mika převede tvoji nahrávku na text a pak napíše tvou lekci.",
        "sk": "Až 90 minút. Mika prevedie tvoju nahrávku na text a potom napíše tvoju lekciu.",
        "hu": "Legfeljebb 90 perc. Mika szöveggé alakítja a felvételedet, aztán megírja a leckédet.",
        "hr": "Do 90 minuta. Mika pretvara tvoju snimku u tekst, a zatim piše tvoju lekciju.",
        "sl": "Do 90 minut. Mika tvoj posnetek pretvori v besedilo in nato napiše tvojo lekcijo.",
        "sr": "Do 90 minuta. Mika pretvara tvoj snimak u tekst, a zatim piše tvoju lekciju.",
        "bg": "До 90 минути. Mika превръща записа ти в текст, после пише урока ти.",
        "el": "Έως 90 λεπτά. Ο Mika μετατρέπει την ηχογράφησή σου σε κείμενο και μετά γράφει το μάθημά σου.",
        "ru": "До 90 минут. Mika превращает запись в текст, а затем пишет урок.",
        "tr": "90 dakikaya kadar. Mika kaydını metne çevirir, sonra dersini yazar.",
        "ar": "حتى 90 دقيقة. يحوّل Mika تسجيلك إلى نص ثم يكتب درسك.",
    },
    "x_account_deleteMsg": {
        "en": "Your courses, cards and history will be erased everywhere. A subscription is managed in Google Play.",
        "fr": "Tes cours, tes cartes et ton historique seront effacés partout. L'abonnement se gère dans Google Play.",
        "de": "Kurse, Karten und Verlauf werden überall gelöscht. Ein Abo verwaltest du in Google Play.",
        "es": "Tus cursos, tarjetas e historial se borrarán en todas partes. La suscripción se gestiona en Google Play.",
        "es419": "Tus cursos, tarjetas e historial se borrarán en todas partes. La suscripción se gestiona en Google Play.",
        "it": "Corsi, carte e cronologia verranno cancellati ovunque. L'abbonamento si gestisce su Google Play.",
        "pt": "Os teus cursos, cartões e histórico serão apagados em todo o lado. A subscrição gere-se no Google Play.",
        "ptBR": "Seus cursos, cartões e histórico serão apagados em todos os lugares. A assinatura é gerenciada no Google Play.",
        "nl": "Je cursussen, kaarten en geschiedenis worden overal gewist. Een abonnement beheer je in Google Play.",
        "pl": "Twoje kursy, karty i historia zostaną usunięte wszędzie. Subskrypcją zarządzasz w Google Play.",
        "ro": "Cursurile, cardurile și istoricul tău vor fi șterse peste tot. Abonamentul se gestionează din Google Play.",
        "sv": "Dina kurser, kort och din historik raderas överallt. En prenumeration hanteras i Google Play.",
        "da": "Dine kurser, kort og din historik slettes overalt. Et abonnement styres i Google Play.",
        "fi": "Kurssisi, korttisi ja historiasi poistetaan kaikkialta. Tilausta hallitaan Google Playssa.",
        "et": "Sinu kursused, kaardid ja ajalugu kustutatakse kõikjalt. Tellimust hallatakse Google Plays.",
        "cs": "Tvoje kurzy, kartičky a historie se všude smažou. Předplatné se spravuje v Google Play.",
        "sk": "Tvoje kurzy, kartičky a história sa všade vymažú. Predplatné sa spravuje v Google Play.",
        "hu": "A kurzusaid, kártyáid és az előzményeid mindenhonnan törlődnek. Az előfizetést a Google Playen kezelheted.",
        "hr": "Tvoji tečajevi, kartice i povijest bit će izbrisani posvuda. Pretplatom se upravlja na Google Playu.",
        "sl": "Tvoji tečaji, kartice in zgodovina bodo izbrisani povsod. Naročnino upravljaš v Google Play.",
        "sr": "Tvoji kursevi, kartice i istorija biće obrisani svuda. Pretplatom se upravlja na Google Play-u.",
        "bg": "Курсовете, картите и историята ти ще бъдат изтрити навсякъде. Абонаментът се управлява от Google Play.",
        "el": "Τα μαθήματα, οι κάρτες και το ιστορικό σου θα διαγραφούν παντού. Τη συνδρομή τη διαχειρίζεσαι στο Google Play.",
        "ru": "Твои курсы, карточки и история будут удалены везде. Подпиской управляют в Google Play.",
        "tr": "Kursların, kartların ve geçmişin her yerden silinecek. Abonelik Google Play'den yönetilir.",
        "ar": "ستُحذف دوراتك وبطاقاتك وسجلك في كل مكان. يُدار الاشتراك من Google Play.",
    },
    "x_auth_rateLimited": {
        "en": "Too many tries. Wait a minute, then try again.",
        "fr": "Trop d'essais. Attends une minute, puis réessaie.",
        "de": "Zu viele Versuche. Warte eine Minute und versuch es dann erneut.",
        "es": "Demasiados intentos. Espera un minuto y vuelve a intentarlo.",
        "es419": "Demasiados intentos. Espera un minuto y vuelve a intentarlo.",
        "it": "Troppi tentativi. Aspetta un minuto, poi riprova.",
        "pt": "Demasiadas tentativas. Espera um minuto e tenta outra vez.",
        "ptBR": "Muitas tentativas. Espere um minuto e tente de novo.",
        "nl": "Te veel pogingen. Wacht een minuut en probeer het opnieuw.",
        "pl": "Zbyt wiele prób. Odczekaj minutę i spróbuj ponownie.",
        "ro": "Prea multe încercări. Așteaptă un minut, apoi încearcă din nou.",
        "sv": "För många försök. Vänta en minut och försök igen.",
        "da": "For mange forsøg. Vent et minut, og prøv igen.",
        "fi": "Liian monta yritystä. Odota minuutti ja yritä uudelleen.",
        "et": "Liiga palju katseid. Oota minut ja proovi uuesti.",
        "cs": "Příliš mnoho pokusů. Počkej minutu a zkus to znovu.",
        "sk": "Príliš veľa pokusov. Počkaj minútu a skús to znova.",
        "hu": "Túl sok próbálkozás. Várj egy percet, aztán próbáld újra.",
        "hr": "Previše pokušaja. Pričekaj minutu pa pokušaj ponovno.",
        "sl": "Preveč poskusov. Počakaj minuto in poskusi znova.",
        "sr": "Previše pokušaja. Sačekaj minut pa pokušaj ponovo.",
        "bg": "Твърде много опити. Изчакай минута и опитай пак.",
        "el": "Πάρα πολλές προσπάθειες. Περίμενε ένα λεπτό και δοκίμασε ξανά.",
        "ru": "Слишком много попыток. Подожди минуту и попробуй снова.",
        "tr": "Çok fazla deneme. Bir dakika bekle, sonra tekrar dene.",
        "ar": "محاولات كثيرة جدًا. انتظر دقيقة ثم حاول مجددًا.",
    },
    "x_sync_failed": {
        "en": "Not synced. Tap to try again.",
        "fr": "Pas synchronisé. Touche pour réessayer.",
        "de": "Nicht synchronisiert. Tippen, um es erneut zu versuchen.",
        "es": "Sin sincronizar. Toca para reintentar.",
        "es419": "Sin sincronizar. Toca para reintentar.",
        "it": "Non sincronizzato. Tocca per riprovare.",
        "pt": "Não sincronizado. Toca para tentar de novo.",
        "ptBR": "Não sincronizado. Toque para tentar de novo.",
        "nl": "Niet gesynchroniseerd. Tik om het opnieuw te proberen.",
        "pl": "Nie zsynchronizowano. Dotknij, aby spróbować ponownie.",
        "ro": "Nesincronizat. Atinge ca să încerci din nou.",
        "sv": "Inte synkat. Tryck för att försöka igen.",
        "da": "Ikke synkroniseret. Tryk for at prøve igen.",
        "fi": "Ei synkronoitu. Yritä uudelleen napauttamalla.",
        "et": "Pole sünkroonitud. Puuduta, et uuesti proovida.",
        "cs": "Nesynchronizováno. Klepni a zkus to znovu.",
        "sk": "Nesynchronizované. Ťukni a skús to znova.",
        "hu": "Nincs szinkronizálva. Koppints az újrapróbáláshoz.",
        "hr": "Nije sinkronizirano. Dodirni za ponovni pokušaj.",
        "sl": "Ni sinhronizirano. Tapni za ponovni poskus.",
        "sr": "Nije sinhronizovano. Dodirni da pokušaš ponovo.",
        "bg": "Не е синхронизирано. Докосни, за да опиташ пак.",
        "el": "Δεν συγχρονίστηκε. Πάτα για να ξαναδοκιμάσεις.",
        "ru": "Не синхронизировано. Нажми, чтобы повторить.",
        "tr": "Eşitlenmedi. Tekrar denemek için dokun.",
        "ar": "لم تتم المزامنة. اضغط للمحاولة مجددًا.",
    },
    "x_error_generic": {
        "en": "Something went wrong. Try again.",
        "fr": "Quelque chose n'a pas marché. Réessaie.",
        "de": "Etwas hat nicht geklappt. Versuch es erneut.",
        "es": "Algo salió mal. Inténtalo de nuevo.",
        "es419": "Algo salió mal. Inténtalo de nuevo.",
        "it": "Qualcosa è andato storto. Riprova.",
        "pt": "Algo correu mal. Tenta outra vez.",
        "ptBR": "Algo deu errado. Tente de novo.",
        "nl": "Er ging iets mis. Probeer het opnieuw.",
        "pl": "Coś poszło nie tak. Spróbuj ponownie.",
        "ro": "Ceva n-a mers. Încearcă din nou.",
        "sv": "Något gick fel. Försök igen.",
        "da": "Noget gik galt. Prøv igen.",
        "fi": "Jokin meni pieleen. Yritä uudelleen.",
        "et": "Midagi läks valesti. Proovi uuesti.",
        "cs": "Něco se pokazilo. Zkus to znovu.",
        "sk": "Niečo sa pokazilo. Skús to znova.",
        "hu": "Valami hiba történt. Próbáld újra.",
        "hr": "Nešto je pošlo po zlu. Pokušaj ponovno.",
        "sl": "Nekaj je šlo narobe. Poskusi znova.",
        "sr": "Nešto je pošlo naopako. Pokušaj ponovo.",
        "bg": "Нещо се обърка. Опитай пак.",
        "el": "Κάτι πήγε στραβά. Δοκίμασε ξανά.",
        "ru": "Что-то пошло не так. Попробуй ещё раз.",
        "tr": "Bir şeyler ters gitti. Tekrar dene.",
        "ar": "حدث خطأ ما. حاول مجددًا.",
    },
    "x_friends_adopt": {
        "en": "Make my lesson from it",
        "fr": "En faire ma leçon",
        "de": "Meine Lektion daraus machen",
        "es": "Hacer mi lección con esto",
        "es419": "Hacer mi lección con esto",
        "it": "Farne la mia lezione",
        "pt": "Fazer a minha lição com isto",
        "ptBR": "Fazer minha aula com isto",
        "nl": "Er mijn les van maken",
        "pl": "Zrób z tego moją lekcję",
        "ro": "Fă din asta lecția mea",
        "sv": "Gör det till min lektion",
        "da": "Gør det til min lektion",
        "fi": "Tee siitä oma oppituntini",
        "et": "Tee sellest minu tund",
        "cs": "Udělat z toho moji lekci",
        "sk": "Urobiť z toho moju lekciu",
        "hu": "Legyen ebből a leckém",
        "hr": "Napravi od toga moju lekciju",
        "sl": "Naredi iz tega mojo lekcijo",
        "sr": "Napravi od toga moju lekciju",
        "bg": "Направи го мой урок",
        "el": "Κάν’ το δικό μου μάθημα",
        "ru": "Сделать из этого мой урок",
        "tr": "Bundan dersimi yap",
        "ar": "اجعله درسي",
    },
    "x_lesson_whoSees": {
        "en": "Who sees this lesson",
        "fr": "Qui voit cette leçon",
        "de": "Wer diese Lektion sieht",
        "es": "Quién ve esta lección",
        "es419": "Quién ve esta lección",
        "it": "Chi vede questa lezione",
        "pt": "Quem vê esta lição",
        "ptBR": "Quem vê esta aula",
        "nl": "Wie deze les ziet",
        "pl": "Kto widzi tę lekcję",
        "ro": "Cine vede această lecție",
        "sv": "Vem ser den här lektionen",
        "da": "Hvem kan se denne lektion",
        "fi": "Kuka näkee tämän oppitunnin",
        "et": "Kes seda tundi näeb",
        "cs": "Kdo vidí tuto lekci",
        "sk": "Kto vidí túto lekciu",
        "hu": "Ki látja ezt a leckét",
        "hr": "Tko vidi ovu lekciju",
        "sl": "Kdo vidi to lekcijo",
        "sr": "Ko vidi ovu lekciju",
        "bg": "Кой вижда този урок",
        "el": "Ποιος βλέπει αυτό το μάθημα",
        "ru": "Кто видит этот урок",
        "tr": "Bu dersi kim görür",
        "ar": "من يرى هذا الدرس",
    },
    "x_settings_level": {
        "en": "Level",
        "fr": "Niveau",
        "de": "Stufe",
        "es": "Nivel",
        "es419": "Nivel",
        "it": "Livello",
        "pt": "Nível",
        "ptBR": "Nível",
        "nl": "Niveau",
        "pl": "Poziom",
        "ro": "Nivel",
        "sv": "Nivå",
        "da": "Niveau",
        "fi": "Taso",
        "et": "Tase",
        "cs": "Úroveň",
        "sk": "Úroveň",
        "hu": "Szint",
        "hr": "Razina",
        "sl": "Raven",
        "sr": "Nivo",
        "bg": "Ниво",
        "el": "Επίπεδο",
        "ru": "Уровень",
        "tr": "Seviye",
        "ar": "المستوى",
    },
    "x_settings_reset": {
        "en": "Erase everything",
        "fr": "Tout effacer",
        "de": "Alles löschen",
        "es": "Borrar todo",
        "es419": "Borrar todo",
        "it": "Cancella tutto",
        "pt": "Apagar tudo",
        "ptBR": "Apagar tudo",
        "nl": "Alles wissen",
        "pl": "Usuń wszystko",
        "ro": "Șterge tot",
        "sv": "Radera allt",
        "da": "Slet alt",
        "fi": "Poista kaikki",
        "et": "Kustuta kõik",
        "cs": "Smazat vše",
        "sk": "Vymazať všetko",
        "hu": "Minden törlése",
        "hr": "Izbriši sve",
        "sl": "Izbriši vse",
        "sr": "Obriši sve",
        "bg": "Изтрий всичко",
        "el": "Διαγραφή όλων",
        "ru": "Стереть всё",
        "tr": "Her şeyi sil",
        "ar": "مسح كل شيء",
    },
    "x_settings_resetTitle": {
        "en": "Erase everything?",
        "fr": "Tout effacer ?",
        "de": "Alles löschen?",
        "es": "¿Borrar todo?",
        "es419": "¿Borrar todo?",
        "it": "Cancellare tutto?",
        "pt": "Apagar tudo?",
        "ptBR": "Apagar tudo?",
        "nl": "Alles wissen?",
        "pl": "Usunąć wszystko?",
        "ro": "Ștergi tot?",
        "sv": "Radera allt?",
        "da": "Slet alt?",
        "fi": "Poistetaanko kaikki?",
        "et": "Kas kustutada kõik?",
        "cs": "Smazat vše?",
        "sk": "Vymazať všetko?",
        "hu": "Mindent törölsz?",
        "hr": "Izbrisati sve?",
        "sl": "Želiš izbrisati vse?",
        "sr": "Obrisati sve?",
        "bg": "Да изтрием ли всичко?",
        "el": "Διαγραφή όλων;",
        "ru": "Стереть всё?",
        "tr": "Her şey silinsin mi?",
        "ar": "مسح كل شيء؟",
    },
    "x_settings_resetBody": {
        "en": "Your lessons and your profile leave this phone. This can't be undone.",
        "fr": "Tes leçons et ton profil quittent ce téléphone. C'est définitif.",
        "de": "Deine Lektionen und dein Profil werden von diesem Handy gelöscht. Das lässt sich nicht rückgängig machen.",
        "es": "Tus lecciones y tu perfil se borran de este teléfono. No se puede deshacer.",
        "es419": "Tus lecciones y tu perfil se borran de este teléfono. No se puede deshacer.",
        "it": "Lezioni e profilo spariscono da questo telefono. Non si può annullare.",
        "pt": "As tuas lições e o teu perfil saem deste telemóvel. Não dá para desfazer.",
        "ptBR": "Suas aulas e seu perfil saem deste celular. Não dá para desfazer.",
        "nl": "Je lessen en je profiel verdwijnen van deze telefoon. Dit kan niet ongedaan worden gemaakt.",
        "pl": "Twoje lekcje i profil znikną z tego telefonu. Tego nie da się cofnąć.",
        "ro": "Lecțiile și profilul tău dispar de pe acest telefon. Nu se poate anula.",
        "sv": "Dina lektioner och din profil försvinner från den här telefonen. Det går inte att ångra.",
        "da": "Dine lektioner og din profil forsvinder fra denne telefon. Det kan ikke fortrydes.",
        "fi": "Oppituntisi ja profiilisi poistetaan tästä puhelimesta. Tätä ei voi perua.",
        "et": "Sinu tunnid ja profiil kustutatakse sellest telefonist. Seda ei saa tagasi võtta.",
        "cs": "Tvoje lekce a profil z tohoto telefonu zmizí. Nejde to vrátit.",
        "sk": "Tvoje lekcie a profil z tohto telefónu zmiznú. Nedá sa to vrátiť.",
        "hu": "A leckéid és a profilod törlődik erről a telefonról. Ez nem vonható vissza.",
        "hr": "Tvoje lekcije i profil nestaju s ovog telefona. Ovo se ne može poništiti.",
        "sl": "Tvoje lekcije in profil izginejo s tega telefona. Tega ni mogoče razveljaviti.",
        "sr": "Tvoje lekcije i profil nestaju sa ovog telefona. Ovo ne može da se poništi.",
        "bg": "Уроците и профилът ти ще изчезнат от този телефон. Това не може да се отмени.",
        "el": "Τα μαθήματα και το προφίλ σου φεύγουν από αυτό το κινητό. Δεν αναιρείται.",
        "ru": "Твои уроки и профиль будут удалены с этого телефона. Это нельзя отменить.",
        "tr": "Derslerin ve profilin bu telefondan silinir. Geri alınamaz.",
        "ar": "ستُحذف دروسك وملفك الشخصي من هذا الهاتف. لا يمكن التراجع عن ذلك.",
    },
    "x_quoted": {
        "en": "“{text}”",
        "fr": "«\u00a0{text}\u00a0»",
        "de": "„{text}“",
        "es": "«{text}»",
        "es419": "“{text}”",
        "it": "«{text}»",
        "pt": "«{text}»",
        "ptBR": "“{text}”",
        "nl": "“{text}”",
        "pl": "„{text}”",
        "ro": "„{text}”",
        "sv": "”{text}”",
        "da": "»{text}«",
        "fi": "”{text}”",
        "et": "„{text}“",
        "cs": "„{text}“",
        "sk": "„{text}“",
        "hu": "„{text}”",
        "hr": "„{text}“",
        "sl": "„{text}“",
        "sr": "„{text}“",
        "bg": "„{text}“",
        "el": "«{text}»",
        "ru": "«{text}»",
        "tr": "“{text}”",
        "ar": "«{text}»",
    },
}

# **Ce que l'iPhone ne traduit pas encore.** Des clés des catalogues Swift, sans phrase dans une
# langue régionale : sans ce relais, Android les lisait en anglais. La phrase du catalogue passe
# toujours en premier ; une ligne d'ici ne sert que tant que l'iPhone n'a rien. Mêmes variables
# `{n}` que la phrase anglaise du catalogue.
FILL: dict[str, dict[str, str]] = {
    "ios_hook_sub": {
        "es419": "Micabo te ayuda a sacar mejores calificaciones en la escuela.",
        "it": "Micabo ti aiuta a prendere voti migliori a scuola.",
        "pt": "O Micabo ajuda-te a ter melhores notas na escola.",
        "ptBR": "O Micabo ajuda você a tirar notas melhores na escola.",
        "nl": "Micabo helpt je betere cijfers te halen op school.",
        "pl": "Micabo pomoże ci zdobywać lepsze oceny w szkole.",
        "ro": "Micabo te ajută să iei note mai bune la școală.",
        "sv": "Micabo hjälper dig att få bättre betyg i skolan.",
        "da": "Micabo hjælper dig med at få bedre karakterer i skolen.",
        "fi": "Micabo auttaa sinua saamaan parempia arvosanoja koulussa.",
        "et": "Micabo aitab sul koolis paremaid hindeid saada.",
        "cs": "Micabo ti pomůže mít ve škole lepší známky.",
        "sk": "Micabo ti pomôže mať v škole lepšie známky.",
        "hu": "A Micabo segít, hogy jobb jegyeid legyenek az iskolában.",
        "hr": "Micabo će ti pomoći da dobivaš bolje ocjene u školi.",
        "sl": "Micabo ti bo pomagal do boljših ocen v šoli.",
        "sr": "Micabo će ti pomoći da dobijaš bolje ocene u školi.",
        "bg": "Micabo ще ти помогне да имаш по-добри оценки в училище.",
        "el": "Το Micabo θα σε βοηθήσει να παίρνεις καλύτερους βαθμούς στο σχολείο.",
        "ru": "Micabo поможет тебе получать в школе более высокие оценки.",
        "ar": "سيساعدك Micabo على الحصول على درجات أفضل في المدرسة.",
    },
    "ios_levelTitle": {
        "es419": "¿En qué punto estás?",
        "it": "A che punto sei?",
        "pt": "Em que ponto estás?",
        "ptBR": "Em que ponto você está?",
        "nl": "Waar sta je?",
        "pl": "Na jakim jesteś etapie?",
        "ro": "Unde te afli?",
        "sv": "Var befinner du dig?",
        "da": "Hvor står du?",
        "fi": "Missä vaiheessa olet?",
        "et": "Kus sa oma õpingutega oled?",
        "cs": "Jak na tom jsi?",
        "sk": "Ako na tom si?",
        "hu": "Hol tartasz most?",
        "hr": "Gdje si trenutačno?",
        "sl": "Kje si zdaj?",
        "sr": "Gde si trenutno?",
        "bg": "Къде си в момента?",
        "el": "Πού βρίσκεσαι;",
        "ru": "На каком ты этапе?",
        "ar": "أين وصلت؟",
    },
    "ios_averageLead": {
        "es419": "Nadie te juzga. Es un punto de partida, no una boleta.",
        "it": "Nessuno ti giudica. È un punto di partenza, non una pagella.",
        "pt": "Ninguém te julga. É um ponto de partida, não uma pauta.",
        "ptBR": "Ninguém está julgando. É um ponto de partida, não um boletim.",
        "nl": "Niemand oordeelt. Dit is een startpunt, geen rapport.",
        "pl": "Nikt cię nie ocenia. To punkt wyjścia, a nie świadectwo.",
        "ro": "Nimeni nu te judecă. E un punct de plecare, nu un carnet de note.",
        "sv": "Ingen dömer. Det här är en startpunkt, inte ett betyg.",
        "da": "Ingen dømmer. Det er et udgangspunkt, ikke en karakterbog.",
        "fi": "Kukaan ei arvostele. Tämä on lähtöpiste, ei todistus.",
        "et": "Keegi ei mõista hukka. See on alguspunkt, mitte tunnistus.",
        "cs": "Nikdo tě nesoudí. Je to výchozí bod, ne vysvědčení.",
        "sk": "Nikto ťa nesúdi. Je to východiskový bod, nie vysvedčenie.",
        "hu": "Senki sem ítélkezik. Ez egy kiindulópont, nem bizonyítvány.",
        "hr": "Nitko ne sudi. Ovo je početna točka, a ne svjedodžba.",
        "sl": "Nihče ne sodi. To je izhodišče, ne spričevalo.",
        "sr": "Niko ne sudi. Ovo je polazna tačka, a ne svedočanstvo.",
        "bg": "Никой не съди. Това е отправна точка, не бележник.",
        "el": "Κανείς δεν σε κρίνει. Είναι ένα σημείο εκκίνησης, όχι έλεγχος.",
        "ru": "Никто не осуждает. Это точка старта, а не табель.",
        "ar": "لا أحد يحكم عليك. هذه نقطة بداية، لا كشف درجات.",
    },
    "ios_targetLead": {
        "es419": "Apunta a lo que de verdad te haría feliz, no a lo que suena razonable.",
        "it": "Punta a ciò che ti renderebbe davvero felice, non a ciò che sembra ragionevole.",
        "pt": "Aponta para o que te faria mesmo feliz, não para o que parece razoável.",
        "ptBR": "Mire no que realmente te deixaria feliz, não no que parece razoável.",
        "nl": "Mik op wat je echt blij zou maken, niet op wat redelijk klinkt.",
        "pl": "Celuj w to, co naprawdę by cię ucieszyło, a nie w to, co brzmi rozsądnie.",
        "ro": "Țintește spre ce te-ar bucura cu adevărat, nu spre ce pare rezonabil.",
        "sv": "Sikta på det som verkligen skulle göra dig glad, inte på det som låter rimligt.",
        "da": "Sigt efter det, der virkelig ville gøre dig glad, ikke det, der lyder fornuftigt.",
        "fi": "Tähtää siihen, mikä oikeasti ilahduttaisi sinua, älä siihen, mikä kuulostaa järkevältä.",
        "et": "Sihi seda, mis sind päriselt rõõmustaks, mitte seda, mis kõlab mõistlikult.",
        "cs": "Miř na to, co by tě opravdu potěšilo, ne na to, co zní rozumně.",
        "sk": "Mier na to, čo by ťa naozaj potešilo, nie na to, čo znie rozumne.",
        "hu": "Arra célozz, ami tényleg boldoggá tenne, ne arra, ami észszerűnek hangzik.",
        "hr": "Ciljaj na ono što bi te stvarno razveselilo, a ne na ono što zvuči razumno.",
        "sl": "Ciljaj na tisto, kar bi te res razveselilo, ne na tisto, kar se sliši razumno.",
        "sr": "Ciljaj na ono što bi te stvarno obradovalo, a ne na ono što zvuči razumno.",
        "bg": "Цели се в това, което наистина би те зарадвало, а не в това, което звучи разумно.",
        "el": "Στόχευσε σε ό,τι θα σε χαροποιούσε πραγματικά, όχι σε ό,τι ακούγεται λογικό.",
        "ru": "Целься в то, что по-настоящему тебя обрадует, а не в то, что кажется разумным.",
        "ar": "استهدف ما سيسعدك حقًا، لا ما يبدو معقولًا.",
    },
    "ios_proof_retention_title": {
        "es419": "Releer es **olvidar**.",
        "it": "Rileggere è **dimenticare**.",
        "pt": "Reler é **esquecer**.",
        "ptBR": "Reler é **esquecer**.",
        "nl": "Herlezen is **vergeten**.",
        "pl": "Powtórne czytanie to **zapominanie**.",
        "ro": "A reciti înseamnă a **uita**.",
        "sv": "Att läsa om är att **glömma**.",
        "da": "At genlæse er at **glemme**.",
        "fi": "Uudelleen lukeminen on **unohtamista**.",
        "et": "Ülelugemine on **unustamine**.",
        "cs": "Znovu číst znamená **zapomínat**.",
        "sk": "Znova čítať znamená **zabúdať**.",
        "hu": "Újraolvasni annyi, mint **felejteni**.",
        "hr": "Ponovno čitanje znači **zaboravljanje**.",
        "sl": "Ponovno branje je **pozabljanje**.",
        "sr": "Ponovno čitanje znači **zaboravljanje**.",
        "bg": "Препрочитането е **забравяне**.",
        "el": "Το ξαναδιάβασμα είναι **ξέχασμα**.",
        "ru": "Перечитывать значит **забывать**.",
        "ar": "إعادة القراءة **نسيان**.",
    },
    "ios_onb_train_reveal": {
        "es419": "Toca la tarjeta para ver la respuesta",
        "it": "Tocca la carta per vedere la risposta",
        "pt": "Toca no cartão para ver a resposta",
        "ptBR": "Toque no cartão para ver a resposta",
        "nl": "Tik op de kaart om het antwoord te zien",
        "pl": "Dotknij fiszki, aby zobaczyć odpowiedź",
        "ro": "Atinge cardul ca să vezi răspunsul",
        "sv": "Tryck på kortet för att se svaret",
        "da": "Tryk på kortet for at se svaret",
        "fi": "Napauta korttia nähdäksesi vastauksen",
        "et": "Puuduta kaarti, et vastust näha",
        "cs": "Klepni na kartičku a uvidíš odpověď",
        "sk": "Ťukni na kartičku a uvidíš odpoveď",
        "hu": "Koppints a kártyára a válaszért",
        "hr": "Dodirni karticu da vidiš odgovor",
        "sl": "Tapni kartico, da vidiš odgovor",
        "sr": "Dodirni karticu da vidiš odgovor",
        "bg": "Докосни картата, за да видиш отговора",
        "el": "Πάτα την κάρτα για να δεις την απάντηση",
        "ru": "Нажми на карточку, чтобы увидеть ответ",
        "ar": "اضغط على البطاقة لترى الإجابة",
    },
    "ios_quiz_time_minutes": {
        "es419": "{n} min al día",
        "it": "{n} min al giorno",
        "pt": "{n} min por dia",
        "ptBR": "{n} min por dia",
        "nl": "{n} min per dag",
        "pl": "{n} min dziennie",
        "ro": "{n} min pe zi",
        "sv": "{n} min om dagen",
        "da": "{n} min om dagen",
        "fi": "{n} min päivässä",
        "et": "{n} min päevas",
        "cs": "{n} min denně",
        "sk": "{n} min denne",
        "hu": "Napi {n} perc",
        "hr": "{n} min dnevno",
        "sl": "{n} min na dan",
        "sr": "{n} min dnevno",
        "bg": "{n} мин на ден",
        "el": "{n} λεπ. τη μέρα",
        "ru": "{n} мин в день",
        "ar": "{n} د يوميًا",
    },
    "ios_build_title": {
        "es419": "Armando tu plan",
        "it": "Prepariamo il tuo piano",
        "pt": "A preparar o teu plano",
        "ptBR": "Montando seu plano",
        "nl": "We bouwen je plan",
        "pl": "Tworzymy twój plan",
        "ro": "Îți construim planul",
        "sv": "Vi bygger din plan",
        "da": "Vi bygger din plan",
        "fi": "Rakennamme suunnitelmaasi",
        "et": "Koostame sinu plaani",
        "cs": "Sestavujeme tvůj plán",
        "sk": "Zostavujeme tvoj plán",
        "hu": "Összerakjuk a terved",
        "hr": "Slažemo tvoj plan",
        "sl": "Sestavljamo tvoj načrt",
        "sr": "Pravimo tvoj plan",
        "bg": "Съставяме плана ти",
        "el": "Φτιάχνουμε το πρόγραμμά σου",
        "ru": "Составляем твой план",
        "ar": "نبني خطتك",
    },
    "ios_build_step1": {
        "es419": "Leyendo tus respuestas",
        "it": "Lettura delle tue risposte",
        "pt": "A ler as tuas respostas",
        "ptBR": "Lendo suas respostas",
        "nl": "Je antwoorden lezen",
        "pl": "Czytamy twoje odpowiedzi",
        "ro": "Citim răspunsurile tale",
        "sv": "Läser dina svar",
        "da": "Læser dine svar",
        "fi": "Luetaan vastauksiasi",
        "et": "Loeme sinu vastuseid",
        "cs": "Čteme tvoje odpovědi",
        "sk": "Čítame tvoje odpovede",
        "hu": "Válaszaid olvasása",
        "hr": "Čitamo tvoje odgovore",
        "sl": "Beremo tvoje odgovore",
        "sr": "Čitamo tvoje odgovore",
        "bg": "Четем отговорите ти",
        "el": "Διαβάζουμε τις απαντήσεις σου",
        "ru": "Читаем твои ответы",
        "ar": "نقرأ إجاباتك",
    },
    "ios_build_step2": {
        "es419": "Calculando tu ritmo",
        "it": "Calcolo del tuo ritmo",
        "pt": "A calcular o teu ritmo",
        "ptBR": "Calculando seu ritmo",
        "nl": "Je tempo bepalen",
        "pl": "Ustalamy twoje tempo",
        "ro": "Calculăm ritmul tău",
        "sv": "Räknar ut din takt",
        "da": "Beregner dit tempo",
        "fi": "Lasketaan tahtiasi",
        "et": "Arvutame sinu tempot",
        "cs": "Počítáme tvoje tempo",
        "sk": "Počítame tvoje tempo",
        "hu": "Tempód kiszámítása",
        "hr": "Računamo tvoj tempo",
        "sl": "Računamo tvoj tempo",
        "sr": "Računamo tvoj tempo",
        "bg": "Изчисляваме темпото ти",
        "el": "Υπολογίζουμε τον ρυθμό σου",
        "ru": "Рассчитываем твой темп",
        "ar": "نحسب وتيرتك",
    },
    "ios_build_step3": {
        "es419": "Repartiendo el trabajo hasta el examen",
        "it": "Distribuzione del lavoro fino all’esame",
        "pt": "A distribuir o trabalho até ao exame",
        "ptBR": "Distribuindo o trabalho até o dia da prova",
        "nl": "Het werk verdelen tot de examendag",
        "pl": "Rozkładamy pracę do dnia egzaminu",
        "ro": "Împărțim munca până în ziua examenului",
        "sv": "Fördelar jobbet fram till provdagen",
        "da": "Fordeler arbejdet frem til eksamen",
        "fi": "Jaetaan työ koepäivään asti",
        "et": "Jaotame töö eksamipäevani",
        "cs": "Rozkládáme práci až do dne zkoušky",
        "sk": "Rozkladáme prácu až do dňa skúšky",
        "hu": "A munka elosztása a vizsga napjáig",
        "hr": "Raspoređujemo posao do dana ispita",
        "sl": "Delo razporejamo do dneva izpita",
        "sr": "Raspoređujemo posao do dana ispita",
        "bg": "Разпределяме работата до деня на изпита",
        "el": "Μοιράζουμε τη δουλειά ως τη μέρα της εξέτασης",
        "ru": "Распределяем работу до дня экзамена",
        "ar": "نوزّع العمل حتى يوم الامتحان",
    },
    "ios_build_step4": {
        "es419": "Fijando tu meta",
        "it": "Impostazione del tuo obiettivo",
        "pt": "A definir o teu objetivo",
        "ptBR": "Definindo sua meta",
        "nl": "Je doel instellen",
        "pl": "Ustawiamy twój cel",
        "ro": "Stabilim obiectivul tău",
        "sv": "Ställer in ditt mål",
        "da": "Sætter dit mål",
        "fi": "Asetetaan tavoitteesi",
        "et": "Seame sinu eesmärgi",
        "cs": "Nastavujeme tvůj cíl",
        "sk": "Nastavujeme tvoj cieľ",
        "hu": "Célod beállítása",
        "hr": "Postavljamo tvoj cilj",
        "sl": "Nastavljamo tvoj cilj",
        "sr": "Postavljamo tvoj cilj",
        "bg": "Задаваме целта ти",
        "el": "Ορίζουμε τον στόχο σου",
        "ru": "Задаём твою цель",
        "ar": "نحدّد هدفك",
    },
    "ios_build_done": {
        "es419": "Tu plan está listo",
        "it": "Il tuo piano è pronto",
        "pt": "O teu plano está pronto",
        "ptBR": "Seu plano está pronto",
        "nl": "Je plan is klaar",
        "pl": "Twój plan jest gotowy",
        "ro": "Planul tău e gata",
        "sv": "Din plan är klar",
        "da": "Din plan er klar",
        "fi": "Suunnitelmasi on valmis",
        "et": "Sinu plaan on valmis",
        "cs": "Tvůj plán je hotový",
        "sk": "Tvoj plán je hotový",
        "hu": "Kész a terved",
        "hr": "Tvoj plan je spreman",
        "sl": "Tvoj načrt je pripravljen",
        "sr": "Tvoj plan je spreman",
        "bg": "Планът ти е готов",
        "el": "Το πρόγραμμά σου είναι έτοιμο",
        "ru": "Твой план готов",
        "ar": "خطتك جاهزة",
    },
    "ios_trial_title": {
        "es419": "Queremos que pruebes Micabo **gratis**.",
        "it": "Vogliamo che provi Micabo **gratis**.",
        "pt": "Queremos que experimentes o Micabo **gratuitamente**.",
        "ptBR": "Queremos que você experimente o Micabo **de graça**.",
        "nl": "We willen dat je Micabo **gratis** uitprobeert.",
        "pl": "Chcemy dać ci szansę wypróbować Micabo **za darmo**.",
        "ro": "Vrem să încerci Micabo **gratuit**.",
        "sv": "Vi vill att du testar Micabo **gratis**.",
        "da": "Vi vil gerne have, at du prøver Micabo **gratis**.",
        "fi": "Haluamme, että kokeilet Micaboa **ilmaiseksi**.",
        "et": "Tahame, et prooviksid Micabot **tasuta**.",
        "cs": "Chceme ti dát možnost vyzkoušet si Micabo **zdarma**.",
        "sk": "Chceme ti dať možnosť vyskúšať si Micabo **zadarmo**.",
        "hu": "Szeretnénk, ha **ingyen** kipróbálnád a Micabót.",
        "hr": "Želimo da Micabo isprobaš **besplatno**.",
        "sl": "Želimo, da Micabo preizkusiš **brezplačno**.",
        "sr": "Želimo da Micabo isprobaš **besplatno**.",
        "bg": "Искаме да пробваш Micabo **безплатно**.",
        "el": "Θέλουμε να δοκιμάσεις το Micabo **δωρεάν**.",
        "ru": "Мы хотим дать тебе попробовать Micabo **бесплатно**.",
        "ar": "نريدك أن تجرّب Micabo **مجانًا**.",
    },
    "ios_trial_noPayment": {
        "es419": "Hoy no pagas nada",
        "it": "Nessun pagamento oggi",
        "pt": "Nada a pagar hoje",
        "ptBR": "Nada a pagar agora",
        "nl": "Nu niets te betalen",
        "pl": "Teraz nic nie płacisz",
        "ro": "Nicio plată acum",
        "sv": "Inget att betala nu",
        "da": "Intet at betale nu",
        "fi": "Ei maksua nyt",
        "et": "Praegu ei tule midagi maksta",
        "cs": "Teď nic neplatíš",
        "sk": "Teraz nič neplatíš",
        "hu": "Most nem kell fizetned",
        "hr": "Sada ne plaćaš ništa",
        "sl": "Zdaj ne plačaš nič",
        "sr": "Sada ne plaćaš ništa",
        "bg": "Сега не плащаш нищо",
        "el": "Καμία πληρωμή τώρα",
        "ru": "Сейчас платить не нужно",
        "ar": "لا دفع الآن",
    },
    "ios_trial_price": {
        "es419": "Luego {yearly} al año, o sea {monthly} al mes.",
        "it": "Poi {yearly} all’anno, cioè {monthly} al mese.",
        "pt": "Depois {yearly} por ano, ou seja, {monthly} por mês.",
        "ptBR": "Depois {yearly} por ano, ou seja, {monthly} por mês.",
        "nl": "Daarna {yearly} per jaar, dat is {monthly} per maand.",
        "pl": "Potem {yearly} rocznie, czyli {monthly} miesięcznie.",
        "ro": "Apoi {yearly} pe an, adică {monthly} pe lună.",
        "sv": "Sedan {yearly} per år, alltså {monthly} i månaden.",
        "da": "Derefter {yearly} om året, altså {monthly} om måneden.",
        "fi": "Sen jälkeen {yearly} vuodessa, eli {monthly} kuukaudessa.",
        "et": "Seejärel {yearly} aastas ehk {monthly} kuus.",
        "cs": "Potom {yearly} za rok, tedy {monthly} měsíčně.",
        "sk": "Potom {yearly} za rok, teda {monthly} mesačne.",
        "hu": "Utána évi {yearly}, vagyis havi {monthly}.",
        "hr": "Zatim {yearly} godišnje, odnosno {monthly} mjesečno.",
        "sl": "Nato {yearly} na leto, torej {monthly} na mesec.",
        "sr": "Zatim {yearly} godišnje, odnosno {monthly} mesečno.",
        "bg": "След това {yearly} на година, тоест {monthly} на месец.",
        "el": "Μετά {yearly} τον χρόνο, δηλαδή {monthly} τον μήνα.",
        "ru": "Потом {yearly} в год, то есть {monthly} в месяц.",
        "ar": "ثم {yearly} سنويًا، أي {monthly} شهريًا.",
    },
    "ios_paywall_badge_free": {
        "es419": "{n} días gratis",
        "it": "{n} giorni gratis",
        "pt": "{n} dias grátis",
        "ptBR": "{n} dias grátis",
        "nl": "{n} dagen gratis",
        "pl": "{n} dni za darmo",
        "ro": "{n} zile gratuite",
        "sv": "{n} dagar gratis",
        "da": "{n} dage gratis",
        "fi": "{n} päivää ilmaiseksi",
        "et": "{n} päeva tasuta",
        "cs": "Dní zdarma: {n}",
        "sk": "Dní zadarmo: {n}",
        "hu": "{n} nap ingyen",
        "hr": "{n} dana besplatno",
        "sl": "Brezplačnih dni: {n}",
        "sr": "{n} dana besplatno",
        "bg": "{n} дни безплатно",
        "el": "{n} μέρες δωρεάν",
        "ru": "{n} дн. бесплатно",
        "ar": "أيام مجانية: {n}",
    },
    "ios_trial_reminder_title": {
        "es419": "Te enviaremos un **recordatorio** antes de que termine tu prueba.",
        "it": "Ti invieremo un **promemoria** prima della fine della prova.",
        "pt": "Vamos enviar-te um **lembrete** antes de o teste acabar.",
        "ptBR": "Vamos te mandar um **lembrete** antes do fim do teste.",
        "nl": "We sturen je een **herinnering** voordat je proefperiode eindigt.",
        "pl": "Wyślemy ci **przypomnienie** przed końcem okresu próbnego.",
        "ro": "Îți trimitem un **reminder** înainte să se termine perioada de probă.",
        "sv": "Vi skickar en **påminnelse** innan din provperiod slutar.",
        "da": "Vi sender dig en **påmindelse**, før din prøveperiode slutter.",
        "fi": "Lähetämme sinulle **muistutuksen** ennen kuin kokeilusi päättyy.",
        "et": "Saadame sulle enne prooviperioodi lõppu **meeldetuletuse**.",
        "cs": "Před koncem zkušební doby ti pošleme **připomínku**.",
        "sk": "Pred koncom skúšobnej doby ti pošleme **pripomienku**.",
        "hu": "A próbaidő vége előtt küldünk egy **emlékeztetőt**.",
        "hr": "Poslat ćemo ti **podsjetnik** prije kraja probnog razdoblja.",
        "sl": "Pred koncem preizkusa ti pošljemo **opomnik**.",
        "sr": "Poslaćemo ti **podsetnik** pre kraja probnog perioda.",
        "bg": "Ще ти изпратим **напомняне** преди края на пробния период.",
        "el": "Θα σου στείλουμε **υπενθύμιση** πριν λήξει η δοκιμή σου.",
        "ru": "Мы пришлём **напоминание** до конца пробного периода.",
        "ar": "سنرسل لك **تذكيرًا** قبل انتهاء فترتك التجريبية.",
    },
    "ios_trial_reminder_sub": {
        "es419": "El día {day}, una notificación te avisa. Si quieres, cancelas en dos toques.",
        "it": "Il giorno {day} ti avvisa una notifica. Se vuoi, disdici in due tocchi.",
        "pt": "No dia {day}, uma notificação avisa-te. Se quiseres, cancelas em dois toques.",
        "ptBR": "No dia {day}, uma notificação te avisa. Se quiser, cancele em dois toques.",
        "nl": "Op dag {day} krijg je een melding. Opzeggen kan in twee tikken.",
        "pl": "W dniu {day} dostaniesz powiadomienie. Jeśli chcesz, anulujesz dwoma stuknięciami.",
        "ro": "În ziua {day}, o notificare te anunță. Dacă vrei, anulezi din două atingeri.",
        "sv": "Dag {day} får du en notis. Avsluta med två tryck om du vill.",
        "da": "På dag {day} får du en notifikation. Opsig med to tryk, hvis du vil.",
        "fi": "Päivänä {day} saat ilmoituksen. Voit perua kahdella napautuksella.",
        "et": "{day}. päeval hoiatab sind teavitus. Soovi korral tühista kahe puudutusega.",
        "cs": "{day}. den tě upozorní oznámení. Když budeš chtít, zrušíš to dvěma klepnutími.",
        "sk": "{day}. deň ťa upozorní notifikácia. Ak chceš, zrušíš to dvoma ťuknutiami.",
        "hu": "A próbaidő {day}. napján értesítést kapsz. Ha szeretnéd, két koppintással lemondhatod.",
        "hr": "{day}. dan upozorit će te obavijest. Ako želiš, otkazuješ s dva dodira.",
        "sl": "{day}. dan te opozori obvestilo. Če želiš, prekličeš z dvema dotikoma.",
        "sr": "{day}. dana upozoriće te obaveštenje. Ako želiš, otkazuješ sa dva dodira.",
        "bg": "На ден {day} ще получиш известие. Ако искаш, се отказваш с две докосвания.",
        "el": "Τη μέρα {day} θα λάβεις ειδοποίηση. Αν θες, ακυρώνεις με δύο πατήματα.",
        "ru": "В день {day} придёт уведомление. Если захочешь, отменишь в два касания.",
        "ar": "في اليوم {day} يصلك إشعار للتنبيه. يمكنك الإلغاء بنقرتين إن أردت.",
    },
    "ios_trial_reminder_cta": {
        "es419": "Continuar gratis",
        "it": "Continua gratis",
        "pt": "Continuar grátis",
        "ptBR": "Continuar de graça",
        "nl": "Gratis verder",
        "pl": "Kontynuuj za darmo",
        "ro": "Continuă gratuit",
        "sv": "Fortsätt gratis",
        "da": "Fortsæt gratis",
        "fi": "Jatka ilmaiseksi",
        "et": "Jätka tasuta",
        "cs": "Pokračovat zdarma",
        "sk": "Pokračovať zadarmo",
        "hu": "Folytatás ingyen",
        "hr": "Nastavi besplatno",
        "sl": "Nadaljuj brezplačno",
        "sr": "Nastavi besplatno",
        "bg": "Продължи безплатно",
        "el": "Συνέχισε δωρεάν",
        "ru": "Продолжить бесплатно",
        "ar": "تابع مجانًا",
    },
    "ios_searchCourse": {
        "es419": "Un curso, una materia…",
        "it": "Un corso, una materia…",
        "pt": "Um curso, uma disciplina…",
        "ptBR": "Um curso, uma matéria…",
        "nl": "Een cursus, een vak…",
        "pl": "Kurs, przedmiot…",
        "ro": "Un curs, o materie…",
        "sv": "En kurs, ett ämne…",
        "da": "Et kursus, et fag…",
        "fi": "Kurssi, oppiaine…",
        "et": "Kursus, aine…",
        "cs": "Kurz, předmět…",
        "sk": "Kurz, predmet…",
        "hu": "Egy kurzus, egy tantárgy…",
        "hr": "Tečaj, predmet…",
        "sl": "Tečaj, predmet…",
        "sr": "Kurs, predmet…",
        "bg": "Курс, предмет…",
        "el": "Ένα μάθημα, ένα αντικείμενο…",
        "ru": "Курс, предмет…",
        "ar": "دورة، مادة…",
    },
    "ios_libraryNoSearch": {
        "es419": "Ningún curso para esta búsqueda",
        "it": "Nessun corso per questa ricerca",
        "pt": "Nenhum curso para esta pesquisa",
        "ptBR": "Nenhum curso para esta busca",
        "nl": "Geen cursus voor deze zoekopdracht",
        "pl": "Brak kursów dla tego wyszukiwania",
        "ro": "Niciun curs pentru această căutare",
        "sv": "Ingen kurs för den här sökningen",
        "da": "Intet kursus til denne søgning",
        "fi": "Ei kursseja tällä haulla",
        "et": "Selle otsingu järgi kursusi pole",
        "cs": "Pro toto hledání žádný kurz",
        "sk": "Pre toto hľadanie žiadny kurz",
        "hu": "Nincs kurzus erre a keresésre",
        "hr": "Nema tečaja za ovo pretraživanje",
        "sl": "Za to iskanje ni tečajev",
        "sr": "Nema kursa za ovu pretragu",
        "bg": "Няма курс за това търсене",
        "el": "Κανένα μάθημα για αυτή την αναζήτηση",
        "ru": "По этому запросу курсов нет",
        "ar": "لا توجد دورة لهذا البحث",
    },
}

# **Les pluriels qu'ICU réduit ne sait pas dire.** L'iPhone ne connaît que `one` et `other` ;
# le croate, le serbe, le slovène, le tchèque, le slovaque, le roumain et l'arabe ont d'autres
# formes (« 3 kartice », « 2 dneva », « 20 de zile »…). Ces formes s'ajoutent à celles du
# catalogue, ou les remplacent. `{count}` est le nombre.
PLURALS_ANDROID: dict[str, dict[str, dict[str, str]]] = {
    "copy_cards": {
        "ro": {"few": "{count} carduri", "other": "{count} de carduri"},
        "hr": {"few": "{count} kartice"},
        "sl": {"two": "{count} kartici", "few": "{count} kartice"},
        "sr": {"few": "{count} kartice"},
    },
    "ios_streak_bestValue": {
        "ro": {"few": "{count} zile", "other": "{count} de zile"},
        "sl": {"two": "{count} dneva", "few": "{count} dnevi"},
    },
    "ios_streak_unit": {
        "ro": {"few": "zile la rând", "other": "de zile la rând"},
        "cs": {"few": "dny v řadě"},
        "sk": {"few": "dni v rade"},
        "sl": {"two": "dneva zapored", "few": "dnevi zapored"},
        "ar": {"two": "يومان متتاليان", "few": "أيام متتالية", "many": "يومًا متتاليًا", "other": "يوم متتالٍ"},
    },
    "ios_profile_streakDays": {
        "ro": {"few": "{count} zile la rând", "other": "{count} de zile la rând"},
    },
    "app_friends_friendCount": {
        "ro": {"few": "{count} prieteni", "other": "{count} de prieteni"},
    },
    "lesson_exam_addCards": {
        "ro": {"few": "Adaugă cele {count} greșeli la carduri", "other": "Adaugă cele {count} de greșeli la carduri"},
    },
    "lesson_exam_submitConfirm": {
        "ro": {"few": "{count} întrebări sunt fără răspuns. Predai oricum?", "other": "{count} de întrebări sunt fără răspuns. Predai oricum?"},
    },
}

# Le portugais du Brésil et l'espagnol d'Amérique latine retombent sur `values-pt` et `values-es`,
# pas sur l'anglais : une phrase identique à l'anglais s'y écrit quand même si la langue mère dit
# autre chose (sinon le Brésil lirait la phrase du Portugal).
PARENT = {"es419": "es", "ptBR": "pt"}

# Le nombre d'un `R.plurals` dont la phrase du catalogue n'est pas (encore) un pluriel ICU et
# porte plusieurs variables. Une phrase à une seule variable n'a pas besoin d'être citée.
PLURAL_COUNT = {"ios_profile_streakToBeat": "days"}

LINE = re.compile(r'^\s*"([^"\\]+)"\s*:\s*"((?:[^"\\]|\\.)*)"\s*,?\s*(//.*)?$')
TABLE = re.compile(r'^\s*static let (\w+): \[String: String\] = \[\s*$')
EXTENSION = re.compile(r'^\s*(?:extension|enum) (\w+)')


def swift_unescape(value: str) -> str:
    out = []
    index = 0
    while index < len(value):
        char = value[index]
        if char == "\\" and index + 1 < len(value):
            nxt = value[index + 1]
            out.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\", "'": "'", "0": ""}.get(nxt, nxt))
            index += 2
            continue
        out.append(char)
        index += 1
    return "".join(out)


def read_catalogs() -> dict[str, dict[str, dict[str, str]]]:
    """{catalogue: {langue: {clé: phrase}}} pour `shared`, `ios` et `lesson`."""
    catalogs: dict[str, dict[str, dict[str, str]]] = {"shared": {}, "ios": {}, "lesson": {}}
    files = [I18N / "Generated" / "SharedI18nCatalogs.swift", I18N / "IosI18nCatalogs.swift", I18N / "LessonI18nCatalogs.swift"]
    files += sorted((I18N / "Locales").glob("I18n+*.swift"))
    for path in files:
        owner = None
        table = None
        for raw in path.read_text(encoding="utf-8").splitlines():
            ext = EXTENSION.match(raw)
            if ext:
                owner = {"SharedI18nCatalogs": "shared", "IosI18nCatalogs": "ios", "LessonI18nCatalogs": "lesson"}.get(ext.group(1))
                continue
            start = TABLE.match(raw)
            if start and owner:
                table = catalogs[owner].setdefault(start.group(1), {})
                continue
            if table is None:
                continue
            if raw.strip() == "]":
                table = None
                continue
            match = LINE.match(raw)
            if match:
                table[match.group(1)] = swift_unescape(match.group(2))
    return catalogs


def lookup(catalogs, key: str, locale: str) -> str | None:
    if key.startswith("lesson."):
        return catalogs["lesson"].get(locale, {}).get(key)
    return catalogs["ios"].get(locale, {}).get(key) or catalogs["shared"].get(locale, {}).get(key)


def android_text(text: str, variables: list[str]) -> tuple[str, bool]:
    """La phrase au format Android, et vrai si elle prend des arguments."""
    has_args = bool(variables)
    if has_args:
        text = text.replace("%", "%%")
        for position, name in enumerate(variables, start=1):
            text = text.replace("{" + name + "}", f"%{position}$s")
    text = escape(text)
    text = text.replace("\\", "\\\\").replace("'", "\\'").replace('"', '\\"').replace("\n", "\\n")
    if text.startswith("@") or text.startswith("?"):
        text = "\\" + text
    return text, has_args


def icu_plural(text: str) -> tuple[str, dict[str, str], str] | None:
    """`avant {count, plural, one {…} other {…}} après` → (variable, {catégorie: phrase}, …)."""
    start = re.search(r"\{(\w+),\s*plural,", text)
    if not start:
        return None
    index = start.end()
    depth = 1
    branches: dict[str, str] = {}
    while index < len(text) and depth > 0:
        while index < len(text) and text[index].isspace():
            index += 1
        if index < len(text) and text[index] == "}":
            depth -= 1
            index += 1
            break
        key_match = re.match(r"(=?\w+)\s*\{", text[index:])
        if not key_match:
            return None
        index += key_match.end()
        level = 1
        body_start = index
        while index < len(text) and level > 0:
            if text[index] == "{":
                level += 1
            elif text[index] == "}":
                level -= 1
            index += 1
        branches[key_match.group(1)] = text[body_start:index - 1]
    before, after = text[:start.start()], text[index:]
    return start.group(1), {k: before + v + after for k, v in branches.items() if not k.startswith("=")}, ""


def plural_items(text: str) -> dict[str, str] | None:
    """Les phrases d'un pluriel ICU au format Android : `#` et la variable du compte en `%1$d`."""
    parsed = icu_plural(text)
    if not parsed:
        return None
    variable, branches, _ = parsed
    out = {}
    for quantity, body in branches.items():
        if quantity not in ("zero", "one", "two", "few", "many", "other"):
            continue
        body = body.replace("%", "%%").replace("#", "%1$d").replace("{" + variable + "}", "%1$d")
        others = [name for name in dict.fromkeys(re.findall(r"\{(\w+)\}", body))]
        for position, name in enumerate(others, start=2):
            body = body.replace("{" + name + "}", f"%{position}$s")
        value = escape(body).replace("\\", "\\\\").replace("'", "\\'").replace('"', '\\"').replace("\n", "\\n")
        out[quantity] = value
    return out if "other" in out else None


def xml_value(text: str) -> str:
    """Une phrase déjà au format Android (`%1$d`…), échappée pour le XML et pour aapt."""
    return escape(text).replace("\\", "\\\\").replace("'", "\\'").replace('"', '\\"').replace("\n", "\\n")


def plain_plural(text: str, base: str | None, name: str) -> dict[str, str] | None:
    """Une phrase sans pluriel ICU : une forme, `other`.

    Une langue qui n'accorde pas (le turc : « {count} soru cevapsız »), ou une phrase que
    l'iPhone n'a pas encore passée en ICU. Le nombre est la variable du pluriel anglais, sinon
    la seule variable de la phrase anglaise, sinon celle que `PLURAL_COUNT` désigne.
    """
    if "plural," in text:
        return None
    parsed = icu_plural(base or "")
    names = list(dict.fromkeys(re.findall(r"\{(\w+)\}", base or "")))
    count = parsed[0] if parsed else PLURAL_COUNT.get(name) or (names[0] if len(names) == 1 else None)
    if count is None:
        return None
    body = text.replace("%", "%%").replace("{" + count + "}", "%1$d")
    for position, other in enumerate(dict.fromkeys(re.findall(r"\{(\w+)\}", body)), start=2):
        body = body.replace("{" + other + "}", f"%{position}$s")
    return {"other": xml_value(body)}


def differs_from_parent(locale: str, parent_text: str | None, base: str) -> bool:
    """Vrai si la langue mère (`PARENT`) dit autre chose que l'anglais."""
    return locale in PARENT and parent_text not in (None, base)


def check_tables(catalogs, by_name: dict[str, str]) -> list[str]:
    """Les variables de chaque phrase de `CUSTOM`, `FILL` et `PLURALS_ANDROID`, contre l'anglais."""
    problems = []

    def variables(text: str) -> set[str]:
        return set(re.findall(r"\{(\w+)\}", text))

    for name, texts in CUSTOM.items():
        problems += [f"{name} [{loc}]" for loc, text in texts.items() if loc not in LOCALES or variables(text) != variables(texts["en"])]
    for name, texts in FILL.items():
        if name not in by_name:
            problems.append(f"{name} (clé inconnue)")
            continue
        base = lookup(catalogs, by_name[name], "en") or ""
        problems += [f"{name} [{loc}]" for loc, text in texts.items() if loc not in LOCALES or variables(text) != variables(base)]
    for name, by_locale in PLURALS_ANDROID.items():
        if name not in by_name:
            problems.append(f"{name} (clé inconnue)")
        for loc, forms in by_locale.items():
            problems += [f"{name} [{loc}/{q}]" for q in forms if loc not in LOCALES or q not in ("zero", "one", "two", "few", "many", "other")]
    return problems


def write_plurals(catalogs, by_name: dict[str, str], names: list[str]) -> list[str]:
    """`res/values-*/plurals.xml`, pour les `R.plurals.*` du code. Rend les noms introuvables."""
    missing = []
    entries: dict[str, dict[str, dict[str, str]]] = {folder: {} for folder in LOCALES.values()}
    for name in names:
        key = by_name.get(name)
        if key is None:
            missing.append(name)
            continue
        base = lookup(catalogs, key, "en") or lookup(catalogs, key, "fr")
        for locale, folder in LOCALES.items():
            text = lookup(catalogs, key, locale) or (base if locale == "en" else None)
            if text is None:
                continue
            if locale not in ("en", "fr") and text == base and not differs_from_parent(locale, lookup(catalogs, key, PARENT.get(locale, "")), base):
                continue
            items = plural_items(text) or plain_plural(text, base, name)
            if items:
                for quantity, form in PLURALS_ANDROID.get(name, {}).get(locale, {}).items():
                    items[quantity] = xml_value(re.sub(r"\{\w+\}", "%1$d", form.replace("%", "%%")))
                entries[folder][name] = items
    for folder, plurals in entries.items():
        path = RES / folder / "plurals.xml"
        if not plurals:
            path.unlink(missing_ok=True)
            continue
        lines = [
            '<?xml version="1.0" encoding="utf-8"?>',
            "<!-- Engendré par android/tools/generate_strings.py depuis les catalogues de l'app iPhone. Ne pas éditer à la main. -->",
            "<resources>",
        ]
        for name in sorted(plurals):
            lines.append(f'    <plurals name="{name}">')
            for quantity in ("zero", "one", "two", "few", "many", "other"):
                if quantity in plurals[name]:
                    lines.append(f'        <item quantity="{quantity}">{plurals[name][quantity]}</item>')
            lines.append("    </plurals>")
        lines.append("</resources>")
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return missing


def main() -> int:
    code = "\n".join(p.read_text(encoding="utf-8") for p in SOURCES.rglob("*.kt"))
    names = sorted(set(re.findall(r"R\.string\.([A-Za-z0-9_]+)", code)))
    plural_names = sorted(set(re.findall(r"R\.plurals\.([A-Za-z0-9_]+)", code)))
    catalogs = read_catalogs()
    every_key = set()
    for tables in catalogs.values():
        for table in tables.values():
            every_key.update(table)
    by_name: dict[str, str] = {}
    for key in every_key:
        by_name.setdefault(re.sub(r"[.\-]", "_", key), key)
    problems = check_tables(catalogs, by_name)
    if problems:
        print("Variables ou langues fausses : " + ", ".join(problems), file=sys.stderr)
        return 1

    missing = []
    icu_strings = []
    entries: dict[str, dict[str, tuple[str, list[str]]]] = {folder: {} for folder in LOCALES.values()}
    for name in names:
        if name == "app_name":
            continue
        if name in CUSTOM:
            texts = CUSTOM[name]
        elif name in by_name:
            key = by_name[name]
            texts = {locale: lookup(catalogs, key, locale) for locale in LOCALES}
            texts = {k: v for k, v in texts.items() if v}
            if "en" not in texts:
                texts["en"] = lookup(catalogs, key, "fr") or key
            for locale, text in FILL.get(name, {}).items():
                texts.setdefault(locale, text)
        else:
            missing.append(name)
            continue
        base = texts["en"]
        # Un pluriel ICU lu comme `R.string` s'afficherait tel quel (« {days, plural, one {…} ») :
        # l'appel doit passer à `R.plurals` et `pluralStringResource`.
        if any("plural," in text for text in texts.values()):
            icu_strings.append(name)
            continue
        variables = list(dict.fromkeys(re.findall(r"\{(\w+)\}", base)))
        for locale, folder in LOCALES.items():
            text = texts.get(locale)
            if text is None:
                continue
            if locale not in ("en", "fr") and text == base and not differs_from_parent(locale, texts.get(PARENT.get(locale, "")), base):
                continue
            entries[folder][name] = (text, variables)

    if icu_strings:
        print("Pluriels ICU appelés en R.string (passer à R.plurals) : " + ", ".join(icu_strings), file=sys.stderr)
        return 1
    missing += write_plurals(catalogs, by_name, plural_names)
    if missing:
        print("Introuvables : " + ", ".join(missing), file=sys.stderr)
        return 1

    for folder, strings in entries.items():
        directory = RES / folder
        directory.mkdir(parents=True, exist_ok=True)
        lines = [
            '<?xml version="1.0" encoding="utf-8"?>',
            "<!-- Engendré par android/tools/generate_strings.py depuis les catalogues de l'app iPhone. Ne pas éditer à la main. -->",
            "<resources>",
        ]
        if folder == "values":
            lines.append('    <string name="app_name" translatable="false">Micabo</string>')
        for name in sorted(strings):
            text, variables = strings[name]
            value, has_args = android_text(text, variables)
            attributes = "" if has_args or "%" not in value else ' formatted="false"'
            lines.append(f'    <string name="{name}"{attributes}>{value}</string>')
        lines.append("</resources>")
        (directory / "strings.xml").write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"{folder}: {len(strings)} phrases")
    return 0


if __name__ == "__main__":
    sys.exit(main())
