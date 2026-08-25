import {
  COURSE_ACCENTS,
  DAILY_MINUTES_STEPS,
  HORIZON_DAYS,
  REVIEW_DAYS,
  REVIEW_RATINGS,
  REVIEW_RATING_LABELS,
  cardsPerYear,
  curveWithMicabo,
  curveWithoutReview,
  dailyMinutesLabel,
  entitlement,
  newCardSnapshot,
  newCardsPerDay,
  previewLabels,
  pricing,
  type CardSnapshot,
} from "@micabo/core";

/**
 * **La référence des fondations, et pas la page d'accueil.**
 *
 * Elle existe parce que les fondations passent avant les composants, et parce qu'un jeton qu'on
 * ne voit jamais posé à côté de ses voisins est un jeton qu'on redéfinit en local six semaines
 * plus tard. Elle sert aussi de vérification de bout en bout : tout ce qui est chiffré ici est
 * **calculé par `@micabo/core`** au moment du rendu, donc si le port dérive, cette page le dit.
 *
 * Elle sera remplacée par la vraie page d'accueil à l'étape 2, et déplacée sous `/fondations`.
 */

export default function FoundationsPage() {
  return (
    <main className="mx-auto max-w-page px-screen py-16">
      <header className="max-w-reading">
        <p className="eyebrow">Étape 1 · Fondations</p>
        <h1 className="mt-3 text-4xl font-bold text-ink sm:text-5xl">
          Les jetons, et les règles qu&apos;ils portent.
        </h1>
        <p className="mt-5 text-[15px] leading-relaxed text-ink-secondary">
          Ce n&apos;est pas la page d&apos;accueil du site — elle arrive à l&apos;étape suivante.
          C&apos;est la référence des fondations, portées valeur par valeur depuis{" "}
          <code className="rounded-[6px] bg-surface-muted px-1.5 py-0.5 text-[13px]">
            MicaboTheme.swift
          </code>
          . Tous les nombres de cette page sont calculés par{" "}
          <code className="rounded-[6px] bg-surface-muted px-1.5 py-0.5 text-[13px]">
            @micabo/core
          </code>{" "}
          : ils bougeront le jour où le port dérivera.
        </p>
      </header>

      <RetentionSection />
      <SchedulerSection />
      <DailyLoadSection />
      <FreeTierSection />
      <ColorSection />
      <MotionSection />
    </main>
  );
}

// MARK: - Le gratuit

