"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";

import type { CountryCode, EducationTier, StudyLevel } from "@micabo/core";

/**
 * Les réponses du parcours, **gardées sur l'appareil pendant qu'on répond.**
 *
 * C'est le motif de `OnboardingPreferences` côté iOS, et il vaut ici pour deux raisons. La
 * première est la même que là-bas : une réponse écrite au fil de l'eau survit à une fermeture en
 * cours de route, et personne ne recommence un parcours de neuf écrans.
 *
 * La seconde est propre au web. Écrire dans `profiles` à chaque réponse voudrait dire une requête
 * réseau par appui, et surtout **une session à chaque écran** : un jeton qui expire au cinquième
 * écran perdrait les quatre premiers. Les réponses s'accumulent donc ici, et se déversent en base
 * dès qu'une session existe — au retour du fournisseur, puis à la fin. Le parcours reste
 * traversable même si la connexion a échoué, ce qui est aussi ce qui le rend vérifiable.
 */

export interface Answers {
  country?: CountryCode;
  /** Le pays écrit à la main, quand la liste ne le contient pas. */
  customCountry?: string;
  stageId?: string;
  studyLevel?: StudyLevel;
  tier?: EducationTier;
  subjects?: string[];
  /** La date de l'examen, en `AAAA-MM-JJ`. Absente si « je sais pas encore ». */
  examDate?: string;
  examName?: string;
  institutionId?: string;
  institutionName?: string;
  /** Vrai quand on a explicitement passé l'écran de l'école. */
  institutionSkipped?: boolean;
}

const KEY = "micabo.onboarding.answers";

interface Store {
  answers: Answers;
  set: (patch: Answers) => void;
  reset: () => void;
  /** Faux pendant la première image : l'état lu du stockage n'est pas encore là. */
  ready: boolean;
}

const StoreContext = createContext<Store | null>(null);

export function OnboardingStore({ children }: { children: React.ReactNode }) {
  const [answers, setAnswers] = useState<Answers>({});
  const [ready, setReady] = useState(false);

  // La lecture se fait après le montage et jamais pendant le rendu : le serveur n'a pas de
  // `localStorage`, et lire au premier rendu ferait diverger le HTML rendu des deux côtés.
  useEffect(() => {
    try {
      const stored = window.localStorage.getItem(KEY);
      if (stored) setAnswers(JSON.parse(stored) as Answers);
    } catch {
      // Un stockage refusé — navigation privée, réglage de confidentialité — ne doit pas
      // empêcher de répondre. On perd la reprise, pas le parcours.
    }
    setReady(true);
  }, []);

  const set = useCallback((patch: Answers) => {
    setAnswers((current) => {
      const merged = { ...current, ...patch };
      try {
        window.localStorage.setItem(KEY, JSON.stringify(merged));
      } catch {
        // Voir plus haut.
      }
      return merged;
    });
  }, []);

  const reset = useCallback(() => {
    setAnswers({});
    try {
      window.localStorage.removeItem(KEY);
    } catch {
      // Voir plus haut.
    }
  }, []);

  const value = useMemo(() => ({ answers, set, reset, ready }), [answers, set, reset, ready]);

  return <StoreContext.Provider value={value}>{children}</StoreContext.Provider>;
}

export function useOnboarding(): Store {
  const store = useContext(StoreContext);
  if (!store) throw new Error("useOnboarding hors de OnboardingStore");
  return store;
}
