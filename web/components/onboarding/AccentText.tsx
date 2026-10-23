import { Fragment } from "react";

/**
 * Un titre dont les mots entre `**` prennent l'accent - le format d'`OnboardingAccentText` sur
 * l'iPhone, et donc celui des phrases qu'on lui reprend (« Voici ce qui va **changer pour
 * toi** »). Les astérisques ne s'affichent jamais, même mal appariés.
 */
export function AccentText({ text }: { text: string }) {
  const parts = text.split("**");
  return (
    <>
      {parts.map((part, index) =>
        index % 2 === 1 && index < parts.length - 1 ? (
          <span key={index} className="home-gradient-text">
            {part}
          </span>
        ) : (
          <Fragment key={index}>{part}</Fragment>
        ),
      )}
    </>
  );
}
