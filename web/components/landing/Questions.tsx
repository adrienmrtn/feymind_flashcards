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
 * Sept, pas quinze. Une foire aux questions qui répond à des questions que personne ne pose est
 * un bloc de texte pour le référencement, et ça se lit. Celles-ci sont celles qu'on se pose
 * devant un outil qui lit ses cours : est-ce que c'est privé, est-ce que ça invente, est-ce
 * que ça marche dans ma langue, combien de temps, ce que devient Anki — et, maintenant que
 * les apps sont publiques et le prix écrit, le téléphone et la fin de l'essai.
 */
export function Questions() {
  const { t } = useI18n();
  const questions = [1, 2, 3, 4, 5, 6, 7].map((n) => ({
    question: t(`landing.faq${n}q`),
    answer: t(`landing.faq${n}a`),
  }));
  return (
    <div className="overflow-hidden rounded-[28px] bg-surface lp-surface-shadow">
      <Accordion className="px-5 sm:px-8">
        {questions.map((item) => (
          <AccordionItem key={item.question} value={item.question}>
            <AccordionTrigger className="py-5 text-[16px] font-bold text-ink">{item.question}</AccordionTrigger>
            <AccordionPanel className="max-w-reading text-[15px] leading-relaxed text-ink-secondary">
              {item.answer}
            </AccordionPanel>
          </AccordionItem>
        ))}
      </Accordion>
    </div>
  );
}
