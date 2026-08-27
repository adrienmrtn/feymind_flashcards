import { CYCLE_STAGES, DEMO_COURSE } from "./demo-course";

/**
 * Les trois temps du cycle, avec la boucle du retour à la mer.
 *
 * Elle est **cernée d'un filet et tenue à sa hauteur** : dans la première version de l'écran
 * iOS dont elle vient, elle se tassait jusqu'à disparaître quand la fiche manquait de place, et
 * un trou blanc à la place d'un schéma ne prouve rien. Or le schéma compte autant que les
 * cartes - c'est le format qu'on oublie toujours d'annoncer.
 */
export function WaterCycleFigure() {
  return (
    <div
      className="rounded-[12px] border p-3"
      style={{
        backgroundColor: `${DEMO_COURSE.accent}17`,
        borderColor: `${DEMO_COURSE.accent}47`,
      }}
    >
      <div className="flex items-start justify-between gap-1">
        {CYCLE_STAGES.map((stage, index) => (
          <div key={stage.label} className="flex flex-1 items-start gap-1">
            <div className="flex-1 text-center">
              <StageIcon index={index} tint={stage.tint} />
              <p className="mt-1.5 text-[10px] font-semibold leading-tight text-ink-secondary">
                {stage.label}
              </p>
            </div>
            {index < CYCLE_STAGES.length - 1 ? (
              <svg
                aria-hidden
                viewBox="0 0 12 12"
                className="mt-2 h-3 w-3 shrink-0"
                style={{ color: DEMO_COURSE.accent, opacity: 0.55 }}
              >
                <path
                  d="M2 6h7M6.5 3l3 3-3 3"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.8"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            ) : null}
          </div>
        ))}
      </div>

      <p
        className="mt-3 flex items-center justify-center gap-1.5 rounded-pill py-1.5 text-center text-[10px] font-semibold"
        style={{ backgroundColor: `${DEMO_COURSE.accent}24`, color: DEMO_COURSE.accent }}
      >
        <svg aria-hidden viewBox="0 0 12 12" className="h-3 w-3">
          <path
            d="M9.5 3.5H4a2 2 0 0 0 0 4h1M6 1.5 4 3.5l2 2"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.6"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
        Les rivières ramènent l&apos;eau à la mer
      </p>
    </div>
  );
}

/**
 * Un soleil, un nuage, une averse. Dessinés à la main parce que ce sont **trois formes
 * reconnaissables**, et qu'un pictogramme de bibliothèque générique dirait « icône » là où on
 * veut dire « schéma ».
 */
function StageIcon({ index, tint }: { index: number; tint: string }) {
  return (
    <svg aria-hidden viewBox="0 0 24 24" className="mx-auto h-6 w-6" style={{ color: tint }}>
      {index === 0 ? (
        <>
          <circle cx="12" cy="12" r="4.5" fill="currentColor" />
          {[0, 45, 90, 135, 180, 225, 270, 315].map((angle) => (
            <line
              key={angle}
              x1={12 + 7 * Math.cos((angle * Math.PI) / 180)}
              y1={12 + 7 * Math.sin((angle * Math.PI) / 180)}
              x2={12 + 9.5 * Math.cos((angle * Math.PI) / 180)}
              y2={12 + 9.5 * Math.sin((angle * Math.PI) / 180)}
              stroke="currentColor"
              strokeWidth="1.8"
              strokeLinecap="round"
            />
          ))}
        </>
      ) : (
        <>
          <path
            d="M6.5 16.5a3.5 3.5 0 0 1 .3-7 5 5 0 0 1 9.6-.7 3.6 3.6 0 0 1 .6 7.2z"
            fill="currentColor"
          />
          {index === 2
            ? [9, 12, 15].map((x, drop) => (
                <line
                  key={x}
                  x1={x}
                  y1={18.5}
                  x2={x - 1}
                  y2={drop === 1 ? 22.5 : 21.5}
                  stroke="currentColor"
                  strokeWidth="1.8"
                  strokeLinecap="round"
                />
              ))
            : null}
        </>
      )}
    </svg>
  );
}
