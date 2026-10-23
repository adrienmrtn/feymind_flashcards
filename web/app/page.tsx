import type { Metadata, Route } from "next";
import { headers } from "next/headers";
import Link from "next/link";
import { redirect } from "next/navigation";

import { AppsSection } from "@/components/landing/AppsSection";
import { Atmosphere } from "@/components/landing/Atmosphere";
import { Closing } from "@/components/landing/Closing";
import { Footer } from "@/components/landing/Footer";
import { FormatStrip } from "@/components/landing/FormatStrip";
import { Hero } from "@/components/landing/Hero";
import { IphoneLanding } from "@/components/landing/IphoneLanding";
import { LessonFeatures } from "@/components/landing/LessonFeatures";
import { Pricing } from "@/components/landing/Pricing";
import { Questions } from "@/components/landing/Questions";
import { SectionHeading } from "@/components/landing/SectionHeading";
import { Steps } from "@/components/landing/Steps";
import { SiteHeader } from "@/components/site/SiteHeader";
import { currentUser } from "@/lib/data/user";
import { LANDING_NAV, LANDING_SECTIONS } from "@/lib/landing-sections";
import { indexableAlternates } from "@/lib/i18n/alternates";
import { UI_LOCALE_META } from "@/lib/i18n/locales";
import { localizedHref, localizedPath } from "@/lib/i18n/paths";
import { getTranslator } from "@/lib/i18n/server";
import { wantsIphoneLanding } from "@/lib/iphone";
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
 * Elle se lit dans l'ordre du produit : ce qu'on dépose et la leçon qui en sort (la carte du
 * héros, qui le joue en boucle), ce que Mika sait lire, les trois étapes, ce qu'il y a dans
 * une leçon, le même compte sur iPhone, Android et le web, le prix, les questions, et un
 * dernier appel. Un lavage d'ambiance dérive derrière le haut de page ; tout le reste est du
 * papier, des cartes blanches, et des entrées au défilement sur une seule courbe.
 *
 * Un lien de confirmation qui retombe ici (Site URL) n'y reste pas : s'il y a un code,
 * on reprend le callback. Une session déjà ouverte laisse la vitrine : le bouton
 * dit Ouvrir l'app, et mène au tableau de bord.
 *
 * **Sur iPhone, ce n'est pas cette page qui s'affiche.** L'appareil qui arrive est déjà celui
 * sur lequel Micabo est une app native : la vitrine y cède la place à la page de
 * téléchargement (`IphoneLanding`), et `?web` la redonne à qui la demande. Rien n'est
 * redirigé — l'adresse reste `/`, et les robots continuent d'y trouver la vitrine.
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

  const [{ t, locale }, user, head] = await Promise.all([
    getTranslator(),
    currentUser(),
    headers(),
  ]);
  const signedIn = Boolean(user);

  if (wantsIphoneLanding(head.get("user-agent"), params)) {
    return <IphoneLanding signedIn={signedIn} />;
  }

  const nav = LANDING_NAV.map((item) => ({ href: item.href, label: t(item.key) }));

  return (
    <div className="lp relative">
      <Atmosphere />
      <SiteHeader nav={nav} signedIn={signedIn} overlay />
      <main id="contenu">
        <Hero signedIn={signedIn} />
        <FormatStrip />

        <section id={LANDING_SECTIONS.how} className="mx-auto mt-28 max-w-page scroll-mt-20 px-screen sm:mt-36">
          <SectionHeading eyebrow="landing.howEyebrow" title="landing.howTitle" note="landing.howNote" />
          <Steps />
        </section>

        <section id={LANDING_SECTIONS.lesson} className="mx-auto mt-28 max-w-page scroll-mt-20 px-screen sm:mt-36">
          <SectionHeading
            eyebrow="landing.lessonEyebrow"
            title="landing.lessonTitle"
            note="landing.lessonNote"
            more={{ href: localizedHref(locale, METHOD_PAGE.path), label: "landing.methodMore" }}
          />
          <LessonFeatures />
          <SectionLinks
            links={[{ href: localizedHref(locale, EXAM_PAGE.path), label: t("landing.examMore") }]}
          />
        </section>

        <AppsSection id={LANDING_SECTIONS.apps} />

        <section id={LANDING_SECTIONS.pricing} className="mx-auto mt-28 max-w-page scroll-mt-20 px-screen sm:mt-36">
          <SectionHeading eyebrow="landing.pricingEyebrow" title="landing.pricingTitle" note="landing.pricingNote" />
          <Pricing signedIn={signedIn} />
        </section>

        <section
          id={LANDING_SECTIONS.questions}
          className="mx-auto mt-28 grid max-w-page scroll-mt-20 gap-10 px-screen sm:mt-36 lg:grid-cols-[0.85fr_1.15fr] lg:gap-14"
        >
          <SectionHeading
            align="left"
            eyebrow="landing.questionsEyebrow"
            title="landing.questionsTitle"
            note="landing.questionsNote"
            more={{ href: localizedHref(locale, ANKI_PAGE.path), label: "landing.questionsMore" }}
          />
          <Questions />
        </section>

        <Closing signedIn={signedIn} />
      </main>

      <Footer signedIn={signedIn} />
    </div>
  );
}

/** Les pages de fond que la section cite en plus de son lien principal. */
function SectionLinks({ links }: { links: { href: Route; label: string }[] }) {
  return (
    <p className="mt-8 text-center">
      {links.map((link) => (
        <Link key={link.href} href={link.href} className="underline-draw text-[14.5px] font-bold text-ink">
          {link.label}
        </Link>
      ))}
    </p>
  );
}
