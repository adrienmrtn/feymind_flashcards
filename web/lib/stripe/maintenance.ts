/**
 * **Le paiement web est ouvert.**
 *
 * À `true`, `startCheckout` refuse avant de regarder qui demande, quelle offre, ou si la clé
 * Stripe est posée : aucune session Checkout n'est créée, d'où que vienne l'appel. L'offre ne
 * montre alors plus de bouton d'achat : elle envoie vers l'App Store et Google Play, où Pro
 * s'achète avec le même compte, et laisse continuer vers l'app web pour la leçon offerte
 * (`StoreCheckout`). C'est ce qui a fermé le paiement du 14 octobre au 3 novembre 2026, le
 * temps de créer les douze prix de la grille par pays (`docs/revenuecat.md`, § 16).
 *
 * C'est une constante et non une variable d'environnement, à dessein : fermer ou rouvrir le
 * paiement est une décision qui se relit dans un commit, pas un réglage qu'on bascule par
 * erreur dans un tableau de bord. Le portail de gestion d'un abonnement existant ne dépend
 * pas de ce drapeau : il ne vend rien.
 *
 * Elle vit dans son propre module, sans `node:crypto` ni rien du serveur, pour que les
 * composants du navigateur (`PaywallOffer`, `DiscountCard`) puissent la lire aussi.
 */
export const CHECKOUT_MAINTENANCE = false;