function FreeTierSection() {
  const blockCounts = [10, 14, 20, 3, 1];

  return (
    <Section
      eyebrow="Le gratuit"
      title="Un cours, sept dixièmes de la fiche, cinq cartes."
      note="Les nombres viennent de ProAccess.swift : c'est l'app qui fait foi, et un cours flouté
      aux sept dixièmes sur le téléphone et à la moitié sur le web serait le même produit qui dit
      deux choses. Le verrou est construit ici, mais il n'est pas armé — il n'y a pas encore de
      table à lire, et le fermer maintenant enfermerait dehors qui vient de payer sur son
      téléphone."
    >
      <div className="grid gap-4 sm:grid-cols-2">
        <Card title="Où la fiche se coupe">
          <p className="mb-4 text-[13px] text-ink-tertiary">
            La coupure se compte <strong className="font-semibold text-ink-secondary">en blocs</strong>
            , pas en caractères : couper un paragraphe au septième dixième de son texte donnerait
            une phrase interrompue au milieu d&apos;un mot, ce qui ressemble à un bug plutôt
            qu&apos;à une limite assumée.
          </p>
          <div className="space-y-1.5 text-[13px]">
            {blockCounts.map((count) => (
              <div
                key={count}
                className="flex items-baseline justify-between border-b border-hairline py-1.5 last:border-0"
              >
                <span className="text-ink-secondary">
                  <span className="numeral font-bold text-ink">{count}</span> bloc
                  {count > 1 ? "s" : ""}
                </span>
                <span className="text-ink-secondary">
                  <span className="numeral font-bold text-accent">
                    {entitlement.sheetLockIndex(count)}
                  </span>{" "}
                  lisible{entitlement.sheetLockIndex(count) > 1 ? "s" : ""}
                </span>
              </div>
            ))}
          </div>
          <p className="mt-4 text-[13px] text-ink-tertiary">
            Toujours au moins un bloc à lire, jamais plus qu&apos;il n&apos;y en a. Et{" "}
            <span className="numeral font-bold text-ink">
              {entitlement.lockedSheetPercent()} %
            </span>{" "}
            restent derrière le cadenas.
          </p>
        </Card>

        <Card title="Les deux offres">
          <p className="mb-4 text-[13px] text-ink-tertiary">
            Deux, pas trois : un paywall à trois colonnes fait comparer des colonnes au lieu de
            faire choisir.
          </p>
          <div className="space-y-2.5">
            {pricing.PLANS.map((plan) => (
              <div
                key={plan.kind}
                className="flex items-baseline justify-between rounded-tile bg-surface-muted px-4 py-3"
              >
                <span>
                  <span className="block text-[13px] font-semibold text-ink">{plan.title}</span>
                  <span className="block text-[11px] text-ink-tertiary">
                    {pricing.planCaption(plan)}
                  </span>
                </span>
                <span className="numeral text-base font-bold text-ink">
                  {pricing.priceText(plan.price)}
                </span>
              </div>
            ))}
          </div>
          <p className="mt-4 text-[13px] text-ink-tertiary">
            L&apos;annuel économise{" "}
            <span className="numeral font-bold text-accent">{pricing.savingsPercent()} %</span> — un
            nombre <strong className="font-semibold text-ink-secondary">calculé</strong> depuis les
            deux prix, jamais écrit. La spec du parcours annonçait 60 % ; c&apos;est le calcul qui a
            raison, et il suivra le jour où un prix bougera.
          </p>
        </Card>
      </div>
    </Section>
  );
}

// MARK: - La courbe

function RetentionSection() {
  const without = curveWithoutReview();
  const withMicabo = curveWithMicabo();

  return (
    <Section
      eyebrow="Répétition espacée"
      title="Relire ne suffit pas. Se souvenir, oui."
      note="Les deux tracés partent confondus et se séparent à la première révision. C'est l'endroit
      où ils divergent qu'on regarde, pas la forme de chacun."
    >
      <figure className="paper rounded-group bg-surface p-6" data-print="keep">
        <svg
          viewBox="0 0 600 220"
          className="h-auto w-full"
          role="img"
          aria-label="Deux courbes de mémorisation sur trente jours : sans révision, la rétention tombe à presque rien ; avec Micabo, elle remonte à chaque révision."
        >
          <line
            x1="0"
            y1="200"
            x2="600"
            y2="200"
            stroke="var(--color-hairline-on-canvas)"
            strokeWidth="1"
          />
          <path
            d={pathFor(without)}
            fill="none"
            stroke="var(--color-ink-tertiary)"
            strokeWidth="2"
            strokeDasharray="4 4"
          />
          <path
            d={pathFor(withMicabo)}
            fill="none"
            stroke="var(--color-accent)"
            strokeWidth="2.5"
            strokeLinejoin="round"
          />
          {REVIEW_DAYS.map((day) => (
            <g key={day}>
              <line
                x1={(day / HORIZON_DAYS) * 600}
                y1="18"
                x2={(day / HORIZON_DAYS) * 600}
                y2="200"
                stroke="var(--color-stroke)"
                strokeWidth="1"
              />
              <circle
                cx={(day / HORIZON_DAYS) * 600}
                cy="18"
                r="3.5"
                fill="var(--color-accent-vivid)"
              />
            </g>
          ))}
        </svg>
        <figcaption className="mt-5 space-y-1.5 text-[13px]">
          <Legend color="var(--color-accent)" label="Avec Micabo, la rétention remonte à chaque révision." />
          <Legend
            color="var(--color-ink-tertiary)"
            dashed
            label="Sans révision, il ne reste presque rien au bout d'un mois."
          />
        </figcaption>
      </figure>
      <p className="mt-4 text-[13px] text-ink-tertiary">
        Révisions à {REVIEW_DAYS.map((day) => `${day} j`).join(", ")} — les intervalles réels, pas
        des repères choisis pour la figure.
      </p>
    </Section>
  );
}

