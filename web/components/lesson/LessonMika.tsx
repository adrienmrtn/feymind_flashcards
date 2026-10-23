"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { ArrowUp, Check, Plus, SquarePen, X } from "lucide-react";

import { dayStamp, mikaGate, mikaTurns, MIKA_LIMITS, type LessonTone, type MikaTurn } from "@micabo/core";

import { KeywordText } from "@/components/lesson/KeywordText";
import { MicaboIcon } from "@/components/lesson/MicaboIcon";
import { Mika } from "@/components/mika/Mika";
import { addMikaCard, askMika } from "@/lib/actions/lesson";
import { useI18n } from "@/lib/i18n/client";
import { lessonPath } from "@/lib/lesson/routes";
import { requestPaywall } from "@/lib/paywall";

/**
 * **Mika, dans la leçon** : une conversation où la leçon est jointe d'office. Une conversation
 * par leçon, gardée dans le navigateur, comme l'app la garde sur l'appareil. Jumeau de
 * `LessonMikaView` et `MikaChat`.
 *
 * La porte est celle de Mika (`mikaGate`) : une question offerte, puis Pro ; un plafond par
 * jour pour un abonné. La question offerte ne se consomme qu'une fois la réponse arrivée.
 * Quand Mika propose une carte, « Ajouter » la range dans la leçon.
 */
interface MikaMessage {
  id: string;
  role: "user" | "mika";
  text: string;
  card?: { front: string; back: string };
  cardAdded?: boolean;
}

const KEYS = {
  freeUsed: "micabo.mika.freeQuestionUsed",
  day: "micabo.mika.day",
  dayCount: "micabo.mika.dayCount",
} as const;

