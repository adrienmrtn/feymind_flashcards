import { Bar, CardSkeleton, HeaderSkeleton } from "@/components/app/Skeleton";

export default function Loading() {
  return (
    <>
      <HeaderSkeleton />
      <div className="mt-8 grid grid-cols-3 gap-3">
        <Bar className="h-20" />
        <Bar className="h-20" />
        <Bar className="h-20" />
      </div>
      <div className="mt-8 space-y-3">
        <CardSkeleton rows={2} />
        <CardSkeleton rows={2} />
      </div>
    </>
  );
}
