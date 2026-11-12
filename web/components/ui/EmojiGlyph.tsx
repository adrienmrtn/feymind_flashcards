import type { ComponentType, SVGProps } from "react";
import {
  AlarmClock,
  Backpack,
  BatteryLow,
  BookOpen,
  Brain,
  Bus,
  CircleHelp,
  Coffee,
  Compass,
  Flag,
  Flame,
  FlaskConical,
  Gem,
  Globe,
  GraduationCap,
  Hourglass,
  Landmark,
  Library,
  Lightbulb,
  Medal,
  Moon,
  NotebookPen,
  Palette,
  PencilRuler,
  School,
  Settings,
  Shield,
  Stethoscope,
  Target,
  Trophy,
  Wrench,
  Zap,
  CloudFog,
  CircleAlert,
} from "lucide-react";

type Glyph = ComponentType<SVGProps<SVGSVGElement> & { strokeWidth?: number | string }>;
type Tint = "blue" | "pink" | "green" | "yellow" | "lilac" | "orange" | "red";

/**
 * **Les emoji des réponses, redessinés en pictogrammes au trait, en deux tons** (direction
 * artistique V3.3 : « icônes plutôt qu'emoji »). Les données gardent leur emoji — l'app et
 * les tests les lisent —, l'écran dessine le pictogramme qui dit la même chose, teinté d'une
 * couleur par idée. Un emoji inconnu (un drapeau, une matière) reste tel quel.
 */
const GLYPHS: Record<string, [Glyph, Tint]> = {
  "🎒": [Backpack, "orange"],
  "🏫": [School, "blue"],
  "🔧": [Wrench, "blue"],
  "⚙️": [Settings, "lilac"],
  "⚙": [Settings, "lilac"],
  "🎓": [GraduationCap, "lilac"],
  "🩺": [Stethoscope, "pink"],
  "🔬": [FlaskConical, "green"],
  "📐": [PencilRuler, "yellow"],
  "📚": [Library, "blue"],
  "📗": [BookOpen, "green"],
  "📖": [BookOpen, "blue"],
  "🎨": [Palette, "pink"],
  "🕌": [Landmark, "green"],
  "🏁": [Flag, "red"],
  "🚩": [Flag, "red"],
  "⏳": [Hourglass, "orange"],
  "😰": [CircleAlert, "red"],
  "🤯": [Brain, "lilac"],
  "🫥": [CloudFog, "blue"],
  "🧭": [Compass, "green"],
  "🔋": [BatteryLow, "yellow"],
  "☕️": [Coffee, "orange"],
  "☕": [Coffee, "orange"],
  "🚌": [Bus, "yellow"],
  "🎯": [Target, "pink"],
  "🤷": [CircleHelp, "lilac"],
  "🌍": [Globe, "green"],
  "📝": [NotebookPen, "blue"],
  "⏰": [AlarmClock, "orange"],
  "🏆": [Trophy, "yellow"],
  "💡": [Lightbulb, "yellow"],
  "🧠": [Brain, "lilac"],
  "🔥": [Flame, "orange"],
  "💤": [Moon, "lilac"],
  "🥉": [Medal, "orange"],
  "🥈": [Medal, "blue"],
  "🥇": [Medal, "yellow"],
  "🔷": [Shield, "blue"],
  "💎": [Gem, "lilac"],
  "⚡": [Zap, "blue"],
};

export function hasGlyph(emoji: string | null | undefined): boolean {
  return Boolean(emoji && GLYPHS[emoji.trim()]);
}

/** Le pictogramme d'un emoji, ou l'emoji lui-même s'il n'en a pas (un drapeau). */
export function EmojiGlyph({
  emoji,
  size = 24,
  className = "",
}: {
  emoji: string | null | undefined;
  size?: number;
  className?: string;
}) {
  const key = (emoji ?? "").trim();
  const glyph = GLYPHS[key];
  if (!glyph) {
    return (
      <span aria-hidden className={`emoji leading-none ${className}`} style={{ fontSize: size * 0.85 }}>
        {key}
      </span>
    );
  }
  const [Icon, tint] = glyph;
  return (
    <span
      aria-hidden
      className={`inline-flex shrink-0 items-center justify-center ${className}`}
      style={{ width: size, height: size, color: `var(--color-icon-${tint})` }}
    >
      <Icon width="100%" height="100%" strokeWidth={2} fill="currentColor" fillOpacity={0.22} />
    </span>
  );
}
