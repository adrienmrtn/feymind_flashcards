import { Bar, CardSkeleton, HeaderSkeleton } from "@/components/app/Skeleton";

export default function Loading() {
  return (
    <>
      <HeaderSkeleton />
      <div className="mt-8 grid gap-3 sm:grid-cols-3">
        <Bar className="h-24" />
        <Bar className="h-24" />
        <Bar className="h-24" />
      </div>
      <div className="mt-10">
        <CardSkeleton rows={4} />
      </div>
    </>
  );
}
