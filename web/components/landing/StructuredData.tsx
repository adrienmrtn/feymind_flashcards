import { CANONICAL_URL, IS_INDEXABLE } from "@/lib/config";

/**
 * **Ce qui dit à Google que « Micabo » est un nom, pas un mot mal orthographié.**
 *
 * Une marque courte et inventée est le cas où les données structurées comptent le plus :
 * sans elles, le moteur doit deviner l'entité derrière la requête, et il propose une
 * correction orthographique. `Organization` avec un `@id` stable, un nom et une adresse
 * donne quelque chose à rattacher.
 *
 * Ce qu'elles ne font pas, et qu'il faut savoir avant d'en attendre trop : **elles ne
 * fabriquent pas de sitelinks.** Les liens sous un résultat sont choisis par Google à partir
 * des pages qu'il a explorées, de leurs titres et des liens internes qui y mènent. On ne les
 * déclare pas ; on rend leur choix possible. Le `SearchAction` de la boîte de recherche est
 * abandonné depuis 2023 et n'est donc pas ici.
 *
 * `WebSite` et `Organization` sont liés par `publisher` plutôt que répétés : deux entités qui
 * s'ignorent dans le même graphe se lisent comme deux marques.
 */
export function SiteStructuredData() {
  // Une prévisualisation ne se déclare pas : elle porterait le même `@id` que le site et
  // désignerait deux adresses pour une seule marque.
  if (!IS_INDEXABLE) return null;

  const graph = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Organization",
        "@id": `${CANONICAL_URL}/#organization`,
        name: "Micabo",
        url: `${CANONICAL_URL}/`,
        logo: `${CANONICAL_URL}/icon-512.png`,
        email: "team@micabo.app",
        description:
          "Micabo transforme un cours en fiche et en flashcards, et les fait revenir par répétition espacée.",
      },
      {
        "@type": "WebSite",
        "@id": `${CANONICAL_URL}/#website`,
        name: "Micabo",
        url: `${CANONICAL_URL}/`,
        inLanguage: "fr-FR",
        publisher: { "@id": `${CANONICAL_URL}/#organization` },
      },
      {
        "@type": "SoftwareApplication",
        "@id": `${CANONICAL_URL}/#app`,
        name: "Micabo",
        applicationCategory: "EducationalApplication",
        operatingSystem: "Web, iOS",
        url: `${CANONICAL_URL}/`,
        publisher: { "@id": `${CANONICAL_URL}/#organization` },
        description:
          "Dépose un polycopié, une photo de tes notes ou une vidéo de cours. Micabo en écrit la fiche, en tire les cartes, et les fait revenir avant que tu l'oublies.",
      },
    ],
  };

  return (
    <script
      type="application/ld+json"
      // Le graphe est écrit ici, sans donnée d'utilisateur : rien à échapper qui vienne
      // d'ailleurs. Les chevrons sont neutralisés par prudence, parce qu'un `</script>`
      // dans une chaîne refermerait la balise.
      dangerouslySetInnerHTML={{
        __html: JSON.stringify(graph).replace(/</g, "\\u003c"),
      }}
    />
  );
}
