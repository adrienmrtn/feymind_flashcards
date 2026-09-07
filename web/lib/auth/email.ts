/**
 * Ce qu'on vérifie **avant** de demander un lien par courriel.
 *
 * Un lien magique envoyé à une adresse qui n'existe pas ne se perd pas : il revient. Le
 * serveur d'en face répond « ce destinataire n'existe pas », et ce rebond est compté contre
 * l'envoyeur. Comme Micabo part encore sur l'envoyeur mutualisé de Supabase, la note est
 * commune : quelques rebonds sur un projet qui envoie dix courriels font un taux à deux
 * chiffres, et le droit d'envoyer se retire.
 *
 * D'où ce fichier. `type="email"` dans le navigateur accepte `a@b`, accepte `gmial.com`,
 * accepte `.test` : il vérifie une forme, pas une boîte. Ici on trie en trois :
 *
 * - **malformée** : GoTrue la refuserait de toute façon, autant le dire tout de suite ;
 * - **impossible** : un domaine réservé (RFC 2606, RFC 6761) n'a pas de DNS, donc pas de
 *   boîte, donc un rebond garanti ;
 * - **douteuse** : `gmial.com` est un domaine valide et vide. On ne bloque pas - on demande.
 *
 * Le troisième cas est le seul qui compte vraiment, parce que c'est le seul que l'utilisateur
 * ne voit pas lui-même. Il relit son adresse et la trouve juste : c'est *son* adresse, il la
 * tape depuis des années. La question « tu voulais dire gmail.com ? » est la seule chose qui
 * l'arrête, et elle doit rester une question - une correction imposée renverrait le lien à
 * quelqu'un d'autre.
 */

export type EmailVerdict =
  | { kind: "ok"; address: string }
  | { kind: "malformed" }
  | { kind: "undeliverable" }
  | { kind: "suspicious"; address: string; suggestion: string };

/**
 * L'adresse telle que GoTrue la rangera.
 *
 * Il met tout en minuscules avant de l'écrire en base, donc c'est cette forme-là qu'on
 * regarde : vérifier `Eleve@Gmail.COM` pour envoyer à `eleve@gmail.com` serait vérifier
 * autre chose que ce qui part.
 */
export function normalizeAddress(raw: string | null | undefined): string {
  return (raw ?? "").trim().toLowerCase();
}

/**
 * Les domaines qui ne peuvent pas recevoir, par décision de l'IETF.
 *
 * `.test`, `.example` et `.invalid` sont réservés par la RFC 2606 pour la documentation et
 * les essais ; `.localhost` et `.local` ne sortent pas de la machine ; `.internal` est
 * réservé pour les réseaux privés. Aucun n'a de serveur de noms public, donc aucun courriel
 * ne part sans revenir.
 */
export const UNDELIVERABLE_TLDS = [
  "test",
  "example",
  "invalid",
  "localhost",
  "local",
  "internal",
  "lan",
  "home",
  "corp",
];

/** La RFC 2606 réserve aussi ces trois-là, entiers. */
export const UNDELIVERABLE_DOMAINS = ["example.com", "example.net", "example.org"];

const UNDELIVERABLE_TLD_SET = new Set(UNDELIVERABLE_TLDS);
const UNDELIVERABLE_DOMAIN_SET = new Set(UNDELIVERABLE_DOMAINS);

/**
 * Les boîtes que nos élèves utilisent vraiment.
 *
 * La liste sert deux fois : une adresse qui tombe dessus passe sans question, et une adresse
 * qui en approche sans y tomber devient une suggestion. Elle est donc volontairement large -
 * un domaine oublié ici ne bloque personne, mais il fait perdre la suggestion qui aurait
 * rattrapé sa faute de frappe.
 *
 * Le tri suit le public : le lycée français, et les trois pays où l'app est traduite.
 */
