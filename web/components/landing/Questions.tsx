import type { ReactNode } from "react";

import { pricing } from "@micabo/core";

import {
  Accordion,
  AccordionItem,
  AccordionPanel,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { Card, CardPanel } from "@/components/ui/card";

/**
 * Les questions, et de vraies questions.
 *
 * Cinq, pas quinze. Une foire aux questions qui répond à des questions que personne ne pose est un
 * bloc de texte pour le référencement, et ça se lit. Celles-ci sont celles qu'on se pose
 * réellement devant un outil qui lit ses cours : est-ce que c'est privé, est-ce que ça marche
 * dans ma langue, est-ce que ça invente.
 */

const QUESTIONS: { question: string; answer: ReactNode }[] = [
  {
    question: "Est-ce que mes cours sont privés ?",
    answer: (
      <>
        Oui. Tes cours ne sont pas exposés dans un catalogue. Il n&apos;y a plus de « Découvrir »
        où un inconnu tomberait sur tes fiches : c&apos;est entre toi et tes amis. Par défaut tu
        les vois seul. Tu peux en partager un au moment de l&apos;import - avec tes amis, ou avec
        personne - et le réglage se décide{" "}
        <strong className="font-semibold text-ink">à cet instant</strong>, pas après coup. Le
        cloisonnement est dans la base : chaque requête est évaluée avec ton identité, donc il
        n&apos;existe pas de requête qui puisse demander les cours de quelqu&apos;un d&apos;autre.
      </>
    ),
  },
  {
    question: "Est-ce que Micabo invente des choses ?",
    answer: (
      <>
        C&apos;est le risque qu&apos;on prend le plus au sérieux, parce qu&apos;une fiche fausse ne
        ressemble pas à une erreur. Un mot mal lu par la reconnaissance de texte peut donner une
        définition parfaitement crédible et complètement fausse. Micabo ne définit donc jamais un
        terme dont il n&apos;est pas sûr : quand le contexte ne tranche pas, le mot douteux
        n&apos;apparaît simplement pas dans la fiche.
      </>
    ),
  },
  {
    question: "Ça marche en anglais ? Dans d'autres systèmes scolaires ?",
    answer: (
      <>
        Oui. Le pays de scolarisation décide à la fois du système de référence - un cégep
        québécois, un A-Level britannique et une prépa française ne demandent pas la même
        rédaction - et de la langue dans laquelle la fiche est écrite. Le site, lui, est en
        français pour l&apos;instant. iPhone et navigateur partagent ce réglage.
      </>
    ),
  },
  {
    question: "Que se passe-t-il à la fin de l'essai ?",
    answer: (
      <>
        Les {pricing.FREE_TRIAL_DAYS} jours d&apos;essai s&apos;arrêtent, et rien ne se prélève
        sans que tu l&apos;aies décidé. Tes cours et tes cartes restent, sur le site comme sur
        iPhone : ce qui se referme, c&apos;est ce que Pro ouvrait, pas ce que tu as déjà écrit.
      </>
    ),
  },
  {
    question: "Et si j'utilise déjà Anki ?",
    answer: (
      <>
        La répétition espacée de Micabo <em>est</em> celle d&apos;Anki - SM-2, avec ses réglages
        par défaut, ses quatre boutons et ses paliers d&apos;apprentissage. Ce que Micabo ajoute
        est ce qu&apos;Anki ne fait pas : écrire la fiche et les cartes à partir de ton cours, et
        replanifier tout un paquet quand tu déclares la date d&apos;un examen. iPhone et
        navigateur tournent sur le même SM-2 : une carte révisée d&apos;un côté ne revient pas de
        l&apos;autre le lendemain.
      </>
    ),
  },
];

export function Questions() {
  return (
    <Card className="lift mt-9 overflow-hidden">
      <CardPanel className="p-0 sm:p-0">
        <Accordion className="px-6">
          {QUESTIONS.map((item) => (
            <AccordionItem key={item.question} value={item.question}>
              <AccordionTrigger className="text-[15px] font-medium text-ink">
                {item.question}
              </AccordionTrigger>
              <AccordionPanel className="max-w-reading text-[14.5px] leading-relaxed text-ink-secondary">
                {item.answer}
              </AccordionPanel>
            </AccordionItem>
          ))}
        </Accordion>
      </CardPanel>
    </Card>
  );
}
