import "server-only";

import { canReadInbox, type FeedbackKind, type InboxRow } from "@/lib/feedback";
import { currentAccessToken, currentUser } from "@/lib/data/user";
import { dataClient } from "@/lib/data/cache";

export type { InboxRow };

export async function listInbox(): Promise<InboxRow[] | null> {
  const user = await currentUser();
  const token = await currentAccessToken();
  if (!user || !token || !canReadInbox(user.email)) return null;

  const { data, error } = await dataClient(token)
    .from("feedback")
    .select("id, kind, message, source, author_label, created_at, read_at")
    .order("created_at", { ascending: false })
    .limit(200);

  if (error || !data) return [];

  return data.map((row) => ({
    id: row.id as string,
    kind: row.kind as FeedbackKind,
    message: row.message as string,
    source: row.source === "ios" ? "ios" : "web",
    authorLabel: (row.author_label as string) || "Compte",
    createdAt: row.created_at as string,
    readAt: (row.read_at as string | null) ?? null,
  }));
}
