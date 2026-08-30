import { CardSkeleton, HeaderSkeleton } from "@/components/app/Skeleton";

export default function Loading() {
  return (
    <div className="mx-auto max-w-[560px]">
      <HeaderSkeleton />
      <div className="mt-5 space-y-4">
        <CardSkeleton rows={6} />
        <CardSkeleton rows={2} />
        <CardSkeleton rows={3} />
      </div>
    </div>
  );
}
