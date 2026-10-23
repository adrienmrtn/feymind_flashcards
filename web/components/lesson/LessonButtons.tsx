import type { ComponentProps } from "react";

/**
 * Les deux boutons d'une étape : noir et plein (« C'est parti », « Continuer »), ou blanc et
 * cerné (« Retour aux leçons »). Jumeaux de `LessonPrimaryButtonStyle` et
 * `MicaboSecondaryButtonStyle`.
 */
export function LessonPrimaryButton({ className, children, ...props }: ComponentProps<"button">) {
  return (
    <button type="button" className={`lesson-btn-primary ${className ?? ""}`} {...props}>
      {children}
    </button>
  );
}

export function LessonSecondaryButton({ className, children, ...props }: ComponentProps<"button">) {
  return (
    <button type="button" className={`lesson-btn-secondary ${className ?? ""}`} {...props}>
      {children}
    </button>
  );
}
