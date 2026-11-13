import type { ComponentType, SVGProps } from "react";
import {
  AlarmClock,
  AlignLeft,
  Atom,
  BookOpen,
  Brain,
  Calculator,
  CalendarDays,
  Camera,
  CircleCheck,
  CircleUserRound,
  ClipboardList,
  Crown,
  Earth,
  Feather,
  FileText,
  FileType,
  Flag,
  Flame,
  FlaskConical,
  Folder,
  GalleryVerticalEnd,
  GraduationCap,
  Hand,
  Hourglass,
  House,
  Languages,
  LayoutGrid,
  Library,
  Lightbulb,
  Link,
  Lock,
  Mail,
  MapPin,
  MessageCircle,
  MessageSquareHeart,
  Mic,
  Palette,
  Puzzle,
  Rocket,
  Scroll,
  Search,
  Star,
  SunMoon,
  Trophy,
  Users,
} from "lucide-react";

import { ICON_FALLBACKS, type IconFallbackId, type MicaboIconId, resolveIconId } from "@/lib/lesson/icons";

type Glyph = ComponentType<SVGProps<SVGSVGElement> & { size?: number | string; strokeWidth?: number | string }>;

/** Les sept teintes d'icône de la direction artistique : une couleur par idée. */
type Tint = "blue" | "pink" | "green" | "yellow" | "lilac" | "orange" | "red";

/**
 * Le dessin et la teinte de chaque icône, portés de `MicaboIcon.swift` (`symbol`, `tone`,
 * `tint`) : bleu pour capter et lire, rose pour s'évaluer, vert pour mémoriser et réussir,
 * jaune pour l'idée et la récompense, lilas pour Mika et ce qui distingue, orange pour l'élan
 * et le temps, rouge pour ce qui se repère de loin. Les matières gardent le ton de leur leçon
 * (`LessonTone.forSubject`).
 */
const GLYPHS: Record<MicaboIconId, [Glyph, Tint]> = {
  etoile: [Star, "yellow"],
  plume: [Feather, "pink"],
  ampoule: [Lightbulb, "yellow"],
  "livre-ouvert": [BookOpen, "pink"],
  fiole: [FlaskConical, "green"],
  globe: [Earth, "green"],
  calculatrice: [Calculator, "blue"],
  sablier: [Hourglass, "orange"],
  puzzle: [Puzzle, "green"],
  trophee: [Trophy, "yellow"],
  drapeau: [Flag, "red"],
  cerveau: [Brain, "lilac"],
  fusee: [Rocket, "blue"],
  loupe: [Search, "blue"],
  cadenas: [Lock, "blue"],
  coche: [CircleCheck, "green"],
  palette: [Palette, "pink"],
  diplome: [GraduationCap, "yellow"],
  atome: [Atom, "lilac"],
  parchemin: [Scroll, "yellow"],
  epingle: [MapPin, "red"],
  reveil: [AlarmClock, "orange"],
  fiche: [FileText, "blue"],
  quiz: [ClipboardList, "pink"],
  cartes: [GalleryVerticalEnd, "green"],
  mika: [MessageCircle, "lilac"],
  photo: [Camera, "blue"],
  pdf: [FileType, "red"],
  lien: [Link, "blue"],
  texte: [AlignLeft, "green"],
  dossier: [Folder, "yellow"],
  examen: [CalendarDays, "pink"],
  flamme: [Flame, "orange"],
  couronne: [Crown, "lilac"],
  audio: [Mic, "green"],
  home: [House, "blue"],
  lessons: [Library, "blue"],
  profile: [CircleUserRound, "blue"],
  mail: [Mail, "blue"],
  apps: [LayoutGrid, "lilac"],
  document: [FileText, "blue"],
  language: [Languages, "lilac"],
  theme: [SunMoon, "lilac"],
  rate: [MessageSquareHeart, "yellow"],
  friends: [Users, "green"],
  privacy: [Hand, "pink"],
};

/** La couleur CSS d'une icône (`--color-icon-…`, qui suit le thème). */
export function iconTint(id: string | null | undefined): string {
  return `var(--color-icon-${GLYPHS[resolveIconId(id)][1]})`;
}

/**
 * **Une icône de Micabo : au trait, en deux tons**, comme `MicaboIconView` dans l'app V3.3.
 *
 * Le contour est plein de la teinte de l'idée, l'intérieur de la même teinte à un quart :
 * le rendu « duotone » des maquettes. Jamais d'emoji, plus d'icône 3D. Elle est décorative
 * par défaut — le texte à côté d'elle dit ce qu'elle est ; `label` la rend lisible seule.
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
  const [Icon, tint] = GLYPHS[resolved];
  return (
    <span
      role={label ? "img" : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
      data-icon={resolved}
      className={className}
      style={{
        display: "inline-flex",
        width: size,
        height: size,
        flexShrink: 0,
        alignItems: "center",
        justifyContent: "center",
        color: `var(--color-icon-${tint})`,
      }}
    >
      <Icon
        aria-hidden
        width="78%"
        height="78%"
        strokeWidth={size >= 48 ? 1.6 : 2}
        fill="currentColor"
        fillOpacity={0.22}
      />
    </span>
  );
}

/** Le nom lucide d'un repli, pour qui en a besoin hors React (les tests, une liste). */
export function fallbackIconName(id: IconFallbackId): string {
  return ICON_FALLBACKS[id];
}
