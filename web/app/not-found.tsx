export default function NotFound() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-[680px] flex-col justify-center px-6">
      <p className="text-[13px] font-medium text-ink-tertiary">404</p>
      <h1 className="mt-2 text-[26px] font-bold leading-tight text-ink">
        Cette page n&apos;existe pas.
      </h1>
      <p className="mt-3 text-[16px] leading-relaxed text-ink-secondary">
        Le lien est mort, ou la page a bougé.
      </p>
      <a
        href="/"
        className="mt-8 w-fit text-[15px] font-medium text-accent underline-offset-4 hover:underline"
      >
        Retour à l&apos;accueil
      </a>
    </main>
  );
}
