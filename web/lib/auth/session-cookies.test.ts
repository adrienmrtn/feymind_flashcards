import { NextRequest, NextResponse } from "next/server";
import { describe, expect, it } from "vitest";

import { expireSessionCookies, sessionIsGone } from "./session-cookies";

describe("sessionIsGone", () => {
  it("ne conclut rien sans réponse du serveur", () => {
    // Réseau coupé, GoTrue injoignable : la session est peut-être encore bonne.
    expect(sessionIsGone(null)).toBe(false);
    expect(sessionIsGone({})).toBe(false);
    expect(sessionIsGone({ status: 500 })).toBe(false);
    expect(sessionIsGone({ status: 503 })).toBe(false);
  });

  it("conclut sur un refus, qui ne changera pas d'avis", () => {
    expect(sessionIsGone({ status: 400 })).toBe(true);
    expect(sessionIsGone({ status: 401 })).toBe(true);
    expect(sessionIsGone({ status: 403 })).toBe(true);
  });
});

describe("expireSessionCookies", () => {
  function requestWith(names: string[]): NextRequest {
    const request = new NextRequest("https://micabo.app/app");
    for (const name of names) request.cookies.set(name, "peu importe");
    return request;
  }

  it("expire le jeton, ses morceaux, et rien d'autre", () => {
    const request = requestWith([
      "sb-khuzodsrznanzhwlbjbx-auth-token.0",
      "sb-khuzodsrznanzhwlbjbx-auth-token.1",
      "micabo-locale",
    ]);
    const response = NextResponse.next();

    expect(expireSessionCookies(request, response)).toBe(2);
    expect(response.cookies.get("micabo-locale")).toBeUndefined();
    for (const part of ["0", "1"]) {
      const cookie = response.cookies.get(`sb-khuzodsrznanzhwlbjbx-auth-token.${part}`);
      expect(cookie?.value).toBe("");
      expect(cookie?.maxAge).toBe(0);
    }
  });

  it("ne touche à rien quand il n'y a pas de session à effacer", () => {
    const response = NextResponse.next();
    expect(expireSessionCookies(requestWith(["micabo-locale"]), response)).toBe(0);
  });
});
