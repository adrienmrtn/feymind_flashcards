import Link from "next/link";

import {
  DEFAULT_DAILY_MINUTES,
  buildQueue,
  dailyLimits,
  entitlement,
  isSheetLength,
  resolveEmoji,
} from "@micabo/core";

import { Session } from "@/components/app/Session";
import { listAllCards, listCourses } from "@/lib/data/courses";
import { readEntitlement } from "@/lib/data/entitlement";
import { createClient } from "@/lib/supabase/server";

/**
 * La session, **et l'écran qui la précède.**
 *
 * On n'entre plus dans une session sans savoir dans quoi on entre : combien de cartes, de quels
 * cours, combien de neuves. C'est le pendant de l'app, où la session se lance depuis un bouton
 * ancré qui annonce son compte — et c'est ce qui permet de reculer, ce qu'un écran qui démarre
 * tout seul ne permet pas.
 *
 * `?cours=<id>` restreint la session à un cours. C'est ce qui manquait pour réviser depuis un
 * cours, comme sur l'iPhone : la file reste construite par le **même `buildQueue`**, seulement sur
 * un sous-ensemble de cartes.
 */
export default async function ReviewPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const params = await searchParams;
  const courseId = typeof params.cours === "string" ? params.cours : null;
  const started = params.go === "1";

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const [allCards, courses, right, profile] = await Promise.all([
    listAllCards(),
    listCourses(),
    readEntitlement(),
    user
      ? supabase
          .from("profiles")
          .select("daily_minutes, sheet_length")
          .eq("id", user.id)
          .maybeSingle()
          .then((result) => result.data)
      : null,
  ]);

  // Le rythme vient du profil, pas d'une constante : c'est lui qui plafonne les cartes neuves, et
  // c'est la colonne que l'iPhone écrit aussi.
  const minutes = profile?.daily_minutes ?? DEFAULT_DAILY_MINUTES;
  void isSheetLength;

  const cards = courseId ? allCards.filter((card) => card.course_id === courseId) : allCards;

  const queue = buildQueue(
    cards.map((card) => ({
      id: card.id,
      state: card.state,
      dueDate: new Date(card.due_date),
      position: card.position,
      createdAt: new Date(card.created_at),
      isSuspended: card.is_suspended,
    })),
    { limits: dailyLimits(minutes) },
  );

  const byId = new Map(cards.map((card) => [card.id, card]));
  const titles = new Map(courses.map((course) => [course.id, course.title]));

  const ordered = queue
    .map((item) => byId.get(item.id))
    .filter((card): card is NonNullable<typeof card> => Boolean(card))
    .map((card) => ({
      id: card.id,
      front: card.front,
      back: card.back,
      hint: card.hint,
      kind: card.kind,
      choices: card.choices ?? [],
      answerIndex: card.correct_choice_index,
      courseTitle: card.course_id ? (titles.get(card.course_id) ?? null) : null,
      snapshot: {
        state: card.state,
        intervalDays: card.interval_days,
        easeFactor: card.ease_factor,
        repetitions: card.repetitions,
        lapses: card.lapses,
        stepIndex: card.step_index,
      },
    }));

  if (ordered.length === 0) {
    return (
      <div className="mx-auto max-w-[520px] py-16 text-center">
        <p className="text-[26px] font-bold text-ink">Tout est à jour.</p>
        <p className="mt-3 text-[15px] leading-relaxed text-ink-secondary">
          {cards.length === 0
            ? "Tu n'as pas encore de cartes ici. Elles se demandent depuis la fiche d'un cours, quand tu l'as lue."
            : "Rien ne revient aujourd'hui. C'est le principe : une carte qu'on revoit trop tôt est une carte pour rien."}
        </p>
        <Link
          href={cards.length === 0 ? "/app/importer" : "/app"}
          className="pressable mt-8 inline-flex rounded-button bg-ink px-6 py-3.5 text-[15px] font-semibold text-on-ink"
        >
          {cards.length === 0 ? "Importer un cours" : "Retour aux cours"}
        </Link>
      </div>
    );
  }

  if (started) {
    return <Session cards={ordered} isPro={right.isPro} />;
  }

  // Ce que la session contient, compté sur la file réelle et pas estimé.
  const fresh = ordered.filter((card) => card.snapshot.state === "new").length;
  const again = ordered.length - fresh;
  const cap = right.isPro ? ordered.length : entitlement.FREE_TIER.cardsPerSession;
  const served = Math.min(ordered.length, cap);

  const involved = courses.filter((course) =>
    cards.some((card) => card.course_id === course.id && byId.has(card.id)),
  );

  return (
    <div className="mx-auto max-w-[560px] py-6">
      <header className="rise">
        <p className="eyebrow text-ink-tertiary">
          {courseId ? "Réviser ce cours" : "Ta session du jour"}
        </p>
        <h1 className="mt-2.5 text-[32px] font-bold leading-tight text-ink">
          <span className="numeral">{served}</span> carte{served > 1 ? "s" : ""} à revoir
        </h1>
      </header>

      <dl className="rise mt-8 grid grid-cols-2 gap-3" style={{ animationDelay: "80ms" }}>
        <Tile value={again} label={again === 1 ? "à revoir" : "à revoir"} />
        <Tile value={fresh} label={fresh === 1 ? "nouvelle" : "nouvelles"} accent />
      </dl>

      {involved.length > 0 ? (
        <section className="rise mt-8" style={{ animationDelay: "140ms" }}>
          <p className="eyebrow mb-3 text-ink-tertiary">
            {involved.length === 1 ? "Le cours" : "Les cours"}
          </p>
          <ul className="paper divide-y divide-hairline overflow-hidden rounded-group bg-surface">
            {involved.map((course) => {
              const count = ordered.filter(
                (card) => titles.get(course.id) === card.courseTitle,
              ).length;
              return (
                <li key={course.id} className="flex items-center gap-3.5 px-5 py-3.5">
                  <span aria-hidden className="emoji text-[18px]">
                    {resolveEmoji(course.emoji, course.subject, course.title)}
                  </span>
                  <span className="min-w-0 flex-1 truncate text-[14.5px] text-ink">
                    {course.title}
                  </span>
                  <span className="numeral shrink-0 text-[13px] text-ink-tertiary">{count}</span>
                </li>
              );
            })}
          </ul>
        </section>
      ) : null}

      <div className="rise mt-9" style={{ animationDelay: "200ms" }}>
        <Link
          href={
            (courseId ? `/app/reviser?cours=${courseId}&go=1` : "/app/reviser?go=1") as never
          }
          className="pressable shiny flex h-14 w-full items-center justify-center rounded-button bg-ink text-[16px] font-semibold text-on-ink"
        >
          Commencer la session
        </Link>

        <p className="mt-3.5 text-center text-[12.5px] leading-relaxed text-ink-tertiary">
          Espace retourne la carte, 1 à 4 la notent.
          {!right.isPro && ordered.length > cap
            ? ` Le gratuit en sert ${cap} à la fois.`
            : ""}
        </p>
      </div>
    </div>
  );
}

function Tile({ value, label, accent }: { value: number; label: string; accent?: boolean }) {
  return (
    <div className={`rounded-group p-5 ${accent ? "bg-accent-soft" : "paper bg-surface"}`}>
      <dd className={`numeral text-[30px] font-bold leading-none ${accent ? "text-accent" : "text-ink"}`}>
        {value}
      </dd>
      <dt className={`mt-1.5 text-[13px] ${accent ? "text-accent" : "text-ink-tertiary"}`}>
        {label}
      </dt>
    </div>
  );
}
