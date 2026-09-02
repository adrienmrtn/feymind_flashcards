"use server";

import { revalidatePath } from "next/cache";

import {
  canReadInbox,
  cleanFeedbackMessage,
  isFeedbackKind,
  type FeedbackKind,
} from "@/lib/feedback";
import { currentUser } from "@/lib/data/user";
import { createClient } from "@/lib/supabase/server";

export interface FeedbackSendResult {
  status: "ok" | "invalid" | "quota" | "error";
  message: string;
}

export async function sendFeedback(
  kind: FeedbackKind,
  message: string,
  source: "web" | "ios" = "web",
): Promise<FeedbackSendResult> {
  const user = await currentUser();
  if (!user) return { status: "error", message: "Connecte-toi." };
  if (!isFeedbackKind(kind)) {
    return { status: "invalid", message: "Dis s'il s'agit d'un bug ou d'une idée." };
  }

  const cleaned = cleanFeedbackMessage(message);
  if (!cleaned) {
    return { status: "invalid", message: "Écris un message." };
  }

  const supabase = await createClient();
  const { error } = await supabase.from("feedback").insert({
    user_id: user.id,
    kind,
    message: cleaned,
    source,
  });

  if (!error) {
    return { status: "ok", message: "C'est noté." };
  }

  if (error.code === "42501" || /feedback_today_count|row-level security/i.test(error.message)) {
    return {
      status: "quota",
      message: `Trop de retours aujourd'hui. Réessaie demain.`,
    };
  }

  return { status: "error", message: "Ça n'est pas passé. Réessaie dans un instant." };
}

export async function markFeedbackRead(id: string): Promise<{ status: "ok" | "error"; message?: string }> {
  const user = await currentUser();
  if (!canReadInbox(user?.email)) {
    return { status: "error", message: "Cette page n'est pas pour ce compte." };
  }

  const supabase = await createClient();
  const { error } = await supabase
    .from("feedback")
    .update({ read_at: new Date().toISOString() })
    .eq("id", id)
    .is("read_at", null);

  if (error) return { status: "error", message: "Impossible de marquer comme lu." };
  revalidatePath("/app/retours");
  return { status: "ok" };
}
