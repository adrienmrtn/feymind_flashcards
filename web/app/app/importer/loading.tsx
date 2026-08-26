import { Bar, HeaderSkeleton } from "@/components/app/Skeleton";

export default function Loading() {
  return (
    <>
      <HeaderSkeleton />
      <Bar className="mt-8 h-[280px] rounded-sheet" />
      <div className="mt-4 grid gap-3 sm:grid-cols-2">
        <Bar className="h-32" />
        <Bar className="h-32" />
      </div>
    </>
  );
}
