import { redirect } from "next/navigation";
import Link from "next/link";

import { InboxList } from "@/components/app/InboxList";
import { listInbox } from "@/lib/data/feedback";
import { canReadInbox } from "@/lib/feedback";
import { currentUser } from "@/lib/data/user";
import { getTranslator } from "@/lib/i18n/server";

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

  const [{ t }, rows] = await Promise.all([getTranslator(), listInbox().then((list) => list ?? [])]);
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
        <h1 className="text-lg font-semibold tracking-tight text-foreground">{t("app.inbox.title")}</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {unread === 0
            ? t("app.inbox.unread.none")
            : unread === 1
              ? t("app.inbox.unread.one")
              : t("app.inbox.unread.many", { count: unread })}
        </p>
      </header>

      <nav className="mt-5 flex flex-wrap gap-2" aria-label={t("app.inbox.filterAria")}>
        <Filter href="/app/retours" current={view === "tous"} label={t("app.inbox.filter.all")} />
        <Filter
          href="/app/retours?vue=non-lus"
          current={view === "non-lus"}
          label={t("app.inbox.filter.unread")}
        />
        <Filter href="/app/retours?vue=bugs" current={view === "bugs"} label={t("app.inbox.filter.bugs")} />
        <Filter href="/app/retours?vue=idees" current={view === "idees"} label={t("app.inbox.filter.ideas")} />
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
