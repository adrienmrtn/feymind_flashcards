"use client";

import { useCallback, useEffect, useMemo, useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";

import {
  CARD_KINDS,
  DEFAULT_QUOTA,
  PER_FORMAT_RANGE,
  TARGET_SCORE_MAX,
  TARGET_SCORE_MIN,
  TOTAL_RANGE,
  asExamKind,
  averageDailyLoad,
  busiestDay,
  clampTargetScore,
  dayDifference,
  defaultFormatsFor,
  desiredGradeLabel,
  desiredGradeScale,
  intensityFor,
  intensityFromTargetScore,
  isAtCap,
  isProjectionEmpty,
  mockQuestionCount,
  planExam,
  quotaTotal,
  startOfDay,
  wantsMock,
  type CardKind,
  type ExamKind,
  type QuestionQuota,
  type StartingPoint,
} from "@micabo/core";
import { ThinkingOrb } from "thinking-orbs";

import { CountStepper } from "@/components/app/CountStepper";
import { GenerationStatus } from "@/components/app/GenerationStatus";
import { ImportPanel, type QueuedDocument } from "@/components/app/ImportPanel";
import { ChoiceRow } from "@/components/onboarding/Scaffold";
import { Button } from "@/components/ui/button";
import { Slider } from "@/components/ui/slider";
import { ExamDayPicker, isoDay } from "@/components/app/exams/ExamCalendar";
import { generateCards, type WrittenCard } from "@/lib/actions/course";
import { deleteCard } from "@/lib/actions/cards";
import { createPlan } from "@/lib/actions/plan";
import { useI18n } from "@/lib/i18n/client";
import { writeSheetFromBrowser } from "@/lib/import/write-sheet";
import { localeBcp47 } from "@/lib/i18n/copy";

/**
 * **Créer un plan, du document brut jusqu'à la date.**
 *
 * Le parcours partait du principe que le matériel existait déjà : on cochait des cours, on
 * posait une date, et si le cours n'avait pas de cartes le plan était vide sans le dire. Il
 * commence maintenant plus tôt et va plus loin, dans un seul fil :
 *
 * ```
 * matériel -> (fiches) -> (cartes, un cours à la fois)
 *          -> jour -> type -> nom -> point de départ -> jours off -> note
 * ```
 *
 * **Une question par page.** Les trois questions sur l'épreuve avaient été empilées sur un
 * seul écran pour raccourcir le parcours ; il n'a pas raccourci, il est devenu un formulaire.
 * Un écran qui pose trois choses se lit trois fois plus lentement que trois écrans qui en
 * posent une, parce qu'on doit d'abord démêler laquelle on répond.
 *
 * **Les fiches s'écrivent toutes au clic sur Continuer**, pas à chaque dépôt. On pose trois
 * polycopiés à la suite sans attendre entre les deux, et l'attente arrive une seule fois, à
 * un moment où l'on sait pourquoi on attend.
 *
 * **Puis une page par cours nouvellement importé**, pour en demander les cartes. Seulement les
 * nouveaux : un cours déjà dans la bibliothèque a déjà eu son tour, et reposer la question
 * ferait de la création d'un plan un inventaire.
 *
 * Ce qui a disparu : l'étape « de combien de temps disposes-tu ». Elle produisait un budget
 * que le plan ensuite défendait contre l'étudiant. Le plan répartit le travail jusqu'au jour J
 * et annonce ce que ça coûte ; c'est tout ce qu'il a le droit de dire.
 */

const STEPS = [
  "materiel",
  "cartes",
  "jour",
  "type",
  "nom",
  "depart",
  "pauses",
  "note",
] as const;
type Step = (typeof STEPS)[number];

export interface PlanCourse {
  id: string;
  title: string;
  emoji: string;
  cardCount: number;
}

export interface PlanCard {
  id: string;
  courseId: string | null;
  kind: string;
  state: "new" | "learning" | "review" | "relearning";
  intervalDays: number;
  dueDate: string;
  isSuspended: boolean;
}

/** Un cours arrivé par ce parcours, et ce qu'on en sait au fil des étapes. */
interface FreshCourse {
  id: string;
  title: string;
  cardCount: number;
}

export function NewPlan({
  courses,
  cards,
  countryCode,
  sheetLength,
}: {
  courses: PlanCourse[];
  cards: PlanCard[];
  countryCode?: string | null;
  sheetLength?: string;
}) {
  const { t, locale } = useI18n();
  const router = useRouter();
  const today = startOfDay(new Date());

  const [step, setStep] = useState<Step>("materiel");
  const [picked, setPicked] = useState<string[]>([]);
  const [queue, setQueue] = useState<QueuedDocument[]>([]);
  const [fresh, setFresh] = useState<FreshCourse[]>([]);
  const [freshIndex, setFreshIndex] = useState(0);
  const [writing, setWriting] = useState<{ done: number; total: number; label: string } | null>(null);

  const [examDate, setExamDate] = useState(isoDay(addWeeks(today, 3)));
  const [month, setMonth] = useState(() => new Date(today.getFullYear(), today.getMonth(), 1));
  const [kind, setKind] = useState<ExamKind>("exam");
  const [name, setName] = useState("");
  const [start, setStart] = useState<StartingPoint>("seen");
  /** Les jours où l'étudiant a dit qu'il ne réviserait pas, en dates ISO. */
  const [offDays, setOffDays] = useState<string[]>([]);
  const [targetScore, setTargetScore] = useState(15);

  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  /**
   * Le document posé dans l'aperçu, pas encore au programme.
   *
   * Le panneau d'import posait un bouton « Ajouter au programme » sous l'aperçu. Ici ce
   * n'était pas un choix : tout ce qu'on dépose sur cet écran **est** le programme. Le
   * bouton posait donc une question dont la réponse était connue, et coûtait un clic de
   * plus. C'est « Continuer » qui met de côté, puis avance.
   */
  const pendingImport = useRef<(() => void) | null>(null);
  const [hasPendingImport, setHasPendingImport] = useState(false);
  /** Ce que « Continuer » exécute sur l'étape des cartes tant que rien n'est écrit. */
  const pendingCards = useRef<(() => Promise<void>) | null>(null);
  const [hasPendingCards, setHasPendingCards] = useState(false);
  const [writingCards, setWritingCards] = useState(false);

  /** Les cours du programme : ceux qu'on a cochés, plus ceux qu'on vient de ficher. */
  const known = useMemo(() => {
    const all = new Map(courses.map((course) => [course.id, course]));
    for (const course of fresh) {
      all.set(course.id, {
        id: course.id,
        title: course.title,
        emoji: "📄",
        cardCount: course.cardCount,
      });
    }
    return all;
  }, [courses, fresh]);

  const chosenDay = startOfDay(new Date(`${examDate}T12:00:00`));
  const daysRemaining = dayDifference(today, chosenDay);
  const intensity = intensityFor(intensityFromTargetScore(targetScore), start);

  const scoped = useMemo(
    () => cards.filter((card) => !card.isSuspended && card.courseId && picked.includes(card.courseId)),
    [cards, picked],
  );

  // Les jours off, en rangs de jours : c'est la forme que le noyau comprend, et c'est la
  // même conversion que fera le serveur au moment d'écrire le plan.
  const offOffsets = useMemo(
    () => offsetsUntil(offDays, today, Math.max(1, daysRemaining)),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [offDays, examDate],
  );

  const plan = useMemo(() => {
    return planExam(
      scoped.map((card) => ({
        id: card.id,
        state: card.state,
        intervalDays: card.intervalDays,
        dueDate: new Date(card.dueDate),
      })),
      chosenDay,
      { intensity, offDays: offOffsets },
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [scoped, intensity, examDate, offOffsets]);

  const visible = STEPS.filter((item) => item !== "cartes" || fresh.length > 0);
  const index = Math.max(0, visible.indexOf(step));

  /** Le nom retenu : celui qu'on a tapé, sinon les cours du programme. */
  const suggestedName = planName(picked, [...known.values()]);
  const finalName = name.trim() || suggestedName;

  const canContinue =
    step === "materiel"
      ? picked.length > 0 || queue.length > 0 || hasPendingImport
      : step === "jour"
        ? daysRemaining >= 0
        : true;

  /**
   * Écrire les fiches en attente, l'une après l'autre.
   *
   * En série et non en parallèle : trois appels de modèle lancés ensemble finissent par se
   * gêner, et surtout la barre d'attente ne voudrait plus rien dire. Un document qui échoue
   * n'arrête pas les autres - on le dit à la fin, et le plan se fait avec le reste.
   */
  async function writeQueued(): Promise<FreshCourse[]> {
    const written: FreshCourse[] = [];
    const failed: string[] = [];

    for (const [position, document] of queue.entries()) {
      setWriting({ done: position, total: queue.length, label: document.label });
      const result = await writeSheetFromBrowser(document);
      if (result.status === "ok" && result.courseId) {
        written.push({ id: result.courseId, title: document.label, cardCount: 0 });
      } else {
        failed.push(document.label);
      }
    }

    setWriting(null);
    setQueue([]);
    if (failed.length > 0) {
      setFailure(t("app.newPlan.writeFailed", { names: failed.join(", ") }));
    }
    return written;
  }

  /**
   * L'étape suivante dans le fil, en tenant compte de ce qui n'existe pas encore.
   *
   * `visible` est calculé avec les cours fraîchement fichés, qui n'existent pas au moment où
   * on quitte le matériel. On passe donc la liste explicitement quand elle vient de changer.
   */
  function stepAfter(from: Step, freshCount: number): Step {
    const list = STEPS.filter((item) => item !== "cartes" || freshCount > 0);
    const at = list.indexOf(from);
    return list[Math.min(list.length - 1, at + 1)] ?? "note";
  }

  async function next() {
    if (!canContinue || busy) return;
    setFailure(null);

    if (step === "materiel") {
      // Un document laissé dans l'aperçu part au programme sans qu'on le redemande.
      if (pendingImport.current) {
        pendingImport.current();
        pendingImport.current = null;
        setHasPendingImport(false);
        return;
      }
      if (queue.length === 0) {
        setStep(stepAfter("materiel", fresh.length));
        return;
      }
      setBusy(true);
      const written = await writeQueued();
      setBusy(false);
      const all = [...fresh, ...written];
      setFresh(all);
      setPicked((current) => [...new Set([...current, ...written.map((course) => course.id)])]);
      setFreshIndex(0);
      setStep(stepAfter("materiel", all.length));
      return;
    }

    // Sur l'étape des cartes, le premier « Continuer » écrit ; le suivant avance.
    if (step === "cartes" && pendingCards.current) {
      const write = pendingCards.current;
      pendingCards.current = null;
      setHasPendingCards(false);
      await write();
      return;
    }

    // Les cartes ne sont pas une étape mais autant d'étapes qu'il y a de cours neufs.
    if (step === "cartes" && freshIndex + 1 < fresh.length) {
      setFreshIndex(freshIndex + 1);
      return;
    }

    if (step === "note") {
      void confirm();
      return;
    }

    setStep(stepAfter(step, fresh.length));
  }

  function back() {
    setFailure(null);

    if (step === "cartes" && freshIndex > 0) {
      setFreshIndex(freshIndex - 1);
      return;
    }

    const previous = visible[index - 1];
    if (!previous) return;
    if (previous === "cartes") setFreshIndex(Math.max(0, fresh.length - 1));
    setStep(previous);
  }

  async function confirm() {
    setBusy(true);
    setFailure(null);

    const result = await createPlan({
      courseIds: picked,
      examDate,
      kind,
      startingPoint: start,
      targetScore,
      formats: defaultFormatsFor(kind),
      name: finalName,
      offDays,
    });

    setBusy(false);
    if (result.status === "error") {
      setFailure(result.message ?? t("app.common.errorGeneric"));
      return;
    }
    startTransition(() => router.push((result.examId ? `/app/plan/${result.examId}` : "/app") as never));
  }

  if (writing) {
    return <WritingSheets state={writing} />;
  }

  const current = fresh[freshIndex];

  return (
    <div className="mx-auto w-full max-w-[620px]">
      <div className="flex items-center justify-between gap-4">
        <div className="flex items-center gap-1.5" aria-hidden>
          {visible.map((item, position) => (
            <span
              key={item}
              className={`h-1.5 rounded-pill transition-all duration-menu ${
                position === index
                  ? "w-6 bg-ink"
                  : position < index
                    ? "w-1.5 bg-ink"
                    : "w-1.5 bg-stroke-strong"
              }`}
            />
          ))}
        </div>
        <Link href={"/app" as never} className="text-[13px] font-medium text-ink-tertiary underline-draw">
          {t("app.newPlan.leave")}
        </Link>
      </div>

      <div key={`${step}:${freshIndex}`} className="rise mt-7">
        {step === "materiel" ? (
          <MaterialStep
            courses={courses}
            picked={picked}
            queue={queue}
            onQueueHandle={(fn) => {
              pendingImport.current = fn;
              // Le bouton s'allume dès qu'un document attend, même sans cours coché.
              setHasPendingImport(Boolean(fn));
            }}
            sheetLength={sheetLength}
            onToggle={(id) =>
              setPicked((current) =>
                current.includes(id) ? current.filter((item) => item !== id) : [...current, id],
              )
            }
            onQueue={(document) => setQueue((current) => [...current, document])}
            onDrop={(position) =>
              setQueue((current) => current.filter((_, index) => index !== position))
            }
          />
        ) : null}

        {step === "cartes" && current ? (
          <CardsStep
            key={current.id}
            course={current}
            position={freshIndex + 1}
            total={fresh.length}
            onWritten={(count) =>
              setFresh((all) =>
                all.map((course) =>
                  course.id === current.id
                    ? { ...course, cardCount: Math.max(0, course.cardCount + count) }
                    : course,
                ),
              )
            }
            onGenerateHandle={(fn) => {
              pendingCards.current = fn;
              setHasPendingCards(Boolean(fn));
            }}
            onWritingChange={setWritingCards}
          />
        ) : null}

        {step === "jour" ? (
          <DayStep
            picked={chosenDay}
            month={month}
            daysRemaining={daysRemaining}
            onMonth={setMonth}
            onSelect={(day) => {
              const start = startOfDay(day);
              if (start.getTime() < today.getTime()) return;
              setExamDate(isoDay(start));
              setMonth(new Date(start.getFullYear(), start.getMonth(), 1));
              // Une date qui recule laisse des jours off derrière elle : ils ne veulent
              // plus rien dire, et les garder ferait mentir le compteur de pauses.
              setOffDays((current) => current.filter((iso) => iso <= isoDay(start)));
            }}
          />
        ) : null}

        {step === "type" ? <KindStep kind={kind} onPick={setKind} /> : null}

        {step === "nom" ? (
          <NameStep name={name} suggestion={suggestedName} onChange={setName} />
        ) : null}

        {step === "depart" ? <StartStep start={start} onPick={setStart} /> : null}

        {step === "pauses" ? (
          <PausesStep
            today={today}
            daysRemaining={daysRemaining}
            offDays={offDays}
            onToggle={(iso) =>
              setOffDays((current) =>
                current.includes(iso)
                  ? current.filter((item) => item !== iso)
                  : [...current, iso].sort(),
              )
            }
          />
        ) : null}

        {step === "note" ? (
          <ScoreStep
            targetScore={targetScore}
            countryCode={countryCode}
            onPick={setTargetScore}
            cardCount={plan.projection.cardCount}
            daysRemaining={daysRemaining}
            daily={averageDailyLoad(plan.projection)}
            peak={busiestDay(plan.projection)}
            load={plan.projection.load}
            empty={isProjectionEmpty(plan.projection)}
            mockQuestions={wantsMock(kind) ? mockQuestionCount(scoped.length) : 0}
            offCount={offOffsets.length}
          />
        ) : null}
      </div>

      {failure ? (
        <p className="mt-4 text-[13.5px] text-negative" role="alert">
          {failure}
        </p>
      ) : null}

      <div className="mt-8">
        <Button
          className="h-14 w-full text-[16px]"
          onClick={() => void next()}
          disabled={busy || pending || writingCards || !canContinue}
        >
          {busy || pending || writingCards ? (
            <>
              <ThinkingOrb state="connecting" size={20} theme="dark" />
              {writingCards ? t("app.generate.writing") : t("app.exams.wait")}
            </>
          ) : step === "note" ? (
            t("app.newPlan.create")
          ) : step === "materiel" && queue.length > 0 ? (
            t("app.newPlan.writeQueue", { count: queue.length })
          ) : step === "cartes" ? (
            hasPendingCards ? t("app.newPlan.cardsWrite") : t("app.newPlan.cardsNext")
          ) : (
            t("app.common.continue")
          )}
        </Button>

        {index > 0 || (step === "cartes" && freshIndex > 0) ? (
          <Button variant="ghost" className="mt-2 w-full" onClick={back} disabled={busy || pending || writingCards}>
            {t("app.common.back")}
          </Button>
        ) : null}
      </div>

      <p className="mt-4 text-center text-[12px] text-ink-tertiary">
        {t(`app.newPlan.hint.${step}`)}
      </p>
    </div>
  );
}

/**
 * L'attente pendant que les fiches s'écrivent.
 *
 * Elle nomme le document en cours et son rang. C'est la seule attente longue du parcours, et
 * une attente qu'on ne sait pas lire est une attente qu'on abandonne.
 */
function WritingSheets({ state }: { state: { done: number; total: number; label: string } }) {
  const { t } = useI18n();
  return (
    <div className="mx-auto w-full max-w-[620px] py-10">
      <div className="panel flex items-center gap-4 p-6">
        <GenerationStatus
          title={t("app.newPlan.writingOne", { name: state.label })}
          hint={t("app.newPlan.writingCount", { done: state.done + 1, total: state.total })}
        />
      </div>
      <p className="mt-4 text-center text-[12px] text-ink-tertiary">{t("app.newPlan.hint.ecriture")}</p>
    </div>
  );
}

/**
 * Le matériel : ce qui existe déjà, et ce qu'on ajoute.
 *
 * Un document déposé ici **n'est pas encore fiché**. Il attend dans une liste, on peut le
 * retirer, et l'écriture part au clic sur Continuer.
 */
function MaterialStep({
  courses,
  picked,
  queue,
  sheetLength,
  onToggle,
  onQueue,
  onDrop,
  onQueueHandle,
}: {
  courses: PlanCourse[];
  picked: string[];
  queue: QueuedDocument[];
  sheetLength?: string;
  onToggle: (id: string) => void;
  onQueue: (document: QueuedDocument) => void;
  onDrop: (position: number) => void;
  /** Ce que « Continuer » doit exécuter quand un document attend dans l'aperçu. */
  onQueueHandle: (queue: (() => void) | null) => void;
}) {
  const { t } = useI18n();
  const [adding, setAdding] = useState(courses.length === 0);

  return (
    <div>
      <p className="eyebrow text-ink-tertiary">{t("app.newPlan.materialEyebrow")}</p>
      <h1 className="mt-2 text-[26px] font-bold leading-[1.12] text-ink">
        {t("app.newPlan.materialTitle")}
      </h1>
      <p className="mt-3 text-[14.5px] leading-relaxed text-ink-secondary">
        {t("app.newPlan.materialLead")}
      </p>

      {courses.length > 0 ? (
        <ul className="mt-6 space-y-2">
          {courses.map((course) => (
            <li key={course.id}>
              <ChoiceRow
                emoji={course.emoji}
                title={course.title || t("app.course.untitled")}
                detail={t("app.course.cardCount", { count: course.cardCount })}
                selected={picked.includes(course.id)}
                onSelect={() => onToggle(course.id)}
              />
            </li>
          ))}
        </ul>
      ) : null}

      {queue.length > 0 ? (
        <ul className="mt-4 space-y-2">
          {queue.map((document, position) => (
            <li
              key={`${document.label}:${position}`}
              className="flex items-center gap-3 rounded-button border border-dashed border-stroke-strong px-4 py-3"
            >
              <span aria-hidden className="emoji text-[18px]">
                📄
              </span>
              <span className="min-w-0 flex-1">
                <span className="block truncate text-[14.5px] font-medium text-ink">
                  {document.label}
                </span>
                <span className="mt-0.5 block text-[12.5px] text-ink-tertiary">
                  {t("app.newPlan.queued")}
                </span>
              </span>
              <button
                type="button"
                onClick={() => onDrop(position)}
                className="pressable shrink-0 text-[12.5px] font-medium text-ink-tertiary underline-draw"
              >
                {t("app.common.remove")}
              </button>
            </li>
          ))}
        </ul>
      ) : null}

      {adding ? (
        <div className="mt-6 panel p-5">
          <ImportPanel
            initialLength={sheetLength as never}
            onQueue={(document) => {
              onQueue(document);
              setAdding(false);
            }}
            queueHandle={onQueueHandle}
          />
        </div>
      ) : (
        <Button variant="outline" className="mt-4 w-full" onClick={() => setAdding(true)}>
          {t("app.newPlan.addMaterial")}
        </Button>
      )}
    </div>
  );
}

/**
 * Les cartes d'un cours qui vient d'arriver, **dans le parcours**.
 *
 * L'étape demandait les formats, puis posait un bouton « Générer ces cartes », puis un
 * « Continuer » à côté. Deux boutons pour un seul geste : on choisissait combien de cartes,
 * on validait ce choix, puis on validait le fait d'avoir validé. Et une fois écrites, les
 * cartes n'étaient qu'un nombre - il fallait quitter le parcours pour aller voir ce que le
 * modèle avait produit, donc personne n'allait voir.
 *
 * Un seul bouton maintenant, celui de l'écran : **Continuer écrit les cartes**, puis les
 * montre. On les lit, on jette celles qui ne valent rien, on en redemande si le compte est
 * court, et le Continuer suivant passe au cours d'après.
 */
function CardsStep({
  course,
  position,
  total,
  onWritten,
  onGenerateHandle,
  onWritingChange,
}: {
  course: FreshCourse;
  position: number;
  total: number;
  onWritten: (count: number) => void;
  /** Ce que « Continuer » exécute tant qu'aucune carte n'a été écrite. */
  onGenerateHandle: (generate: (() => Promise<void>) | null) => void;
  onWritingChange: (writing: boolean) => void;
}) {
  const { t } = useI18n();
  const [quota, setQuota] = useState<QuestionQuota>(DEFAULT_QUOTA);
  const [writing, setWriting] = useState(false);
  const [cards, setCards] = useState<WrittenCard[]>([]);
  const [failure, setFailure] = useState<string | null>(null);
  const [startedAt, setStartedAt] = useState<number | null>(null);
  const [asking, setAsking] = useState(false);

  const count = quotaTotal(quota);
  const capped = isAtCap(quota);
  const written = cards.length;

  function step(kind: CardKind, delta: number) {
    setQuota((current) => ({
      ...current,
      [kind]: Math.min(
        PER_FORMAT_RANGE.max,
        Math.max(PER_FORMAT_RANGE.min, current[kind] + delta),
      ),
    }));
  }

  const ask = useCallback(async () => {
    setFailure(null);
    setStartedAt(Date.now());
    setWriting(true);
    onWritingChange(true);
    const result = await generateCards(course.id, quota);
    setWriting(false);
    onWritingChange(false);
    setAsking(false);
    if (result.status === "error") {
      setFailure(result.message ?? t("app.common.errorGeneric"));
      return;
    }
    setCards((current) => [...current, ...(result.cards ?? [])]);
    onWritten(result.count);
  }, [course.id, onWritingChange, onWritten, quota, t]);

  // Tant que rien n'est écrit, « Continuer » écrit. Ensuite il passe au cours suivant.
  useEffect(() => {
    onGenerateHandle(written === 0 && !writing ? ask : null);
    return () => onGenerateHandle(null);
  }, [ask, onGenerateHandle, writing, written]);

  async function drop(cardId: string) {
    setCards((current) => current.filter((card) => card.id !== cardId));
    onWritten(-1);
    const result = await deleteCard(cardId, course.id);
    if (result.status === "error") setFailure(result.message ?? t("app.common.errorGeneric"));
  }

  return (
    <div>
      <p className="eyebrow text-ink-tertiary">
        {total > 1
          ? t("app.newPlan.cardsEyebrowOf", { position, total })
          : t("app.newPlan.cardsEyebrow")}
      </p>
      <h1 className="mt-2 text-[26px] font-bold leading-[1.12] text-ink">
        {t("app.newPlan.cardsTitle", { name: course.title })}
      </h1>
      <p className="mt-3 text-[14.5px] leading-relaxed text-ink-secondary">
        {written > 0 ? t("app.newPlan.cardsDone", { count: written }) : t("app.newPlan.cardsLead")}
      </p>

      {writing ? (
        <div className="mt-6 panel flex items-center gap-4 p-5">
          <GenerationStatus
            compact
            title={t("app.generate.writing")}
            hint={t("app.generate.requested", { count })}
            startedAt={startedAt ?? undefined}
          />
        </div>
      ) : written > 0 && !asking ? (
        <>
          <ul className="mt-6 panel divide-y divide-hairline">
            {cards.map((card) => (
              <li key={card.id} className="flex items-start gap-3 px-5 py-3.5">
                <span
                  aria-hidden
                  className="mt-0.5 flex h-6 shrink-0 items-center rounded-pill bg-surface-muted px-2 text-[10.5px] font-semibold uppercase tracking-wide text-ink-tertiary"
                >
                  {t(card.kind === "cloze" ? "app.cardKind.gap" : `app.cardKind.${card.kind}`)}
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block text-[14.5px] font-medium leading-snug text-ink">
                    {card.front}
                  </span>
                  <span className="mt-0.5 block text-[13px] leading-snug text-ink-tertiary">
                    {card.back}
                  </span>
                </span>
                <button
                  type="button"
                  onClick={() => void drop(card.id)}
                  className="pressable shrink-0 text-[12.5px] font-medium text-ink-tertiary underline-draw hover:text-negative"
                >
                  {t("app.common.remove")}
                </button>
              </li>
            ))}
          </ul>

          <button
            type="button"
            onClick={() => setAsking(true)}
            className="pressable mt-3 text-[13px] font-medium text-ink-secondary underline-draw"
          >
            {t("app.newPlan.cardsMore")}
          </button>
        </>
      ) : (
        <>
          <div className="mt-6 panel divide-y divide-hairline px-5">
            {CARD_KINDS.map((format) => (
              <div key={format.kind} className="flex items-center gap-4 py-3.5">
                <span aria-hidden className="emoji text-[22px]">
                  {format.emoji}
                </span>
                <div className="min-w-0 flex-1">
                  <p className="text-[15px] font-medium text-ink">
                    {t(format.kind === "cloze" ? "app.cardKind.gap" : `app.cardKind.${format.kind}`)}
                  </p>
                  <p className="mt-0.5 text-[12.5px] text-ink-tertiary">
                    {t(
                      format.kind === "cloze"
                        ? "app.generate.kindDetail.gap"
                        : `app.generate.kindDetail.${format.kind}`,
                    )}
                  </p>
                </div>
                <CountStepper
                  size="sm"
                  value={quota[format.kind]}
                  min={PER_FORMAT_RANGE.min}
                  max={capped ? quota[format.kind] : PER_FORMAT_RANGE.max}
                  onChange={(next) => step(format.kind, next - quota[format.kind])}
                  minusLabel={t("app.generate.lessAria", {
                    kind: t(
                      format.kind === "cloze" ? "app.cardKind.gap" : `app.cardKind.${format.kind}`,
                    ),
                  })}
                  plusLabel={t("app.generate.moreAria", {
                    kind: t(
                      format.kind === "cloze" ? "app.cardKind.gap" : `app.cardKind.${format.kind}`,
                    ),
                  })}
                />
              </div>
            ))}
          </div>

          <div className="mt-3 flex flex-wrap items-center justify-between gap-3">
            <p className="numeral text-[13px] text-ink-tertiary">
              {capped
                ? t("app.generate.totalMax", { count, max: TOTAL_RANGE.max })
                : t("app.generate.total", { count })}
            </p>
            {asking ? (
              <Button variant="outline" size="sm" disabled={count === 0} onClick={() => void ask()}>
                {t("app.generate.addToDeck")}
              </Button>
            ) : null}
          </div>
        </>
      )}

      {failure ? (
        <p className="mt-4 rounded-button bg-negative-soft px-4 py-3 text-[13.5px] text-negative" role="alert">
          {failure}
        </p>
      ) : null}
    </div>
  );
}

function DayStep({
  picked,
  month,
  daysRemaining,
  onMonth,
  onSelect,
}: {
  picked: Date;
  month: Date;
  daysRemaining: number;
  onMonth: (next: Date) => void;
  onSelect: (day: Date) => void;
}) {
  const { t, locale } = useI18n();
  const today = startOfDay(new Date());

  return (
    <div>
      <p className="eyebrow text-ink-tertiary">{t("app.newPlan.dayEyebrow")}</p>
      <h1 className="page-title mt-2">{t("app.exams.whichDay")}</h1>
      <p className="mt-3 text-[16px] font-semibold capitalize text-ink">
        {picked.toLocaleDateString(localeBcp47(locale), {
          weekday: "long",
          day: "numeric",
          month: "long",
        })}
      </p>
      <p className="numeral mt-1 text-[13.5px] text-ink-secondary">
        {t("app.newPlan.daysLeft", { count: Math.max(0, daysRemaining) })}
      </p>
      <div className="mt-5">
        <ExamDayPicker
          month={month}
          selected={picked}
          minDate={today}
          onMonth={onMonth}
          onSelect={onSelect}
        />
      </div>
    </div>
  );
}

/** Une figure par type d'épreuve : la rangée en demande une, et un carré vide se remarque. */
const KIND_EMOJI: Record<ExamKind, string> = {
  exam: "📝",
  midterm: "📗",
  final: "🎓",
  quiz: "⚡",
  oral: "🗣",
  mock: "⏱",
};

const START_EMOJI: Record<StartingPoint, string> = {
  cold: "🌱",
  seen: "📖",
  solid: "💪",
};

function KindStep({ kind, onPick }: { kind: ExamKind; onPick: (next: ExamKind) => void }) {
  const { t } = useI18n();
  const options: ExamKind[] = ["exam", "midterm", "final", "quiz", "oral", "mock"];

  return (
    <div>
      <p className="eyebrow text-ink-tertiary">{t("app.newPlan.kindEyebrow")}</p>
      <h1 className="page-title mt-2">{t("app.newPlan.kindTitle")}</h1>
      <p className="page-lead">{t(`app.newPlan.kindDetail.${kind}`)}</p>
      <ul className="mt-6 flex flex-wrap gap-2">
        {options.map((option) => (
          <li key={option}>
            <Pill
              emoji={KIND_EMOJI[option]}
              label={t(`app.plan.kind.${option}`)}
              selected={kind === option}
              onSelect={() => onPick(asExamKind(option))}
            />
          </li>
        ))}
      </ul>
    </div>
  );
}

/**
 * Le point de départ : la seule question que le journal ne peut pas remplacer.
 *
 * Le produit sait ce qui a été travaillé **dans l'app**. Il ne sait rien d'un cours suivi en
 * amphi toute l'année, ni d'un chapitre découvert la veille.
 */
function StartStep({
  start,
  onPick,
}: {
  start: StartingPoint;
  onPick: (next: StartingPoint) => void;
}) {
  const { t } = useI18n();
  const options: StartingPoint[] = ["cold", "seen", "solid"];

  return (
    <div>
      <p className="eyebrow text-ink-tertiary">{t("app.newPlan.startEyebrow")}</p>
      <h1 className="page-title mt-2">{t("app.newPlan.startTitle")}</h1>
      <p className="page-lead">{t(`app.newPlan.startDetail.${start}`)}</p>
      <ul className="mt-6 flex flex-wrap gap-2">
        {options.map((option) => (
          <li key={option}>
            <Pill
              emoji={START_EMOJI[option]}
              label={t(`app.newPlan.start.${option}`)}
              selected={start === option}
              onSelect={() => onPick(option)}
            />
          </li>
        ))}
      </ul>
    </div>
  );
}

/**
 * Le nom de l'épreuve.
 *
 * Le plan s'appelait par ses cours : « Histoire · Géographie ». Ça marche tant qu'on n'a
 * qu'un plan, et ça devient illisible dès qu'on en a trois sur le même programme - un bac
 * blanc, le vrai bac, un contrôle de chapitre, tous nommés pareil. Le nom est donc
 * demandé, et la suggestion reste là pour ceux qui n'ont rien à dire de plus.
 */
function NameStep({
  name,
  suggestion,
  onChange,
}: {
  name: string;
  suggestion: string;
  onChange: (next: string) => void;
}) {
  const { t } = useI18n();

  return (
    <div>
      <p className="eyebrow text-ink-tertiary">{t("app.newPlan.nameEyebrow")}</p>
      <h1 className="page-title mt-2">{t("app.newPlan.nameTitle")}</h1>
      <p className="page-lead">{t("app.newPlan.nameLead")}</p>

      <input
        type="text"
        value={name}
        onChange={(event) => onChange(event.target.value)}
        placeholder={suggestion || t("app.newPlan.namePlaceholder")}
        maxLength={80}
        autoComplete="off"
        aria-label={t("app.newPlan.nameTitle")}
        className="mt-6 h-14 w-full rounded-group border border-stroke-strong bg-surface px-4 text-[17px] font-semibold text-ink outline-none transition-colors duration-hover placeholder:font-normal placeholder:text-ink-tertiary focus:border-ink"
      />

      {suggestion && name.trim().length === 0 ? (
        <p className="mt-3 text-[12.5px] text-ink-tertiary">
          {t("app.newPlan.nameSuggestion", { name: suggestion })}
        </p>
      ) : null}
    </div>
  );
}

/**
 * Les jours off : la seule chose que l'étudiant déclare encore sur son temps.
 *
 * On demandait avant, jour de semaine par jour de semaine, combien de minutes seraient
 * consacrées à réviser. Personne ne le sait, et le plan passait ensuite son temps à défendre
 * un budget inventé contre celui qui l'avait inventé. La charge de travail décide de la
 * journée ; ce qui reste à demander, c'est le dimanche où l'on ne sera pas là, parce que
 * celui-là ne se devine pas.
 *
 * Un jour touché prend un 💤 et sort du plan. C'est un état, pas une nuance : il n'y a pas de
 * demi-journée, parce qu'une demi-journée ne se tient pas.
 */
function PausesStep({
  today,
  daysRemaining,
  offDays,
  onToggle,
}: {
  today: Date;
  daysRemaining: number;
  offDays: string[];
  onToggle: (iso: string) => void;
}) {
  const { t, locale } = useI18n();
  const bcp = localeBcp47(locale);

  // Jusqu'à la veille de l'épreuve, et pas au-delà de quatre semaines : pointer chaque jour
  // d'un semestre n'a plus de sens, et une grille de cent cases ne se lit pas.
  const days = Array.from({ length: Math.min(28, Math.max(0, daysRemaining)) }, (_, offset) => {
    const day = new Date(today.getTime());
    day.setDate(day.getDate() + offset);
    return day;
  });

  return (
    <div>
      <p className="eyebrow text-ink-tertiary">{t("app.newPlan.timeEyebrow")}</p>
      <h1 className="page-title mt-2">{t("app.newPlan.pausesTitle")}</h1>
      <p className="page-lead">{t("app.newPlan.pausesLead")}</p>

      {days.length === 0 ? (
        <p className="mt-6 text-[13.5px] text-ink-secondary">{t("app.newPlan.pausesNone")}</p>
      ) : (
        <>
          <div className="mt-6 grid grid-cols-7 gap-1.5">
            {days.map((day) => {
              const iso = isoDay(day);
              const off = offDays.includes(iso);
              return (
                <button
                  key={iso}
                  type="button"
                  onClick={() => onToggle(iso)}
                  aria-pressed={off}
                  aria-label={day.toLocaleDateString(bcp, {
                    weekday: "long",
                    day: "numeric",
                    month: "long",
                  })}
                  className={`pressable flex h-16 flex-col items-center justify-center gap-0.5 rounded-[10px] border transition-colors duration-hover ${
                    off
                      ? "border-ink bg-ink text-on-ink"
                      : "border-hairline bg-surface text-ink hover:bg-surface-muted"
                  }`}
                >
                  <span
                    className={`text-[10px] uppercase tracking-wide ${off ? "text-on-ink-muted" : "text-ink-tertiary"}`}
                  >
                    {day.toLocaleDateString(bcp, { weekday: "short" }).replace(".", "")}
                  </span>
                  <span className="numeral text-[15px] font-semibold leading-none">
                    {day.getDate()}
                  </span>
                  <span className="flex h-4 items-center">
                    {off ? (
                      <span aria-hidden className="emoji emoji-pop text-[12px] leading-none">
                        💤
                      </span>
                    ) : null}
                  </span>
                </button>
              );
            })}
          </div>

          {/* Rien à dire quand rien n'est posé : « 0 jour de pause » occupe une ligne pour
              répéter ce que la grille montre déjà. */}
          {offDays.length > 0 ? (
            <p className="mt-3 text-[12.5px] text-ink-tertiary">
              {t("app.newPlan.pausesCount", { count: offDays.length })}
            </p>
          ) : null}
        </>
      )}
    </div>
  );
}

/**
 * La note visée, seule sur sa page.
 *
 * C'était un bloc de fin de formulaire : un curseur, un chiffre, une phrase. Or c'est la
 * seule question du parcours dont la réponse **change ce que le produit va demander** - viser
 * deux points de plus, c'est accepter un passage de plus par carte, tous les jours, jusqu'au
 * jour J. Elle mérite donc son écran, et une réponse qui se voit : le chiffre grossit d'un
 * cran à chaque cran gagné, l'anneau se remplit, et la projection en dessous se recalcule
 * pendant qu'on tient encore le curseur. C'est la seule promesse que le parcours puisse
 * tenir tout de suite.
 */
function ScoreStep({
  targetScore,
  countryCode,
  onPick,
  cardCount,
  daysRemaining,
  daily,
  peak,
  load,
  empty,
  mockQuestions,
  offCount,
}: {
  targetScore: number;
  countryCode?: string | null;
  onPick: (value: number) => void;
  cardCount: number;
  daysRemaining: number;
  daily: number;
  peak: { offset: number; count: number } | null;
  load: number[];
  empty: boolean;
  mockQuestions: number;
  offCount: number;
}) {
  const { t } = useI18n();
  const scale = desiredGradeScale(countryCode);
  const fraction =
    (targetScore - TARGET_SCORE_MIN) / Math.max(1, TARGET_SCORE_MAX - TARGET_SCORE_MIN);

  // La clé change à chaque cran : c'est ce qui relance l'animation, sans quoi React garderait
  // le même nœud et le chiffre se contenterait de changer.
  const RADIUS = 52;
  const CIRCUMFERENCE = 2 * Math.PI * RADIUS;

  return (
    <div>
      <p className="eyebrow text-ink-tertiary">{t("app.newPlan.gradeEyebrow")}</p>
      <h1 className="page-title mt-2">{t("app.exams.desiredGrade")}</h1>
      <p className="page-lead">{t("app.newPlan.gradeLead")}</p>

      <div className="mt-7 flex justify-center">
        <div className="relative flex h-[148px] w-[148px] items-center justify-center">
          <svg viewBox="0 0 120 120" className="absolute inset-0 h-full w-full -rotate-90">
            <circle
              cx="60"
              cy="60"
              r={RADIUS}
              fill="none"
              stroke="var(--color-surface-sunken)"
              strokeWidth="8"
            />
            <circle
              cx="60"
              cy="60"
              r={RADIUS}
              fill="none"
              stroke="var(--chart-work)"
              strokeWidth="8"
              strokeLinecap="round"
              strokeDasharray={CIRCUMFERENCE}
              strokeDashoffset={CIRCUMFERENCE * (1 - Math.max(0.02, fraction))}
              style={{
                transition: "stroke-dashoffset 520ms var(--ease-out-strong)",
              }}
            />
          </svg>
          <span key={targetScore} className="grade-pop numeral hero-value text-[40px]">
            {desiredGradeLabel(targetScore, countryCode)}
          </span>
        </div>
      </div>

      <div className="mt-6 flex items-center gap-3">
        <span className="numeral w-12 shrink-0 text-[12.5px] text-ink-tertiary">{scale.min}</span>
        <Slider
          className="min-w-0 flex-1"
          min={TARGET_SCORE_MIN}
          max={TARGET_SCORE_MAX}
          step={1}
          value={targetScore}
          onValueChange={(value) => onPick(clampTargetScore(Number(value)))}
          aria-label={t("app.exams.desiredGrade")}
        />
        <span className="numeral w-12 shrink-0 text-right text-[12.5px] text-ink-tertiary">
          {scale.max}
        </span>
      </div>

      {empty ? (
        <p className="mt-7 text-[13.5px] leading-relaxed text-caution">
          {t("app.exams.missingCards")}
        </p>
      ) : (
        <div className="panel mt-7 p-4">
          <p className="text-[13.5px] leading-relaxed text-ink-secondary">
            {t("app.newPlan.projection", {
              cards: cardCount,
              days: Math.max(0, daysRemaining),
              daily,
              peak: peak?.count ?? daily,
            })}
          </p>
          {mockQuestions > 0 ? (
            <p className="mt-2 text-[13px] leading-relaxed text-ink-secondary">
              {t("app.newPlan.projectionMock", { questions: mockQuestions })}
            </p>
          ) : null}
          {offCount > 0 ? (
            <p className="mt-2 text-[13px] leading-relaxed text-ink-secondary">
              {t("app.newPlan.projectionOff", { count: offCount })}
            </p>
          ) : null}
          <div className="mt-3 flex h-10 items-end gap-[2px]">
            {load.map((count, position) => {
              const max = Math.max(1, ...load);
              return (
                <span
                  key={position}
                  className="min-w-0 flex-1 rounded-t-[2px]"
                  style={{
                    height: `${Math.max(4, (count / max) * 100)}%`,
                    backgroundColor:
                      peak && position === peak.offset
                        ? "var(--chart-fragile)"
                        : "var(--chart-work)",
                    opacity: count === 0 ? 0.25 : 1,
                    transition: "height 420ms var(--ease-out-strong)",
                  }}
                />
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}

function Pill({
  emoji,
  label,
  selected,
  onSelect,
}: {
  emoji: string;
  label: string;
  selected: boolean;
  onSelect: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onSelect}
      aria-pressed={selected}
      className={`pressable flex h-9 items-center gap-1.5 rounded-full border px-3 text-[13px] font-medium transition-colors duration-hover ${
        selected
          ? "border-ink bg-ink text-on-ink"
          : "border-stroke-strong bg-surface text-ink hover:bg-surface-muted"
      }`}
    >
      <span aria-hidden className="emoji text-[13px]">
        {emoji}
      </span>
      {label}
    </button>
  );
}


function planName(courseIds: string[], courses: PlanCourse[]): string {
  const titles = courseIds
    .map((id) => courses.find((course) => course.id === id)?.title.trim())
    .filter((title): title is string => Boolean(title));
  return titles.slice(0, 2).join(" · ");
}


function addWeeks(date: Date, weeks: number): Date {
  const result = new Date(date.getTime());
  result.setDate(result.getDate() + weeks * 7);
  return result;
}

/** Des dates ISO vers des rangs de jours : la forme que `planExam` attend. */
function offsetsUntil(days: readonly string[], today: Date, window: number): number[] {
  const first = startOfDay(today);
  const offsets: number[] = [];
  for (const day of days) {
    const date = startOfDay(new Date(`${day}T12:00:00`));
    const offset = Math.round((date.getTime() - first.getTime()) / 86_400_000);
    if (offset >= 0 && offset < window) offsets.push(offset);
  }
  return offsets;
}
