/**
 * **Les deux fiches de Micabo dans les boutiques**, écrites une fois.
 *
 * La vitrine, le pied de page, la page iPhone, le profil, le manifeste et la bannière Safari
 * lisent ces constantes : une adresse recopiée à six endroits finit par différer d'un
 * caractère, et c'est le lien qu'on ne reclique jamais qui meurt.
 *
 * L'adresse App Store ne porte **pas** de segment de pays (`/fr/`, `/my/`…) : sans lui, Apple
 * ouvre la boutique du pays de l'appareil. Avec, un visiteur français atterrissait dans la
 * boutique malaisienne.
 */
export const APP_STORE_ID = "6806651497";
export const APP_STORE_URL = `https://apps.apple.com/app/micabo/id${APP_STORE_ID}`;

export const PLAY_STORE_ID = "com.micabo.app";
export const PLAY_STORE_URL = `https://play.google.com/store/apps/details?id=${PLAY_STORE_ID}`;
