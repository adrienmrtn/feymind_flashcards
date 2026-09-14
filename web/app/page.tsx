import type { Metadata, Route } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { ClosingWash } from "@/components/landing/ClosingWash";
import { DemoCards } from "@/components/landing/DemoCards";
import { ExamMode } from "@/components/landing/ExamMode";
import { Footer } from "@/components/landing/Footer";
import { Hero } from "@/components/landing/Hero";
import { Proof } from "@/components/landing/Proof";
import { Questions } from "@/components/landing/Questions";
import { RetentionChart } from "@/components/landing/RetentionChart";
import { Reveal } from "@/components/landing/Reveal";
import { Steps } from "@/components/landing/Steps";
import { SiteHeader } from "@/components/site/SiteHeader";
import { currentUser } from "@/lib/data/user";
import { T } from "@/components/i18n/T";
import { LANDING_SECTIONS } from "@/lib/landing-sections";
import { indexableAlternates } from "@/lib/i18n/alternates";
import { UI_LOCALE_META } from "@/lib/i18n/locales";
import { localizedHref, localizedPath } from "@/lib/i18n/paths";
import { getTranslator } from "@/lib/i18n/server";
import { ANKI_PAGE, EXAM_PAGE, METHOD_PAGE } from "@/lib/site-pages";

/**
 * `absolute` court-circuite le gabarit `%s - Micabo` de la charpente : sans ça, la marque
 * serait écrite deux fois dans le titre de la page qui la porte.
 */
export async function generateMetadata(): Promise<Metadata> {
  const { t, locale } = await getTranslator();
  return {
    title: { absolute: t("landing.metaTitle") },
    description: t("landing.metaDescription"),
    alternates: indexableAlternates(locale, "/"),
    openGraph: {
      url: localizedPath(locale, "/"),
      locale: UI_LOCALE_META[locale].og,
    },
  };
}

/**
 * La vitrine. Elle montre le produit. Elle ne pose aucune question.
 *
 * Elle se lit dans l'ordre du produit : l'app telle qu'elle s'ouvre, puis les six étapes qui
 * y mènent, les cartes qu'on retourne, la raison pour laquelle ça tient, le mode examen, ce
 * que ça donne, et les questions qu'on se pose avant de commencer.
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

  const [{ t, locale }, user] = await Promise.all([getTranslator(), currentUser()]);
  const signedIn = Boolean(user);
  const nav = [
    { href: `#${LANDING_SECTIONS.how}`, label: t("site.how") },
    { href: `#${LANDING_SECTIONS.method}`, label: t("site.method") },
    { href: `#${LANDING_SECTIONS.exam}`, label: t("site.exam") },
    { href: `#${LANDING_SECTIONS.questions}`, label: t("site.questions") },
  ];

  return (
    <>
      <SiteHeader nav={nav} signedIn={signedIn} />
      <main id="contenu">
        <Hero signedIn={signedIn} />

        <Section
          id={LANDING_SECTIONS.how}
          eyebrow="landing.howEyebrow"
          title="landing.howTitle"
          note="landing.howNote"
        >
          <Steps />
        </Section>

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
          more={{ href: localizedHref(locale, METHOD_PAGE.path), label: "landing.methodMore" }}
        >
          <RetentionChart />
        </Section>

        <Section
          id={LANDING_SECTIONS.exam}
          eyebrow="landing.examEyebrow"
          title="landing.examTitle"
          note="landing.examNote"
          more={{ href: localizedHref(locale, EXAM_PAGE.path), label: "landing.examMore" }}
        >
          <ExamMode />
        </Section>

        <section id={LANDING_SECTIONS.results} className="mx-auto mt-28 max-w-page scroll-mt-20 px-screen sm:mt-36">
          <Proof />
        </section>

        <Section
          id={LANDING_SECTIONS.questions}
          eyebrow="landing.questionsEyebrow"
          title="landing.questionsTitle"
          note="landing.questionsNote"
          more={{ href: localizedHref(locale, ANKI_PAGE.path), label: "landing.questionsMore" }}
        >
          <Questions />
        </Section>

        <ClosingWash signedIn={signedIn} />
      </main>

      <Footer signedIn={signedIn} />
    </>
  );
}

/**
 * Une section de la vitrine : un sur-titre, un titre centré, une phrase, et ce qu'elle montre.
 *
 * Le titre est centré comme ceux du parcours d'inscription : sur 1100 px, un titre calé à
 * gauche fait chercher la suite à droite, et il n'y a rien.
 */
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
      <Reveal className="mx-auto max-w-[60ch] text-center">
        <p className="eyebrow text-ink-tertiary">
          <T k={eyebrow} />
        </p>
        <h2 className="mt-2.5 text-balance text-[30px] font-bold leading-[1.08] tracking-tight-title text-ink sm:text-[40px]">
          <T k={title} />
        </h2>
        {note ? (
          <p className="mx-auto mt-4 max-w-reading text-[16px] leading-relaxed text-ink-secondary">
            <T k={note} />
          </p>
        ) : null}
        {more ? (
          <p className="mt-4">
            <Link href={more.href} className="underline-draw text-[14.5px] font-medium text-ink">
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
