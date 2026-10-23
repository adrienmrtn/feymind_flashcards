"use client";

import type { NoteBlock } from "@micabo/core";

import { NoteBlockList } from "@/components/lesson/NoteBlocks";
import { Mika } from "@/components/mika/Mika";
import { useI18n } from "@/lib/i18n/client";

/**
 * **Mika écrit les notes** : les vrais blocs d'une leçon, un paragraphe avec son mot-clé et un
 * encadré « À retenir », et Mika qui réfléchit au-dessus. Le cycle de l'eau, comme partout.
 */
export function MikaWritesStory() {
  const { t } = useI18n();
  const blocks: NoteBlock[] = [
    { type: "paragraph", text: t("demo.sheetParagraph").replace(t("demo.evap").toLowerCase(), `**${t("demo.evap").toLowerCase()}**`) },
    { type: "definition", term: t("demo.defTerm"), text: t("demo.defText") },
    { type: "callout", kind: "remember", title: null, text: t("demo.card1Note") },
  ];
  return (
    <div className="relative w-full max-w-[340px]">
      <div className="absolute -top-9 right-2 z-10">
        <Mika mood="think" size={76} label="" />
      </div>
      <div className="paper rounded-[22px] bg-surface p-4 pt-7 text-start">
        <NoteBlockList blocks={blocks} tone="blue" />
      </div>
    </div>
  );
}
