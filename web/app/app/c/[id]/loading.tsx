"use client";

import { CourseOpeningFallback } from "@/components/app/ImportHandoff";
import { Bar, CardSkeleton, HeaderSkeleton } from "@/components/app/Skeleton";

export default function Loading() {
  return (
    <CourseOpeningFallback>
      <HeaderSkeleton />
      <div className="mt-8 space-y-3">
        <CardSkeleton rows={3} />
        <Bar className="h-32" />
        <CardSkeleton rows={2} />
      </div>
    </CourseOpeningFallback>
  );
}
