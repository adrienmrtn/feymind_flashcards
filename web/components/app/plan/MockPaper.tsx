"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";

import { MOCK_GAP, type MockAnswer, type MockQuestion } from "@micabo/core";

import { Button } from "@/components/ui/button";
import { finishMockSession } from "@/lib/actions/mocks";
import { useI18n } from "@/lib/i18n/client";
import { requestPaywall } from "@/lib/paywall";

/**
 * **La copie.** Toutes les questions posées d'un coup, aucune réponse avant la remise.
 *
 * L'écran d'avant servait une carte à la fois, la retournait, et demandait à l'étudiant de se
 * déclarer juste ou faux. Il mesurait donc la confiance en soi, pas le savoir - et toujours
 * dans le sens qui rassure. Ici on coche, on écrit, on dicte ; personne ne se note.
 *
 * La feuille se lit en entier dès la première seconde. C'est délibéré : gérer son temps sur
 * une épreuve est une compétence, et elle ne se travaille pas si le produit décide de l'ordre
 * et cache ce qui reste. On saute une question, on y revient, on voit ce qui est encore blanc.
 *
 * Le chronomètre est affiché mais ne ferme rien de force jusqu'à zéro, où il remet la copie
 * telle quelle - comme un surveillant qui ramasse.
 *
 * **La remise est la porte du gratuit.** Passer la copie ne coûte rien ; la correction, si.
 * Pour qui n'est pas abonné, « Remettre la copie » ouvre donc le paywall et la copie reste
 * ouverte derrière - rien n'est envoyé, rien n'est perdu, et l'offre arrive au moment précis
 * où ce qu'elle vend vient d'être gagné. Le serveur refuse de son côté : voir
 * `finishMockSession`.
 */
export function MockPaper({
  sessionId,
  examName,
  minutes,
  questions,
  withAudio,
  isPro,
}: {
  sessionId: string;
  examName: string;
  minutes: number;
  questions: MockQuestion[];
  withAudio: boolean;
  isPro: boolean;
}) {
  const { t } = useI18n();
  const router = useRouter();

  const [answers, setAnswers] = useState<Record<string, MockAnswer>>({});
  const [saving, setSaving] = useState(false);
  const [failed, setFailed] = useState(false);
  const [confirming, setConfirming] = useState(false);
  const [remaining, setRemaining] = useState(minutes * 60);
  const deadline = useRef(Date.now() + minutes * 60_000);

  const answered = useMemo(
    () => questions.filter((question) => isAnswered(answers[question.id])).length,
    [answers, questions],
  );

  const hand = useCallback(async () => {
    // Le gratuit s'arrête ici : la copie reste à l'écran, l'offre passe devant.
    if (!isPro) {
      setConfirming(false);
      requestPaywall();
      return;
    }

    setSaving(true);
    setFailed(false);
    const result = await finishMockSession(
      sessionId,
      questions.map((question) => answers[question.id] ?? { id: question.id }),
    );
    if (result.status === "paywall") {
      setSaving(false);
      setConfirming(false);
      requestPaywall();
      return;
    }
    if (result.status === "error") {
      setSaving(false);
      setFailed(true);
      return;
    }
    router.refresh();
  }, [answers, isPro, questions, router, sessionId]);

  useEffect(() => {
    const timer = setInterval(() => {
      const left = Math.max(0, Math.round((deadline.current - Date.now()) / 1000));
      setRemaining(left);
      if (left === 0) {
        clearInterval(timer);
        void hand();
      }
    }, 1000);
    return () => clearInterval(timer);
  }, [hand]);

  function set(id: string, patch: Partial<MockAnswer>) {
    setAnswers((current) => ({ ...current, [id]: { ...current[id], id, ...patch } }));
  }

  return (
    <div className="mx-auto w-full max-w-[720px] pb-24">
      <header className="sticky top-14 z-20 -mx-4 border-b border-border bg-background/95 px-4 py-3 backdrop-blur-md lg:top-0 lg:mx-0 lg:rounded-b-group lg:px-5">
        <div className="flex items-center justify-between gap-4">
          <span className="min-w-0">
            <span className="block truncate text-[14px] font-semibold text-ink">{examName}</span>
            <span className="numeral block text-[12px] text-ink-tertiary">
              {t("app.mock.answered", { done: answered, total: questions.length })}
            </span>
          </span>
          <span
            className={`numeral shrink-0 rounded-full px-2.5 py-1 text-[13px] font-semibold ${
              remaining <= 60 ? "bg-negative-soft text-negative" : "bg-surface-muted text-ink"
            }`}
            role="timer"
            aria-live="off"
          >
            {clock(remaining)}
          </span>
        </div>
        <span
          aria-hidden
          className="mt-2 block h-1 overflow-hidden rounded-pill bg-surface-sunken"
        >
          <span
            className="block h-full rounded-pill transition-all duration-menu"
            style={{
              width: `${(answered / Math.max(1, questions.length)) * 100}%`,
              backgroundColor: "var(--chart-work)",
            }}
          />
        </span>
      </header>

      <p className="mt-5 text-[13px] leading-relaxed text-ink-secondary">
        {withAudio
          ? t("app.mock.paperLeadAudio", { count: questions.length })
          : t("app.mock.paperLead", { count: questions.length })}
      </p>

      <ol className="mt-5 space-y-3">
        {questions.map((question, index) => (
          <li key={question.id}>
            <QuestionCard
              question={question}
              position={index + 1}
              answer={answers[question.id]}
              onAnswer={(patch) => set(question.id, patch)}
            />
          </li>
        ))}
      </ol>

      <div className="mt-8">
        {confirming ? (
          <div className="panel p-5">
            <p className="section-title">{t("app.mock.handTitle")}</p>
            <p className="section-lead">
              {answered < questions.length
                ? t("app.mock.handBlank", { count: questions.length - answered })
                : t("app.mock.handAll")}
            </p>
            <div className="mt-4 flex flex-wrap gap-2">
              <Button disabled={saving} onClick={() => void hand()}>
                {saving ? t("app.mock.grading") : t("app.mock.handConfirm")}
              </Button>
              <Button variant="ghost" disabled={saving} onClick={() => setConfirming(false)}>
                {t("app.mock.handBack")}
              </Button>
            </div>
          </div>
        ) : (
          <Button className="h-12 w-full text-[15px]" onClick={() => setConfirming(true)}>
            {t("app.mock.hand")}
          </Button>
        )}

        {failed ? (
          <p className="mt-3 text-center text-[13px] text-negative" role="alert">
            {t("app.mock.failed")}
          </p>
        ) : null}
      </div>
    </div>
  );
}