export const KNOWN_DOMAINS = [
  // Les grands
  "gmail.com",
  "googlemail.com",
  "outlook.com",
  "outlook.fr",
  "outlook.de",
  "outlook.es",
  "outlook.com.tr",
  "hotmail.com",
  "hotmail.fr",
  "hotmail.de",
  "hotmail.es",
  "hotmail.co.uk",
  "live.com",
  "live.fr",
  "live.de",
  "msn.com",
  "yahoo.com",
  "yahoo.fr",
  "yahoo.de",
  "yahoo.es",
  "yahoo.co.uk",
  "ymail.com",
  "icloud.com",
  "me.com",
  "mac.com",
  "proton.me",
  "protonmail.com",
  "mail.com",
  "zoho.com",
  "aol.com",
  "yandex.com",
  "yandex.ru",
  // France
  "orange.fr",
  "wanadoo.fr",
  "free.fr",
  "sfr.fr",
  "laposte.net",
  "bbox.fr",
  "numericable.fr",
  "neuf.fr",
  "aliceadsl.fr",
  "club-internet.fr",
  // Allemagne
  "gmx.de",
  "gmx.net",
  "gmx.at",
  "web.de",
  "t-online.de",
  "freenet.de",
  "posteo.de",
  // Espagne
  "telefonica.net",
  "terra.es",
  "movistar.es",
  // Turquie
  "mynet.com",
  "superonline.com",
  "windowslive.com",
];

const KNOWN_DOMAIN_SET = new Set(KNOWN_DOMAINS);

/**
 * Les fins de domaine qu'un doigt rate en visant la bonne.
 *
 * `.con` est `.com` avec l'annulaire au lieu de l'index, `.fe` est `.fr` de trois
 * millimètres. Ce sont des extensions qui existent rarement et qu'on ne tape jamais
 * exprès : la correction est sûre, contrairement à une distance d'édition sur le domaine
 * entier.
 */
export const TLD_TYPOS: Record<string, string> = {
  con: "com",
  cmo: "com",
  ocm: "com",
  vom: "com",
  xom: "com",
  clm: "com",
  cim: "com",
  cpm: "com",
  comm: "com",
  co: "com",
  ffr: "fr",
  fe: "fr",
  fir: "fr",
  rf: "fr",
  ed: "de",
  dr: "de",
  ez: "es",
  nte: "net",
  ner: "net",
};

/**
 * Le verdict sur une adresse, avant tout appel réseau.
 *
 * Rien ici ne remplace une vérification par le serveur : seule la boîte d'en face sait si
 * elle existe. Ce qu'on attrape, c'est ce qui est *certainement* perdu, et ce qui en a
 * l'air.
 */
export function inspectAddress(raw: string | null | undefined): EmailVerdict {
  const address = normalizeAddress(raw);

  if (!isWellFormed(address)) return { kind: "malformed" };

  const domain = address.slice(address.lastIndexOf("@") + 1);

  if (UNDELIVERABLE_DOMAIN_SET.has(domain)) return { kind: "undeliverable" };
  if (UNDELIVERABLE_TLD_SET.has(domain.slice(domain.lastIndexOf(".") + 1))) {
    return { kind: "undeliverable" };
  }

  const corrected = suggestDomain(domain);
  if (corrected) {
    const local = address.slice(0, address.lastIndexOf("@"));
    return { kind: "suspicious", address, suggestion: `${local}@${corrected}` };
  }

  return { kind: "ok", address };
}

/** Vrai quand l'adresse peut partir sans question. Le raccourci des appelants pressés. */
export function isSendableAddress(raw: string | null | undefined): boolean {
  return inspectAddress(raw).kind === "ok";
}

/**
 * La forme, et rien d'autre.
 *
 * Volontairement plus strict que la RFC 5321, qui autorise des guillemets, des commentaires
 * et un domaine sans point. Ces adresses existent dans les normes et pas chez les élèves :
 * les accepter, c'est accepter `eleve@lycee`, qui rebondit.
 */
