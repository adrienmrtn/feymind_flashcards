"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Check, ChevronLeft, Clock, Share2, UserPlus, Zap } from "lucide-react";

import { displayUsername, leagueFor, xpToNextLeague } from "@micabo/core";

import { MicaboIcon } from "@/components/lesson/MicaboIcon";
import { MikaBubble } from "@/components/xp/MikaBubble";
import { useI18n } from "@/lib/i18n/client";
import { FRIENDS_PATH, HOME_PATH } from "@/lib/lesson/routes";
import { createClient } from "@/lib/supabase/client";
import { useXp } from "@/lib/xp/client";
import { LEAGUE_EMOJI, LEAGUE_TONE, leagueNameKey } from "@/lib/xp/league";
import { daysUntilWeekEnd } from "@/lib/xp/state";
import { syncXp } from "@/lib/xp/sync";

/** Ce que `friends_league()` rend : l'élève et ses amis acceptés, triés par XP de la semaine. */
interface LeagueRow {
  user_id: string;
  username: string | null;
  display_name: string | null;
  xp_week: number;
  is_me: boolean;
}

/** Le lien que « Inviter des amis » partage. */
export const INVITE_URL = "https://micabo.app";

/**
 * **La ligue de la semaine** (`docs/refonte-knowunity.md` § 3) : la ligue de l'élève d'après son
 * XP de la semaine (`leagueFor`), ce qui manque pour la suivante, le temps qui reste jusqu'à
 * lundi minuit, et le classement entre amis (`rpc('friends_league')`).
 *
 * Sans ami, ou quand l'appel échoue (la fonction n'est peut-être pas encore déployée), la seule
 * ligne de l'élève avec son XP locale, et de quoi ajouter ou inviter des amis. L'XP de l'élève est
 * la plus grande des deux, celle du serveur ou celle de ce navigateur : le téléphone et le site
 * écrivent la même ligne.
 */