function isAnswered(answer: MockAnswer | undefined): boolean {
  if (!answer) return false;
  if (answer.choiceIndex != null) return true;
  if (answer.truth != null) return true;
  return (answer.text ?? "").trim().length > 0;
}

function QuestionCard({
  question,
  position,
  answer,
  onAnswer,
}: {
  question: MockQuestion;
  position: number;
  answer: MockAnswer | undefined;
  onAnswer: (patch: Partial<MockAnswer>) => void;
}) {
  const { t } = useI18n();

  return (
    <section className="panel p-5">
      <div className="flex items-baseline gap-3">
        <span className="numeral w-5 shrink-0 text-[12.5px] font-semibold text-ink-tertiary">
          {position}
        </span>
        <p className="min-w-0 flex-1 text-[15px] leading-snug text-ink">
          {question.kind === "gap" ? <GapPrompt prompt={question.prompt} /> : question.prompt}
        </p>
      </div>

      <div className="mt-4 pl-8">
        {question.kind === "choice" ? (
          <ul className="space-y-1.5">
            {question.choices.map((choice, index) => (
              <li key={index}>
                <label
                  className={`flex cursor-pointer items-start gap-3 rounded-button border px-4 py-2.5 text-[14px] transition-colors duration-hover ${
                    answer?.choiceIndex === index
                      ? "border-ink bg-surface-muted text-ink"
                      : "border-border text-ink-secondary hover:bg-surface-muted/60"
                  }`}
                >
                  <input
                    type="radio"
                    name={question.id}
                    className="mt-1 accent-[var(--color-ink)]"
                    checked={answer?.choiceIndex === index}
                    onChange={() => onAnswer({ choiceIndex: index })}
                  />
                  <span className="min-w-0">{choice}</span>
                </label>
              </li>
            ))}
          </ul>
        ) : null}

        {question.kind === "truefalse" ? (
          <div className="flex gap-2">
            {[true, false].map((value) => (
              <button
                key={String(value)}
                type="button"
                aria-pressed={answer?.truth === value}
                onClick={() => onAnswer({ truth: value })}
                className={`pressable rounded-button border px-5 py-2 text-[14px] font-medium transition-colors duration-hover ${
                  answer?.truth === value
                    ? "border-ink bg-ink text-on-ink"
                    : "border-border text-ink-secondary hover:bg-surface-muted/60"
                }`}
              >
                {value ? t("app.mock.true") : t("app.mock.false")}
              </button>
            ))}
          </div>
        ) : null}

        {question.kind === "gap" ? (
          <input
            type="text"
            value={answer?.text ?? ""}
            onChange={(event) => onAnswer({ text: event.target.value })}
            placeholder={t("app.mock.gapPlaceholder")}
            className="w-full max-w-[24rem] rounded-button border border-input bg-surface px-3.5 py-2.5 text-[14px] text-ink outline-none focus-visible:border-ink"
          />
        ) : null}

        {question.kind === "feynman" ? (
          <Dictation
            value={answer?.text ?? ""}
            onChange={(text) => onAnswer({ text })}
          />
        ) : null}
      </div>
    </section>
  );
}

