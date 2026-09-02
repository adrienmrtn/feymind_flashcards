import type { Metadata } from "next";
import Link from "next/link";

import { LegalSection, LegalShell } from "@/components/legal/LegalShell";
import { LEGAL_CONTACT, PRIVACY_PATH, TERMS_PATH } from "@/lib/legal";

export const metadata: Metadata = {
  title: "Support",
  description:
    "Une question, un bug, un abonnement à gérer : comment joindre Micabo, et où se passent les réglages.",
  alternates: { canonical: "/support" },
};

/**
 * La page que l'App Store exige comme « Support URL ».
 *
 * Elle doit s'ouvrir sans compte. Apple la clique à la relecture. Un mailto
 * tout seul, ou une page derrière une connexion, se fait refuser.
 */
export default function SupportPage() {
  return (
    <LegalShell title="Support">
      <p>
        Micabo transforme un cours en fiche et en cartes, puis les fait revenir
        avant que tu les oublies. Cette page dit comment obtenir de l&apos;aide,
        gérer un abonnement, ou partir.
      </p>
      <p>
        Écris-nous :{" "}
        <a href={`mailto:${LEGAL_CONTACT}`} className="underline-draw text-ink">
          {LEGAL_CONTACT}
        </a>
        . On répond dans la semaine, souvent le jour même.
      </p>

      <LegalSection title="Un bug, une idée">
        <p>
          Sur iPhone : Profil → Réglages → « Faire un retour ». Ça ouvre un
          courriel déjà adressé, avec le sujet prérempli.
        </p>
        <p>
          Sur le site, ou si le bouton ne s&apos;ouvre pas : envoie un message à{" "}
          <a href={`mailto:${LEGAL_CONTACT}`} className="underline-draw text-ink">
            {LEGAL_CONTACT}
          </a>
          . Dis ce que tu faisais, et ce que tu attendais. Une capture aide.
        </p>
      </LegalSection>

      <LegalSection title="L'abonnement">
        <p>
          <strong className="font-semibold text-ink">Acheté sur iPhone.</strong>{" "}
          Réglages iOS → ton nom → Abonnements → Micabo. C&apos;est Apple qui
          encaisse : résiliation, renouvellement et remboursement passent par
          ce menu, pas par nous.
        </p>
        <p>
          <strong className="font-semibold text-ink">Acheté sur le site.</strong>{" "}
          Le bouton « Gérer mon abonnement » du profil ouvre le portail de
          facturation. Tu peux aussi nous écrire.
        </p>
        <p>
          Un essai de trois jours, s&apos;il est proposé, ne se transforme en
          paiement que si tu le laisses aller à son terme. Tes cours restent
          après : ce qui se referme, c&apos;est Pro, pas ce que tu as déjà
          écrit.
        </p>
      </LegalSection>

      <LegalSection title="Ton compte et tes données">
        <p>
          Corriger le pays, le palier, l&apos;école : Réglages, sur iPhone ou
          sur le site.
        </p>
        <p>
          Télécharger une copie : Réglages → « Télécharger mes données ».
          Supprimer le compte : Réglages → « Supprimer mon compte ». Ça
          efface le profil, les cours, les fiches, les cartes et
          l&apos;historique. Tu peux aussi demander la même chose par
          courriel.
        </p>
      </LegalSection>

      <LegalSection title="Un cours partagé">
        <p>
          Un cours est privé tant que tu ne le partages pas. Partager le
          montre à tes amis seulement. Pour le refermer : ouvre la fiche →
          visibilité → Privé. Pour retirer un ami : Profil → Amis, puis
          retire-le.
        </p>
        <p>
          Un cours qui n&apos;aurait pas dû être partagé, ou qui te paraît
          abusif : écris-nous à{" "}
          <a href={`mailto:${LEGAL_CONTACT}`} className="underline-draw text-ink">
            {LEGAL_CONTACT}
          </a>{" "}
          avec le nom du cours et, si tu l&apos;as, celui de l&apos;auteur. On
          le retire.
        </p>
      </LegalSection>

      <LegalSection title="À lire">
        <p>
          <Link href={PRIVACY_PATH} className="underline-draw text-ink">
            Politique de confidentialité
          </Link>
          {" · "}
          <Link href={TERMS_PATH} className="underline-draw text-ink">
            Conditions d&apos;utilisation
          </Link>
        </p>
      </LegalSection>
    </LegalShell>
  );
}
