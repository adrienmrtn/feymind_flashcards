import Link from "next/link";

import {
  DEFAULT_DAILY_MINUTES,
  EXAM_INTENSITY_LABELS,
  courseAccent,
  dailyLimits,
  dayDifference,
  examCountdownLabel,
  examUrgency,
  resolveEmoji,
  startOfDay,
  stripInlineMarkup,
  studyCounts,
  type ExamIntensity,
  type ExamUrgency,
} from "@micabo/core";

import { ExamMark } from "@/components/app/ExamMark";
import {
  listAllCards,
  listCourses,
  listExams,
  listPendingFriendRequests,
  type CardRow,
  type CourseRow,
  type ExamRow,
  type FriendRequestRow,
} from "@/lib/data/courses";
import { examMarksFor } from "@/lib/data/exam-marks";
import { createClient } from "@/lib/supabase/server";

/**
 * **Le tableau de bord : l'écran d'ouverture du web.**
 *
 * Après la connexion on arrive ici, pas sur l'étagère. Cinq choses, dans cet ordre : le
 * prochain examen (coloré selon l'urgence), les cartes dues aujourd'hui, les derniers cours
 * ajoutés, les cartes qui coincent, et les demandes d'amis — ces dernières n'existent pas
 * encore, la case est déjà là pour qu'elles aient un endroit.
 */
export default async function DashboardPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const [courses, cards, exams, friends, profile] = await Promise.all([
    listCourses(),
    listAllCards(),
    listExams(),
    listPendingFriendRequests(),
    user
      ? supabase
          .from("profiles")
          .select("daily_minutes, display_name")
          .eq("id", user.id)
          .maybeSingle()
          .then((result) => result.data)
      : null,
  ]);

  const minutes = profile?.daily_minutes ?? DEFAULT_DAILY_MINUTES;
  const today = startOfDay(new Date());
  const titles = new Map(courses.map((course) => [course.id, course]));

  const counts = studyCounts(
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

  const nextExam = exams
    .map((exam) => ({
      ...exam,
      days: dayDifference(today, startOfDay(new Date(`${exam.exam_date}T12:00:00`))),
    }))
    .filter((exam) => exam.days >= 0)
    .sort((left, right) => left.days - right.days)[0];

  const recent = [...courses]
    .filter((course) => !course.is_from_library)
    .sort((left, right) => right.created_at.localeCompare(left.created_at))
    .slice(0, 4);

  const hard = [...cards]
    .filter((card) => !card.is_suspended && (card.lapses > 0 || card.ease_factor < 2.3))
    .sort((left, right) => right.lapses - left.lapses || left.ease_factor - right.ease_factor)
    .slice(0, 5);

  const greeting = greetingFor(new Date());
  const name = profile?.display_name?.trim().split(/\s+/)[0];

  return (
    <>
      <header>
        <p className="eyebrow text-ink-tertiary">{greeting}</p>
        <h1 className="mt-2 text-[32px] font-bold leading-tight text-ink">
          {name ? `${name}.` : "Tableau de bord"}
        </h1>
      </header>

      <div className="mt-8 grid gap-4 lg:grid-cols-2">
        <ExamCard exam={nextExam} courses={titles} />
        <ReviewCard counts={counts} />
      </div>

      <section className="mt-8">
        <SectionHead title="Derniers cours ajoutés" href="/app/cours" action="Tous les cours" />
        {recent.length === 0 ? (
          <EmptyBlock
            title="Rien sur l'étagère."
            body="Importe un polycopié : la fiche s'écrit, et tu décides ensuite s'il en faut des cartes."
            href="/app/importer"
            action="Importer un cours"
          />
        ) : (
          <ul className="paper divide-y divide-hairline overflow-hidden rounded-group bg-surface">
            {recent.map((course) => (
              <li key={course.id}>
                <Link
                  href={`/app/c/${course.id}` as never}
                  className="hover-row flex items-center gap-4 px-5 py-4"
                >
                  <span
                    aria-hidden
                    className="flex h-11 w-11 shrink-0 items-center justify-center rounded-tile text-[20px]"
                    style={{
                      backgroundColor: `${course.accent_hex ?? courseAccent(course.id)}1f`,
                    }}
                  >
                    {resolveEmoji(course.emoji, course.subject, course.title)}
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-[16px] font-semibold text-ink">
                      {course.title || "Sans titre"}
                    </span>
                    <span className="mt-0.5 block truncate text-[13px] text-ink-tertiary">
                      {[course.subject, addedLabel(course.created_at)].filter(Boolean).join(" · ")}
                    </span>
                  </span>
                  <Chevron />
                </Link>
              </li>
            ))}
          </ul>
        )}
      </section>

      <div className="mt-8 grid gap-4 lg:grid-cols-2">
        <HardCards cards={hard} courses={titles} exams={examMarksFor(exams, hard)} />
        <FriendsCard requests={friends} />
      </div>
    </>
  );
}

