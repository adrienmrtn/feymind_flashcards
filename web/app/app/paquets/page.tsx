import { redirect } from "next/navigation";

/**
 * Les paquets ont rejoint les cours.
 *
 * Ils listaient les mêmes lignes que « Mes cours », sous un autre nom, avec une règle de
 * partage - « un cours part d'un document, un paquet part des cartes » - qui n'était écrite
 * nulle part à l'écran. Un paquet est désormais un cours sans fiche, et il se range avec les
 * autres.
 */
export default function DecksMoved() {
  redirect("/app/cours");
}
