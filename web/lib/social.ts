/** Les types sociaux, sans serveur : les composants clients peuvent les importer. */

export type Relation = "unknown" | "requested" | "awaitingMe" | "friends" | "me";

export interface DirectoryPerson {
  id: string;
  username: string;
  institutionId: string | null;
  institutionName: string | null;
  relation: Relation;
}
