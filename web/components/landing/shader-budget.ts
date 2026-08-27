/**
 * Plafond commun des toiles Paper Shaders.
 *
 * Sans ça, chaque canvas prend le ratio de l'écran et un budget Full HD × 4 — trop
 * pour une page d'accueil, surtout sur téléphone. Un pixel par pixel CSS, et au plus
 * une 720p, suffit : la fibre et le grain ne gagnent rien à être plus nets.
 */
export const SHADER_BUDGET = {
  minPixelRatio: 1,
  maxPixelCount: 1280 * 720,
  webGlContextAttributes: { failIfMajorPerformanceCaveat: false },
} as const;
