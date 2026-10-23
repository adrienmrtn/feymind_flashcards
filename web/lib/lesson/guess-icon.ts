/**
 * **L'icône d'une leçon qui n'en a pas reçu**, déduite de sa matière ou de son titre : globe
 * pour la géographie, fiole pour la chimie, parchemin pour l'histoire, calculatrice pour les
 * maths, atome pour la physique, livre sinon. Les mots-clés couvrent les cinq langues de
 * l'app, sans accents. Jumeau de `MicaboIcon.guess` côté Swift, dans le même ordre : la
 * première matière reconnue gagne.
 */
const SUBJECT_KEYWORDS: readonly [string, readonly string[]][] = [
  ["calculatrice", ["math", "algebr", "geometr", "statisti", "calcul", "matemat", "probabil"]],
  ["atome", ["physi", "fizik", "fisica", "mecaniq", "electric", "optique", "quantum"]],
  ["fiole", ["chimi", "chemi", "kimya", "quimic", "biolog", "svt", "biyoloji", "life science"]],
  ["globe", ["geograph", "geografi", "cografya", "erdkunde", "environnement", "climat"]],
  ["parchemin", ["histoir", "history", "histori", "tarih", "geschicht", "droit", "law", "recht"]],
  ["cerveau", ["philo", "psycho", "socio", "neuro"]],
  ["palette", ["arts", "dessin", "design", "musique", "music", "muzik"]],
  ["plume", ["litter", "literat", "francais", "french", "edebiyat", "poesie", "lettres"]],
  ["diplome", ["econom", "finance", "gestion", "ekonomi", "wirtschaft"]],
  ["fusee", ["informati", "computer", "program", "bilgisayar"]],
];

export function guessIcon(subject: string | null | undefined, title: string): string {
  const text = `${subject ?? ""} ${title}`
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "");
  for (const [icon, keys] of SUBJECT_KEYWORDS) {
    if (keys.some((key) => text.includes(key))) return icon;
  }
  return "livre-ouvert";
}
