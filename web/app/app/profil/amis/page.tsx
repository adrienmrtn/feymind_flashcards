import Link from "next/link";
import { ChevronLeft } from "lucide-react";

import { displayUsername } from "@micabo/core";

import { FriendSearch } from "@/components/app/FriendSearch";
import { PeopleList } from "@/components/app/PeopleList";
import { listSchoolmates, listSocialGraph } from "@/lib/data/social";
import { getTranslator } from "@/lib/i18n/server";
import { PROFILE_PATH } from "@/lib/lesson/routes";

/**
 * **Les amis**, depuis le Profil : les demandes reçues d'abord, puis de quoi en ajouter, les
 * camarades de l'établissement, la liste. Même ordre que l'iPhone (`FriendsView`).
 */
export default async function FriendsPage() {
  const [{ t }, graph, schoolmates] = await Promise.all([getTranslator(), listSocialGraph(), listSchoolmates()]);

  return (
    <div className="mx-auto flex w-full max-w-[640px] flex-col gap-5 pb-6">
      <header className="flex flex-col gap-2 pt-1">
        <Link href={PROFILE_PATH} className="pressable flex w-fit items-center gap-1 text-[14px] font-bold text-ink-secondary">
          <ChevronLeft aria-hidden="true" className="size-4" strokeWidth={2.8} />
          {t("app.friends.backToProfile")}
        </Link>
        <h1 className="text-[32px] font-extrabold leading-tight tracking-tight-title text-ink">{t("app.profileTab.friends")}</h1>
        <p className="text-[15px] font-semibold text-ink-secondary">{graph.me ? displayUsername(graph.me.username) : t("app.friends.yourAccount")}</p>
      </header>

      <div className="flex flex-col gap-5">
        <PeopleList caption={t("app.friends.incoming")} people={graph.incoming} />
        <FriendSearch />
        {graph.incoming.length === 0 && graph.friends.length === 0 && schoolmates.length === 0 ? <p className="text-[15px] font-medium text-ink-secondary">{t("app.friends.empty")}</p> : null}
        {schoolmates.length > 0 && graph.me?.institutionName ? <PeopleList caption={t("app.friends.atSchool", { school: graph.me.institutionName })} people={schoolmates} /> : null}
        <PeopleList caption={t("app.friends.list")} people={graph.friends} />
        <PeopleList caption={t("app.friends.outgoing")} people={graph.outgoing} />
      </div>
    </div>
  );
}
