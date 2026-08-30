"use client";

import type React from "react";
import { Slider as SliderPrimitive } from "@base-ui/react/slider";

import { cn } from "@/lib/utils";

/**
 * Curseur Base UI, **pouce dans la piste**.
 *
 * Le pouce est positionné en `absolute` par la librairie (`top: 50%` +
 * `translate`). S'il est frère de la piste dans un flex, son bloc
 * contenant n'est plus la piste : le rond flotte à côté, et la valeur
 * visuelle ne correspond plus au cran. Dedans, le centre du rond pose
 * sur le trait.
 *
 * `thumbAlignment="edge"` aligne les extrémités sur min et max, sans
 * que la moitié du pouce dépasse — sinon 10/20 se lit avant le début
 * de la piste.
 */
export function Slider({
  className,
  "aria-label": ariaLabel,
  ...props
}: SliderPrimitive.Root.Props): React.ReactElement {
  return (
    <SliderPrimitive.Root
      thumbAlignment="edge"
      className={cn("w-full", className)}
      {...props}
    >
      <SliderPrimitive.Control className="relative flex h-10 w-full touch-none items-center select-none">
        <SliderPrimitive.Track className="relative h-1.5 w-full rounded-full bg-surface-sunken">
          <SliderPrimitive.Indicator className="h-full rounded-full bg-ink" />
          <SliderPrimitive.Thumb
            aria-label={typeof ariaLabel === "string" ? ariaLabel : undefined}
            className="size-5 rounded-full border border-stroke-strong bg-surface shadow-xs outline-none focus-visible:ring-2 focus-visible:ring-ink/20"
          />
        </SliderPrimitive.Track>
      </SliderPrimitive.Control>
    </SliderPrimitive.Root>
  );
}
