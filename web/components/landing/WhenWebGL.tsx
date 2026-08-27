"use client";

import { useWebGL2 } from "@/lib/useWebGL2";

/** Monte les enfants seulement si WebGL 2 répond. Sinon le repli CSS reste seul. */
export function WhenWebGL({ children }: { children: React.ReactNode }) {
  const ok = useWebGL2();
  if (!ok) return null;
  return children;
}
