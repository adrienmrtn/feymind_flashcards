import { Bar, HeaderSkeleton } from "@/components/app/Skeleton";

export default function Loading() {
  return (
    <>
      <HeaderSkeleton />
      <Bar className="mt-8 h-[280px]" />
      <div className="mt-4 grid grid-cols-4 gap-2">
        <Bar className="h-12" />
        <Bar className="h-12" />
        <Bar className="h-12" />
        <Bar className="h-12" />
      </div>
    </>
  );
}
