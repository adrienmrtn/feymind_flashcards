"use client";

import { useEffect, useRef, useState } from "react";

import { SheetBlocks } from "@/components/sheet/SheetBlocks";
import { DEMO_COURSE, DEMO_SHEET, TRANSFORMATION_SHEET } from "@/components/demo/demo-course";
import { RawPage } from "@/components/demo/RawPage";
import { WaterCycleFigure } from "@/components/demo/WaterCycleFigure";

/**
 * **La signature du site : une page, deux états, la même empreinte.**
 *
 * Le polycopié brut et la fiche occupent le *même rectangle*, au pixel, et c'est la barre de
 * défilement qui fait passer de l'un à l'autre. Ce n'est pas une trouvaille de site web, c'est
 * l'observation que l'app a déjà faite pour son écran de démonstration : « les deux états occupent
 * la même place, ce qui fait lire une transformation et non deux illustrations ». Deux images côte
 * à côte donnent une comparaison ; deux états au même endroit donnent une transformation — et la
 * transformation *est* le produit.
 *
 * **C'est la fiche qui donne la hauteur, et la page brute qui s'y plie.** La première version
 * faisait l'inverse — la page brute en flux, la fiche en `absolute inset-0` — et la fiche, plus
 * haute que la page de cinq lignes qui la portait, se faisait rogner aux deux tiers. Le rectangle
 * était bien unique, et c'était le mauvais. Une fiche coupée à mi-hauteur ne montre pas une
 * transformation, elle montre un défaut d'affichage.
 *
 * Le mouvement est piloté en JavaScript et non en CSS, et c'est conforme à la règle plutôt qu'une
 * entorse : le défilement est une **entrée continue de l'utilisateur**, donc du mouvement
 * dynamique, et c'est précisément le cas où le JavaScript a sa place. Rien n'est écrit dans l'état
 * de React — les styles sont posés sur les nœuds dans la boucle d'animation, sinon la page se
 * rendrait à nouveau soixante fois par seconde.
 */