function isWellFormed(address: string): boolean {
  if (address.length === 0 || address.length > 254) return false;
  if (/\s/.test(address)) return false;

  const at = address.indexOf("@");
  if (at <= 0 || at !== address.lastIndexOf("@")) return false;

  const local = address.slice(0, at);
  const domain = address.slice(at + 1);

  if (local.length > 64) return false;
  if (local.startsWith(".") || local.endsWith(".") || local.includes("..")) return false;
  if (!/^[a-z0-9!#$%&'*+/=?^_`{|}~.-]+$/.test(local)) return false;

  if (domain.length === 0 || domain.length > 253) return false;
  if (!/^[a-z0-9.-]+$/.test(domain)) return false;
  if (domain.startsWith(".") || domain.endsWith(".") || domain.includes("..")) return false;
  if (domain.startsWith("-") || domain.endsWith("-")) return false;

  const labels = domain.split(".");
  if (labels.length < 2) return false;
  if (labels.some((label) => label.length === 0 || label.startsWith("-") || label.endsWith("-"))) {
    return false;
  }

  const tld = labels.at(-1) ?? "";
  return tld.length >= 2 && /^[a-z]+$/.test(tld);
}

/**
 * Le domaine qu'on aurait voulu taper, ou rien.
 *
 * Deux passes, dans cet ordre. La fin d'abord, parce qu'une faute sur l'extension est sûre
 * et se corrige seule : `gmail.con` n'a pas besoin qu'on cherche des voisins. Le domaine
 * entier ensuite, contre la liste des boîtes connues.
 *
 * Le seuil de distance dépend de la longueur : sur un domaine court, deux caractères de
 * différence font un autre domaine (`free.fr` et `gree.fr`), et proposer devient deviner.
 */
function suggestDomain(domain: string): string | null {
  if (KNOWN_DOMAIN_SET.has(domain)) return null;

  const cut = domain.lastIndexOf(".");
  const tld = domain.slice(cut + 1);
  const fixedTld = TLD_TYPOS[tld];
  if (fixedTld && fixedTld !== tld) {
    const repaired = `${domain.slice(0, cut)}.${fixedTld}`;
    if (KNOWN_DOMAIN_SET.has(repaired)) return repaired;
  }

  let best: string | null = null;
  let bestDistance = Number.POSITIVE_INFINITY;

  for (const candidate of KNOWN_DOMAINS) {
    const limit = candidate.length <= 8 ? 1 : 2;
    const distance = editDistance(domain, candidate, limit);
    if (distance <= limit && distance < bestDistance) {
      best = candidate;
      bestDistance = distance;
    }
  }

  return best;
}

/**
 * Distance de Damerau-Levenshtein, version « alignement optimal ».
 *
 * L'inversion compte pour une opération et non deux, ce qui compte ici : `gmial` est
 * `gmail` avec deux lettres échangées, la faute de frappe la plus courante qui soit. Sans
 * elle, `gmial.com` serait à distance 2 de `gmail.com`, au même rang que des domaines qui
 * n'ont rien à voir.
 *
 * `limit` arrête le calcul dès qu'une ligne entière dépasse le seuil : on compare contre
 * une soixantaine de domaines à chaque frappe, et la réponse exacte au-delà du seuil ne
 * sert à personne.
 */
function editDistance(a: string, b: string, limit: number): number {
  if (Math.abs(a.length - b.length) > limit) return limit + 1;
  if (a.length === 0) return b.length;
  if (b.length === 0) return a.length;

  const source = [...a];
  const target = [...b];

  // Trois lignes de la matrice suffisent, et elles tournent : l'avant-dernière n'est gardée
  // que pour l'inversion, qui regarde deux lignes en arrière.
  //
  // Les `!` disent ce que les bornes garantissent déjà - `i` va de 1 à `source.length`, `j`
  // de 1 à `target.length`, et les lignes ont `target.length + 1` cases. TypeScript ne peut
  // pas le déduire, mais aucun de ces index ne sort du tableau.
  let previousPrevious = new Uint16Array(target.length + 1);
  let previous = Uint16Array.from({ length: target.length + 1 }, (_, index) => index);
  let current = new Uint16Array(target.length + 1);

  for (let i = 1; i <= source.length; i += 1) {
    current[0] = i;
    let rowBest = i;

    for (let j = 1; j <= target.length; j += 1) {
      const substitution = source[i - 1] === target[j - 1] ? 0 : 1;
      let value = Math.min(
        current[j - 1]! + 1,
        previous[j]! + 1,
        previous[j - 1]! + substitution,
      );

      if (
        i > 1 &&
        j > 1 &&
        source[i - 1] === target[j - 2] &&
        source[i - 2] === target[j - 1]
      ) {
        value = Math.min(value, previousPrevious[j - 2]! + 1);
      }

      current[j] = value;
      rowBest = Math.min(rowBest, value);
    }

    if (rowBest > limit) return limit + 1;

    const recycled = previousPrevious;
    previousPrevious = previous;
    previous = current;
    current = recycled;
  }

  return previous[target.length]!;
}
