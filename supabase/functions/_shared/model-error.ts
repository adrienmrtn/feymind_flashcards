/**
 * Erreur d'écriture modèle. Le nom `FalError` est historique : Gemini
 * la relance avec le même statut, pour que les fonctions n'aient pas deux
 * façons de raconter la même panne.
 */
export class FalError extends Error {
  readonly status: number;

  constructor(message: string, status = 502) {
    super(message);
    this.status = status;
  }
}
