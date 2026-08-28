import Link from "next/link";

import { displayUsername } from "@micabo/core";

export interface RankingRow {
  userId: string;
  username: string | null;
  passes: number;
  isMe: boolean;
}

/**
 * Le classement de la semaine, entre amis.
 *
 * On ne le montre que s'il y a vraiment un cercle : un podium tout seul
 * n'est pas un classement. Le trophée marque la première place.
 */
export function WeekRanking({ rows }: { rows: readonly RankingRow[] }) {
  if (rows.length < 2) return null;

  return (
    <section className="paper mt-8 rounded-group bg-surface p-6">
      <p className="eyebrow text-ink-tertiary">🏆 Classement de la semaine</p>
      <ol className="mt-4 divide-y divide-hairline">
        {rows.map((row, index) => {
          const first = index === 0;
          const label = row.username ? displayUsername(row.username) : "Quelqu'un";
          return (
            <li key={row.userId}>
              <Link
                href={row.isMe ? ("/app/profil" as never) : (`/app/u/${row.username ?? ""}` as never)}
                className="hover-row -mx-2 flex items-center gap-3 rounded-button px-2 py-3"
              >
                <span className="emoji w-7 shrink-0 text-center text-[16px]" aria-hidden>
                  {first ? "🏆" : `${index + 1}`}
                </span>
                <span className="min-w-0 flex-1 truncate text-[14.5px] font-medium text-ink">
                  {label}
                  {row.isMe ? (
                    <span className="ml-1.5 text-[12px] font-normal text-ink-tertiary">toi</span>
                  ) : null}
                </span>
                <span className="numeral shrink-0 text-[14px] font-semibold text-ink">
                  {row.passes}
                </span>
              </Link>
            </li>
          );
        })}
      </ol>
      <p className="mt-3 text-[12px] text-ink-tertiary">cartes passées depuis lundi</p>
    </section>
  );
}
