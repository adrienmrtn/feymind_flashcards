import Link from "next/link";

import { displayUsername } from "@micabo/core";

import { FriendActions } from "@/components/app/FriendActions";
import type { DirectoryPerson } from "@/lib/social";

export function PeopleList({
  caption,
  people,
}: {
  caption: string;
  people: DirectoryPerson[];
}) {
  if (people.length === 0) return null;

  return (
    <section>
      <p className="eyebrow mb-3 text-ink-tertiary">{caption}</p>
      <ul className="paper divide-y divide-hairline overflow-hidden rounded-group bg-surface">
        {people.map((person) => (
          <li key={person.id} className="hover-row flex items-center gap-3 px-5 py-3.5">
            <Link href={`/app/u/${person.username}` as never} className="min-w-0 flex-1">
              <p className="truncate text-[14.5px] font-semibold text-ink">
                {displayUsername(person.username)}
              </p>
              {person.institutionName ? (
                <p className="truncate text-[12.5px] text-ink-tertiary">{person.institutionName}</p>
              ) : null}
            </Link>
            <FriendActions personId={person.id} relation={person.relation} />
          </li>
        ))}
      </ul>
    </section>
  );
}
