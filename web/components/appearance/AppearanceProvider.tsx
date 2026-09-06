"use client";

import { createContext, useContext, useMemo, useState, type ReactNode } from "react";

import { setAppearanceCookie } from "@/lib/actions/appearance";
import { applyAppearance } from "@/lib/apply-appearance";
import type { Appearance } from "@/lib/appearance";

const AppearanceContext = createContext<{
  appearance: Appearance;
  setAppearance: (next: Appearance) => void;
} | null>(null);

export function AppearanceProvider({
  initial,
  children,
}: {
  initial: Appearance;
  children: ReactNode;
}) {
  const [appearance, setAppearanceState] = useState(initial);

  const value = useMemo(
    () => ({
      appearance,
      setAppearance(next: Appearance) {
        setAppearanceState(next);
        applyAppearance(next);
        void setAppearanceCookie(next);
      },
    }),
    [appearance],
  );

  return <AppearanceContext.Provider value={value}>{children}</AppearanceContext.Provider>;
}

export function useAppearance() {
  const context = useContext(AppearanceContext);
  if (!context) {
    throw new Error("useAppearance attend AppearanceProvider");
  }
  return context;
}