function ExamCard({
  exam,
  courses,
}: {
  exam: (ExamRow & { days: number }) | undefined;
  courses: Map<string, CourseRow>;
}) {
  if (!exam) {
    return (
      <Link
        href={"/app/examens" as never}
        className="paper hover-tile group rounded-group bg-surface p-6"
      >
        <p className="eyebrow text-ink-tertiary">Prochain examen</p>
        <p className="mt-3 text-[18px] font-semibold text-ink">Aucun examen prévu.</p>
        <p className="mt-2 text-[13.5px] leading-relaxed text-ink-secondary">
          Une date remet les cartes dans le bon ordre. Sans elle, la répétition espacée ignore le
          jour J.
        </p>
        <p className="mt-5 text-[13px] font-semibold text-accent">Ajouter un examen</p>
      </Link>
    );
  }

  const urgency = examUrgency(exam.days);
  const tone = urgencyTone(urgency);
  const attached = (exam.course_ids ?? [])
    .map((id) => courses.get(id)?.title)
    .filter(Boolean)
    .slice(0, 3);
  const intensity = asIntensity(exam.intensity);

  return (
    <Link
      href={"/app/examens" as never}
      className={`hover-tile group rounded-group p-6 ${tone.surface}`}
    >
      <p className={`eyebrow ${tone.muted}`}>Prochain examen</p>
      <div className="mt-3 flex items-start justify-between gap-4">
        <div className="min-w-0">
          <p className={`text-[18px] font-semibold leading-snug ${tone.ink}`}>{exam.name}</p>
          <p className={`mt-1 text-[13.5px] ${tone.muted}`}>{frenchDate(exam.exam_date)}</p>
        </div>
        <div className="shrink-0 text-right">
          <p className={`numeral text-[28px] font-bold leading-none ${tone.ink}`}>
            {examCountdownLabel(exam.days)}
          </p>
        </div>
      </div>
      <p className={`mt-4 text-[13px] ${tone.muted}`}>
        {EXAM_INTENSITY_LABELS[intensity]}
        {attached.length > 0 ? ` · ${attached.join(", ")}` : " · aucun cours rattaché"}
      </p>
    </Link>
  );
}

function ReviewCard({
  counts,
}: {
  counts: { total: number; newCards: number; learning: number; review: number };
}) {
  if (counts.total === 0) {
    return (
      <Link
        href="/app/reviser"
        className="paper hover-tile group rounded-group bg-positive-soft p-6"
      >
        <p className="eyebrow text-positive">Aujourd&apos;hui</p>
        <p className="mt-3 text-[18px] font-semibold text-ink">Tout est à jour.</p>
        <p className="mt-2 text-[13.5px] leading-relaxed text-ink-secondary">
          Rien ne revient aujourd&apos;hui. C&apos;est le principe : une carte qu&apos;on revoit trop
          tôt est une carte pour rien.
        </p>
      </Link>
    );
  }

  return (
    <Link
      href="/app/reviser"
        className="paper hover-tile group rounded-group bg-surface p-6"
    >
      <p className="eyebrow text-ink-tertiary">À réviser aujourd&apos;hui</p>
      <p className="mt-3 numeral text-[40px] font-bold leading-none text-ink">{counts.total}</p>
      <p className="mt-1 text-[13.5px] text-ink-secondary">
        carte{counts.total > 1 ? "s" : ""} due{counts.total > 1 ? "s" : ""}
      </p>
      <p className="mt-4 text-[13px] text-ink-tertiary">
        {[
          counts.review ? `${counts.review} révision${counts.review > 1 ? "s" : ""}` : null,
          counts.learning ? `${counts.learning} en apprentissage` : null,
          counts.newCards ? `${counts.newCards} neuve${counts.newCards > 1 ? "s" : ""}` : null,
        ]
          .filter(Boolean)
          .join(" · ")}
      </p>
      <p className="mt-5 text-[13px] font-semibold text-accent">Commencer la session</p>
    </Link>
  );
}

