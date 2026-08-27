import Link from "next/link";

import { displayUsername } from "@micabo/core";

import { FriendSearch } from "@/components/app/FriendSearch";
import { PeopleList } from "@/components/app/PeopleList";
import { listSchoolmates, listSocialGraph } from "@/lib/data/social";

/**
 * Les amis : les demandes reçues d'abord, puis la liste, puis de quoi en ajouter.
 *
 * Même ordre que l'iPhone. Les camarades de l'établissement sont proposés sans
 * rien taper : on ne connaît pas le @ de ses camarades.
 */
export default async function FriendsPage() {
  const [graph, schoolmates] = await Promise.all([listSocialGraph(), listSchoolmates()]);

  return (
    <div className="mx-auto max-w-[560px]">
      <header>
        <p className="eyebrow text-ink-tertiary">
          {graph.me ? displayUsername(graph.me.username) : "Ton compte"}
        </p>
        <h1 className="mt-2 text-[32px] font-bold leading-tight text-ink">Amis</h1>
      </header>

      <div className="mt-8 space-y-8">
        <PeopleList caption="Demandes reçues" people={graph.incoming} />

        <FriendSearch />

        {graph.incoming.length === 0 &&
        graph.friends.length === 0 &&
        schoolmates.length === 0 ? (
          <p className="text-[14.5px] leading-relaxed text-ink-secondary">
            Personne pour l&apos;instant. Cherche un nom d&apos;utilisateur pour ajouter
            quelqu&apos;un - c&apos;est le même @ que sur l&apos;iPhone.
          </p>
        ) : null}

        {schoolmates.length > 0 && graph.me?.institutionName ? (
          <PeopleList caption={`À ${graph.me.institutionName}`} people={schoolmates} />
        ) : null}

        <PeopleList caption="Tes amis" people={graph.friends} />
        <PeopleList caption="Demandes envoyées" people={graph.outgoing} />
      </div>

      <p className="mt-10 text-[13px] text-ink-tertiary">
        <Link href={"/app/profil" as never} className="underline-draw">
          Retour au profil
        </Link>
      </p>
    </div>
  );
}
