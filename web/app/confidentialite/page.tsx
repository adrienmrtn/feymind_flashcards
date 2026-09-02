import type { Metadata } from "next";
import Link from "next/link";

import { LegalSection, LegalShell } from "@/components/legal/LegalShell";
import { LEGAL_CONTACT, LEGAL_EDITOR, LEGAL_IOS_BUNDLE, LEGAL_SITE, TERMS_PATH } from "@/lib/legal";

export const metadata: Metadata = {
  title: "Confidentialité",
  description:
    "Ce que Micabo retient de vous, sur iPhone et sur le site, et ce que vous pouvez en faire.",
  alternates: { canonical: "/confidentialite" },
};

/**
 * La politique de confidentialité, pour les deux clients.
 *
 * Les adresses sont celles que l'app iOS ouvre déjà depuis le paywall
 * (`https://micabo.app/confidentialite`).
 */
export default function PrivacyPage() {
  return (
    <LegalShell title="Politique de confidentialité">
      <p>
        Cette politique décrit les données que Micabo traite lorsque vous utilisez le site{" "}
        <a href={LEGAL_SITE} className="underline-draw text-ink">
          micabo.app
        </a>{" "}
        ou l&apos;application iPhone (identifiant {LEGAL_IOS_BUNDLE}). Les deux clients
        partagent le même compte et la même base. Elle s&apos;applique aussi si vous
        n&apos;avez pas encore de compte et que vous consultez le site.
      </p>
      <p>
        Le responsable du traitement est {LEGAL_EDITOR}, qui édite Micabo. Pour toute
        question, correction ou suppression :{" "}
        <a href={`mailto:${LEGAL_CONTACT}`} className="underline-draw text-ink">
          {LEGAL_CONTACT}
        </a>
        .
      </p>

      <LegalSection title="Ce que Micabo est">
        <p>
          Micabo transforme un cours (PDF, photo, document, vidéo) en fiche et en
          flashcards, puis les fait revenir avant que vous les oubliiez. Un mode examen
          resserre les révisions à l&apos;approche d&apos;une date. Vous pouvez partager un
          cours avec des amis, ou le garder pour vous.
        </p>
      </LegalSection>

      <LegalSection title="Quelles données nous traitons">
        <p>
          <strong className="font-semibold text-ink">Le compte.</strong> Adresse e-mail,
          identifiants fournis par Apple ou Google si vous choisissez ces connexions,
          et un nom d&apos;utilisateur. Nous ne stockons pas votre mot de passe : la
          connexion par courriel se fait par un lien, pas par un secret que nous
          garderions.
        </p>
        <p>
          <strong className="font-semibold text-ink">Le parcours scolaire.</strong> Pays
          d&apos;études, palier, matières, établissement si vous le donnez. Cela sert à
          écrire la fiche dans la bonne langue et le bon système, et à vous montrer les
          camarades du même établissement si un cours est partagé.
        </p>
        <p>
          <strong className="font-semibold text-ink">Vos cours.</strong> Les fichiers ou
          liens que vous déposez, le texte qui en est extrait, les fiches et les cartes
          générées, les images de schémas, les examens (nom, date, note visée) et
          l&apos;historique de révision (quand une carte revient, comment vous l&apos;avez
          notée).
        </p>
        <p>
          <strong className="font-semibold text-ink">Les amis.</strong> Les demandes
          d&apos;ami, la liste de vos amis, et la visibilité que vous posez sur chaque
          cours au moment de l&apos;import : vous seul, vos amis, ou les camarades de
          votre établissement. Il n&apos;existe pas de catalogue public où un inconnu
          tomberait sur vos fiches.
        </p>
        <p>
          <strong className="font-semibold text-ink">L&apos;abonnement.</strong> L&apos;état
          de votre accès Pro (actif, essai, résilié), pas le numéro de votre carte. Le
          paiement est encaissé par Apple sur iPhone, par Stripe sur le site. RevenueCat
          tient le droit, pour que l&apos;iPhone et le navigateur soient d&apos;accord.
        </p>
        <p>
          <strong className="font-semibold text-ink">La liste d&apos;attente.</strong> Si
          vous laissez votre adresse avant d&apos;avoir un compte, nous la gardons pour
          vous prévenir de l&apos;ouverture, avec la page d&apos;où vous venez. Elle n&apos;est
          pas liée à un compte et n&apos;est pas visible via l&apos;application.
        </p>
        <p>
          <strong className="font-semibold text-ink">Les retours.</strong> Si vous
          envoyez un bug ou une idée depuis l&apos;app, nous gardons le message, le type
          (bug ou idée), et le lien avec votre compte, pour y répondre. Ils restent
          24 mois, puis sont effacés. Ils ne servent pas à vous profiler.
        </p>
        <p>
          <strong className="font-semibold text-ink">L&apos;usage des générations.</strong>{" "}
          Un compteur par jour et par fonction (fiche, cartes, explication), sans le
          contenu du cours. Il sert à limiter les abus, pas à vous profiler.
        </p>
        <p>
          <strong className="font-semibold text-ink">L&apos;annuaire.</strong> Votre nom
          d&apos;utilisateur et, si vous l&apos;avez indiqué, votre établissement. C&apos;est
          ce que voient un ami ou un camarade, pas votre e-mail ni vos préférences.
        </p>
        <p>
          <strong className="font-semibold text-ink">Ce qui reste sur l&apos;appareil.</strong>{" "}
          Sur iPhone, certaines pièces (images d&apos;occlusion, audio d&apos;une carte)
          peuvent ne jamais quitter le téléphone. Les réponses du parcours d&apos;accueil
          restent d&apos;abord sur l&apos;appareil, puis sont écrites en base une fois le
          compte ouvert.
        </p>
        <p>
          Nous ne vendons pas vos données. Nous n&apos;affichons pas de publicité. Nous
          n&apos;entraînons pas un modèle de langage sur vos cours, sauf si un réglage
          explicite le propose un jour — et ce réglage n&apos;existe pas aujourd&apos;hui.
        </p>
      </LegalSection>

      <LegalSection title="Pourquoi nous les traitons">
        <p>Les bases légales, au sens du RGPD :</p>
        <ul className="list-disc space-y-2 pl-5">
          <li>
            <strong className="font-semibold text-ink">L&apos;exécution du contrat</strong> —
            créer le compte, importer un cours, écrire la fiche et les cartes, les
            réviser, synchroniser iPhone et site, gérer l&apos;abonnement.
          </li>
          <li>
            <strong className="font-semibold text-ink">L&apos;intérêt légitime</strong> —
            sécuriser le service, empêcher les abus, diagnostiquer une panne, et
            lire les retours que vous nous envoyez. Cet
            intérêt ne passe pas avant le vôtre : le cloisonnement est dans la base, pas
            seulement dans l&apos;application.
          </li>
          <li>
            <strong className="font-semibold text-ink">L&apos;obligation légale</strong> —
            conserver ce que la facturation ou la comptabilité exigent, le temps
            prescrit.
          </li>
          <li>
            <strong className="font-semibold text-ink">Le consentement</strong> — quand
            vous choisissez de partager un cours, d&apos;ouvrir l&apos;appareil photo, ou
            de vous connecter avec Apple ou Google.
          </li>
        </ul>
      </LegalSection>

      <LegalSection title="Qui y a accès">
        <p>
          Vos cours ne sont lisibles que par vous, sauf si vous les avez partagés. Chaque
          requête à la base est évaluée avec votre identité : il n&apos;existe pas de
          requête qui puisse demander les cours de quelqu&apos;un d&apos;autre. Les
          retours que vous envoyez sont lus par l&apos;équipe, à l&apos;adresse{" "}
          {LEGAL_CONTACT}. Personne d&apos;autre n&apos;y a accès depuis
          l&apos;application.
        </p>
        <p>Des prestataires voient une partie des données, uniquement pour fournir le service :</p>
        <ul className="list-disc space-y-2 pl-5">
          <li>
            <strong className="font-semibold text-ink">Supabase</strong> (Union
            européenne, région Stockholm) — compte, base, fichiers.
          </li>
          <li>
            <strong className="font-semibold text-ink">Vercel</strong> — hébergement du
            site et journaux techniques (adresse IP, URL). Le traitement peut avoir
            lieu hors de l&apos;Union européenne, sous les clauses contractuelles types
            du prestataire.
          </li>
          <li>
            <strong className="font-semibold text-ink">Apple et Google</strong> — si vous
            vous connectez avec eux, ou si vous payez sur l&apos;App Store.
          </li>
          <li>
            <strong className="font-semibold text-ink">Stripe</strong> — paiement sur le
            site.
          </li>
          <li>
            <strong className="font-semibold text-ink">RevenueCat</strong> — état de
            l&apos;abonnement, partagé entre iPhone et site.
          </li>
          <li>
            <strong className="font-semibold text-ink">fal.ai et les modèles qu&apos;il
            appelle</strong> (aujourd&apos;hui, des modèles de langage, notamment de
            Google) — le texte ou l&apos;image de votre cours, le temps d&apos;écrire la
            fiche ou les cartes. Ils n&apos;ont pas le droit de s&apos;en servir pour
            autre chose que cette génération.
          </li>
          <li>
            <strong className="font-semibold text-ink">YouTube / Google</strong> — si vous
            importez une vidéo, nous en lisons les métadonnées et les sous-titres.
          </li>
        </ul>
        <p>
          Certains de ces prestataires sont établis hors de l&apos;Union européenne. Le
          transfert n&apos;a alors lieu que pour fournir le service, et s&apos;appuie sur
          les garanties prévues par le RGPD (décision d&apos;adéquation ou clauses
          contractuelles types du prestataire).
        </p>
      </LegalSection>

      <LegalSection title="Cookies et traceurs">
        <p>
          Le site pose les cookies nécessaires à la session (vous reconnaître d&apos;une
          page à l&apos;autre une fois connecté). Nous ne posons pas de cookie de mesure
          d&apos;audience, ni de publicité, ni de pistage inter-sites. C&apos;est pour
          cela qu&apos;il n&apos;y a pas de bandeau de consentement : il n&apos;y a rien à
          refuser de ce côté-là.
        </p>
        <p>
          L&apos;iPhone n&apos;utilise pas de cookies. Il garde un jeton de session dans le
          trousseau de l&apos;appareil.
        </p>
      </LegalSection>

      <LegalSection title="Combien de temps nous les gardons">
        <p>
          Tant que le compte existe. Les retours partent au plus tard au bout de
          24 mois. Si vous le supprimez, depuis Réglages sur le site
          ou dans l&apos;app iPhone, ou en nous écrivant, nous effaçons le profil, les
          cours (y compris le texte extrait), les fiches, les cartes, l&apos;historique,
          les examens, les amitiés, les compteurs d&apos;usage, les retours et l&apos;adresse éventuellement
          laissée sur la liste d&apos;attente.
        </p>
        <p>
          Un cours que vous avez partagé disparaît pour vos amis quand vous le
          supprimez. Un ami qui a déjà révisé vos cartes conserve son propre historique,
          pas votre document.
        </p>
        <p>
          Après suppression, il reste chez des prestataires ce que la loi ou leur
          contrat impose : factures Stripe ou Apple, identifiant d&apos;abonnement
          RevenueCat, journaux techniques (Vercel, Supabase) quelques semaines. fal.ai
          reçoit le texte le temps d&apos;écrire la fiche ; nous ne lui demandons pas de
          le conserver.
        </p>
      </LegalSection>

      <LegalSection title="Vos droits">
        <p>
          Vous pouvez accéder à vos données, les corriger, les exporter, vous opposer à
          un traitement, ou demander l&apos;effacement. Pour télécharger une copie :
          Réglages → « Télécharger mes données ». Pour effacer le compte : Réglages →
          « Supprimer le compte », sur le site ou dans l&apos;app iPhone. Vous pouvez
          aussi écrire à{" "}
          <a href={`mailto:${LEGAL_CONTACT}`} className="underline-draw text-ink">
            {LEGAL_CONTACT}
          </a>
          . Nous répondons dans le mois.
        </p>
        <p>
          Vous pouvez aussi introduire une réclamation auprès de la CNIL
          (cnil.fr).
        </p>
      </LegalSection>

      <LegalSection title="Mineurs">
        <p>
          Micabo s&apos;adresse à des étudiants, y compris au lycée. Nous ne demandons
          pas la date de naissance. Si vous avez moins de quinze ans, l&apos;usage du
          service doit se faire avec l&apos;accord d&apos;un titulaire de l&apos;autorité
          parentale. Nous n&apos;utilisons pas les données d&apos;un mineur pour de la
          publicité, ni pour un profilage commercial.
        </p>
      </LegalSection>

      <LegalSection title="L&apos;iPhone, en plus du site">
        <p>
          L&apos;app peut demander l&apos;accès à vos photos ou à l&apos;appareil photo
          pour importer un cours. Ce n&apos;est pas obligatoire : le site accepte un
          fichier déposé. Les notifications, si vous les autorisez, ne servent qu&apos;à
          vous rappeler une révision. Le même compte ouvre l&apos;app et le site.
        </p>
      </LegalSection>

      <LegalSection title="Modifications">
        <p>
          Si cette politique change de façon substantielle, nous mettons à jour la date
          en tête de page. L&apos;usage continu après cette date vaut pour la nouvelle
          version, sauf si la loi exige un accord distinct.
        </p>
        <p>
          Les{" "}
          <Link href={TERMS_PATH} className="underline-draw text-ink">
            conditions d&apos;utilisation
          </Link>{" "}
          complètent ce texte.
        </p>
      </LegalSection>
    </LegalShell>
  );
}