export function LeagueScreen({ userId, myName }: { userId: string; myName: string }) {
  const { t } = useI18n();
  const xp = useXp();
  const [rows, setRows] = useState<LeagueRow[] | null>(null);
  const [now] = useState(() => new Date());

  useEffect(() => {
    let alive = true;
    async function load() {
      await syncXp(userId);
      try {
        const { data, error } = await createClient().rpc("friends_league");
        if (!alive) return;
        setRows(error || !Array.isArray(data) ? [] : (data as LeagueRow[]));
      } catch {
        if (alive) setRows([]);
      }
    }
    void load();
    return () => {
      alive = false;
    };
  }, [userId]);

  // La ligne de l'élève : celle du serveur, relevée par l'XP de ce navigateur ; ou la seule.
  const ranked = (() => {
    if (rows === null) return null;
    const list = rows.map((row) => ({ ...row, xp_week: row.is_me ? Math.max(row.xp_week ?? 0, xp.week) : row.xp_week ?? 0 }));
    if (!list.some((row) => row.is_me)) list.push({ user_id: userId, username: null, display_name: myName, xp_week: xp.week, is_me: true });
    return list.sort((a, b) => b.xp_week - a.xp_week || Number(b.is_me) - Number(a.is_me));
  })();

  const myWeek = Math.max(xp.week, ranked?.find((row) => row.is_me)?.xp_week ?? 0);
  const league = leagueFor(myWeek);
  const next = xpToNextLeague(myWeek);
  const tone = LEAGUE_TONE[league];
  const alone = ranked !== null && ranked.length <= 1;

  return (
    <div className="mx-auto flex w-full max-w-[640px] flex-col gap-5 pb-6">
      <header className="flex flex-col gap-2 pt-1">
        <Link href={HOME_PATH} className="pressable flex w-fit items-center gap-1 text-[14px] font-bold text-ink-secondary">
          <ChevronLeft aria-hidden="true" className="size-4 rtl:rotate-180" strokeWidth={2.8} />
          {t("lesson.tab.home")}
        </Link>
        <h1 className="text-[32px] font-extrabold leading-tight tracking-tight-title text-ink">{t("app.kx.league.title")}</h1>
      </header>

      <section className="flex flex-col items-center gap-2 rounded-[26px] p-5 text-center shadow-floating" style={{ background: `var(--color-tone-${tone}-pale)` }}>
        <span className="relative flex size-[92px] items-center justify-center rounded-full bg-surface/70">
          <MicaboIcon id="trophee" size={64} />
          <span aria-hidden="true" className="absolute -bottom-1 -end-1 text-[28px] leading-none">
            {LEAGUE_EMOJI[league]}
          </span>
        </span>
        <p className="text-[24px] font-extrabold leading-tight" style={{ color: `var(--color-tone-${tone}-ink)` }}>
          {t("app.kx.league.leagueName", { league: t(leagueNameKey(league)) })}
        </p>
        <p className="text-[15px] font-bold text-ink">
          {next ? t("app.kx.league.toNext", { n: next.missing, league: t(leagueNameKey(next.next)) }) : t("app.kx.league.top")}
        </p>
        <span className="mt-1 inline-flex items-center gap-1.5 rounded-pill bg-surface/80 px-3 py-1 text-[13px] font-extrabold text-ink-secondary">
          <Clock aria-hidden="true" className="size-3.5" strokeWidth={2.6} />
          {t("app.kx.league.endsIn", { days: daysUntilWeekEnd(now) })}
        </span>
      </section>

      <section aria-labelledby="kx-ranking" className="flex flex-col gap-2">
        <h2 id="kx-ranking" className="ps-1 text-[12px] font-extrabold uppercase tracking-caps text-ink-secondary">
          {t("app.kx.league.ranking")}
        </h2>
        {ranked === null ? (
          <div className="flex flex-col gap-2" aria-hidden="true">
            {[0, 1, 2].map((index) => (
              <div key={index} className="h-[58px] rounded-[18px] bg-surface-muted" />
            ))}
          </div>
        ) : (
          <ol className="flex flex-col gap-1.5">
            {ranked.map((row, index) => {
              const name = row.is_me ? t("app.profileTab.you") : row.display_name?.trim() || (row.username ? displayUsername(row.username) : t("app.friends.someone"));
              return (
                <li
                  key={row.user_id}
                  className={`flex items-center gap-3 rounded-[18px] px-3 py-2.5 ${row.is_me ? "shadow-[inset_0_0_0_2px_var(--color-accent)]" : "shadow-[inset_0_0_0_1.5px_var(--color-stroke)]"}`}
                  style={{ background: row.is_me ? "var(--color-accent-soft)" : "var(--color-surface)" }}
                >
                  <span className={`numeral w-6 text-center text-[16px] font-extrabold ${index === 0 ? "text-caution-ink" : "text-ink-tertiary"}`}>{index + 1}</span>
                  <span className="numeral flex size-9 shrink-0 items-center justify-center rounded-full bg-accent text-[15px] font-extrabold text-on-ink">
                    {(row.is_me ? myName : name).replace(/^@/, "").charAt(0).toUpperCase() || "?"}
                  </span>
                  <span className={`min-w-0 flex-1 truncate text-[16px] font-extrabold ${row.is_me ? "text-accent" : "text-ink"}`}>{name}</span>
                  <span className="numeral inline-flex items-center gap-1 text-[15px] font-extrabold text-ink">
                    <Zap aria-hidden="true" className="size-4 fill-current text-accent" strokeWidth={2.2} />
                    {t("app.kx.league.xp", { n: row.xp_week })}
                  </span>
                </li>
              );
            })}
          </ol>
        )}
      </section>

      {alone ? (
        <section className="flex flex-col gap-3">
          <MikaBubble mood="wave" size={64}>
            {t("app.kx.league.alone")}
          </MikaBubble>
          <FriendButtons />
        </section>
      ) : ranked !== null ? (
        <FriendButtons />
      ) : null}
    </div>
  );
}

/** « Ajouter des amis » (l'écran Amis) et « Inviter des amis » (le partage, sinon le lien copié). */
function FriendButtons() {
  const { t } = useI18n();
  const [copied, setCopied] = useState(false);

  async function invite() {
    const text = t("app.kx.league.inviteText");
    try {
      if (typeof navigator.share === "function") {
        await navigator.share({ title: "Micabo", text, url: INVITE_URL });
        return;
      }
    } catch (error) {
      // Partage annulé : rien à faire. Une autre erreur : on copie le lien à la place.
      if (error instanceof DOMException && error.name === "AbortError") return;
    }
    try {
      await navigator.clipboard.writeText(`${text} ${INVITE_URL}`);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 2200);
    } catch {
      // Pas de presse-papiers : le lien reste lisible dans le texte d'aide.
    }
  }

  return (
    <div className="grid grid-cols-1 gap-2.5 sm:grid-cols-2">
      <Link href={FRIENDS_PATH} className="pressable flex h-[52px] items-center justify-center gap-2 rounded-pill bg-ink px-4 text-[16px] font-extrabold text-on-ink">
        <UserPlus aria-hidden="true" className="size-5" strokeWidth={2.4} />
        {t("app.kx.league.addFriends")}
      </Link>
      <button type="button" onClick={() => void invite()} className="pressable flex h-[52px] items-center justify-center gap-2 rounded-pill bg-surface px-4 text-[16px] font-extrabold text-ink shadow-[inset_0_0_0_1.5px_var(--color-stroke)]">
        {copied ? <Check aria-hidden="true" className="size-5 text-correct" strokeWidth={2.8} /> : <Share2 aria-hidden="true" className="size-5" strokeWidth={2.4} />}
        <span aria-live="polite">{copied ? t("app.kx.league.copied") : t("app.kx.league.invite")}</span>
      </button>
    </div>
  );
}
