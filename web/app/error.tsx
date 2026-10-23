"use client";

import { LoadError } from "@/components/app/LoadError";

/**
 * Le filet du dessus : une erreur levée **dans** `app/app/layout.tsx` (le profil, lu pour le nom
 * et la visite guidée) ne passe pas par `app/app/error.tsx`, qui vit sous ce layout. Sans ce
 * fichier, elle tombait sur la page d'erreur brute de Next.
 */
export default LoadError;
