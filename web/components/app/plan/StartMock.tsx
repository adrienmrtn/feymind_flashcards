"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { startMockSession } from "@/lib/actions/mocks";
import { useI18n } from "@/lib/i18n/client";

/**
 * Ouvrir un examen blanc, après **la seule question qui change la copie** : as-tu un micro ?
 *
 * Répondre oui ajoute des questions Feynman - « explique ce mécanisme comme à quelqu'un qui ne
 * l'a jamais vu » - répondues à l'oral. C'est la seule façon de vérifier qu'on sait vraiment :
 * un QCM se devine, un texte à trou se retrouve, une explication à voix haute ne se bluffe pas.
 * Taper la même explication au clavier ne mesurerait pas la même chose, parce qu'on la
 * reformule jusqu'à ce qu'elle sonne bien.
 *
 * La question est posée **avant** l'ouverture, et pas au milieu : une autorisation de micro
 * demandée pendant l'épreuve arrête le chronomètre dans la tête de l'étudiant.
 */
export function StartMock({
  examId,
  variant = "default",
  size = "sm",
  className,
}: {
  examId: string;
  variant?: "default" | "outline";
  size?: "sm" | "default";
  className?: string;
}) {
  const { t } = useI18n();
  const router = useRouter();
  const [asking, setAsking] = useState(false);
  const [pending, startTransition] = useTransition();
  const [failed, setFailed] = useState<string | null>(null);

  function open(withAudio: boolean) {
    setFailed(null);
    startTransition(async () => {
      const result = await startMockSession(examId, withAudio);
      if (result.status === "ok" && result.sessionId) {
        router.push(`/app/plan/blanc/${result.sessionId}` as never);
        return;
      }
      setAsking(false);
      setFailed(result.message ?? t("app.mock.failed"));
    });
  }

  /**
   * Demander le micro pour de vrai avant de composer la copie.
   *
   * Sans ça, on écrirait trois questions orales à quelqu'un qui a refusé l'accès, et il
   * découvrirait le problème une fois le chronomètre lancé. Le flux est relâché aussitôt :
   * ce qui compte ici est l'autorisation, pas l'enregistrement.
   */
  async function askMicrophone() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      for (const track of stream.getTracks()) track.stop();
      open(true);
    } catch (error) {
      // **Trois refus différents, trois phrases.** Ils étaient dits d'une seule voix - « le
      // micro a été refusé » - ce qui envoyait chercher une autorisation dans les réglages du
      // navigateur à quelqu'un dont l'ordinateur n'a tout simplement pas de micro, et faisait
      // passer pour un choix de l'étudiant un en-tête du site qui coupait tout.
      const name = error instanceof DOMException ? error.name : "";
      if (name === "NotFoundError" || name === "OverconstrainedError") {
        setFailed(t("app.mock.micMissing"));
      } else if (name === "NotAllowedError" || name === "SecurityError") {
        setFailed(t("app.mock.micDenied"));
      } else {
        setFailed(t("app.mock.micBroken"));
      }
      setAsking(false);
    }
  }

  if (!asking) {
    return (
      <span className={className}>
        <Button size={size} variant={variant} disabled={pending} onClick={() => setAsking(true)}>
          {pending ? t("app.exams.wait") : t("app.mock.start")}
        </Button>
        {failed ? (
          <span className="mt-2 block text-[12.5px] text-negative" role="alert">
            {failed}
          </span>
        ) : null}
      </span>
    );
  }

  return (
    <div className="panel w-full p-5">
      <p className="section-title">{t("app.mock.micTitle")}</p>
      <p className="section-lead max-w-[52ch]">{t("app.mock.micLead")}</p>

      <div className="mt-4 flex flex-wrap gap-2">
        <Button disabled={pending} onClick={() => void askMicrophone()}>
          {pending ? t("app.exams.wait") : t("app.mock.micYes")}
        </Button>
        <Button variant="outline" disabled={pending} onClick={() => open(false)}>
          {t("app.mock.micNo")}
        </Button>
        <Button variant="ghost" disabled={pending} onClick={() => setAsking(false)}>
          {t("app.common.cancel")}
        </Button>
      </div>

      <p className="mt-3 text-[12px] text-ink-tertiary">{t("app.mock.micHint")}</p>

      {failed ? (
        <p className="mt-3 text-[12.5px] text-negative" role="alert">
          {failed}
        </p>
      ) : null}
    </div>
  );
}
