import type { Metadata, Route } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { ClosingWash } from "@/components/landing/ClosingWash";
import { DemoCards } from "@/components/landing/DemoCards";
import { ExamMode } from "@/components/landing/ExamMode";
import { Footer } from "@/components/landing/Footer";
import { Hero } from "@/components/landing/Hero";
import { LandingHeader } from "@/components/landing/LandingHeader";
import { Questions } from "@/components/landing/Questions";
import { RetentionChart } from "@/components/landing/RetentionChart";
import { Reveal } from "@/components/landing/Reveal";
import { SourceMarquee } from "@/components/landing/SourceMarquee";
import { currentUser } from "@/lib/data/user";
import { T } from "@/components/i18n/T";
import { listedLandingSourceImages } from "@/lib/landing-source-images";
import { LANDING_SECTIONS } from "@/lib/landing-sections";
import { getTranslator } from "@/lib/i18n/server";
import { ANKI_PAGE, EXAM_PAGE, METHOD_PAGE } from "@/lib/site-pages";

/**
 * `absolute` court-circuite le gabarit `%s - Micabo` de la charpente : sans ça, la marque
 * serait écrite deux fois dans le titre de la page qui la porte.
 */
export async function generateMetadata(): Promise<Metadata> {
  const { t } = await getTranslator();
  return {
    title: { absolute: t("landing.metaTitle") },
    description: t("landing.metaDescription"),
    alternates: { canonical: "/" },
  };
}

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

        <SourceMarquee availableIds={listedLandingSourceImages()} />

        <Section
          id={LANDING_SECTIONS.cards}
          eyebrow="landing.cardsEyebrow"
          title="landing.cardsTitle"
          note="landing.cardsNote"
        >
          <DemoCards />
        </Section>

        <Section
          id={LANDING_SECTIONS.method}
          eyebrow="landing.methodEyebrow"
          title="landing.methodTitle"
          note="landing.methodNote"
          more={{ href: METHOD_PAGE.path, label: "landing.methodMore" }}
        >
          <RetentionChart />
        </Section>

        <Section
          id={LANDING_SECTIONS.exam}
          eyebrow="landing.examEyebrow"
          title="landing.examTitle"
          note="landing.examNote"
          more={{ href: EXAM_PAGE.path, label: "landing.examMore" }}
        >
          <ExamMode />
        </Section>

        <Section
          id={LANDING_SECTIONS.questions}
          eyebrow="landing.questionsEyebrow"
          title="landing.questionsTitle"
          note=""
          more={{ href: ANKI_PAGE.path, label: "landing.questionsMore" }}
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
        <p className="eyebrow text-ink-tertiary">
          <T k={eyebrow} />
        </p>
        <h2 className="mt-2.5 max-w-[26ch] text-[30px] font-bold leading-[1.08] tracking-tight-title text-ink sm:text-[40px]">
          <T k={title} />
        </h2>
        {note ? (
          <p className="mt-4 max-w-reading text-[16px] leading-relaxed text-ink-secondary">
            <T k={note} />
          </p>
        ) : null}
        {more ? (
          <p className="mt-4">
            <Link
              href={more.href}
              className="underline-draw text-[14.5px] font-medium text-ink"
            >
              <T k={more.label} />
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
