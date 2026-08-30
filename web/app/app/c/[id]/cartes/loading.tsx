import { CardSkeleton, HeaderSkeleton } from "@/components/app/Skeleton";

export default function Loading() {
  return (
    <>
      <HeaderSkeleton />
      <div className="mt-8 overflow-hidden rounded-group">
        <CardSkeleton rows={6} />
      </div>
    </>
  );
}
