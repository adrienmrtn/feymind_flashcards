import { CardSkeleton, HeaderSkeleton } from "@/components/app/Skeleton";

export default function Loading() {
  return (
    <>
      <HeaderSkeleton />
      <div className="mt-9 space-y-4">
        <CardSkeleton rows={1} />
        <CardSkeleton rows={3} />
      </div>
    </>
  );
}
