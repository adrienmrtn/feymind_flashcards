import type { UiLocale } from "./locales";

/**
 * Libellés d'affichage des matières. La valeur stockée reste le français du
 * noyau : l'iPhone la lit telle quelle. Ici on ne traduit que ce qu'on montre.
 */

const FAMILIES: Record<string, Record<UiLocale, string>> = {
  Sciences: {
    en: "Sciences",
    fr: "Sciences",
    de: "Naturwiss.",
    es: "Ciencias",
    tr: "Bilimler",
  },
  Santé: {
    en: "Health",
    fr: "Santé",
    de: "Gesundheit",
    es: "Salud",
    tr: "Sağlık",
  },
  "Sciences humaines": {
    en: "Humanities",
    fr: "Sciences humaines",
    de: "Geisteswiss.",
    es: "Humanidades",
    tr: "Beşeri bilimler",
  },
  Langues: {
    en: "Languages",
    fr: "Langues",
    de: "Sprachen",
    es: "Idiomas",
    tr: "Diller",
  },
  "Droit & économie": {
    en: "Law & economics",
    fr: "Droit & économie",
    de: "Recht & Wiwi",
    es: "Derecho y economía",
    tr: "Hukuk ve ekonomi",
  },
  Technique: {
    en: "Engineering",
    fr: "Technique",
    de: "Technik",
    es: "Técnica",
    tr: "Teknik",
  },
  "Et aussi": {
    en: "And also",
    fr: "Et aussi",
    de: "Und auch",
    es: "Y también",
    tr: "Ayrıca",
  },
};

