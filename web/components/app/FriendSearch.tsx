"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";

import { displayUsername } from "@micabo/core";

import { FriendActions } from "@/components/app/FriendActions";
import { searchPeople } from "@/lib/actions/social";
import { useI18n } from "@/lib/i18n/client";
import type { DirectoryPerson } from "@/lib/social";

/**
 * Cherche un @ dans l'annuaire. La requête part après une courte pause,
 * comme sur l'iPhone : une frappe ne doit pas faire dix allers-retours.
 */
export function FriendSearch() {
  const { t } = useI18n();
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<DirectoryPerson[]>([]);
  const [busy, setBusy] = useState(false);

  const run = useCallback((needle: string) => {
    setBusy(true);
    void searchPeople(needle).then((found) => {
      setResults(found);
      setBusy(false);
    });
  }, []);

  useEffect(() => {
    const needle = query.trim();
    if (needle.length < 2) {
      setResults([]);
      setBusy(false);
      return;
    }

    const timer = window.setTimeout(() => run(needle), 320);
    return () => window.clearTimeout(timer);
  }, [query, run]);

  return (
    <section>
      <p className="eyebrow mb-3 text-ink-tertiary">{t("app.friends.addSomeone")}</p>
      <div className="flex h-12 items-center rounded-button bg-surface-muted px-4">
        <span className="pr-1 text-[15px] font-semibold text-ink-tertiary">@</span>
        <input
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          spellCheck={false}
          autoCapitalize="none"
          placeholder={t("app.friends.usernamePlaceholder")}
          className="h-full min-w-0 flex-1 bg-transparent text-[15px] text-ink outline-none placeholder:text-ink-tertiary"
        />
        {busy ? <span className="text-[12px] text-ink-tertiary">…</span> : null}
      </div>

      {results.length > 0 ? (
        <ul className="mt-3 divide-y divide-hairline overflow-hidden rounded-2xl border border-border bg-card">
          {results.map((person) => (
            <li key={person.id} className="hover-row flex items-center gap-3 px-5 py-3.5">
              <Link href={`/app/u/${person.username}` as never} className="min-w-0 flex-1">
                <p className="truncate text-[14.5px] font-semibold text-ink">
                  {displayUsername(person.username)}
                </p>
                {person.institutionName ? (
                  <p className="truncate text-[12.5px] text-ink-tertiary">{person.institutionName}</p>
                ) : null}
              </Link>
              <FriendActions
                personId={person.id}
                relation={person.relation}
                onDone={() => run(query)}
              />
            </li>
          ))}
        </ul>
      ) : null}
    </section>
  );
}