export function Transformation() {
  const wrapper = useRef<HTMLDivElement>(null);
  const stage = useRef<HTMLDivElement>(null);
  const sweep = useRef<HTMLDivElement>(null);
  const raw = useRef<HTMLDivElement>(null);
  const blocks = useRef<HTMLDivElement>(null);
  const stageHeight = useRef(0);
  const [reduced, setReduced] = useState(false);

  useEffect(() => {
    const query = window.matchMedia("(prefers-reduced-motion: reduce)");
    setReduced(query.matches);
    const listen = (event: MediaQueryListEvent) => setReduced(event.matches);
    query.addEventListener("change", listen);
    return () => query.removeEventListener("change", listen);
  }, []);

  useEffect(() => {
    if (reduced) return;

    let frame = 0;

    /** La hauteur du rectangle, mesurée une fois : la relire à chaque image ferait recalculer
     *  la mise en page soixante fois par seconde pour un nombre qui ne change pas. */
    const measure = () => {
      stageHeight.current = stage.current?.offsetHeight ?? 0;
    };

    const paint = () => {
      frame = 0;
      const node = wrapper.current;
      if (!node) return;

      const bounds = node.getBoundingClientRect();
      const travel = bounds.height - window.innerHeight;
      const progress = travel <= 0 ? 1 : clamp(-bounds.top / travel);

      // Trois temps qui se chevauchent : le balayage lit la page, la fiche s'écrit par-dessus,
      // la page brute s'effface. Deux moitiés qui se succéderaient proprement se liraient comme
      // deux animations et non comme une transformation.
      const reading = clamp(progress / 0.42);
      const writing = clamp((progress - 0.3) / 0.52);

      if (sweep.current) {
        const height = stageHeight.current;
        sweep.current.style.opacity = progress > 0.02 && writing < 0.9 ? "1" : "0";
        // Un déplacement en pixels et non en pourcentage : un pourcentage de `translateY` se
        // compte sur la hauteur de l'élément déplacé — la bande — et non sur celle de la page,
        // donc le balayage ne parcourait qu'un quart du chemin.
        sweep.current.style.transform = `translate3d(0, ${(reading * height * 1.1 - height * 0.1).toFixed(1)}px, 0)`;
      }

      if (raw.current) {
        // La page brute ne disparaît pas tout à fait : il en reste un souffle sous la fiche,
        // qui dit d'où elle vient.
        raw.current.style.opacity = (1 - writing * 0.92).toFixed(3);
      }

      // Les blocs se posent **l'un après l'autre**, dans l'ordre où on les lirait. C'est ce qui
      // fait lire une page en train de s'écrire plutôt qu'une page qui apparaît.
      const children = blocks.current?.children;
      if (children) {
        const count = children.length;
        for (let index = 0; index < count; index += 1) {
          const element = children[index] as HTMLElement;
          const start = (index / count) * 0.82;
          const local = clamp((writing - start) / 0.24);
          element.style.opacity = local.toFixed(3);
          element.style.transform = `translate3d(0, ${((1 - local) * 8).toFixed(2)}px, 0)`;
        }
      }
    };

    const schedule = () => {
      if (frame === 0) frame = requestAnimationFrame(paint);
    };

    const remeasure = () => {
      measure();
      schedule();
    };

    measure();
    paint();
    window.addEventListener("scroll", schedule, { passive: true });
    window.addEventListener("resize", remeasure, { passive: true });

    // Les polices arrivent après le premier rendu et changent la hauteur du texte : sans cette
    // seconde mesure, le balayage parcourt la hauteur d'avant.
    const fonts = (document as Document & { fonts?: FontFaceSet }).fonts;
    fonts?.ready.then(remeasure);

    return () => {
      if (frame) cancelAnimationFrame(frame);
      window.removeEventListener("scroll", schedule);
      window.removeEventListener("resize", remeasure);
    };
  }, [reduced]);

  // Mouvement réduit : les deux états, l'un à côté de l'autre, sans rien qui bouge. On ne perd
  // que le fil du passage de l'un à l'autre, et les intitulés le disent en mots.
  if (reduced) {
    return (
      <section className="mx-auto mt-32 max-w-page px-screen">
        <Heading />
        <div className="mt-12 grid gap-8 sm:grid-cols-2">
          <figure>
            <figcaption className="eyebrow mb-3 text-ink-tertiary">Ce que tu déposes</figcaption>
            <RawPage />
          </figure>
          <figure>
            <figcaption className="eyebrow mb-3 text-ink-tertiary">Ce que tu relis</figcaption>
            <div className="paper rounded-button bg-surface p-5">
              <SheetBlocks blocks={DEMO_SHEET} tint={DEMO_COURSE.accent} />
              <div className="mt-3.5">
                <WaterCycleFigure />
              </div>
            </div>
          </figure>
        </div>
      </section>
    );
  }

  return (
    <section aria-label="Ce que Micabo fait d'un cours">
      <div className="mx-auto max-w-page px-screen pt-32">
        <Heading />
      </div>

      {/* La hauteur de ce bloc **est** la durée de l'animation : c'est ce qui donne le même
          rythme sur un écran de portable et sur un grand moniteur. */}
      <div ref={wrapper} className="relative h-[280vh]">
        <div className="sticky top-0 flex h-screen items-center">
          <div className="mx-auto w-full max-w-page px-screen">
            <div className="mx-auto max-w-[420px]">
              {/* La fiche est en flux : c'est **elle** qui donne au rectangle sa hauteur. La
                  page brute vient par-dessus, en position absolue, donc les deux ont exactement
                  la même empreinte et aucune des deux n'est rognée. */}
              <div ref={stage} className="relative">
                <div className="paper rounded-button bg-surface p-5">
                  <div ref={blocks}>
                    {TRANSFORMATION_SHEET.map((block, index) => (
                      <div key={index} className={index === 0 ? "" : "mt-3.5"}>
                        <SheetBlocks blocks={[block]} tint={DEMO_COURSE.accent} />
                      </div>
                    ))}
                    <div className="mt-3.5">
                      <WaterCycleFigure />
                    </div>
                  </div>
                </div>

                <div
                  ref={raw}
                  aria-hidden
                  className="absolute inset-0 overflow-hidden rounded-button"
                >
                  <RawPage fill />
                  {/* Le balayage de lecture : la même image que celle de l'app pendant qu'elle
                      travaille. */}
                  <div
                    ref={sweep}
                    className="pointer-events-none absolute inset-x-0 top-0 h-16 opacity-0"
                    style={{
                      background:
                        "linear-gradient(to bottom, transparent, color-mix(in oklch, var(--color-accent) 28%, transparent), transparent)",
                    }}
                  />
                </div>
              </div>

              <p className="mt-6 text-center text-[13px] text-ink-tertiary">
                {DEMO_COURSE.chapter} · le même document, deux fois
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function Heading() {
  return (
    <div className="max-w-reading">
      <p className="eyebrow text-ink-tertiary">Le même document</p>
      <h2 className="mt-2.5 text-3xl font-bold text-ink sm:text-4xl">
        Tu déposes un polycopié. Tu récupères une page.
      </h2>
      <p className="mt-4 text-[16px] leading-relaxed text-ink-secondary">
        Pas un résumé, pas une liste à puces : une{" "}
        <strong className="font-semibold text-ink">fiche</strong> — un plan, des définitions, ce qui
        compte en couleur, et un schéma quand le cours s&apos;y prête. Regarde-la s&apos;écrire
        par-dessus l&apos;original.
      </p>
    </div>
  );
}

function clamp(value: number): number {
  return value < 0 ? 0 : value > 1 ? 1 : value;
}
