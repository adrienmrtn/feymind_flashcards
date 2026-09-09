"use client";

import { useCallback, useEffect, useState } from "react";

import {
  DEFAULT_READING_SIZE,
  isReadingSize,
  readReadingSize,
  writeReadingSize,
  type ReadingSize,
} from "./reading-size";

const EVENT = "micabo:sheet-size";

/**
 * La taille de lecture, partagée par toutes les fiches ouvertes.
 *
 * Elle part du défaut au premier rendu et **ne lit l'appareil qu'ensuite** : le serveur ne
 * connaît pas `localStorage`, et rendre 1,18 côté client contre 1 côté serveur ferait une
 * erreur d'hydratation à chaque ouverture de fiche.
 *
 * Le petit évènement maison sert à ce que la partie verrouillée d'une fiche grossisse en même
 * temps que la partie lisible : ce sont deux composants, c'est une seule page.
 */
export function useReadingSize(): [ReadingSize, (next: ReadingSize) => void] {
  const [size, setSize] = useState<ReadingSize>(DEFAULT_READING_SIZE);

  useEffect(() => {
    setSize(readReadingSize());

    function onChange(event: Event) {
      const next = (event as CustomEvent<string>).detail;
      if (isReadingSize(next)) setSize(next);
    }

    window.addEventListener(EVENT, onChange);
    return () => window.removeEventListener(EVENT, onChange);
  }, []);

  const choose = useCallback((next: ReadingSize) => {
    setSize(next);
    writeReadingSize(next);
    window.dispatchEvent(new CustomEvent(EVENT, { detail: next }));
  }, []);

  return [size, choose];
}
