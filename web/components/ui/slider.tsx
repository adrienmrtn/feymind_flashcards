"use client";

import type React from "react";
import { Slider as SliderPrimitive } from "@base-ui/react/slider";

import { cn } from "@/lib/utils";

export function Slider({
  className,
  ...props
}: SliderPrimitive.Root.Props): React.ReactElement {
  return (
    <SliderPrimitive.Root
      thumbAlignment="center"
      className={cn("w-full", className)}
      {...props}
    >
      <SliderPrimitive.Control className="flex h-5 w-full touch-none items-center select-none">
        <SliderPrimitive.Track className="relative h-1.5 w-full grow rounded-full bg-surface-sunken">
          <SliderPrimitive.Indicator className="bg-ink" />
        </SliderPrimitive.Track>
        <SliderPrimitive.Thumb className="block size-4 rounded-full border border-stroke-strong bg-surface shadow-xs outline-none focus-visible:ring-2 focus-visible:ring-ink/20" />
      </SliderPrimitive.Control>
    </SliderPrimitive.Root>
  );
}
