"use client";

import { useI18n } from "@/lib/i18n/client";

import {
  Accordion,
  AccordionItem,
  AccordionPanel,
  AccordionTrigger,
} from "@/components/ui/accordion";

/**
 * Les questions, et de vraies questions.
 *
 * Six, pas quinze. Une foire aux questions qui répond à des questions que personne ne pose est
 * un bloc de texte pour le référencement, et ça se lit. Celles-ci sont celles qu'on se pose
 * devant un outil qui lit ses cours : est-ce que c'est privé, est-ce que ça invente, est-ce
 * que ça marche dans ma langue, combien de temps par jour, et sur mon téléphone.
 */
export function Questions() {
  const { t } = useI18n();
  const questions = [
    { question: t("landing.faq1q"), answer: t("landing.faq1a") },
    { question: t("landing.faq2q"), answer: t("landing.faq2a") },
    { question: t("landing.faq3q"), answer: t("landing.faq3a") },
    { question: t("landing.faq4q"), answer: t("landing.faq4a") },
    { question: t("landing.faq5q"), answer: t("landing.faq5a") },
    { question: t("landing.faq6q"), answer: t("landing.faq6a") },
  ];
  return (
    <div className="paper overflow-hidden rounded-sheet bg-surface">
      <Accordion className="px-6 sm:px-8">
        {questions.map((item) => (
          <AccordionItem key={item.question} value={item.question}>
            <AccordionTrigger className="text-[15.5px] font-medium text-ink">{item.question}</AccordionTrigger>
            <AccordionPanel className="max-w-reading text-[14.5px] leading-relaxed text-ink-secondary">
              {item.answer}
            </AccordionPanel>
          </AccordionItem>
        ))}
      </Accordion>
    </div>
  );
}
