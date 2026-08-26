"use client";

import { useEffect, useRef, useState } from "react";

/**
 * Une phrase dont le gras se pose **mot par mot**.
 *
 * L'animation dure le temps de lire la phrase, ce qui donne au parcours le rythme d'une
 * conversation plutôt que celui d'un formulaire. Elle est réservée aux moments où l'on n'attend
 * rien de l'étudiant, et jamais aux écrans de démonstration, où le regard doit aller au contenu.
 *
 * **Deux choses ont été corrigées ici, et la seconde est la leçon.**
 *
 * La première version sortait tout de suite quand `prefers-reduced-motion` était demandé, en
 * posant tous les mots d'un coup. C'était mal raisonné : ce réglage protège du **mouvement**, et
 * un mot qui change de couleur et de graisse ne se déplace pas d'un pixel. La règle est de réduire,
 * pas d'annuler — on garde ce qui aide à comprendre, on retire les déplacements. Le dévoilement
 * reste donc, et il se contente d'aller plus vite.
 *
 * La seconde : cette branche-là était **invisible depuis l'extérieur**. Trois vidéos image par
 * image ont dit « aucun état intermédiaire » sans pouvoir dire pourquoi, parce que rien dans le
 * document ne disait où en était l'animation. D'où `data-words-shown` : l'avancement est écrit sur
 * le nœud, donc il se lit en une ligne dans une console au lieu de se déduire d'un enregistrement.
 * Une animation qu'on ne peut pas mesurer est une animation qu'on ne peut pas réparer.
 */
export function WordByWord({
  text,
  className,
  onDone,
}: {
  text: string;
  className?: string;
  onDone?: () => void;
}) {
  const words = text.split(" ");
  const [shown, setShown] = useState(0);
  const done = useRef(onDone);
  done.current = onDone;

  useEffect(() => {
    const parts = text.split(" ");
    // Sous mouvement réduit, la phrase se pose vite — mais elle se pose quand même.
    const quick = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const lead = quick ? 60 : 300;
    const pace = (word: string) =>
      quick ? 60 : 170 + Math.min(220, word.length * 34);

    setShown(0);

    let cancelled = false;
    let index = 0;
    let timer = 0;

    const tick = () => {
      if (cancelled) return;
      index += 1;
      setShown(index);

      if (index >= parts.length) {
        done.current?.();
        return;
      }
      // Un mot court se lit plus vite qu'un mot long : le rythme suit la longueur plutôt qu'un
      // intervalle fixe, sinon « et » et « organiser » prennent le même temps.
      timer = window.setTimeout(tick, pace(parts[index - 1] ?? ""));
    };

    timer = window.setTimeout(tick, lead);

    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [text]);

  return (
    <p
      className={className}
      aria-label={text}
      /* L'avancement, lisible depuis le document : c'est ce qui rend l'animation vérifiable. */
      data-words-shown={shown}
      data-words-total={words.length}
    >
      {words.map((word, index) => (
        <span
          key={index}
          aria-hidden
          className={
            index < shown
              ? "font-bold text-ink transition-colors duration-200 ease-out-strong"
              : "font-normal text-ink-tertiary"
          }
        >
          {word}
          {index < words.length - 1 ? " " : ""}
        </span>
      ))}
    </p>
  );
}
