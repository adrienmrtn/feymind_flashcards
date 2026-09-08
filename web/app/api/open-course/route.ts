import { NextResponse } from "next/server";

/**
 * Pont hors du routeur : le navigateur quitte vraiment `/app/importer`,
 * puis arrive sur la fiche. Un `location` ou un GET vers `/app/c/:id`
 * reste une navigation SPA, et Next affichait « This page couldn't load ».
 */
const ALLOWED = /^\/app\/(c\/[0-9a-f-]{36}(\/cartes)?|paquets\/[0-9a-f-]{36})(\?.*)?$/i;

export function GET(request: Request) {
  const to = new URL(request.url).searchParams.get("to") ?? "";
  const path = to.startsWith("/") ? to : "";
  if (!ALLOWED.test(path)) {
    return NextResponse.redirect(new URL("/app", request.url), 303);
  }
  return NextResponse.redirect(new URL(path, request.url), 303);
}
