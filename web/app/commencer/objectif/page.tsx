import { redirect } from "next/navigation";

/** La moyenne visée a rejoint la moyenne actuelle : les deux se règlent sur le même écran. */
export default function RetiredTargetStep() {
  redirect("/commencer/moyenne");
}
