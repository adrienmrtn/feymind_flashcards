import { CardSkeleton, HeaderSkeleton } from "@/components/app/Skeleton";

export default function Loading() {
  return (
    <>
      <HeaderSkeleton />
      <div className="grid min-w-0 items-start gap-4 lg:grid-cols-2">
        <CardSkeleton rows={4} />
        <CardSkeleton rows={3} />
        <div className="lg:col-span-2">
          <CardSkeleton rows={6} />
        </div>
        <CardSkeleton rows={3} />
        <CardSkeleton rows={3} />
      </div>
    </>
  );
}
