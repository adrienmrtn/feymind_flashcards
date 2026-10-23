/**
 * Erreur d'écriture modèle. Le nom `FalError` est historique : Gemini
 * la relance avec le même statut, pour que les fonctions n'aient pas deux
 * façons de raconter la même panne.
 */
export class FalError extends Error {
  /** Le statut rendu à l'appelant. Une panne amont reste un 502 pour l'app. */
  readonly status: number;
  /**
   * Le statut du fournisseur, quand il en a rendu un.
   *
   * Il ne sort jamais vers l'appelant : un 403 de notre compte fal n'est pas un 403 de
   * l'utilisateur. Il sert à décider si un second essai a un sens, et c'est tout.
   */
  readonly upstreamStatus?: number;
  /**
   * **Pourquoi**, en un mot que l'app et les journaux peuvent compter.
   *
   * Le 21 octobre 2026, quarante-cinq « Ce thème n'a pas pu s'écrire » ont laissé la même
   * phrase dans les journaux sans dire si le fournisseur avait refusé, si le JSON était
   * tronqué ou si les notes étaient invalides. `provider`, `invalid_json`, `invalid_content`
   * et `timeout` tranchent, et partent dans le corps du 502 (`reason`) pour que l'app puisse
   * les compter de son côté.
   */
  readonly reason?: FailureReason;

  constructor(message: string, status = 502, upstreamStatus?: number, reason?: FailureReason) {
    super(message);
    this.status = status;
    this.upstreamStatus = upstreamStatus;
    this.reason = reason;
  }
}

export type FailureReason = "provider" | "invalid_json" | "invalid_content" | "timeout" | "config";
