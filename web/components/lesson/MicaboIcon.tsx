import type { ComponentType } from "react";
import {
  FileText,
  Hand,
  House,
  Languages,
  LayoutGrid,
  Library,
  Mail,
  Mic,
  Star,
  SunMoon,
  UserRound,
  Users,
} from "lucide-react";

import {
  ICON_FALLBACKS,
  type IconFallbackId,
  iconSrc,
  isIcon3D,
  resolveIconId,
} from "@/lib/lesson/icons";

const FALLBACK_COMPONENTS: Record<IconFallbackId, ComponentType<{ className?: string; strokeWidth?: number }>> = {
  audio: Mic,
  home: House,
  lessons: Library,
  profile: UserRound,
  mail: Mail,
  apps: LayoutGrid,
  document: FileText,
  language: Languages,
  theme: SunMoon,
  rate: Star,
  friends: Users,
  privacy: Hand,
};

/**
 * **Une icône 3D à la taille demandée**, ou son repli au trait.
 *
 * C'est `MicaboIconView` côté Swift : l'image de la base quand elle existe, sinon une icône
 * lucide. L'image est décorative par défaut — le texte à côté d'elle dit ce qu'elle est ;
 * `label` la rend lisible quand elle est seule.
 */
export function MicaboIcon({
  id,
  size = 40,
  label,
  className,
}: {
  id: string | null | undefined;
  size?: number;
  label?: string;
  className?: string;
}) {
  const resolved = resolveIconId(id);
  if (isIcon3D(resolved)) {
    return (
      // eslint-disable-next-line @next/next/no-img-element -- une image statique, sans recadrage.
      <img
        src={iconSrc(resolved)}
        width={size}
        height={size}
        alt={label ?? ""}
        aria-hidden={label ? undefined : true}
        draggable={false}
        decoding="async"
        data-icon={resolved}
        className={className}
        style={{ width: size, height: size, objectFit: "contain" }}
      />
    );
  }
  const Fallback = FALLBACK_COMPONENTS[resolved];
  return (
    <span
      role={label ? "img" : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
      className={className}
      style={{ display: "inline-flex", width: size, height: size, alignItems: "center", justifyContent: "center" }}
    >
      <Fallback className="size-[62%] text-ink-secondary" strokeWidth={1.9} />
    </span>
  );
}

/** Le nom lucide d'un repli, pour qui en a besoin hors React (les tests, une liste). */
export function fallbackIconName(id: IconFallbackId): string {
  return ICON_FALLBACKS[id];
}
