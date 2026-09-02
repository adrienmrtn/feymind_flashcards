import type { UiLocale } from "./locales";

/**
 * Libellés d'affichage des matières. La valeur stockée reste le français du
 * noyau : l'iPhone la lit telle quelle. Ici on ne traduit que ce qu'on montre.
 */

const FAMILIES: Record<string, Record<UiLocale, string>> = {
  Sciences: {
    fr: "Sciences",
    de: "Naturwiss.",
    es: "Ciencias",
    tr: "Bilimler",
  },
  Santé: {
    fr: "Santé",
    de: "Gesundheit",
    es: "Salud",
    tr: "Sağlık",
  },
  "Sciences humaines": {
    fr: "Sciences humaines",
    de: "Geisteswiss.",
    es: "Humanidades",
    tr: "Beşeri bilimler",
  },
  Langues: {
    fr: "Langues",
    de: "Sprachen",
    es: "Idiomas",
    tr: "Diller",
  },
  "Droit & économie": {
    fr: "Droit & économie",
    de: "Recht & Wiwi",
    es: "Derecho y economía",
    tr: "Hukuk ve ekonomi",
  },
  Technique: {
    fr: "Technique",
    de: "Technik",
    es: "Técnica",
    tr: "Teknik",
  },
  "Et aussi": {
    fr: "Et aussi",
    de: "Und auch",
    es: "Y también",
    tr: "Ayrıca",
  },
};

