"use client";

import { pricing } from "@micabo/core";
import { useI18n } from "@/lib/i18n/client";

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

export function Questions() {
  const { t } = useI18n();
  const questions = [
    { question: t("landing.faq1q"), answer: t("landing.faq1a") },
    { question: t("landing.faq2q"), answer: t("landing.faq2a") },
    { question: t("landing.faq3q"), answer: t("landing.faq3a") },
    {
      question: t("landing.faq4q"),
      answer: t("landing.faq4a", { days: pricing.FREE_TRIAL_DAYS }),
    },
    { question: t("landing.faq5q"), answer: t("landing.faq5a") },
  ];
  return (
    <Card className="lift mt-9 overflow-hidden">
      <CardPanel className="p-0 sm:p-0">
        <Accordion className="px-6">
          {questions.map((item) => (
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