function HardCards({
  cards,
  courses,
  exams,
}: {
  cards: CardRow[];
  courses: Map<string, CourseRow>;
  exams: ReadonlyMap<string, { name: string; daysRemaining: number }>;
}) {
  return (
    <section className="paper rounded-group bg-surface p-6">
      <p className="eyebrow text-ink-tertiary">Cartes les plus difficiles</p>
      {cards.length === 0 ? (
        <p className="mt-3 text-[14.5px] leading-relaxed text-ink-secondary">
          Aucune carte n&apos;a encore coincé. Ça viendra — et c&apos;est pour ça qu&apos;on les
          note.
        </p>
      ) : (
        <ul className="mt-4 divide-y divide-hairline">
          {cards.map((card) => {
            const course = card.course_id ? courses.get(card.course_id) : undefined;
            const exam = exams.get(card.id);
            const href = card.course_id
              ? (`/app/c/${card.course_id}/cartes` as never)
              : ("/app/cours" as never);
            return (
              <li key={card.id}>
                <Link
                  href={href}
                  className="hover-row -mx-2 flex items-start gap-3 rounded-button px-2 py-3"
                >
                  <span className="min-w-0 flex-1">
                    <span className="block text-[14.5px] font-medium leading-snug text-ink">
                      {previewFront(card.front)}
                    </span>
                    <span className="mt-0.5 flex items-center gap-1.5">
                      <span className="min-w-0 truncate text-[12.5px] text-ink-tertiary">
                        {course?.title ?? "Sans cours"}
                      </span>
                      {exam ? (
                        <ExamMark name={exam.name} daysRemaining={exam.daysRemaining} />
                      ) : null}
                    </span>
                  </span>
                  <span className="numeral shrink-0 text-[13px] font-semibold text-negative">
                    {card.lapses} oubli{card.lapses > 1 ? "s" : ""}
                  </span>
                </Link>
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}

function FriendsCard({ requests }: { requests: FriendRequestRow[] }) {
  return (
    <section className="paper rounded-group bg-surface p-6">
      <p className="eyebrow text-ink-tertiary">Demandes d&apos;amis</p>
      {requests.length === 0 ? (
        <>
          <p className="mt-3 text-[18px] font-semibold text-ink">Rien pour l&apos;instant.</p>
          <p className="mt-2 text-[13.5px] leading-relaxed text-ink-secondary">
            Les demandes d&apos;amis arriveront ici. On pourra alors partager un cours sans
            l&apos;ouvrir à tout le monde.
          </p>
        </>
      ) : (
        <ul className="mt-4 space-y-2">
          {requests.map((request) => (
            <li
              key={request.requesterId}
              className="flex items-center justify-between gap-3 rounded-button bg-surface-muted px-3 py-2.5"
            >
              <span className="truncate text-[14.5px] font-medium text-ink">
                {request.username ? `@${request.username}` : "Quelqu'un"}
              </span>
              <span className="shrink-0 text-[12px] text-ink-tertiary">Bientôt</span>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

function SectionHead({
  title,
  href,
  action,
}: {
  title: string;
  href: string;
  action: string;
}) {
  return (
    <div className="mb-3 flex items-baseline justify-between gap-4">
      <h2 className="text-[15px] font-semibold text-ink">{title}</h2>
      <Link href={href as never} className="text-[13px] font-medium text-accent hover:underline">
        {action}
      </Link>
    </div>
  );
}

function EmptyBlock({
  title,
  body,
  href,
  action,
}: {
  title: string;
  body: string;
  href: string;
  action: string;
}) {
  return (
    <div className="rounded-group bg-canvas-sage p-7">
      <p className="text-[16px] font-semibold text-ink">{title}</p>
      <p className="mt-2 max-w-[46ch] text-[14px] leading-relaxed text-ink-reading">{body}</p>
      <Link
        href={href as never}
        className="pressable mt-5 inline-flex rounded-button bg-ink px-5 py-2.5 text-[14px] font-semibold text-on-ink"
      >
        {action}
      </Link>
    </div>
  );
}

function Chevron() {
  return (
    <svg
      aria-hidden
      viewBox="0 0 20 20"
      className="h-4 w-4 shrink-0 text-ink-tertiary"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M8 4l6 6-6 6" />
    </svg>
  );
}

function urgencyTone(urgency: ExamUrgency): { surface: string; ink: string; muted: string } {
  switch (urgency) {
    case "critical":
      return { surface: "bg-negative-soft", ink: "text-negative", muted: "text-negative/70" };
    case "soon":
      return { surface: "bg-caution-soft", ink: "text-caution", muted: "text-caution/75" };
    case "upcoming":
      return { surface: "bg-info-soft", ink: "text-info", muted: "text-info/70" };
    case "later":
      return { surface: "bg-accent-soft", ink: "text-accent", muted: "text-accent/75" };
    case "past":
      return { surface: "bg-surface-muted", ink: "text-ink-secondary", muted: "text-ink-tertiary" };
  }
}

function asIntensity(value: string): ExamIntensity {
  return value === "light" || value === "intense" || value === "standard" ? value : "standard";
}

function frenchDate(value: string): string {
  return new Date(`${value}T12:00:00`).toLocaleDateString("fr-FR", {
    weekday: "long",
    day: "numeric",
    month: "long",
  });
}

function addedLabel(iso: string): string {
  const date = new Date(iso);
  return date.toLocaleDateString("fr-FR", { day: "numeric", month: "short" });
}

function previewFront(front: string): string {
  const plain = stripInlineMarkup(front).replace(/\s+/g, " ").trim();
  return plain.length > 90 ? `${plain.slice(0, 87)}…` : plain || "Carte sans question";
}

function greetingFor(now: Date): string {
  const hour = now.getHours();
  if (hour < 6) return "Bonne nuit";
  if (hour < 12) return "Bonjour";
  if (hour < 18) return "Bon après-midi";
  return "Bonsoir";
}
