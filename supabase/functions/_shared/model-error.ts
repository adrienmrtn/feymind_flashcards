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

  constructor(message: string, status = 502, upstreamStatus?: number) {
    super(message);
    this.status = status;
    this.upstreamStatus = upstreamStatus;
  }
}
