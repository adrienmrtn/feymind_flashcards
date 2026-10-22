import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { ChevronLeft } from "lucide-react";

import { displayUsername } from "@micabo/core";

import { FriendActions } from "@/components/app/FriendActions";
import { getDirectoryPerson } from "@/lib/data/social";
import { getTranslator } from "@/lib/i18n/server";
import { FRIENDS_PATH, PROFILE_PATH } from "@/lib/lesson/routes";

/**
 * **Le profil d'un camarade** : son @, son école, et le lien qui vous unit (demander, accepter,
 * retirer). Ses cours ne s'y lisent plus : la bibliothèque a disparu avec la refonte.
 */
export default async function UserPage({ params }: { params: Promise<{ username: string }> }) {
  const { username } = await params;
  const person = await getDirectoryPerson(username);
  if (!person) notFound();
  if (person.relation === "me") redirect(PROFILE_PATH);
  const { t } = await getTranslator();

  return (
    <div className="mx-auto flex w-full max-w-[640px] flex-col gap-5 pb-6">
      <header className="flex flex-col gap-2 pt-1">
        <Link href={FRIENDS_PATH} className="pressable flex w-fit items-center gap-1 text-[14px] font-bold text-ink-secondary">
          <ChevronLeft aria-hidden="true" className="size-4" strokeWidth={2.8} />
          {t("app.friends.allFriends")}
        </Link>
        <p className="text-[12px] font-extrabold uppercase tracking-caps text-ink-tertiary">{person.institutionName ?? t("app.friends.classmate")}</p>
        <div className="flex flex-wrap items-end justify-between gap-3">
          <h1 className="text-[32px] font-extrabold leading-tight tracking-tight-title text-ink">{displayUsername(person.username)}</h1>
          <FriendActions personId={person.id} relation={person.relation} />
        </div>
      </header>
    </div>
  );
}
