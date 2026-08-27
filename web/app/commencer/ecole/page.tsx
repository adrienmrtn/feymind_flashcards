"use client";

import { useEffect, useRef, useState } from "react";
import { ThinkingOrb } from "thinking-orbs";

import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { useOnboarding } from "@/lib/onboarding/store";
import { createClient } from "@/lib/supabase/client";

/**
 * L'établissement.
 *
 * Il ouvre la bibliothèque : « public » veut dire lisible par les camarades du **même
 * établissement**, et sans lui il n'y a pas de camarades. C'est ce qui justifie la question.
 *
 * Elle a son échappatoire, posée en haut à droite, et ce n'est pas une politesse : le demander à
 * quelqu'un qui n'en a pas, qui est entre deux écoles ou qui n'a pas envie de le dire ne doit pas
 * fermer le parcours. **Passer laisse le champ vide et l'écrit** - sans ça, l'écran se reposerait
 * plus tard comme s'il n'avait jamais été vu.
 *
 * Le texte libre reste accepté, mais il ne donne pas d'identifiant : **seul un résultat choisi dans
 * la liste en pose un**, et c'est cet identifiant, pas le nom, qui décide de qui voit quoi. Deux
 * étudiants qui tapent « Lycée Voltaire » et « lycee voltaire » ne sont pas camarades.
 */

interface Suggestion {
  id: string;
  name: string;
  country_code: string;
  kind: string;
}

export default function SchoolStep() {
  const { answers, set, ready } = useOnboarding();
  const [query, setQuery] = useState(answers.institutionName ?? "");
  const [results, setResults] = useState<Suggestion[]>([]);
  const [searching, setSearching] = useState(false);
  const chosenId = answers.institutionId ?? null;
  const latest = useRef(0);

  useEffect(() => {
    const needle = query.trim();
    if (needle.length < 2) {
      setResults([]);
      return;
    }

    // Un appel par frappe ferait une requête par lettre, et les réponses arriveraient dans le
    // désordre. Le compteur garde la dernière, quoi qu'il arrive.
    const token = ++latest.current;
    setSearching(true);

    const timer = window.setTimeout(async () => {
      const supabase = createClient();
      const { data } = await supabase.rpc("search_institutions", {
        query: needle,
        result_limit: 8,
      });

      if (token !== latest.current) return;
      setResults((data as Suggestion[] | null) ?? []);
      setSearching(false);
    }, 220);

    return () => window.clearTimeout(timer);
  }, [query]);

  return (
    <Scaffold
      eyebrow="Ton parcours"
      title="Tu étudies dans quelle école ?"
      skip={{ label: "Passer", href: "/commencer/parcours" }}
      footer={
        <ContinueButton
          enabled={query.trim().length > 0 && ready}
          href="/commencer/parcours"
          onPress={() => {
            // Le nom libre est gardé, mais sans identifiant : c'est l'identifiant qui décide de
            // qui voit quoi, et on ne l'invente pas.
            if (!chosenId) set({ institutionName: query.trim(), institutionId: undefined });
          }}
        />
      }
    >
      <div>
        <div className="paper flex items-center gap-2 rounded-button bg-surface px-4">
          <svg aria-hidden viewBox="0 0 20 20" className="h-4 w-4 shrink-0 text-ink-tertiary">
            <circle cx="9" cy="9" r="5.5" fill="none" stroke="currentColor" strokeWidth="1.8" />
            <path d="M13 13l4 4" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
          </svg>
          <label htmlFor="school" className="sr-only">
            Le nom de ton école
          </label>
          <input
            id="school"
            type="text"
            autoComplete="off"
            value={query}
            onChange={(event) => {
              setQuery(event.target.value);
              // Modifier le texte après avoir choisi dans la liste retire l'identifiant : il ne
              // correspondrait plus à ce qui est écrit.
              if (chosenId) set({ institutionId: undefined });
            }}
            placeholder="Lycée, université, école…"
            className="h-14 min-w-0 flex-1 bg-transparent text-[16px] text-ink outline-none placeholder:text-ink-tertiary"
          />
          {searching ? <ThinkingOrb state="searching" size={20} /> : null}
        </div>

        <div className="mt-2 space-y-1.5">
          {results.map((item) => {
            const selected = chosenId === item.id;
            return (
              <button
                key={item.id}
                type="button"
                onClick={() => {
                  set({ institutionId: item.id, institutionName: item.name });
                  setQuery(item.name);
                  setResults([]);
                }}
                className={`pressable flex w-full items-center gap-3 rounded-button px-4 py-3 text-left transition-colors duration-hover ${
                  selected ? "bg-accent-soft" : "bg-surface paper"
                }`}
              >
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-[15px] font-medium text-ink">
                    {item.name}
                  </span>
                  <span className="block text-[12px] uppercase tracking-caps text-ink-tertiary">
                    {item.kind}
                  </span>
                </span>
              </button>
            );
          })}
        </div>

        {chosenId ? (
          <p className="mt-4 text-[13px] text-accent">
            Tu verras ce que tes camarades de {answers.institutionName} partagent.
          </p>
        ) : query.trim().length > 0 ? (
          <p className="mt-4 text-[13px] text-ink-tertiary">
            On garde ce nom. Choisis-le dans la liste si tu veux voir tes camarades.
          </p>
        ) : null}
      </div>
    </Scaffold>
  );
}
