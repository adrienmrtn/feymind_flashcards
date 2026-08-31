import type { Metadata } from "next";
import Link from "next/link";

import { LegalSection, LegalShell } from "@/components/legal/LegalShell";
import { LEGAL_CONTACT, LEGAL_EDITOR, LEGAL_IOS_BUNDLE, LEGAL_SITE, PRIVACY_PATH } from "@/lib/legal";

export const metadata: Metadata = {
  title: "Conditions d'utilisation",
  description:
    "Les règles du service Micabo, pour l'iPhone et le site : compte, cours, abonnement, responsabilités.",
  alternates: { canonical: "/conditions" },
};

/**
 * Les conditions, pour les deux clients.
 *
 * Même adresse que le paywall iOS : `https://micabo.app/conditions`.
 */
export default function TermsPage() {
  return (
    <LegalShell title="Conditions d'utilisation">
      <p>
        Ces conditions régissent l&apos;usage de Micabo — le site{" "}
        <a href={LEGAL_SITE} className="underline-draw text-ink">
          micabo.app
        </a>{" "}
        et l&apos;application iPhone ({LEGAL_IOS_BUNDLE}). En créant un compte ou en
        utilisant le service, vous les acceptez. Si vous n&apos;êtes pas d&apos;accord,
        n&apos;ouvrez pas de compte.
      </p>
      <p>
        L&apos;éditeur est {LEGAL_EDITOR}. Contact :{" "}
        <a href={`mailto:${LEGAL_CONTACT}`} className="underline-draw text-ink">
          {LEGAL_CONTACT}
        </a>
        .
      </p>

      <LegalSection title="Le service">
        <p>
          Micabo lit un document de cours que vous déposez et en écrit une fiche et des
          flashcards. Il les fait revenir selon une répétition espacée (la même règle
          SM-2 sur iPhone et sur le site). Vous pouvez poser la date d&apos;un examen :
          le plan de révision se resserre alors vers ce jour. Un même compte ouvre les
          deux clients.
        </p>
        <p>
          Une partie du service est accessible sans abonnement. L&apos;accès Pro (cours
          et cartes au-delà du plafond gratuit, selon l&apos;offre affichée au moment de
          l&apos;achat) est payant.
        </p>
      </LegalSection>

      <LegalSection title="Le compte">
        <p>
          Vous pouvez vous connecter avec Apple, Google, ou un lien envoyé par courriel.
          Vous êtes responsable de l&apos;accès à votre boîte mail et à ces comptes
          tiers. Un seul compte par personne.
        </p>
        <p>
          Vous pouvez supprimer le compte depuis Réglages, sur le site ou dans l&apos;app
          iPhone. Cela efface vos cours, vos cartes et votre historique. Les achats déjà
          encaissés par Apple ou Stripe restent soumis à leurs règles de remboursement.
        </p>
      </LegalSection>

      <LegalSection title="Vos cours">
        <p>
          Vous gardez la propriété de ce que vous déposez. Vous nous donnez seulement
          le droit, limité et révocable, de le lire, de le stocker et de le transformer
          en fiche et en cartes, pour vous fournir le service — y compris en l&apos;envoyant
          à un modèle de langage le temps de la génération.
        </p>
        <p>
          Vous ne déposez que des documents que vous avez le droit d&apos;utiliser. Un
          polycopié de votre professeur, vos notes, une vidéo dont l&apos;import est
          autorisé : oui. Un ouvrage entier recopié, le devoir d&apos;un autre, un
          contenu illégal : non. Nous pouvons retirer un cours ou fermer un compte qui
          casse cette règle.
        </p>
        <p>
          La visibilité se décide à l&apos;import. Un cours privé reste entre vous. Un
          cours partagé n&apos;est visible que par les personnes que vous avez choisies
          (amis, ou camarades de l&apos;établissement). Ce n&apos;est pas une
          bibliothèque ouverte à tous.
        </p>
      </LegalSection>

      <LegalSection title="Ce que Micabo n'est pas">
        <p>
          La fiche et les cartes sont générées automatiquement. Elles peuvent se
          tromper, omettre un passage, ou mal lire un scan. Micabo n&apos;est pas un
          professeur, ni une garantie de note. Vous restez responsable de ce que vous
          apprenez et de ce que vous rendez le jour de l&apos;examen.
        </p>
        <p>
          Nous nous efforçons de ne pas inventer une définition quand le document ne la
          porte pas. Ça ne rend pas le résultat infaillible.
        </p>
      </LegalSection>

      <LegalSection title="L'abonnement">
        <p>
          Les prix, la durée et l&apos;essai éventuel sont ceux affichés avant le
          paiement. Ils peuvent changer pour les nouveaux achats ; un abonnement déjà
          en cours garde ses conditions jusqu&apos;à son renouvellement.
        </p>
        <p>
          <strong className="font-semibold text-ink">Sur iPhone</strong>, le paiement
          passe par l&apos;App Store. La résiliation, le renouvellement et les
          remboursements suivent les règles d&apos;Apple. Gérez l&apos;abonnement dans
          les réglages de votre compte Apple.
        </p>
        <p>
          <strong className="font-semibold text-ink">Sur le site</strong>, le paiement
          passe par Stripe. La résiliation se fait depuis l&apos;espace de facturation
          indiqué dans le profil, ou en nous écrivant. Un essai, s&apos;il est proposé,
          ne se transforme en paiement que si vous le laissez aller à son terme.
        </p>
        <p>
          L&apos;accès Pro acheté d&apos;un côté vaut de l&apos;autre : le même compte
          est Pro sur iPhone et sur le site. Un incident de paiement peut ouvrir une
          période de grâce ; nous ne fermons pas l&apos;accès à la première heure.
        </p>
      </LegalSection>

      <LegalSection title="Ce que vous ne faites pas">
        <ul className="list-disc space-y-2 pl-5">
          <li>Utiliser le service pour nuire à quelqu&apos;un, harceler, ou tricher d&apos;une façon qui viole le règlement de votre établissement.</li>
          <li>Tenter d&apos;accéder aux cours d&apos;un autre compte, de contourner le cloisonnement, ou de surcharger volontairement le service.</li>
          <li>Revendre l&apos;accès, extraire le service par un robot au-delà d&apos;un usage humain normal, ou copier Micabo pour en faire un produit concurrent à partir de nos générations.</li>
          <li>Déposer des contenus illégaux, haineux, ou qui portent atteinte à la vie privée d&apos;autrui.</li>
        </ul>
      </LegalSection>

      <LegalSection title="Disponibilité">
        <p>
          Nous faisons notre possible pour que iPhone et site restent joignables. Une
          maintenance, une panne d&apos;un prestataire (hébergeur, modèle, boutique) ou
          une erreur de génération peut interrompre le service. Nous n&apos;offrons pas
          de garantie de résultat scolaire, ni de disponibilité ininterrompue.
        </p>
      </LegalSection>

      <LegalSection title="Responsabilité">
        <p>
          Si vous êtes un consommateur, vos droits légaux (garantie, médiation,
          clauses abusives) s&apos;appliquent et ces conditions ne les écartent pas.
        </p>
        <p>
          Au-delà, Micabo n&apos;est pas responsable des notes obtenues, d&apos;une
          fiche incomplète, d&apos;un oubli le jour J, ou d&apos;un dommage indirect
          (temps perdu, examen manqué). Notre responsabilité, si elle était retenue
          pour un manquement qui nous est imputable, est limitée au montant que vous
          nous avez versé au cours des douze derniers mois — sauf faute lourde, dol,
          ou atteinte à l&apos;intégrité de la personne.
        </p>
      </LegalSection>

      <LegalSection title="Mineurs">
        <p>
          Si vous avez moins de quinze ans, un titulaire de l&apos;autorité parentale
          doit accepter ces conditions et surveiller l&apos;usage. Le partage d&apos;un
          cours avec des amis reste sous votre responsabilité, et sous la leur.
        </p>
      </LegalSection>

      <LegalSection title="Droit applicable">
        <p>
          Ces conditions sont régies par le droit français. En cas de litige, et après
          une tentative de résolution écrite à{" "}
          <a href={`mailto:${LEGAL_CONTACT}`} className="underline-draw text-ink">
            {LEGAL_CONTACT}
          </a>
          , les tribunaux français sont compétents — sous réserve des règles de
          protection du consommateur qui vous seraient plus favorables.
        </p>
      </LegalSection>

      <LegalSection title="Modifications">
        <p>
          Nous pouvons mettre à jour ces conditions. La date en tête de page fait foi.
          Un changement qui touche au prix d&apos;un abonnement en cours vous est
          annoncé avant le renouvellement.
        </p>
        <p>
          La{" "}
          <Link href={PRIVACY_PATH} className="underline-draw text-ink">
            politique de confidentialité
          </Link>{" "}
          décrit le traitement de vos données.
        </p>
      </LegalSection>
    </LegalShell>
  );
}
