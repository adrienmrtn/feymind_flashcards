import Link from "next/link";

import { Button } from "@/components/ui/button";

export default function NotFound() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-[680px] flex-col justify-center px-6">
      <p className="text-[13px] font-medium text-ink-tertiary">404</p>
      <h1 className="mt-2 text-[26px] font-bold leading-tight text-ink">
        Cette page n&apos;existe pas.
      </h1>
      <p className="mt-3 text-[16px] leading-relaxed text-ink-secondary">
        Le lien est mort, ou la page a bougé.
      </p>
      <Button
        variant="link"
        className="mt-8 h-auto w-fit px-0 text-[15px] text-accent"
        render={<Link href="/" />}
      >
        Retour à l&apos;accueil
      </Button>
    </main>
  );
}
