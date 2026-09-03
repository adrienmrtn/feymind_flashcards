import Link from "next/link";

import { displayUsername } from "@micabo/core";

import { FriendSearch } from "@/components/app/FriendSearch";
import { PeopleList } from "@/components/app/PeopleList";
import { listSchoolmates, listSocialGraph } from "@/lib/data/social";
import { getTranslator } from "@/lib/i18n/server";

/**
 * Les amis : les demandes reçues d'abord, puis la liste, puis de quoi en ajouter.
 *
 * Même ordre que l'iPhone. Les camarades de l'établissement sont proposés sans
 * rien taper : on ne connaît pas le @ de ses camarades.
 */
export default async function FriendsPage() {
  const [{ t }, graph, schoolmates] = await Promise.all([
    getTranslator(),
    listSocialGraph(),
    listSchoolmates(),
  ]);

  return (
    <div className="mx-auto max-w-[560px]">
      <header>
        <h1 className="text-lg font-semibold tracking-tight text-foreground">
          {t("app.friends.title")}
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {graph.me ? displayUsername(graph.me.username) : t("app.friends.yourAccount")}
        </p>
      </header>

      <div className="mt-5 space-y-5">
        <PeopleList caption={t("app.friends.incoming")} people={graph.incoming} />

        <div data-tour="amis-recherche">
          <FriendSearch />
        </div>

        {graph.incoming.length === 0 &&
        graph.friends.length === 0 &&
        schoolmates.length === 0 ? (
          <p className="text-sm text-muted-foreground">{t("app.friends.empty")}</p>
        ) : null}

        {schoolmates.length > 0 && graph.me?.institutionName ? (
          <PeopleList
            caption={t("app.friends.atSchool", { school: graph.me.institutionName })}
            people={schoolmates}
          />
        ) : null}

        <PeopleList caption={t("app.friends.list")} people={graph.friends} />
        <PeopleList caption={t("app.friends.outgoing")} people={graph.outgoing} />
      </div>

      <p className="mt-6 text-[13px] text-ink-tertiary">
        <Link href={"/app/profil" as never} className="underline-draw">
          {t("app.friends.backToProfile")}
        </Link>
      </p>
    </div>
  );
}
