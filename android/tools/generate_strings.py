#!/usr/bin/env python3
"""
**Les textes de l'app Android, tirés des catalogues de l'app iPhone.**

Le script lit les noms `R.string.*` utilisés par le code Kotlin, retrouve chaque phrase dans les
catalogues Swift (`Micabo/Services/I18n` : `SharedI18nCatalogs`, `IosI18nCatalogs`,
`LessonI18nCatalogs` et les 21 langues régionales de `Locales/`), et écrit un
`res/values-*/strings.xml` par langue. `lesson.notes.callout.why` devient
`lesson_notes_callout_why` ; les phrases propres à Android (préfixe `x_`) sont dans `CUSTOM`
ci-dessous. Les variables `{n}` deviennent `%1$s`, dans l'ordre de la phrase anglaise.

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
        "tr": "Hangi dilde çalışıyorsun?",
        "nl": "In welke taal studeer je?",
        "pl": "W jakim języku się uczysz?",
        "ar": "بأي لغة تدرس؟",
        "ru": "На каком языке ты учишься?",
    },
    "x_onb_language_sub": {
        "en": "Mika writes your lessons, quizzes and flashcards in this language.",
        "fr": "Mika écrit tes leçons, tes quiz et tes flashcards dans cette langue.",
        "de": "Mika schreibt deine Lektionen, Quizze und Karteikarten in dieser Sprache.",
        "es": "Mika escribe tus lecciones, quizzes y flashcards en este idioma.",
        "es419": "Mika escribe tus lecciones, quizzes y flashcards en este idioma.",
        "it": "Mika scrive lezioni, quiz e flashcard in questa lingua.",
        "pt": "O Mika escreve as tuas lições, quizzes e flashcards nesta língua.",
        "ptBR": "O Mika escreve suas lições, quizzes e flashcards neste idioma.",
        "tr": "Mika derslerini, testlerini ve kartlarını bu dilde yazar.",
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
        "tr": "Hadi başlayalım!",
        "nl": "Aan de slag!",
        "pl": "Zaczynamy!",
    },
    "x_score_1": {"en": "I'm struggling", "fr": "J'ai du mal", "de": "Ich tue mich schwer", "es": "Me cuesta", "es419": "Me cuesta", "it": "Faccio fatica", "pt": "Tenho dificuldades", "ptBR": "Tenho dificuldade", "tr": "Zorlanıyorum"},
    "x_score_2": {"en": "Just below average", "fr": "Un peu en dessous de la moyenne", "de": "Knapp unter dem Durchschnitt", "es": "Un poco por debajo de la media", "es419": "Un poco por debajo del promedio", "it": "Poco sotto la media", "pt": "Um pouco abaixo da média", "ptBR": "Um pouco abaixo da média", "tr": "Ortalamanın biraz altında"},
    "x_score_3": {"en": "Average", "fr": "Dans la moyenne", "de": "Durchschnittlich", "es": "En la media", "es419": "En el promedio", "it": "Nella media", "pt": "Na média", "ptBR": "Na média", "tr": "Ortalama"},
    "x_score_4": {"en": "Good", "fr": "Bien", "de": "Gut", "es": "Bien", "es419": "Bien", "it": "Bene", "pt": "Bom", "ptBR": "Bom", "tr": "İyi"},
    "x_score_5": {"en": "Top of the class", "fr": "Parmi les meilleurs", "de": "Unter den Besten", "es": "Entre los mejores", "es419": "Entre los mejores", "it": "Tra i migliori", "pt": "Entre os melhores", "ptBR": "Entre os melhores", "tr": "En iyiler arasında"},
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
        "tr": "Birkaç satır daha, Mika bununla çalışabilir.",
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
        "tr": "Bağlantı yok. İnternetini kontrol edip tekrar dene.",
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
        "tr": "Yakında Android'de",
    },
    "x_paywall_soonBody": {
        "en": "Subscriptions open on Android very soon. Your free lesson is waiting for you in the meantime.",
        "fr": "Les abonnements arrivent très bientôt sur Android. En attendant, ta leçon offerte t'attend.",
        "de": "Abos gibt es sehr bald auf Android. Bis dahin wartet deine kostenlose Lektion auf dich.",
        "es": "Las suscripciones llegan muy pronto a Android. Mientras tanto, tu lección gratis te espera.",
        "es419": "Las suscripciones llegan muy pronto a Android. Mientras tanto, tu lección gratis te espera.",
        "it": "Gli abbonamenti arrivano prestissimo su Android. Intanto, la tua lezione gratuita ti aspetta.",
        "pt": "As subscrições chegam muito em breve ao Android. Até lá, a tua lição grátis espera por ti.",
        "ptBR": "As assinaturas chegam muito em breve ao Android. Enquanto isso, sua lição grátis te espera.",
        "tr": "Abonelikler çok yakında Android'de. Bu arada ücretsiz dersin seni bekliyor.",
    },
    "x_paywall_finePrint": {
        "en": "{n} days free, then {price} per {unit}. Renews automatically, cancel anytime in Google Play.",
        "fr": "{n} jours offerts, puis {price} par {unit}. Renouvellement automatique, résiliable à tout moment dans Google Play.",
        "de": "{n} Tage gratis, danach {price} pro {unit}. Verlängert sich automatisch, jederzeit in Google Play kündbar.",
        "es": "{n} días gratis, luego {price} por {unit}. Se renueva automáticamente, cancela cuando quieras en Google Play.",
        "es419": "{n} días gratis, luego {price} por {unit}. Se renueva automáticamente, cancela cuando quieras en Google Play.",
        "it": "{n} giorni gratis, poi {price} a {unit}. Rinnovo automatico, disdici quando vuoi su Google Play.",
        "pt": "{n} dias grátis, depois {price} por {unit}. Renova automaticamente, cancela quando quiseres no Google Play.",
        "ptBR": "{n} dias grátis, depois {price} por {unit}. Renova automaticamente, cancele quando quiser no Google Play.",
        "tr": "{n} gün ücretsiz, ardından {unit} başına {price}. Otomatik yenilenir, Google Play'den istediğin zaman iptal et.",
    },
    "x_paywall_finePrintNoTrial": {
        "en": "{price} per {unit}. Renews automatically, cancel anytime in Google Play.",
        "fr": "{price} par {unit}. Renouvellement automatique, résiliable à tout moment dans Google Play.",
        "de": "{price} pro {unit}. Verlängert sich automatisch, jederzeit in Google Play kündbar.",
        "es": "{price} por {unit}. Se renueva automáticamente, cancela cuando quieras en Google Play.",
        "es419": "{price} por {unit}. Se renueva automáticamente, cancela cuando quieras en Google Play.",
        "it": "{price} a {unit}. Rinnovo automatico, disdici quando vuoi su Google Play.",
        "pt": "{price} por {unit}. Renova automaticamente, cancela quando quiseres no Google Play.",
        "ptBR": "{price} por {unit}. Renova automaticamente, cancele quando quiser no Google Play.",
        "tr": "{unit} başına {price}. Otomatik yenilenir, Google Play'den istediğin zaman iptal et.",
    },
    "x_paywall_subscribe": {
        "en": "Go Pro", "fr": "Passer à Pro", "de": "Pro holen", "es": "Hazte Pro", "es419": "Hazte Pro",
        "it": "Passa a Pro", "pt": "Passar a Pro", "ptBR": "Assinar o Pro", "tr": "Pro'ya geç",
        "nl": "Word Pro", "pl": "Przejdź na Pro", "ru": "Перейти на Pro", "ar": "اشترك في Pro",
    },
    "x_record_limit": {
        "en": "Up to 90 minutes. Mika turns your recording into text, then writes your lesson.",
        "fr": "Jusqu'à 90 minutes. Mika met ton enregistrement en texte, puis écrit ta leçon.",
        "de": "Bis zu 90 Minuten. Mika macht aus deiner Aufnahme Text und schreibt dann deine Lektion.",
        "es": "Hasta 90 minutos. Mika convierte tu grabación en texto y luego escribe tu lección.",
        "es419": "Hasta 90 minutos. Mika convierte tu grabación en texto y luego escribe tu lección.",
        "it": "Fino a 90 minuti. Mika trasforma la registrazione in testo, poi scrive la tua lezione.",
        "pt": "Até 90 minutos. O Mika passa a gravação a texto e depois escreve a tua lição.",
        "ptBR": "Até 90 minutos. O Mika transforma a gravação em texto e depois escreve sua lição.",
        "tr": "90 dakikaya kadar. Mika kaydını metne çevirir, sonra dersini yazar.",
        "nl": "Tot 90 minuten. Mika zet je opname om in tekst en schrijft dan je les.",
        "pl": "Do 90 minut. Mika zamienia nagranie na tekst, a potem pisze twoją lekcję.",
        "ru": "До 90 минут. Мика превращает запись в текст, а затем пишет урок.",
        "ar": "حتى 90 دقيقة. يحوّل ميكا تسجيلك إلى نص ثم يكتب درسك.",
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
        "tr": "Kursların, kartların ve geçmişin her yerden silinecek. Abonelik Google Play'den yönetilir.",
        "nl": "Je cursussen, kaarten en geschiedenis worden overal gewist. Een abonnement beheer je in Google Play.",
        "pl": "Twoje kursy, karty i historia zostaną usunięte wszędzie. Subskrypcją zarządzasz w Google Play.",
        "ru": "Твои курсы, карточки и история будут удалены везде. Подпиской управляют в Google Play.",
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
        "tr": "Çok fazla deneme. Bir dakika bekle, sonra tekrar dene.",
        "nl": "Te veel pogingen. Wacht een minuut en probeer het opnieuw.",
        "pl": "Zbyt wiele prób. Odczekaj minutę i spróbuj ponownie.",
        "ru": "Слишком много попыток. Подожди минуту и попробуй снова.",
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
        "tr": "Eşitlenmedi. Tekrar denemek için dokun.",
        "nl": "Niet gesynchroniseerd. Tik om het opnieuw te proberen.",
        "pl": "Nie zsynchronizowano. Dotknij, aby spróbować ponownie.",
        "ru": "Не синхронизировано. Нажми, чтобы повторить.",
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
        "tr": "Bir şeyler ters gitti. Tekrar dene.",
        "nl": "Er ging iets mis. Probeer het opnieuw.",
        "pl": "Coś poszło nie tak. Spróbuj ponownie.",
        "ru": "Что-то пошло не так. Попробуй ещё раз.",
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
        "ptBR": "Fazer minha lição com isto",
        "tr": "Bundan dersimi yap",
        "nl": "Er mijn les van maken",
        "pl": "Zrób z tego moją lekcję",
        "ru": "Сделать из этого мой урок",
        "ar": "اجعله درسي",
    },
    "x_settings_level": {
        "en": "Level", "fr": "Niveau", "de": "Stufe", "es": "Nivel", "es419": "Nivel", "it": "Livello",
        "pt": "Nível", "ptBR": "Nível", "tr": "Seviye", "nl": "Niveau", "pl": "Poziom",
    },
    "x_settings_reset": {
        "en": "Erase everything", "fr": "Tout effacer", "de": "Alles löschen", "es": "Borrar todo", "es419": "Borrar todo",
        "it": "Cancella tutto", "pt": "Apagar tudo", "ptBR": "Apagar tudo", "tr": "Her şeyi sil",
    },
    "x_settings_resetTitle": {
        "en": "Erase everything?", "fr": "Tout effacer ?", "de": "Alles löschen?", "es": "¿Borrar todo?", "es419": "¿Borrar todo?",
        "it": "Cancellare tutto?", "pt": "Apagar tudo?", "ptBR": "Apagar tudo?", "tr": "Her şey silinsin mi?",
    },
    "x_settings_resetBody": {
        "en": "Your lessons and your profile leave this phone. This can't be undone.",
        "fr": "Tes leçons et ton profil quittent ce téléphone. C'est définitif.",
        "de": "Deine Lektionen und dein Profil werden von diesem Handy gelöscht. Das lässt sich nicht rückgängig machen.",
        "es": "Tus lecciones y tu perfil se borran de este teléfono. No se puede deshacer.",
        "es419": "Tus lecciones y tu perfil se borran de este teléfono. No se puede deshacer.",
        "it": "Lezioni e profilo spariscono da questo telefono. Non si può annullare.",
        "pt": "As tuas lições e o teu perfil saem deste telemóvel. Não dá para desfazer.",
        "ptBR": "Suas lições e seu perfil saem deste celular. Não dá para desfazer.",
        "tr": "Derslerin ve profilin bu telefondan silinir. Geri alınamaz.",
    },
}

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
            if text is None or (locale not in ("en", "fr") and text == base):
                continue
            items = plural_items(text)
            if items:
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

    missing = []
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
        else:
            missing.append(name)
            continue
        base = texts["en"]
        if "plural," in base:
            print(f"pluriel ICU non géré : {name}", file=sys.stderr)
        variables = list(dict.fromkeys(re.findall(r"\{(\w+)\}", base)))
        for locale, folder in LOCALES.items():
            text = texts.get(locale)
            if text is None:
                continue
            if locale != "en" and text == base and locale != "fr":
                continue
            entries[folder][name] = (text, variables)

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
