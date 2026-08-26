import { CardSkeleton, HeaderSkeleton } from "@/components/app/Skeleton";

export default function Loading() {
  return (
    <>
      <HeaderSkeleton />
      <div className="mt-9 overflow-hidden rounded-group">
        <CardSkeleton rows={5} />
      </div>
    </>
  );
}