function pathFor(points: { x: number; y: number }[]): string {
  return points
    .map((point, index) => {
      const x = point.x * 600;
      const y = 200 - point.y * 182;
      return `${index === 0 ? "M" : "L"}${x.toFixed(2)} ${y.toFixed(2)}`;
    })
    .join(" ");
}

function Legend({ color, label, dashed }: { color: string; label: string; dashed?: boolean }) {
  return (
    <div className="flex items-center gap-2.5 text-ink-secondary">
      <span
        aria-hidden
        className="h-0.5 w-6 shrink-0 rounded-pill"
        style={
          dashed
            ? { backgroundImage: `repeating-linear-gradient(to right, ${color} 0 4px, transparent 4px 8px)` }
            : { backgroundColor: color }
        }
      />
      {label}
    </div>
  );
}

// MARK: - Le planificateur

function SchedulerSection() {
  const now = new Date(1_700_000_000 * 1000);
  const fresh = newCardSnapshot();
  const reviewing: CardSnapshot = newCardSnapshot({
    state: "review",
    intervalDays: 10,
    easeFactor: 2.5,
    repetitions: 3,
  });

  const rows = [
    { label: "Une carte neuve", labels: previewLabels(fresh, { now }) },
    { label: "En révision, 10 jours, facilité 2,5", labels: previewLabels(reviewing, { now }) },
  ];

  return (
    <Section
      eyebrow="SM-2"
      title="Ce que chaque bouton promet."
      note="Les mêmes valeurs que MicaboTests/SM2SchedulerTests.swift, vérifiées en TypeScript. Deux
      copies de cette formule qui divergent d'un dixième donnent une carte révisée deux fois."
    >
      <div className="paper overflow-hidden rounded-group bg-surface">
        {rows.map((row, index) => (
          <div key={row.label} className={index > 0 ? "border-t border-hairline" : undefined}>
            <p className="px-5 pt-4 text-[13px] text-ink-secondary">{row.label}</p>
            <div className="grid grid-cols-4 gap-px p-5 pt-3">
              {REVIEW_RATINGS.map((rating) => (
                <div key={rating} className="text-center">
                  <p className="text-[11px] font-medium text-ink-tertiary">
                    {REVIEW_RATING_LABELS[rating]}
                  </p>
                  <p className="numeral mt-1 text-lg font-bold text-accent">
                    {row.labels[rating]}
                  </p>
                  <p className="mt-1 text-[11px] text-ink-tertiary">touche {rating}</p>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
      <p className="mt-4 max-w-reading text-[13px] text-ink-tertiary">
        Les quatre touches sont la raison pour laquelle la session du web{" "}
        <strong className="font-semibold text-ink-secondary">ne s&apos;animera pas</strong> : un
        geste répété des centaines de fois par soirée n&apos;a pas droit à une animation, quelle
        qu&apos;elle soit.
      </p>
    </Section>
  );
}

// MARK: - Le rythme

function DailyLoadSection() {
  return (
    <Section
      eyebrow="Rythme quotidien"
      title="Ce que le temps donné décide."
      note="Le plafond de cartes neuves n'est pas un réglage de plus : c'est ce qui empêche les
      sessions des jours suivants de déborder. Une carte neuve revient huit fois avant d'être
      acquise."
    >
      <div className="paper overflow-hidden rounded-group bg-surface">
        <table className="w-full text-left text-[13px]">
          <thead>
            <tr className="border-b border-hairline text-ink-tertiary">
              <th className="px-5 py-3 font-medium">Par jour</th>
              <th className="px-5 py-3 font-medium">Cartes neuves</th>
              <th className="px-5 py-3 font-medium">Dans un an</th>
            </tr>
          </thead>
          <tbody>
            {DAILY_MINUTES_STEPS.filter((step) => [5, 15, 30, 60, 120].includes(step)).map(
              (step) => (
                <tr key={step} className="border-b border-hairline last:border-0">
                  <td className="px-5 py-3 text-ink-secondary">{dailyMinutesLabel(step)}</td>
                  <td className="numeral px-5 py-3 font-bold text-ink">{newCardsPerDay(step)}</td>
                  <td className="numeral px-5 py-3 text-ink-secondary">
                    {cardsPerYear(step).toLocaleString("fr-FR")}
                  </td>
                </tr>
              ),
            )}
          </tbody>
        </table>
      </div>
      <p className="mt-4 max-w-reading text-[13px] text-ink-tertiary">
        Le défaut est 15 minutes, soit huit cartes neuves par jour. Le parcours d&apos;accueil du
        web ne pose pas la question — la date d&apos;examen est une meilleure question — donc un
        compte né sur le web arrive avec ce défaut.
      </p>
    </Section>
  );
}

// MARK: - Les couleurs

function ColorSection() {
  const inks = [
    ["Encre", "--color-ink"],
    ["Encre secondaire", "--color-ink-secondary"],
    ["Encre tertiaire", "--color-ink-tertiary"],
    ["Encre de lecture", "--color-ink-reading"],
  ] as const;

  const accents = [
    ["Accent", "--color-accent", "Ce qui est actif, sélectionné, interactif"],
    ["Accent vif", "--color-accent-vivid", "Grandes surfaces remplies, jamais de texte dessus"],
    ["Accent doux", "--color-accent-soft", "Fond d'une pastille active"],
    ["Passage en avant", "--color-sheet-emphasis", "L'encre d'un passage marqué, pas son fond"],
  ] as const;

  return (
    <Section
      eyebrow="Couleur"
      title="Un seul accent, et deux verts qui ne font pas la même chose."
      note="L'accent est assez sombre pour porter du texte de onze points sur un fond pastel ;
      le vert vif est celui du logo et ne remplit que de grandes surfaces. Rien d'autre n'est
      coloré, sauf les retours d'information et les teintes de couverture des cours."
    >
      <div className="grid gap-4 sm:grid-cols-2">
        <Card title="Encre">
          <div className="space-y-2">
            {inks.map(([label, token]) => (
              <Swatch key={token} label={label} token={token} />
            ))}
          </div>
        </Card>
        <Card title="Accent">
          <div className="space-y-2">
            {accents.map(([label, token, note]) => (
              <Swatch key={token} label={label} token={token} note={note} />
            ))}
          </div>
        </Card>
      </div>

      <Card title="Teintes de couverture des cours" className="mt-4">
        <p className="mb-4 text-[13px] text-ink-tertiary">
          Choisies <strong className="font-semibold text-ink-secondary">par index</strong>, depuis
          l&apos;identifiant du cours : c&apos;est de la logique, pas du style, donc elle vit dans{" "}
          <code className="rounded-[6px] bg-surface-muted px-1.5 py-0.5">@micabo/core</code>. Le
          même cours doit être de la même couleur sur le téléphone et sur le web.
        </p>
        <div className="flex flex-wrap gap-2">
          {COURSE_ACCENTS.map((hex) => (
            <div
              key={hex}
              className="flex h-14 w-14 items-end justify-center rounded-tile pb-1 text-[10px] font-medium text-white/80"
              style={{ backgroundColor: hex }}
            >
              {hex.replace("#", "")}
            </div>
          ))}
        </div>
      </Card>
    </Section>
  );
}

function Swatch({ label, token, note }: { label: string; token: string; note?: string }) {
  return (
    <div className="flex items-center gap-3">
      <span
        aria-hidden
        className="h-8 w-8 shrink-0 rounded-[10px] ring-1 ring-black/5"
        style={{ backgroundColor: `var(${token})` }}
      />
      <span className="min-w-0">
        <span className="block text-[13px] font-medium text-ink">{label}</span>
        <span className="block truncate text-[11px] text-ink-tertiary">{note ?? token}</span>
      </span>
    </div>
  );
}

// MARK: - Le mouvement

function MotionSection() {
  return (
    <Section
      eyebrow="Mouvement"
      title="La fréquence décide, pas le goût."
      note="Ce qui est vu cent fois par jour n'est pas animé. Ce qui est vu une fois dans une vie a
      droit au budget d'enchantement. Et rien ne rebondit : une courbe qui dépasse sa cible puis
      revient donne, sur vingt écrans, un produit qui tremble."
    >
      <div className="grid gap-4 sm:grid-cols-3">
        <Card title="Survol, dans le produit">
          <p className="mb-4 text-[13px] text-ink-tertiary">
            Seule l&apos;ombre change. Rien ne monte, rien ne grossit.
          </p>
          <div className="paper flex h-20 items-center justify-center rounded-tile bg-surface text-[13px] text-ink-secondary">
            Passe la souris
          </div>
        </Card>
        <Card title="Survol, sur la vitrine">
          <p className="mb-4 text-[13px] text-ink-tertiary">
            Deux points de levée, et c&apos;est tout ce qu&apos;on s&apos;autorise.
          </p>
          <div className="lift paper flex h-20 items-center justify-center rounded-tile bg-surface text-[13px] text-ink-secondary">
            Passe la souris
          </div>
        </Card>
        <Card title="Appui">
          <p className="mb-4 text-[13px] text-ink-tertiary">
            Une échelle de 0,97, la même partout. En dessous de 0,95, le geste devient théâtral.
          </p>
          <button
            type="button"
            className="pressable h-20 w-full rounded-tile bg-ink text-[13px] font-medium text-on-ink"
          >
            Appuie
          </button>
        </Card>
      </div>

      <Card title="Les courbes, et les budgets" className="mt-4">
        <div className="grid gap-x-8 gap-y-2 text-[13px] sm:grid-cols-2">
          <Token name="--ease-out-strong" value="cubic-bezier(0.23, 1, 0.32, 1)" note="entrée, sortie" />
          <Token name="--ease-in-out-strong" value="cubic-bezier(0.77, 0, 0.175, 1)" note="déplacement" />
          <Token name="--duration-press" value="160 ms" note="retour d'appui" />
          <Token name="--duration-hover" value="150 ms" note="survol" />
          <Token name="--duration-menu" value="220 ms" note="menu, sélecteur" />
          <Token name="--duration-sheet" value="320 ms" note="feuille, panneau" />
        </div>
        <p className="mt-5 text-[13px] text-ink-tertiary">
          <strong className="font-semibold text-ink-secondary">Aucun `ease-in` nulle part</strong> :
          il démarre lentement, donc il retarde exactement l&apos;instant qu&apos;on regarde.
        </p>
      </Card>

      <Card title="La seule fioriture" className="mt-4">
        <p className="text-[15px] leading-relaxed text-ink-reading">
          Un filet d&apos;un point qui{" "}
          <a
            href="#"
            data-print="bare"
            className="underline-draw font-medium text-accent decoration-0"
          >
            se trace depuis la gauche
          </a>{" "}
          au survol d&apos;un lien. C&apos;est le survol qui a le plus l&apos;air fait à la main, et
          il ne coûte qu&apos;une transition de <code>background-size</code>.
        </p>
      </Card>
    </Section>
  );
}

function Token({ name, value, note }: { name: string; value: string; note: string }) {
  return (
    <div className="flex items-baseline justify-between gap-4 border-b border-hairline py-1.5 last:border-0">
      <code className="text-[12px] text-ink-secondary">{name}</code>
      <span className="shrink-0 text-right">
        <span className="block text-[12px] text-ink">{value}</span>
        <span className="block text-[11px] text-ink-tertiary">{note}</span>
      </span>
    </div>
  );
}

// MARK: - Charpente

function Section({
  eyebrow,
  title,
  note,
  children,
}: {
  eyebrow: string;
  title: string;
  note: string;
  children: React.ReactNode;
}) {
  return (
    <section className="mt-20">
      <p className="eyebrow">{eyebrow}</p>
      <h2 className="mt-2.5 text-2xl font-bold text-ink">{title}</h2>
      <p className="mt-3 max-w-reading text-[15px] leading-relaxed text-ink-secondary">{note}</p>
      <div className="mt-7">{children}</div>
    </section>
  );
}

function Card({
  title,
  className,
  children,
}: {
  title: string;
  className?: string;
  children: React.ReactNode;
}) {
  return (
    <div className={`paper rounded-group bg-surface p-6 ${className ?? ""}`}>
      <p className="eyebrow mb-4">{title}</p>
      {children}
    </div>
  );
}