const SUBJECTS: Record<string, Record<UiLocale, string>> = {
  Mathématiques: { fr: "Mathématiques", de: "Mathematik", es: "Matemáticas", tr: "Matematik" },
  Physique: { fr: "Physique", de: "Physik", es: "Física", tr: "Fizik" },
  Chimie: { fr: "Chimie", de: "Chemie", es: "Química", tr: "Kimya" },
  SVT: { fr: "SVT", de: "Biologie", es: "Biología", tr: "Biyoloji" },
  Statistiques: { fr: "Statistiques", de: "Statistik", es: "Estadística", tr: "İstatistik" },
  Astronomie: { fr: "Astronomie", de: "Astronomie", es: "Astronomía", tr: "Astronomi" },
  Géologie: { fr: "Géologie", de: "Geologie", es: "Geología", tr: "Jeoloji" },
  Médecine: { fr: "Médecine", de: "Medizin", es: "Medicina", tr: "Tıp" },
  Pharmacie: { fr: "Pharmacie", de: "Pharmazie", es: "Farmacia", tr: "Eczacılık" },
  "Soins infirmiers": { fr: "Soins infirmiers", de: "Pflege", es: "Enfermería", tr: "Hemşirelik" },
  Kinésithérapie: { fr: "Kinésithérapie", de: "Physioth.", es: "Fisioterapia", tr: "Fizyoterapi" },
  Anatomie: { fr: "Anatomie", de: "Anatomie", es: "Anatomía", tr: "Anatomi" },
  Nutrition: { fr: "Nutrition", de: "Ernährung", es: "Nutrición", tr: "Beslenme" },
  Histoire: { fr: "Histoire", de: "Geschichte", es: "Historia", tr: "Tarih" },
  Géographie: { fr: "Géographie", de: "Geografie", es: "Geografía", tr: "Coğrafya" },
  Philosophie: { fr: "Philosophie", de: "Philosophie", es: "Filosofía", tr: "Felsefe" },
  Sociologie: { fr: "Sociologie", de: "Soziologie", es: "Sociología", tr: "Sosyoloji" },
  Psychologie: { fr: "Psychologie", de: "Psychologie", es: "Psicología", tr: "Psikoloji" },
  "Sciences politiques": { fr: "Sciences politiques", de: "Politik", es: "Ciencias políticas", tr: "Siyaset" },
  Anglais: { fr: "Anglais", de: "Englisch", es: "Inglés", tr: "İngilizce" },
  Espagnol: { fr: "Español", de: "Spanisch", es: "Español", tr: "İspanyolca" },
  Allemand: { fr: "Allemand", de: "Deutsch", es: "Alemán", tr: "Almanca" },
  Italien: { fr: "Italien", de: "Italienisch", es: "Italiano", tr: "İtalyanca" },
  Portugais: { fr: "Portugais", de: "Portugiesisch", es: "Portugués", tr: "Portekizce" },
  Japonais: { fr: "Japonais", de: "Japanisch", es: "Japonés", tr: "Japonca" },
  Chinois: { fr: "Chinois", de: "Chinesisch", es: "Chino", tr: "Çince" },
  Arabe: { fr: "Arabe", de: "Arabisch", es: "Árabe", tr: "Arapça" },
  Russe: { fr: "Russe", de: "Russisch", es: "Ruso", tr: "Rusça" },
  "Latin & grec": { fr: "Latin & grec", de: "Latein", es: "Latín y griego", tr: "Latince" },
  Français: { fr: "Français", de: "Französisch", es: "Francés", tr: "Fransızca" },
  Droit: { fr: "Droit", de: "Recht", es: "Derecho", tr: "Hukuk" },
  Économie: { fr: "Économie", de: "Wirtschaft", es: "Economía", tr: "Ekonomi" },
  Comptabilité: { fr: "Comptabilité", de: "Buchhaltung", es: "Contabilidad", tr: "Muhasebe" },
  Finance: { fr: "Finance", de: "Finanzen", es: "Finanzas", tr: "Finans" },
  Management: { fr: "Management", de: "Management", es: "Management", tr: "Yönetim" },
  Marketing: { fr: "Marketing", de: "Marketing", es: "Marketing", tr: "Pazarlama" },
  Informatique: { fr: "Informatique", de: "Informatik", es: "Informática", tr: "Bilişim" },
  Algorithmique: { fr: "Algorithmique", de: "Algorithmen", es: "Algoritmos", tr: "Algoritma" },
  Réseaux: { fr: "Réseaux", de: "Netzwerke", es: "Redes", tr: "Ağlar" },
  Électronique: { fr: "Électronique", de: "Elektronik", es: "Electrónica", tr: "Elektronik" },
  Mécanique: { fr: "Mécanique", de: "Mechanik", es: "Mecánica", tr: "Mekanik" },
  "Génie civil": { fr: "Génie civil", de: "Bauwesen", es: "Obra civil", tr: "İnşaat" },
  Architecture: { fr: "Architecture", de: "Architektur", es: "Arquitectura", tr: "Mimarlık" },
  Arts: { fr: "Arts", de: "Kunst", es: "Artes", tr: "Sanat" },
  Musique: { fr: "Musique", de: "Musik", es: "Música", tr: "Müzik" },
  Cinéma: { fr: "Cinéma", de: "Film", es: "Cine", tr: "Sinema" },
  Théâtre: { fr: "Théâtre", de: "Theater", es: "Teatro", tr: "Tiyatro" },
  Danse: { fr: "Danse", de: "Tanz", es: "Danza", tr: "Dans" },
  Photographie: { fr: "Photographie", de: "Fotografie", es: "Fotografía", tr: "Fotoğraf" },
  Journalisme: { fr: "Journalisme", de: "Journalismus", es: "Periodismo", tr: "Gazetecilik" },
  Pédagogie: { fr: "Pédagogie", de: "Pädagogik", es: "Pedagogía", tr: "Pedagoji" },
  "Sport & STAPS": { fr: "Sport & STAPS", de: "Sport", es: "Deporte", tr: "Spor" },
  "Code de la route": { fr: "Code de la route", de: "Führerschein", es: "Tráfico", tr: "Trafik" },
  "Culture générale": { fr: "Culture générale", de: "Allgemeinwissen", es: "Cultura general", tr: "Genel kültür" },
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
