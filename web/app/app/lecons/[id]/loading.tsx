import { Bar } from "@/components/app/Skeleton";

/** Le squelette d'une leçon qui s'ouvre : l'illustration, le titre, la barre, trois ronds. */
export default function Loading() {
  return (
    <div className="flex flex-col items-center gap-5 pt-10">
      <Bar className="size-[88px] rounded-full" />
      <Bar className="h-8 w-[60%]" />
      <Bar className="h-3.5 w-[70%] max-w-[420px] rounded-pill" />
      <div className="mt-10 flex w-full max-w-[520px] flex-col gap-16">
        <Bar className="size-[84px] self-end rounded-full" />
        <Bar className="size-[84px] self-center rounded-full" />
        <Bar className="size-[84px] self-start rounded-full" />
      </div>
    </div>
  );
}
