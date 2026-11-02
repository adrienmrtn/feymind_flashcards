/**
 * **Le paiement web est fermé.**
 *
 * Tant que c'est vrai, `startCheckout` refuse avant de regarder qui demande, quelle offre,
 * ou si la clé Stripe est posée : aucune session Checkout n'est créée, d'où que vienne
 * l'appel. Et l'offre ne montre plus de bouton d'achat qui répondrait « en maintenance » :
 * elle envoie vers l'App Store et Google Play, où Pro s'achète avec le même compte, et laisse
 * continuer vers l'app web pour la leçon offerte (`StoreCheckout`).
 *
 * C'est une constante et non une variable d'environnement, à dessein : rouvrir le paiement
 * est une décision qui se relit dans un commit, pas un réglage qu'on bascule par erreur
 * dans un tableau de bord. Le portail de gestion d'un abonnement existant reste ouvert :
 * il ne vend rien.
 *
 * Elle vit dans son propre module, sans `node:crypto` ni rien du serveur, pour que les
 * composants du navigateur (`PaywallOffer`, `DiscountCard`) puissent la lire aussi.
 */
export const CHECKOUT_MAINTENANCE = true;
