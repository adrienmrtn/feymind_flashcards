import { NextResponse } from "next/server";

import { refreshLibraryAfterImport } from "@/lib/actions/course";

/**
 * Invalide les listes **sans** Server Action : une action au montage de la
 * fiche relançait un vol RSC de `/app/c/:id` et affichait
 * « This page couldn't load » alors que le cours était déjà là.
 */
export async function POST() {
  await refreshLibraryAfterImport();
  return NextResponse.json({ status: "ok" });
}
