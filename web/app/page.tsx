import type { Metadata, Route } from "next";
import { redirect } from "next/navigation";

import { AuthReturnCatcher } from "@/components/landing/AuthReturnCatcher";
import { DemoCards } from "@/components/landing/DemoCards";
import { ExamMode } from "@/components/landing/ExamMode";
import { Footer } from "@/components/landing/Footer";
import { Hero } from "@/components/landing/Hero";
import { LandingHeader } from "@/components/landing/LandingHeader";
import { Pricing } from "@/components/landing/Pricing";
import { Questions } from "@/components/landing/Questions";
import { RetentionChart } from "@/components/landing/RetentionChart";
import { Reveal } from "@/components/landing/Reveal";
import { SourceMarquee } from "@/components/landing/SourceMarquee";
import { StartButton } from "@/components/landing/StartButton";
import { resumePath } from "@/lib/auth/resume";
import { createClient } from "@/lib/supabase/server";

export const metadata: Metadata = {
  title: "Micabo — apprends tout, plus vite",
  description:
    "Dépose un polycopié, une photo de tes notes ou une vidéo de cours. Micabo en écrit la fiche que tu relis, en tire les cartes qui te la font retenir, et les fait revenir juste avant que tu l'oublies.",
};

/**
 * La vitrine. Elle montre le produit. Elle ne pose aucune question.
 *
 * Elle se lit d'un seul défilement : les sections s'enchaînent en apparaissant, et aucune ne
 * dépend du défilement pour se dessiner — c'était la cause de la fiche coupée en deux.
 *
 * Un lien de confirmation qui retombe ici (Site URL) n'y reste pas : s'il y a un code ou une
 * session, on reprend le parcours.
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

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (user) redirect(await resumePath());

  return (
    <>
      <AuthReturnCatcher />
      <LandingHeader />
      <main>
        <Hero />

        <SourceMarquee />

        <Section
          eyebrow="Comment ça marche"
          title="Trois gestes, et c'est appris."
          note="Rien à paramétrer, rien à découper à la main. Tu déposes, tu relis, tu révises."
        >
          <div className="grid gap-4 sm:grid-cols-3">
            {STEPS.map((step, index) => (
              <Reveal as="div" key={step.n} delay={index} className="paper lift rounded-group bg-surface p-6">
                <p className="numeral text-[20px] font-bold text-accent">{step.n}</p>
                <p className="mt-3 text-[17px] font-semibold text-ink">{step.title}</p>
                <p className="mt-1.5 text-[14.5px] leading-relaxed text-ink-secondary">
                  {step.text}
                </p>
              </Reveal>
            ))}
          </div>
        </Section>

        <Section
          eyebrow="De la fiche aux cartes"
          title="Quatre formats, parce qu'un cours ne se révise pas d'une seule façon."
          note="Recto verso pour une définition, QCM pour un choix qui se piège, texte à trou pour une formulation exacte, schéma pour ce qui se dessine."
        >
          <DemoCards />
        </Section>

        <Section
          eyebrow="Pourquoi ça tient"
          title="Relire ne suffit pas. Se souvenir, oui."
          note="Ce qu'on a dû retrouver de mémoire tient — surtout si ça revient au bon moment, de moins en moins souvent."
        >
          <RetentionChart />
        </Section>

        <Section
          eyebrow="Mode examen"
          title="Tu donnes la date. Micabo réorganise tout."
          note="La répétition espacée ignore le jour J. Le mode examen lui donne une date butoir, et resserre les cartes à l'approche de l'épreuve."
        >
          <ExamMode />
        </Section>

        <Section
          eyebrow="Le prix"
          title="Un cours gratuit, pour de vrai."
          note="Assez pour voir Micabo tourner sur ton propre cours avant de décider quoi que ce soit."
        >
          <Pricing />
        </Section>

        <Section eyebrow="Questions" title="Ce qu'on nous demande." note="">
          <Questions />
        </Section>

        <Reveal as="section" className="mx-auto mt-28 max-w-page px-screen pb-12 text-center">
          <h2 className="mx-auto max-w-[22ch] text-[34px] font-bold leading-[1.06] tracking-display text-ink sm:text-[46px]">
            Ton prochain contrôle commence maintenant.
          </h2>
          <div className="mt-9">
            <StartButton />
          </div>
        </Reveal>
      </main>

      <Footer />
    </>
  );
}

const STEPS = [
  { n: "1", title: "Tu déposes un cours", text: "PDF, photo, Word ou une vidéo YouTube." },
  { n: "2", title: "Micabo écrit la fiche", text: "Le plan, les définitions, ce qui compte." },
  { n: "3", title: "Les cartes reviennent", text: "Juste avant que tu oublies. Jusqu'au jour J." },
] as const;

function Section({
  eyebrow,
  title,
  note,
  children,
}: {
  eyebrow: string;
  title: string;
  note: string;
  children: React.ReactNode;
}) {
  return (
    <section className="mx-auto mt-28 max-w-page px-screen sm:mt-36">
      <Reveal>
        <p className="eyebrow text-ink-tertiary">{eyebrow}</p>
        <h2 className="mt-2.5 max-w-[26ch] text-[30px] font-bold leading-[1.08] tracking-tight-title text-ink sm:text-[40px]">
          {title}
        </h2>
        {note ? (
          <p className="mt-4 max-w-reading text-[16px] leading-relaxed text-ink-secondary">{note}</p>
        ) : null}
      </Reveal>
      <Reveal delay={1} className="mt-9">
        {children}
      </Reveal>
    </section>
  );
}
