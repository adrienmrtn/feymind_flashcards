import { redirect } from "next/navigation";
import Link from "next/link";

import { InboxList } from "@/components/app/InboxList";
import { listInbox } from "@/lib/data/feedback";
import { canReadInbox } from "@/lib/feedback";
import { currentUser } from "@/lib/data/user";

/**
 * La boîte des retours. Un seul compte la voit : `team@micabo.app`.
 */
export default async function InboxPage({
  searchParams,
}: {
  searchParams: Promise<{ vue?: string }>;
}) {
  const user = await currentUser();
  if (!canReadInbox(user?.email)) redirect("/app");

  const rows = (await listInbox()) ?? [];
  const params = await searchParams;
  const view = params.vue === "non-lus" || params.vue === "bugs" || params.vue === "idees"
    ? params.vue
    : "tous";

  const filtered = rows.filter((row) => {
    if (view === "non-lus") return !row.readAt;
    if (view === "bugs") return row.kind === "bug";
    if (view === "idees") return row.kind === "idea";
    return true;
  });

  const unread = rows.filter((row) => !row.readAt).length;

  return (
    <div className="mx-auto max-w-[640px]">
      <header>
        <h1 className="text-lg font-semibold tracking-tight text-foreground">Retours</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {unread === 0
            ? "Rien de nouveau."
            : unread === 1
              ? "1 non lu."
              : `${unread} non lus.`}
        </p>
      </header>

      <nav className="mt-5 flex flex-wrap gap-2" aria-label="Filtrer les retours">
        <Filter href="/app/retours" current={view === "tous"} label="Tous" />
        <Filter href="/app/retours?vue=non-lus" current={view === "non-lus"} label="Non lus" />
        <Filter href="/app/retours?vue=bugs" current={view === "bugs"} label="Bugs" />
        <Filter href="/app/retours?vue=idees" current={view === "idees"} label="Idées" />
      </nav>

      <div className="mt-5">
        <InboxList rows={filtered} />
      </div>
    </div>
  );
}

function Filter({
  href,
  current,
  label,
}: {
  href: string;
  current: boolean;
  label: string;
}) {
  return (
    <Link
      href={href as never}
      aria-current={current ? "page" : undefined}
      className={`rounded-pill px-3 py-1.5 text-[13px] font-medium ${
        current
          ? "bg-accent-soft text-accent"
          : "bg-surface-muted text-ink-secondary hover:text-ink"
      }`}
    >
      {label}
    </Link>
  );
}
