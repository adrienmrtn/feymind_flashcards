import { Bar, HeaderSkeleton } from "@/components/app/Skeleton";

export default function Loading() {
  return (
    <>
      <HeaderSkeleton />
      <div className="mt-9 space-y-3">
        <Bar className="h-32" />
        <Bar className="h-28" />
      </div>
    </>
  );
}
