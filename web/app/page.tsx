import type { Metadata, Route } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { ClosingWash } from "@/components/landing/ClosingWash";
import { DemoCards } from "@/components/landing/DemoCards";
import { ExamMode } from "@/components/landing/ExamMode";
import { Footer } from "@/components/landing/Footer";
import { Hero } from "@/components/landing/Hero";
import { IosAlso } from "@/components/landing/IosAlso";
import { LandingHeader } from "@/components/landing/LandingHeader";
import { Questions } from "@/components/landing/Questions";
import { RetentionChart } from "@/components/landing/RetentionChart";
import { Reveal } from "@/components/landing/Reveal";
import { SourceMarquee } from "@/components/landing/SourceMarquee";
import { currentUser } from "@/lib/data/user";
import { LANDING_SECTIONS } from "@/lib/landing-sections";
import { ANKI_PAGE, EXAM_PAGE, METHOD_PAGE } from "@/lib/site-pages";

/**
 * `absolute` court-circuite le gabarit `%s - Micabo` de la charpente : sans ça, la marque
 * serait écrite deux fois dans le titre de la page qui la porte.
 */
export const metadata: Metadata = {
  title: { absolute: "Micabo - apprends tout, plus vite" },
  description:
    "Dépose un polycopié, une photo de tes notes ou une vidéo de cours. Micabo en écrit la fiche que tu relis, en tire les cartes qui te la font retenir, et les fait revenir juste avant que tu l'oublies.",
  alternates: { canonical: "/" },
};

/**
 * La vitrine. Elle montre le produit. Elle ne pose aucune question.
 *
 * Elle se lit d'un seul défilement : le document devient une fiche, des cartes, puis un examen.
 *
 * Un lien de confirmation qui retombe ici (Site URL) n'y reste pas : s'il y a un code,
 * on reprend le callback. Une session déjà ouverte laisse la vitrine : le bouton
 * dit Ouvrir l'app, et mène au tableau de bord.
 */
export default async function LandingPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const params = await searchParams;
  const code = typeof params.code === "string" ? params.code : null;
  const tokenHash = typeof params.token_hash === "string" ? params.token_hash : null;
  const type = typeof params.type === "string" ? params.type : null;
  if (code || tokenHash) {
    const next = typeof params.next === "string" ? params.next : "/app";
    const callback = new URL("/auth/callback", "http://local.invalid");
    if (code) callback.searchParams.set("code", code);
    if (tokenHash) callback.searchParams.set("token_hash", tokenHash);
    if (type) callback.searchParams.set("type", type);
    callback.searchParams.set("next", next);
    redirect(`${callback.pathname}${callback.search}` as Route);
  }

  const user = await currentUser();
  const signedIn = Boolean(user);

  return (
    <>
      <LandingHeader signedIn={signedIn} />
      <main id="contenu">
        <Hero signedIn={signedIn} />

        <SourceMarquee />

        <Section
          id={LANDING_SECTIONS.cards}
          eyebrow="Les cartes"
          title="Retourne-en une."
          note="Quatre façons de réviser le même cours. Appuie : le verso est déjà là."
        >
          <DemoCards />
        </Section>

        <Section
          id={LANDING_SECTIONS.method}
          eyebrow="Pourquoi ça tient"
          title="Relire ne suffit pas. Se souvenir, oui."
          note="Ce qu'on a dû retrouver de mémoire tient - surtout si ça revient au bon moment, de moins en moins souvent."
          more={{ href: METHOD_PAGE.path, label: "Lire la méthode en détail" }}
        >
          <RetentionChart />
        </Section>

        <section
          id={LANDING_SECTIONS.iphone}
          className="mx-auto mt-28 max-w-page scroll-mt-20 px-screen sm:mt-36"
        >
          <Reveal>
            <IosAlso />
          </Reveal>
        </section>

        <Section
          id={LANDING_SECTIONS.exam}
          eyebrow="Mode examen"
          title="Tu donnes la date. Micabo réorganise tout."
          note="La répétition espacée ignore le jour J. Le mode examen lui donne une date butoir, et resserre les cartes à l'approche de l'épreuve."
          more={{ href: EXAM_PAGE.path, label: "Comment le plan se resserre" }}
        >
          <ExamMode />
        </Section>

        <Section
          id={LANDING_SECTIONS.questions}
          eyebrow="Questions"
          title="Ce qu'on nous demande."
          note=""
          more={{ href: ANKI_PAGE.path, label: "Micabo ou Anki : la comparaison" }}
        >
          <Questions />
        </Section>

        <ClosingWash signedIn={signedIn} />
      </main>

      <Footer signedIn={signedIn} />
    </>
  );
}

function Section({
  id,
  eyebrow,
  title,
  note,
  more,
  children,
}: {
  id?: string;
  eyebrow: string;
  title: string;
  note: string;
  /**
   * La page qui développe la section.
   *
   * Ces liens ne sont pas décoratifs : une page que rien ne cite depuis l'accueil est une page
   * que Google explore en dernier, et qu'il ne proposera jamais sous le résultat de la marque.
   */
  more?: { href: Route; label: string };
  children: React.ReactNode;
}) {
  return (
    // `scroll-mt` : la barre de la vitrine est collante, et une ancre sans marge
    // dépose le titre derrière elle.
    <section id={id} className="mx-auto mt-28 max-w-page scroll-mt-20 px-screen sm:mt-36">
      <Reveal>
        <p className="eyebrow text-ink-tertiary">{eyebrow}</p>
        <h2 className="mt-2.5 max-w-[26ch] text-[30px] font-bold leading-[1.08] tracking-tight-title text-ink sm:text-[40px]">
          {title}
        </h2>
        {note ? (
          <p className="mt-4 max-w-reading text-[16px] leading-relaxed text-ink-secondary">{note}</p>
        ) : null}
        {more ? (
          <p className="mt-4">
            <Link
              href={more.href}
              className="underline-draw text-[14.5px] font-medium text-ink"
            >
              {more.label}
            </Link>
          </p>
        ) : null}
      </Reveal>
      <Reveal delay={1} className="mt-9">
        {children}
      </Reveal>
    </section>
  );
}
