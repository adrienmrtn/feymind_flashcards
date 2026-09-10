import { describe, expect, it, vi } from "vitest";

vi.mock("@vercel/analytics", () => ({ track: vi.fn() }));

import { track } from "@vercel/analytics";

import { STEPS } from "../onboarding/steps";

import {
  FUNNEL_EVENTS,
  stepEvent,
  trackCheckoutStart,
  trackOnboardingStep,
  trackPaywallView,
} from "./funnel";

describe("stepEvent", () => {
  it("numbers every screen of the tunnel, first to last", () => {
    const first = stepEvent("/commencer/bienvenue");
    const last = stepEvent("/commencer/compte");
    expect(first).toEqual({ step: "bienvenue", index: 1, of: STEPS.length });
    expect(last).toEqual({
      step: "compte",
      index: STEPS.length,
      of: STEPS.length,
    });
  });

  it("keeps the order of the tunnel, so the funnel reads top to bottom", () => {
    const indices = STEPS.map((step) => stepEvent(step.path)?.index);
    expect(indices).toEqual(STEPS.map((_, i) => i + 1));
  });

  it("ignores addresses outside the tunnel", () => {
    expect(stepEvent("/app")).toBeNull();
    expect(stepEvent("/commencer")).toBeNull();
    expect(stepEvent("/commencer/offre")).toBeNull();
  });
});

describe("track helpers", () => {
  it("sends the step with its number, and nothing outside the tunnel", () => {
    vi.mocked(track).mockClear();
    trackOnboardingStep("/commencer/repos");
    expect(track).toHaveBeenCalledWith(FUNNEL_EVENTS.step, {
      step: "repos",
      index: 12,
      of: STEPS.length,
    });
    trackOnboardingStep("/app");
    expect(track).toHaveBeenCalledTimes(1);
  });

  it("names the door the paywall opened from, and the plan chosen", () => {
    vi.mocked(track).mockClear();
    trackPaywallView("session");
    trackCheckoutStart("yearly", "home");
    expect(track).toHaveBeenNthCalledWith(1, FUNNEL_EVENTS.paywall, {
      surface: "session",
      stage: "plans",
    });
    expect(track).toHaveBeenNthCalledWith(2, FUNNEL_EVENTS.checkout, {
      plan: "yearly",
      surface: "home",
    });
  });
});
