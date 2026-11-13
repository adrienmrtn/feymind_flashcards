"use client";

import { useI18n } from "@/lib/i18n/client";

import { Reveal } from "./Reveal";
import { SectionHeading } from "./SectionHeading";

/**
 * **L'app iPhone telle qu'elle est** : quatre captures réelles, pas des maquettes.
 *
 * Les images sont des rendus de l'app (`renders/run-347`, iPhone 15 Pro, thème marine),
 * recadrées sous la barre d'accueil et converties en WebP (`public/app-screens/`) : la Home,
 * le chemin d'une leçon, le chat avec Mika sur la photo d'une feuille, et la séance de
 * concentration liée à une leçon. Aucun écran n'est inventé ; les captures sont en français,
 * la langue des rendus.
 *
 * Sur un téléphone, la rangée défile de côté (un écran et le bord du suivant) ; sur un grand
 * écran, les quatre tiennent côte à côte.
 */
const SCREENS = [
  { src: "/app-screens/home.webp", caption: "landing.screenHome" },
  { src: "/app-screens/lecon.webp", caption: "landing.screenLesson" },
  { src: "/app-screens/chat.webp", caption: "landing.screenChat" },
  { src: "/app-screens/focus.webp", caption: "landing.screenFocus" },
] as const;

export function AppScreens({ id }: { id?: string }) {
  const { t } = useI18n();
  return (
    <section id={id} className="mx-auto mt-28 max-w-page scroll-mt-20 sm:mt-36">
      <div className="px-screen">
        <SectionHeading eyebrow="landing.screensEyebrow" title="landing.screensTitle" note="landing.screensNote" />
      </div>
      <Reveal delay={2}>
        <ul className="mt-12 flex snap-x snap-mandatory gap-4 overflow-x-auto px-screen pb-4 [scrollbar-width:none] md:grid md:grid-cols-4 md:gap-5 md:overflow-visible">
          {SCREENS.map((screen) => (
            <li key={screen.src} className="w-[68%] shrink-0 snap-center sm:w-[44%] md:w-auto">
              <figure className="flex flex-col gap-3">
                <div className="overflow-hidden rounded-[30px] border-[1.5px] border-stroke bg-canvas">
                  {/* eslint-disable-next-line @next/next/no-img-element -- une capture fixe, déjà au bon format. */}
                  <img
                    src={screen.src}
                    alt={t(screen.caption)}
                    width={507}
                    height={1046}
                    loading="lazy"
                    decoding="async"
                    className="block h-auto w-full"
                    style={{ outline: "none" }}
                  />
                </div>
                <figcaption className="px-1 text-center text-[14.5px] font-semibold leading-snug text-ink-secondary">
                  {t(screen.caption)}
                </figcaption>
              </figure>
            </li>
          ))}
        </ul>
      </Reveal>
    </section>
  );
}
