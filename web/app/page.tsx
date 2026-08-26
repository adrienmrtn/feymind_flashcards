import type { Metadata } from "next";

import { DemoCards } from "@/components/landing/DemoCards";
import { ExamMode } from "@/components/landing/ExamMode";
import { Footer } from "@/components/landing/Footer";
import { Hero } from "@/components/landing/Hero";
import { Pricing } from "@/components/landing/Pricing";
import { Questions } from "@/components/landing/Questions";
import { RetentionChart } from "@/components/landing/RetentionChart";
import { Transformation } from "@/components/landing/Transformation";

/**
 * La page d'accueil.
 *
 * **Une seule règle la gouverne, et c'est celle du parcours d'accueil de l'app : la démonstration
 * est le seul argument.** Une page qui montre une chose est plus crédible qu'une page qui en
 * promet six, et c'est aussi ce qui la distingue — le site de chaque outil d'IA scolaire est une
 * liste de fonctionnalités empilées en sections, et c'est précisément la tête d'un site fait à la
 * chaîne.
 *
 * Ce qui n'y est pas, et c'est délibéré : pas de mur de logos « ils nous font confiance », parce
 * qu'une app d'étudiants n'a pas de clients d'entreprise ; pas de carrousel de témoignages à
 * photos d'avatars ; pas de chiffre d'utilisateurs, parce qu'il n'y en a pas encore et qu'un
 * nombre sur un site indexé est une affirmation commerciale ; pas de bulle de chat ; aucun
 * dégradé, aucun bandeau sombre, aucune étoile scintillante.
 *
 * Et pas de display serif ni d'accent terracotta, nommément : l'ivoire de Micabo est à quelques
 * points du crème que les pages produites à la chaîne ont adopté, et ce sont les deux autres
 * marqueurs de ce cliché qu'il ne faut surtout pas lui associer.
 */

export const metadata: Metadata = {
  title: "Micabo — ton cours devient une fiche",
  description:
    "Dépose un polycopié, une photo de tes notes ou une vidéo de cours. Micabo en écrit la fiche que tu relis, en tire les cartes qui te la font retenir, et les fait revenir juste avant que tu l'oublies.",
};

export default function LandingPage() {
  return (
    <>
      <main>
        <Hero />

        {/* La signature : une page, deux états, la même empreinte. */}
        <Transformation />

        <Section
          eyebrow="De la fiche aux cartes"
          title="Ce que la fiche devient, quand tu veux la retenir."
          note="Quatre formats, parce qu'un cours ne se révise pas d'une seule façon : recto verso pour une définition, QCM pour un choix qui se piège, texte à trou pour une formulation exacte, et le schéma pour ce qui se dessine."
        >
          <DemoCards />
          <p className="mt-6 max-w-reading text-[13.5px] leading-relaxed text-ink-tertiary">
            Les cartes ne sont pas produites au passage : elles se demandent depuis la fiche, quand
            tu l&apos;as lue et que tu sais ce que tu veux retenir.
          </p>
        </Section>

        <Section
          eyebrow="Pourquoi ça tient"
          title="Relire ne suffit pas. Se souvenir, oui."
          note="Ce qu'on relit s'oublie presque aussi vite que ce qu'on n'a pas relu. Ce qu'on a dû retrouver de mémoire tient — et il suffit de le retrouver au bon moment, de moins en moins souvent."
        >
          <RetentionChart />
        </Section>

        <Section
          eyebrow="Mode examen"
          title="Tu donnes la date. Micabo réorganise tout."
          note="La répétition espacée optimise la mémoire à long terme, et se fiche de la date de ton contrôle : une carte revue hier avec un intervalle de vingt jours retomberait trois semaines après l'épreuve. Le mode examen lui donne une date butoir."
        >
          <ExamMode />
        </Section>

        <Section
          eyebrow="Le prix"
          title="Un cours gratuit, pour de vrai."
          note="Assez pour voir Micabo tourner sur ton propre cours avant de décider quoi que ce soit — ce qui est le seul essai qui veuille dire quelque chose."
        >
          <Pricing />
        </Section>

        <Section eyebrow="Questions" title="Ce qu'on nous demande." note="">
          <Questions />
        </Section>
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
    <section className="mx-auto mt-32 max-w-page px-screen">
      <p className="eyebrow text-ink-tertiary">{eyebrow}</p>
      <h2 className="mt-2.5 max-w-[24ch] text-3xl font-bold text-ink sm:text-4xl">{title}</h2>
      {note ? (
        <p className="mt-4 max-w-reading text-[16px] leading-relaxed text-ink-secondary">{note}</p>
      ) : null}
      <div className="mt-9">{children}</div>
    </section>
  );
}
