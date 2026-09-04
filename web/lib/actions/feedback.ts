"use server";

import { revalidatePath } from "next/cache";

import {
  canReadInbox,
  cleanFeedbackMessage,
  isFeedbackKind,
  type FeedbackKind,
} from "@/lib/feedback";
import { currentUser } from "@/lib/data/user";
import { actionT } from "@/lib/i18n/action";
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
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };
  if (!isFeedbackKind(kind)) {
    return { status: "invalid", message: await actionT("app.errors.feedbackKind") };
  }

  const cleaned = cleanFeedbackMessage(message);
  if (!cleaned) {
    return { status: "invalid", message: await actionT("app.errors.writeMessage") };
  }

  const supabase = await createClient();
  const { error } = await supabase.from("feedback").insert({
    user_id: user.id,
    kind,
    message: cleaned,
    source,
  });

  if (!error) {
    return { status: "ok", message: await actionT("app.errors.noted") };
  }

  if (error.code === "42501" || /feedback_today_count|row-level security/i.test(error.message)) {
    return {
      status: "quota",
      message: `Trop de retours aujourd'hui. Réessaie demain.`,
    };
  }

  return { status: "error", message: await actionT("app.errors.tryAgain") };
}

export async function markFeedbackRead(id: string): Promise<{ status: "ok" | "error"; message?: string }> {
  const user = await currentUser();
  if (!canReadInbox(user?.email)) {
    return { status: "error", message: await actionT("app.errors.wrongAccount") };
  }

  const supabase = await createClient();
  const { error } = await supabase
    .from("feedback")
    .update({ read_at: new Date().toISOString() })
    .eq("id", id)
    .is("read_at", null);

  if (error) return { status: "error", message: await actionT("app.errors.markReadFailed") };
  revalidatePath("/app/retours");
  return { status: "ok" };
}
