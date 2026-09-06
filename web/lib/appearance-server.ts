import { cache } from "react";
import { cookies } from "next/headers";

import {
  APPEARANCE_COOKIE,
  DEFAULT_APPEARANCE,
  appearanceFromUnknown,
  type Appearance,
} from "./appearance";

export const readAppearance = cache(async (): Promise<Appearance> => {
  const store = await cookies();
  return appearanceFromUnknown(store.get(APPEARANCE_COOKIE)?.value);
});
