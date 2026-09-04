"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";

import { adoptSharedCourse } from "@/lib/actions/social";
import { useI18n } from "@/lib/i18n/client";

export function AdoptCourse({
  courseId,
  alreadyId,
}: {
  courseId: string;
  alreadyId: string | null;
}) {
  const { t } = useI18n();
  const router = useRouter();
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);

  if (alreadyId) {
    return (
      <button
        type="button"
        onClick={() => router.push(`/app/c/${alreadyId}` as never)}
        className="pressable h-14 w-full rounded-button bg-accent text-[16px] font-semibold text-on-ink"
      >
        {t("app.shared.alreadyYours")}
      </button>
    );
  }

  return (
    <div>
      <button
        type="button"
        disabled={pending}
        onClick={() =>
          start(async () => {
            const result = await adoptSharedCourse(courseId);
            if (result.status === "ok" && result.courseId) {
              router.push(`/app/c/${result.courseId}` as never);
              return;
            }
            setError(result.message ?? t("app.shared.adoptError"));
          })
        }
        className="pressable h-14 w-full rounded-button bg-accent text-[16px] font-semibold text-on-ink"
      >
        {pending ? t("app.shared.adding") : t("app.shared.addCourseAndCards")}
      </button>
      {error ? (
        <p className="mt-2 text-center text-[13px] text-negative" role="alert">
          {error}
        </p>
      ) : null}
    </div>
  );
}
