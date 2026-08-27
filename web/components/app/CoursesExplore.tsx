"use client";

import { createContext, useContext, useEffect, useState, useTransition, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import { ThinkingOrb } from "thinking-orbs";

const ExploreNav = createContext<{
  openDiscover: () => void;
} | null>(null);

/**
 * L'étagère et Découvrir, **sans laisser l'ancienne vue figée**.
 *
 * Un `Link` vers `?vue=decouvrir` attend la bibliothèque avant de bouger : la
 * latence se lit comme un onglet mort. Ici le clic pose tout de suite l'orbe,
 * et la page serveur arrive derrière.
 */
export function CoursesExplore({
  discover,
  revise,
  children,
}: {
  discover: boolean;
  revise: ReactNode;
  children: ReactNode;
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [target, setTarget] = useState<"cours" | "decouvrir">(discover ? "decouvrir" : "cours");

  useEffect(() => {
    setTarget(discover ? "decouvrir" : "cours");
  }, [discover]);

  useEffect(() => {
    router.prefetch("/app/cours?vue=decouvrir");
  }, [router]);

  function openDiscover() {
    if (target === "decouvrir" && discover && !pending) return;
    setTarget("decouvrir");
    startTransition(() => {
      router.push("/app/cours?vue=decouvrir" as never);
    });
  }

  function openShelf() {
    if (target === "cours" && !discover && !pending) return;
    setTarget("cours");
    startTransition(() => {
      router.push("/app/cours");
    });
  }

  const showDiscoverOrb = target === "decouvrir" && (!discover || pending);

  return (
    <ExploreNav.Provider value={{ openDiscover }}>
      <header className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="eyebrow text-ink-tertiary">
            {target === "decouvrir" ? "📖 Bibliothèque" : "📚 Ton étagère"}
          </p>
          <h1 className="mt-2 text-[32px] font-bold leading-tight text-ink">Cours</h1>
        </div>
        {target !== "decouvrir" ? revise : null}
      </header>

      <nav className="mt-6 flex gap-1 rounded-button bg-surface-muted p-1">
        <TabButton current={target === "cours"} onClick={openShelf} label="Tes cours" />
        <TabButton
          current={target === "decouvrir"}
          onClick={openDiscover}
          label="Découvrir"
          pending={pending && target === "decouvrir"}
        />
      </nav>

      {showDiscoverOrb ? <DiscoverPending /> : children}
    </ExploreNav.Provider>
  );
}

export function DiscoverLink({ className, children }: { className?: string; children: ReactNode }) {
  const nav = useContext(ExploreNav);
  if (!nav) {
    return (
      <a href="/app/cours?vue=decouvrir" className={className}>
        {children}
      </a>
    );
  }

  return (
    <button type="button" onClick={nav.openDiscover} className={className}>
      {children}
    </button>
  );
}

export function DiscoverPending() {
  return (
    <div className="mt-16 flex flex-col items-center justify-center gap-4 text-center">
      <ThinkingOrb state="searching" size={64} />
      <div>
        <p className="text-[15.5px] font-semibold text-ink">On ouvre la bibliothèque…</p>
        <p className="mt-0.5 text-[13px] text-ink-tertiary">Les cours déjà fichés arrivent.</p>
      </div>
    </div>
  );
}

function TabButton({
  current,
  onClick,
  label,
  pending = false,
}: {
  current: boolean;
  onClick: () => void;
  label: string;
  pending?: boolean;
}) {
  return (
    <button
      type="button"
      aria-current={current ? "page" : undefined}
      onClick={onClick}
      className={`flex flex-1 items-center justify-center gap-2 rounded-button px-4 py-2.5 text-center text-[14px] font-semibold ${
        current ? "bg-surface text-ink shadow-sm" : "text-ink-tertiary"
      }`}
    >
      {pending ? <ThinkingOrb state="searching" size={18} /> : null}
      {label}
    </button>
  );
}