function read(key: string): string | null {
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

function write(key: string, value: string): void {
  try {
    window.localStorage.setItem(key, value);
  } catch {
    // Le navigateur refuse d'écrire : la conversation vit le temps de la page.
  }
}

function conversationKey(lessonId: string): string {
  return `micabo.mika.lesson.${lessonId}`;
}

function loadConversation(lessonId: string): MikaMessage[] {
  try {
    const raw = read(conversationKey(lessonId));
    const parsed = raw ? (JSON.parse(raw) as unknown) : null;
    return Array.isArray(parsed) ? (parsed as MikaMessage[]).filter((message) => message && typeof message.text === "string") : [];
  } catch {
    return [];
  }
}

function askedToday(): number {
  return read(KEYS.day) === dayStamp() ? Number(read(KEYS.dayCount) ?? 0) || 0 : 0;
}

/** Une réponse est arrivée : la question offerte est passée, et le jour en compte une de plus. */
function noteAnswered(): void {
  write(KEYS.freeUsed, "1");
  const count = askedToday();
  write(KEYS.day, dayStamp());
  write(KEYS.dayCount, String(count + 1));
}

export function LessonMika({ lessonId, title, tone, isPro }: { lessonId: string; title: string; tone: LessonTone; isPro: boolean }) {
  const { t } = useI18n();
  const [messages, setMessages] = useState<MikaMessage[]>([]);
  const [draft, setDraft] = useState("");
  const [thinking, setThinking] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const [capReached, setCapReached] = useState(false);
  const [loaded, setLoaded] = useState(false);
  const bottom = useRef<HTMLDivElement>(null);
  const input = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    setMessages(loadConversation(lessonId));
    setLoaded(true);
  }, [lessonId]);

  useEffect(() => {
    if (loaded) write(conversationKey(lessonId), JSON.stringify(messages));
  }, [lessonId, loaded, messages]);

  useEffect(() => {
    bottom.current?.scrollIntoView({ block: "end", behavior: "smooth" });
  }, [messages.length, thinking]);

  const canRetry = failure !== null && messages[messages.length - 1]?.role === "user" && !thinking;

  async function ask(thread: MikaMessage[]) {
    setThinking(true);
    setFailure(null);
    const turns: MikaTurn[] = mikaTurns(thread.map((message) => ({ role: message.role, text: message.text })));
    const result = await askMika(lessonId, turns);
    setThinking(false);
    if (result.status !== "ok" || !result.reply) {
      if (result.code === "daily_limit") setCapReached(true);
      setFailure(result.message ?? t("app.common.errorGeneric"));
      return;
    }
    noteAnswered();
    setMessages((current) => [...current, { id: crypto.randomUUID(), role: "mika", text: result.reply!, ...(result.card ? { card: result.card } : {}) }]);
  }

  function send(text = draft) {
    const clean = text.trim().slice(0, MIKA_LIMITS.messageCharacters);
    if (!clean || thinking) return;
    const gate = mikaGate({ isPro, freeQuestionUsed: read(KEYS.freeUsed) === "1", askedToday: askedToday() });
    if (gate === "paywall") {
      input.current?.blur();
      requestPaywall("mika");
      return;
    }
    if (gate === "dailyCapReached") {
      setCapReached(true);
      return;
    }
    setDraft("");
    setCapReached(false);
    const thread = [...messages, { id: crypto.randomUUID(), role: "user" as const, text: clean }];
    setMessages(thread);
    void ask(thread);
  }

  function retry() {
    if (!canRetry) return;
    void ask(messages);
  }

  function reset() {
    setMessages([]);
    setDraft("");
    setFailure(null);
    setCapReached(false);
  }

  async function addCard(message: MikaMessage) {
    if (!message.card || message.cardAdded) return;
    const result = await addMikaCard(lessonId, message.card.front, message.card.back);
    if (result.status === "ok") setMessages((current) => current.map((entry) => (entry.id === message.id ? { ...entry, cardAdded: true } : entry)));
    else setFailure(result.message ?? t("app.common.errorGeneric"));
  }

  const suggestions = [t("lesson.mika.suggestExplain"), t("lesson.mika.suggestExample"), t("lesson.mika.suggestQuiz")];

  return (
    <div className="mx-auto flex min-h-[calc(100svh-6rem)] w-full max-w-[640px] flex-col">
      <header className="flex items-center gap-3 py-2.5">
        <MicaboIcon id="mika" size={36} />
        <div className="flex min-w-0 flex-1 flex-col">
          <p className="text-[18px] font-extrabold leading-tight text-ink">Mika</p>
          <p className="truncate text-[13px] font-medium text-ink-secondary">{title}</p>
        </div>
        {messages.length > 0 ? (
          <button type="button" onClick={reset} aria-label={t("lesson.mika.new")} className="pressable flex size-9 items-center justify-center rounded-full text-ink-secondary hover:bg-surface-muted">
            <SquarePen aria-hidden="true" className="size-[18px]" strokeWidth={2.2} />
          </button>
        ) : null}
        <Link href={lessonPath(lessonId)} aria-label={t("lesson.circle.close")} className="pressable flex size-9 items-center justify-center rounded-full text-ink-secondary hover:bg-surface-muted">
          <X aria-hidden="true" className="size-5" strokeWidth={2.6} />
        </Link>
      </header>

      <div className="flex flex-1 flex-col gap-3.5 py-4">
        {loaded && messages.length === 0 ? (
          <div className="flex flex-col items-center gap-3.5 pt-3 text-center">
            <Mika mood="wave" size={130} label="" />
            <p className="max-w-[420px] text-[20px] font-bold leading-snug text-ink">{t("lesson.mika.welcome", { lesson: title })}</p>
            <div className="flex w-full max-w-[420px] flex-col gap-2">
              {suggestions.map((suggestion) => (
                <button key={suggestion} type="button" onClick={() => send(suggestion)} className="pressable rounded-pill bg-surface px-4 py-[11px] text-[15px] font-bold text-ink shadow-[inset_0_0_0_1.5px_var(--color-stroke)]">
                  {suggestion}
                </button>
              ))}
            </div>
          </div>
        ) : null}

        {messages.map((message) => {
          const mine = message.role === "user";
          return (
            <div key={message.id} className={`flex flex-col gap-2 ${mine ? "items-end pl-10" : "items-start pr-10"}`}>
              <div className={`whitespace-pre-wrap rounded-[18px] px-3.5 py-[11px] text-[16px] font-medium leading-snug ${mine ? "bg-ink text-on-ink" : "bg-surface text-ink shadow-[inset_0_0_0_1px_var(--color-hairline)]"}`}>
                <KeywordText text={message.text} tints={!mine} />
              </div>
              {message.card ? (
                <div className="flex w-full max-w-[420px] flex-col gap-2 rounded-[16px] p-3.5" style={{ background: `var(--color-tone-${tone}-pale)` }}>
                  <p className="text-[15px] font-extrabold text-ink">
                    <KeywordText text={message.card.front} />
                  </p>
                  <p className="text-[14px] font-medium text-ink-secondary">
                    <KeywordText text={message.card.back} />
                  </p>
                  <button
                    type="button"
                    disabled={message.cardAdded}
                    onClick={() => void addCard(message)}
                    className="pressable flex items-center gap-1.5 self-start text-[14px] font-extrabold"
                    style={{ color: message.cardAdded ? "var(--color-correct-ink)" : `var(--color-tone-${tone}-ink)` }}
                  >
                    {message.cardAdded ? <Check aria-hidden="true" className="size-4" strokeWidth={3} /> : <Plus aria-hidden="true" className="size-4" strokeWidth={3} />}
                    {message.cardAdded ? t("lesson.mika.cardAdded") : t("lesson.mika.addCard")}
                  </button>
                </div>
              ) : null}
            </div>
          );
        })}

        {thinking ? (
          <div className="flex">
            <Mika mood="think" size={72} label="" />
          </div>
        ) : null}

        {failure || capReached ? (
          <div className="flex items-center gap-2.5" role="alert">
            <p className="flex-1 text-[14px] font-medium text-wrong-ink">{capReached ? t("lesson.mika.capReached") : failure}</p>
            {canRetry && !capReached ? (
              <button type="button" onClick={retry} className="pressable text-[14px] font-extrabold text-ink">
                {t("lesson.path.retry")}
              </button>
            ) : null}
          </div>
        ) : null}
        <div ref={bottom} />
      </div>

      <form
        className="lesson-bottom-bar -mx-4 flex items-end gap-2.5 bg-canvas px-4 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-2.5 lg:-mx-10 lg:px-10"
        onSubmit={(event) => {
          event.preventDefault();
          send();
        }}
      >
        <textarea
          ref={input}
          value={draft}
          onChange={(event) => setDraft(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === "Enter" && !event.shiftKey) {
              event.preventDefault();
              send();
            }
          }}
          rows={1}
          maxLength={MIKA_LIMITS.messageCharacters}
          placeholder={t("lesson.mika.placeholder")}
          aria-label={t("lesson.mika.placeholder")}
          className="max-h-40 min-h-[46px] flex-1 resize-none rounded-[22px] bg-surface px-4 py-3 text-[16px] font-medium text-ink shadow-[inset_0_0_0_1px_var(--color-hairline)] outline-none placeholder:text-ink-tertiary focus-visible:shadow-[inset_0_0_0_2px_var(--color-accent)]"
        />
        <button
          type="submit"
          disabled={!draft.trim() || thinking}
          aria-label={t("lesson.mika.send")}
          className={`pressable flex size-11 shrink-0 items-center justify-center rounded-full text-on-ink ${draft.trim() && !thinking ? "bg-ink" : "bg-ink-tertiary"}`}
        >
          <ArrowUp aria-hidden="true" className="size-5" strokeWidth={2.8} />
        </button>
      </form>
    </div>
  );
}
