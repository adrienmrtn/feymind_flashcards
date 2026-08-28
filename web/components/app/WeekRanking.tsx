import Link from "next/link";

import { displayUsername } from "@micabo/core";

import { Card, CardHeader, CardPanel, CardTitle } from "@/components/ui/card";

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
 * n'est pas un classement.
 */
export function WeekRanking({ rows }: { rows: readonly RankingRow[] }) {
  if (rows.length < 2) return null;

  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-[15px] font-semibold text-ink">
          Classement de la semaine
        </CardTitle>
      </CardHeader>
      <CardPanel className="pt-0">
        <ol className="divide-y divide-hairline">
          {rows.map((row, index) => {
            const label = row.username ? displayUsername(row.username) : "Quelqu'un";
            return (
              <li key={row.userId}>
                <Link
                  href={row.isMe ? ("/app/profil" as never) : (`/app/u/${row.username ?? ""}` as never)}
                  className="-mx-2 flex items-center gap-3 rounded-lg px-2 py-3"
                >
                  <span className="numeral w-7 shrink-0 text-center text-[13px] text-ink-tertiary">
                    {index + 1}
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
      </CardPanel>
    </Card>
  );
}
