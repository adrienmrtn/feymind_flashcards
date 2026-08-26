import { CardSkeleton, HeaderSkeleton } from "@/components/app/Skeleton";

export default function Loading() {
  return (
    <>
      <HeaderSkeleton />
      <div className="mt-8 grid gap-4 lg:grid-cols-2">
        <CardSkeleton rows={3} />
        <CardSkeleton rows={3} />
      </div>
      <div className="mt-8">
        <CardSkeleton rows={4} />
      </div>
    </>
  );
}