const SUBJECTS: Record<string, Record<UiLocale, string>> = {
  Mathématiques: { en: "Mathematics", fr: "Mathématiques", de: "Mathematik", es: "Matemáticas", tr: "Matematik" },
  Physique: { en: "Physics", fr: "Physique", de: "Physik", es: "Física", tr: "Fizik" },
  Chimie: { en: "Chemistry", fr: "Chimie", de: "Chemie", es: "Química", tr: "Kimya" },
  SVT: { en: "Biology", fr: "SVT", de: "Biologie", es: "Biología", tr: "Biyoloji" },
  Statistiques: { en: "Statistics", fr: "Statistiques", de: "Statistik", es: "Estadística", tr: "İstatistik" },
  Astronomie: { en: "Astronomy", fr: "Astronomie", de: "Astronomie", es: "Astronomía", tr: "Astronomi" },
  Géologie: { en: "Geology", fr: "Géologie", de: "Geologie", es: "Geología", tr: "Jeoloji" },
  Médecine: { en: "Medicine", fr: "Médecine", de: "Medizin", es: "Medicina", tr: "Tıp" },
  Pharmacie: { en: "Pharmacy", fr: "Pharmacie", de: "Pharmazie", es: "Farmacia", tr: "Eczacılık" },
  "Soins infirmiers": { en: "Nursing", fr: "Soins infirmiers", de: "Pflege", es: "Enfermería", tr: "Hemşirelik" },
  Kinésithérapie: { en: "Physiotherapy", fr: "Kinésithérapie", de: "Physioth.", es: "Fisioterapia", tr: "Fizyoterapi" },
  Anatomie: { en: "Anatomy", fr: "Anatomie", de: "Anatomie", es: "Anatomía", tr: "Anatomi" },
  Nutrition: { en: "Nutrition", fr: "Nutrition", de: "Ernährung", es: "Nutrición", tr: "Beslenme" },
  Histoire: { en: "History", fr: "Histoire", de: "Geschichte", es: "Historia", tr: "Tarih" },
  Géographie: { en: "Geography", fr: "Géographie", de: "Geografie", es: "Geografía", tr: "Coğrafya" },
  Philosophie: { en: "Philosophy", fr: "Philosophie", de: "Philosophie", es: "Filosofía", tr: "Felsefe" },
  Sociologie: { en: "Sociology", fr: "Sociologie", de: "Soziologie", es: "Sociología", tr: "Sosyoloji" },
  Psychologie: { en: "Psychology", fr: "Psychologie", de: "Psychologie", es: "Psicología", tr: "Psikoloji" },
  "Sciences politiques": { en: "Political science", fr: "Sciences politiques", de: "Politik", es: "Ciencias políticas", tr: "Siyaset" },
  Anglais: { en: "English", fr: "Anglais", de: "Englisch", es: "Inglés", tr: "İngilizce" },
  Espagnol: { en: "Spanish", fr: "Español", de: "Spanisch", es: "Español", tr: "İspanyolca" },
  Allemand: { en: "German", fr: "Allemand", de: "Deutsch", es: "Alemán", tr: "Almanca" },
  Italien: { en: "Italian", fr: "Italien", de: "Italienisch", es: "Italiano", tr: "İtalyanca" },
  Portugais: { en: "Portuguese", fr: "Portugais", de: "Portugiesisch", es: "Portugués", tr: "Portekizce" },
  Japonais: { en: "Japanese", fr: "Japonais", de: "Japanisch", es: "Japonés", tr: "Japonca" },
  Chinois: { en: "Chinese", fr: "Chinois", de: "Chinesisch", es: "Chino", tr: "Çince" },
  Arabe: { en: "Arabic", fr: "Arabe", de: "Arabisch", es: "Árabe", tr: "Arapça" },
  Russe: { en: "Russian", fr: "Russe", de: "Russisch", es: "Ruso", tr: "Rusça" },
  "Latin & grec": { en: "Latin & Greek", fr: "Latin & grec", de: "Latein", es: "Latín y griego", tr: "Latince" },
  Français: { en: "French", fr: "Français", de: "Französisch", es: "Francés", tr: "Fransızca" },
  Droit: { en: "Law", fr: "Droit", de: "Recht", es: "Derecho", tr: "Hukuk" },
  Économie: { en: "Economics", fr: "Économie", de: "Wirtschaft", es: "Economía", tr: "Ekonomi" },
  Comptabilité: { en: "Accounting", fr: "Comptabilité", de: "Buchhaltung", es: "Contabilidad", tr: "Muhasebe" },
  Finance: { en: "Finance", fr: "Finance", de: "Finanzen", es: "Finanzas", tr: "Finans" },
  Management: { en: "Management", fr: "Management", de: "Management", es: "Management", tr: "Yönetim" },
  Marketing: { en: "Marketing", fr: "Marketing", de: "Marketing", es: "Marketing", tr: "Pazarlama" },
  Informatique: { en: "Computer science", fr: "Informatique", de: "Informatik", es: "Informática", tr: "Bilişim" },
  Algorithmique: { en: "Algorithms", fr: "Algorithmique", de: "Algorithmen", es: "Algoritmos", tr: "Algoritma" },
  Réseaux: { en: "Networks", fr: "Réseaux", de: "Netzwerke", es: "Redes", tr: "Ağlar" },
  Électronique: { en: "Electronics", fr: "Électronique", de: "Elektronik", es: "Electrónica", tr: "Elektronik" },
  Mécanique: { en: "Mechanics", fr: "Mécanique", de: "Mechanik", es: "Mecánica", tr: "Mekanik" },
  "Génie civil": { en: "Civil engineering", fr: "Génie civil", de: "Bauwesen", es: "Obra civil", tr: "İnşaat" },
  Architecture: { en: "Architecture", fr: "Architecture", de: "Architektur", es: "Arquitectura", tr: "Mimarlık" },
  Arts: { en: "Arts", fr: "Arts", de: "Kunst", es: "Artes", tr: "Sanat" },
  Musique: { en: "Music", fr: "Musique", de: "Musik", es: "Música", tr: "Müzik" },
  Cinéma: { en: "Film", fr: "Cinéma", de: "Film", es: "Cine", tr: "Sinema" },
  Théâtre: { en: "Theatre", fr: "Théâtre", de: "Theater", es: "Teatro", tr: "Tiyatro" },
  Danse: { en: "Dance", fr: "Danse", de: "Tanz", es: "Danza", tr: "Dans" },
  Photographie: { en: "Photography", fr: "Photographie", de: "Fotografie", es: "Fotografía", tr: "Fotoğraf" },
  Journalisme: { en: "Journalism", fr: "Journalisme", de: "Journalismus", es: "Periodismo", tr: "Gazetecilik" },
  Pédagogie: { en: "Education", fr: "Pédagogie", de: "Pädagogik", es: "Pedagogía", tr: "Pedagoji" },
  "Sport & STAPS": { en: "Sport", fr: "Sport & STAPS", de: "Sport", es: "Deporte", tr: "Spor" },
  "Code de la route": { en: "Highway code", fr: "Code de la route", de: "Führerschein", es: "Tráfico", tr: "Trafik" },
  "Culture générale": { en: "General knowledge", fr: "Culture générale", de: "Allgemeinwissen", es: "Cultura general", tr: "Genel kültür" },
};

export function displayFamily(name: string, locale: UiLocale): string {
  return FAMILIES[name]?.[locale] ?? name;
}

export function displaySubject(name: string, locale: UiLocale): string {
  return SUBJECTS[name]?.[locale] ?? name;
}

export function subjectDisplayCoverage() {
  return { families: Object.keys(FAMILIES), subjects: Object.keys(SUBJECTS) };
}
