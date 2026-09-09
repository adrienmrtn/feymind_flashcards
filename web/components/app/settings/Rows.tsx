import type { ReactNode } from "react";

/**
 * **Les réglages sont des lignes, pas des cartes.**
 *
 * Chaque réglage était une carte de sa taille, posée dans une grille à deux colonnes. Deux
 * défauts, et le second est le pire. D'abord la grille laissait des trous : une carte
 * « Abonnement » de quatre lignes à côté d'une carte « Retours » de quinze en laissait onze
 * de vide. Ensuite, et surtout, **une carte annonce une chose importante** - c'est ce qu'une
 * carte fait sur toutes les autres pages de Micabo - alors qu'un réglage est une chose qu'on
 * vient changer et qu'on quitte.
 *
 * Une ligne se lit en diagonale : l'intitulé à gauche, la commande à droite, alignée avec
 * toutes les autres. On trouve « Apparence » sans lire « Langue du site », ce qui est
 * exactement ce qu'on demande à un écran de réglages.
 *
 * Les commandes larges - un mur de matières, un curseur, un champ de recherche - descendent
 * sous l'intitulé plutôt que de comprimer la colonne de droite.
 */
export function SettingsGroup({
  icon,
  title,
  hint,
  action,
  children,
}: {
  icon: string;
  title: ReactNode;
  hint?: ReactNode;
  /** Ce que le groupe a à dire de lui-même : « Enregistré », un compte, un état. */
  action?: ReactNode;
  children: ReactNode;
}) {
  return (
    <section className="overflow-hidden rounded-group border border-stroke bg-surface">
      <div className="flex items-start gap-3 px-5 py-4">
        <span
          aria-hidden
          className="emoji mt-px flex size-7 shrink-0 items-center justify-center rounded-button bg-surface-muted text-[15px]"
        >
          {icon}
        </span>
        <div className="min-w-0 flex-1">
          <h2 className="section-title">{title}</h2>
          {hint ? <p className="mt-0.5 text-[13px] text-ink-tertiary">{hint}</p> : null}
        </div>
        {action ? <div className="shrink-0">{action}</div> : null}
      </div>
      <div className="border-t border-hairline">{children}</div>
    </section>
  );
}

/**
 * Une ligne de réglage.
 *
 * `control` tient à droite de l'intitulé quand il est étroit ; `children` prend toute la
 * largeur en dessous. Les deux peuvent coexister : un curseur porte sa valeur à droite et
 * sa piste dessous.
 */
export function SettingsRow({
  label,
  hint,
  htmlFor,
  control,
  children,
  tone = "normal",
  tour,
}: {
  label: ReactNode;
  hint?: ReactNode;
  /** Rend l'intitulé cliquable quand la commande est un champ unique. */
  htmlFor?: string;
  control?: ReactNode;
  children?: ReactNode;
  tone?: "normal" | "danger";
  tour?: string;
}) {
  const Label = htmlFor ? "label" : "p";

  return (
    <div
      className="border-b border-hairline px-5 py-4 last:border-b-0"
      data-tour={tour}
    >
      <div className="flex flex-wrap items-center justify-between gap-x-6 gap-y-3">
        <div className="min-w-0 flex-1 basis-[15rem]">
          <Label
            htmlFor={htmlFor}
            className={`block text-[14px] font-medium ${
              tone === "danger" ? "text-negative" : "text-ink"
            }`}
          >
            {label}
          </Label>
          {hint ? (
            <p className="mt-1 max-w-[52ch] text-[13px] leading-relaxed text-ink-tertiary">
              {hint}
            </p>
          ) : null}
        </div>
        {control ? <div className="shrink-0">{control}</div> : null}
      </div>
      {children ? <div className="mt-3.5">{children}</div> : null}
    </div>
  );
}

/** Le champ d'une ligne : même hauteur et même fond partout, sinon la colonne se casse. */
export const ROW_FIELD =
  "h-10 rounded-button bg-surface-muted px-3 text-[14px] text-ink outline-none placeholder:text-ink-tertiary";

/** Le bouton d'une ligne, à droite. */
export const ROW_BUTTON =
  "pressable h-10 rounded-button bg-accent px-4 text-[13.5px] font-semibold text-on-ink disabled:opacity-40";

/** Le bouton discret d'une ligne : révéler, replier, refaire. */
export const ROW_GHOST =
  "pressable h-10 rounded-button bg-surface-muted px-4 text-[13.5px] font-medium text-ink disabled:opacity-40";
