"use client";

import { SettingsRow, ROW_FIELD } from "@/components/app/settings/Rows";
import { useI18n } from "@/lib/i18n/client";
import { READING_SIZES, type ReadingSize } from "@/lib/sheet/reading-size";
import { useReadingSize } from "@/lib/sheet/use-reading-size";

/**
 * **L'échelle de lecture des fiches, sur cet appareil.**
 *
 * Elle vivait dans la barre d'outils de la fiche, à côté du gras et des surligneurs, et c'était
 * l'erreur : ces boutons-là marquent le texte choisi, celui-ci change la page entière. Mis
 * côte à côte, on essaie d'agrandir un mot et la fiche entière grossit. La barre garde donc la
 * taille **du passage**, et l'échelle de l'écran descend ici, avec les autres réglages
 * d'affichage - le thème, la langue - qui lui ressemblent.
 *
 * Elle reste sur l'appareil : une fiche partagée ne doit pas emporter la vue d'un lecteur.
 */

const LABEL: Record<ReadingSize, string> = {
  petit: "app.sheet.size.petit",
  normal: "app.sheet.size.normal",
  grand: "app.sheet.size.grand",
};

export function ReadingSizeRow() {
  const { t } = useI18n();
  const [size, choose] = useReadingSize();

  return (
    <SettingsRow
      label={t("app.settings.readingSize")}
      hint={t("app.settings.readingSizeHint")}
      control={
        <div
          role="group"
          aria-label={t("app.settings.readingSize")}
          className={`flex items-center gap-0.5 rounded-button bg-surface-muted p-0.5 ${ROW_FIELD}`}
        >
          {READING_SIZES.map((value, index) => (
            <button
              key={value}
              type="button"
              onClick={() => choose(value)}
              aria-pressed={value === size}
              title={t(LABEL[value])}
              aria-label={t(LABEL[value])}
              className={`pressable flex h-9 w-10 items-center justify-center rounded-[calc(var(--radius-button)-2px)] font-semibold transition-colors duration-hover ${
                value === size ? "bg-surface text-ink shadow-paper" : "text-ink-tertiary"
              }`}
              style={{ fontSize: `${12 + index * 2}px` }}
            >
              A
            </button>
          ))}
        </div>
      }
    />
  );
}
