import { redirect } from "next/navigation";

/** Un paquet est un cours : son atelier de cartes est celui du cours. */
export default async function DeckWorkshopMoved({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  redirect(`/app/c/${id}/cartes`);
}
