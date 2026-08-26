import type { Metadata } from "next";

import { DemoCards } from "@/components/landing/DemoCards";
import { ExamMode } from "@/components/landing/ExamMode";
import { Footer } from "@/components/landing/Footer";
import { Hero } from "@/components/landing/Hero";
import { LandingHeader } from "@/components/landing/LandingHeader";
import { Pricing } from "@/components/landing/Pricing";
import { Questions } from "@/components/landing/Questions";
import { RetentionChart } from "@/components/landing/RetentionChart";
import { StartButton } from "@/components/landing/StartButton";
import { Transformation } from "@/components/landing/Transformation";

export const metadata: Metadata = {
  title: "Micabo — ton cours devient une fiche",
  description:
    "Dépose un polycopié, une photo de tes notes ou une vidéo de cours. Micabo en écrit la fiche que tu relis, en tire les cartes qui te la font retenir, et les fait revenir juste avant que tu l'oublies.",
};

/**
 * La vitrine. Elle montre le produit. Elle ne pose aucune question.
 * « Commencer » ouvre le parcours, un écran à la fois.
 */
export default function LandingPage() {
  return (
    <>
      <LandingHeader />
      <main>
        <Hero />

        <section className="mx-auto mt-28 max-w-page px-screen">
          <p className="eyebrow text-ink-tertiary">Comment ça marche</p>
          <h2 className="mt-2.5 max-w-[20ch] text-3xl font-bold text-ink sm:text-4xl">
            Trois gestes. C&apos;est tout.
          </h2>
          <ol className="mt-9 grid gap-4 sm:grid-cols-3">
            {[
              {
                n: "1",
                title: "Tu déposes un cours",
                text: "PDF, photo, Word ou une vidéo YouTube.",
              },
              {
                n: "2",
                title: "Micabo écrit la fiche",
                text: "Le plan, les définitions, ce qui compte.",
              },
              {
                n: "3",
                title: "Les cartes reviennent",
                text: "Juste avant que tu oublies. Jusqu'au jour J.",
              },
            ].map((step) => (
              <li key={step.n} className="paper rounded-group bg-surface p-6">
                <p className="numeral text-[22px] font-bold text-accent">{step.n}</p>
                <p className="mt-3 text-[17px] font-semibold text-ink">{step.title}</p>
                <p className="mt-1.5 text-[14.5px] leading-relaxed text-ink-secondary">
                  {step.text}
                </p>
              </li>
            ))}
          </ol>
        </section>

        <Transformation />

        <Section
          eyebrow="De la fiche aux cartes"
          title="Ce que la fiche devient, quand tu veux la retenir."
          note="Recto verso, QCM, texte à trou, schéma. Quatre formats, parce qu'un cours ne se révise pas d'une seule façon."
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

        <section className="mx-auto mt-28 max-w-page px-screen pb-10 text-center">
          <h2 className="text-3xl font-bold tracking-tight-title text-ink sm:text-4xl">
            Ton cours. Une fiche. Des cartes.
          </h2>
          <p className="mx-auto mt-4 max-w-reading text-[16px] leading-relaxed text-ink-secondary">
            Clique sur Commencer. Le parcours s&apos;ouvre, un écran à la fois.
          </p>
          <div className="mt-8">
            <StartButton />
          </div>
        </section>
      </main>

      <Footer />
    </>
  );
}

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
    <section className="mx-auto mt-28 max-w-page px-screen">
      <p className="eyebrow text-ink-tertiary">{eyebrow}</p>
      <h2 className="mt-2.5 max-w-[24ch] text-3xl font-bold text-ink sm:text-4xl">{title}</h2>
      {note ? (
        <p className="mt-4 max-w-reading text-[16px] leading-relaxed text-ink-secondary">{note}</p>
      ) : null}
      <div className="mt-9">{children}</div>
    </section>
  );
}
