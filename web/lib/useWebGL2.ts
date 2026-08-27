"use client";

import { useEffect, useState } from "react";

/**
 * Paper Shaders exige WebGL 2. On ne monte les toiles qu'après un sondage
 * réussi : sans ça, le constructeur lève, et la page se retrouve avec une
 * promesse rejetée pour chaque shader.
 */
export function useWebGL2() {
  const [supported, setSupported] = useState(false);

  useEffect(() => {
    try {
      const canvas = document.createElement("canvas");
      const gl = canvas.getContext("webgl2", { failIfMajorPerformanceCaveat: false });
      setSupported(Boolean(gl));
    } catch {
      setSupported(false);
    }
  }, []);

  return supported;
}
