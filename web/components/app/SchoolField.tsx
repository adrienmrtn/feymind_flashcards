"use client";

import { useEffect, useRef, useState } from "react";
import { ThinkingOrb } from "thinking-orbs";

import { useI18n } from "@/lib/i18n/client";
import { createClient } from "@/lib/supabase/client";

interface Suggestion {
  id: string;
  name: string;
  country_code: string;
  kind: string;
}

/**
 * Le champ école du profil.
 *
 * On ne sort aucune liste tant que l'étudiant n'a pas tapé. Un nom déjà
 * enregistré n'est pas une recherche : c'est juste ce qui est écrit.
 */
export function SchoolField({
  initialName,
  initialId,
  onChange,
}: {
  initialName: string;
  initialId: string | null;
  onChange: (next: { name: string; id: string | null }) => void;
}) {
  const { t } = useI18n();
  const [query, setQuery] = useState(initialName);
  const [chosenId, setChosenId] = useState<string | null>(initialId);
  const [results, setResults] = useState<Suggestion[]>([]);
  const [searching, setSearching] = useState(false);
  const [typing, setTyping] = useState(false);
  const latest = useRef(0);

  useEffect(() => {
    if (!typing) {
      setResults([]);
      setSearching(false);
      return;
    }

    const needle = query.trim();
    if (needle.length < 2) {
      setResults([]);
      setSearching(false);
      return;
    }

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
  }, [query, typing]);

  return (
    <div>
      <div className="flex items-center gap-2 rounded-button bg-surface-muted px-4">
        <span aria-hidden className="emoji text-[16px]">
          🏫
        </span>
        <label htmlFor="profile-school" className="sr-only">
          {t("app.settings.schoolSr")}
        </label>
        <input
          id="profile-school"
          type="text"
          autoComplete="off"
          value={query}
          onChange={(event) => {
            const next = event.target.value;
            setTyping(true);
            setQuery(next);
            if (chosenId) {
              setChosenId(null);
              onChange({ name: next, id: null });
            }
          }}
          onBlur={() => onChange({ name: query.trim(), id: chosenId })}
          placeholder={t("app.settings.schoolPlaceholder")}
          className="h-12 min-w-0 flex-1 bg-transparent text-[15px] text-ink outline-none placeholder:text-ink-tertiary"
        />
        {searching ? <ThinkingOrb state="searching" size={20} /> : null}
      </div>

      {results.length > 0 ? (
        <div className="mt-2 space-y-1">
          {results.map((item) => {
            const selected = chosenId === item.id;
            return (
              <button
                key={item.id}
                type="button"
                onClick={() => {
                  setChosenId(item.id);
                  setQuery(item.name);
                  setTyping(false);
                  setResults([]);
                  onChange({ name: item.name, id: item.id });
                }}
                className={`pressable flex w-full items-center gap-2 rounded-button px-3 py-2.5 text-left ${
                  selected ? "bg-accent-soft" : "bg-surface-muted"
                }`}
              >
                <span className="min-w-0 flex-1 truncate text-[14px] font-medium text-ink">
                  {item.name}
                </span>
                <span className="text-[11px] uppercase tracking-caps text-ink-tertiary">
                  {item.kind}
                </span>
              </button>
            );
          })}
        </div>
      ) : typing && query.trim().length < 2 ? (
        <p className="mt-2 text-[12.5px] text-ink-tertiary">
          {t("app.settings.schoolTypeMore")}
        </p>
      ) : !typing ? (
        <p className="mt-2 text-[12.5px] text-ink-tertiary">
          {t("app.settings.schoolSearchHint")}
        </p>
      ) : null}
    </div>
  );
}
