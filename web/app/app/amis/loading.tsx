import { CardSkeleton, HeaderSkeleton } from "@/components/app/Skeleton";

export default function Loading() {
  return (
    <>
      <HeaderSkeleton />
      <div className="mt-9 space-y-4">
        <CardSkeleton rows={2} />
        <CardSkeleton rows={4} />
      </div>
    </>
  );
}