/** Le trou se voit : sans marque, on lit la phrase sans comprendre ce qu'on doit écrire. */
function GapPrompt({ prompt }: { prompt: string }) {
  const parts = prompt.split(MOCK_GAP);
  return (
    <>
      {parts.map((part, index) => (
        <span key={index}>
          {part}
          {index < parts.length - 1 ? (
            <span
              aria-hidden
              className="mx-1 inline-block w-16 translate-y-[1px] border-b-2 border-ink/40"
            />
          ) : null}
        </span>
      ))}
    </>
  );
}

/**
 * Dicter une explication.
 *
 * La reconnaissance vocale du navigateur transcrit en direct, et le texte reste **modifiable**
 * : une transcription qui écorche un terme technique ferait perdre des points sur un mot que
 * l'étudiant a dit juste. Là où le navigateur ne sait pas transcrire, on écrit - la question
 * garde son sens, elle perd seulement son avantage.
 */
function Dictation({ value, onChange }: { value: string; onChange: (text: string) => void }) {
  const { t } = useI18n();
  const [listening, setListening] = useState(false);
  const [supported, setSupported] = useState(true);
  const recognition = useRef<SpeechRecognitionLike | null>(null);
  const committed = useRef("");

  useEffect(() => {
    const Recognition =
      (window as unknown as { SpeechRecognition?: SpeechRecognitionConstructor })
        .SpeechRecognition ??
      (window as unknown as { webkitSpeechRecognition?: SpeechRecognitionConstructor })
        .webkitSpeechRecognition;
    if (!Recognition) {
      setSupported(false);
      return;
    }
    const instance = new Recognition();
    instance.continuous = true;
    instance.interimResults = true;
    instance.lang = document.documentElement.lang || "fr-FR";
    recognition.current = instance;
    return () => {
      instance.onresult = null;
      instance.onend = null;
      try {
        instance.stop();
      } catch {
        // Une reconnaissance déjà arrêtée jette : il n'y a rien à réparer.
      }
    };
  }, []);

  function toggle() {
    const instance = recognition.current;
    if (!instance) return;

    if (listening) {
      instance.stop();
      setListening(false);
      return;
    }

    committed.current = value.trim();
    instance.onresult = (event: SpeechRecognitionEventLike) => {
      let interim = "";
      let settled = "";
      for (let index = event.resultIndex; index < event.results.length; index += 1) {
        const result = event.results[index];
        const text = result?.[0]?.transcript ?? "";
        if (result?.isFinal) settled += text;
        else interim += text;
      }
      if (settled) committed.current = `${committed.current} ${settled}`.trim();
      onChange(`${committed.current} ${interim}`.trim());
    };
    instance.onend = () => setListening(false);

    try {
      instance.start();
      setListening(true);
    } catch {
      setListening(false);
    }
  }

  return (
    <div>
      <textarea
        value={value}
        onChange={(event) => onChange(event.target.value)}
        rows={4}
        placeholder={supported ? t("app.mock.spokenPlaceholder") : t("app.mock.typedPlaceholder")}
        className="w-full rounded-button border border-input bg-surface px-3.5 py-2.5 text-[14px] leading-relaxed text-ink outline-none focus-visible:border-ink"
      />
      <div className="mt-2 flex flex-wrap items-center gap-3">
        {supported ? (
          <button
            type="button"
            onClick={toggle}
            aria-pressed={listening}
            className={`pressable inline-flex items-center gap-2 rounded-full px-3.5 py-1.5 text-[13px] font-medium transition-colors duration-hover ${
              listening ? "bg-negative-soft text-negative" : "bg-surface-muted text-ink"
            }`}
          >
            <span
              aria-hidden
              className={`size-2 rounded-full ${listening ? "bg-negative" : "bg-ink-tertiary"}`}
            />
            {listening ? t("app.mock.dictateStop") : t("app.mock.dictate")}
          </button>
        ) : null}
        <span className="text-[12px] text-ink-tertiary">
          {supported ? t("app.mock.dictateHint") : t("app.mock.dictateUnsupported")}
        </span>
      </div>
    </div>
  );
}

interface SpeechRecognitionResultLike {
  isFinal: boolean;
  [index: number]: { transcript: string } | undefined;
}

interface SpeechRecognitionEventLike {
  resultIndex: number;
  results: { length: number; [index: number]: SpeechRecognitionResultLike | undefined };
}

interface SpeechRecognitionLike {
  continuous: boolean;
  interimResults: boolean;
  lang: string;
  onresult: ((event: SpeechRecognitionEventLike) => void) | null;
  onend: (() => void) | null;
  start(): void;
  stop(): void;
}

type SpeechRecognitionConstructor = new () => SpeechRecognitionLike;

function clock(seconds: number): string {
  const minutes = Math.floor(seconds / 60);
  const rest = seconds % 60;
  return `${minutes}:${`${rest}`.padStart(2, "0")}`;
}
