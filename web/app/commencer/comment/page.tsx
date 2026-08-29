import { redirect } from "next/navigation";

/**
 * L'ancien « Voici comment ça marche » répétait la démo en trois phrases.
 * Les trois écrans du début le montrent déjà.
 */
export default function RetiredHowItWorksStep() {
  redirect("/commencer/ecole");
}
