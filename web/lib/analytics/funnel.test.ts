import { describe, expect, it, vi } from "vitest";

vi.mock("@vercel/analytics", () => ({ track: vi.fn() }));

import { track } from "@vercel/analytics";

import { STEPS } from "../onboarding/steps";

import {
  FUNNEL_EVENTS,
  stepEvent,
  trackCheckoutStart,
  trackOnboardingAnswer,
  trackOnboardingStep,
  trackPaywallView,
} from "./funnel";

describe("stepEvent", () => {
  it("numbers every screen of the tunnel, first to last", () => {
    const first = stepEvent("/commencer/bienvenue");
    const last = stepEvent("/commencer/offre");
    expect(first).toEqual({ step: "bienvenue", index: 1, of: STEPS.length });
    // L'offre a maintenant son adresse, juste après le compte : elle est la dernière marche.
    expect(last).toEqual({
      step: "offre",
      index: STEPS.length,
      of: STEPS.length,
    });
    expect(stepEvent("/commencer/compte")?.index).toBe(STEPS.length - 1);
  });

  it("keeps the order of the tunnel, so the funnel reads top to bottom", () => {
    const indices = STEPS.map((step) => stepEvent(step.path)?.index);
    expect(indices).toEqual(STEPS.map((_, i) => i + 1));
  });

  it("ignores addresses outside the tunnel", () => {
    expect(stepEvent("/app")).toBeNull();
    expect(stepEvent("/commencer")).toBeNull();
    expect(stepEvent("/commencer/repos")).toBeNull();
  });
});

describe("track helpers", () => {
  it("sends the step with its number, and nothing outside the tunnel", () => {
    vi.mocked(track).mockClear();
    trackOnboardingStep("/commencer/rythme");
    expect(track).toHaveBeenCalledWith(FUNNEL_EVENTS.step, {
      step: "rythme",
      index: 8,
      of: STEPS.length,
    });
    trackOnboardingStep("/app");
    expect(track).toHaveBeenCalledTimes(1);
  });

  it("sends a closed answer as an identifier, never typed text", () => {
    vi.mocked(track).mockClear();
    trackOnboardingAnswer("country", "fr");
    trackOnboardingAnswer("dailyMinutes", 15);
    expect(track).toHaveBeenNthCalledWith(1, FUNNEL_EVENTS.answer, { field: "country", value: "fr" });
    expect(track).toHaveBeenNthCalledWith(2, FUNNEL_EVENTS.answer, { field: "dailyMinutes", value: 15 });
  });

  it("names the door the paywall opened from, and the plan chosen", () => {
    vi.mocked(track).mockClear();
    trackPaywallView("session");
    trackCheckoutStart("yearly", "onboarding");
    expect(track).toHaveBeenNthCalledWith(1, FUNNEL_EVENTS.paywall, {
      surface: "session",
      stage: "plans",
    });
    expect(track).toHaveBeenNthCalledWith(2, FUNNEL_EVENTS.checkout, {
      plan: "yearly",
      surface: "onboarding",
    });
  });
});
