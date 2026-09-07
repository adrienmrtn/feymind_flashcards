# Le courriel, et pourquoi il a failli se fermer

Le 7 septembre 2026, Supabase a écrit que le projet `khuzodsrznanzhwlbjbx` renvoyait trop de
courriels et que le droit d'envoyer pouvait être suspendu. Ce fichier dit ce qui s'est passé,
ce que le code fait désormais, et ce qui reste à faire dans le tableau de bord — parce que
cette dernière partie ne peut pas être écrite dans un dépôt.

## Ce qui s'est passé

Micabo envoie ses liens de connexion par **l'envoyeur mutualisé de Supabase**
(`noreply@mail.app.supabase.io`). C'est un envoyeur de démonstration, partagé entre tous les
projets, et sa réputation est commune : un rebond chez l'un compte pour tout le monde.

Le volume du projet est minuscule — une poignée de liens envoyés depuis le 25 août, la
majorité des comptes arrivant par Apple et Google, qui n'envoient rien. C'est exactement ce
qui rend l'alerte facile à déclencher : **le taux de rebond est une fraction, et le
dénominateur tient sur une main.** Une seule adresse morte suffit à faire un pourcentage à
deux chiffres.

Les journaux d'authentification donnent la source principale :

| Quand | Adresse | Ce qui s'est passé |
|---|---|---|
| 5 sept. | `review2@apple.com` | Lien envoyé pour de bon. `apple.com` refuse les boîtes qu'il n'a pas : rebond dur. |
| 6 sept., 17 h 29 – 17 h 33 | — | Cinq `400 Unable to validate email address` en quatre minutes, depuis `17.185.64.85` (un appareil d'Apple), référent `micabo://auth-callback`. |

La séquence se lit toute seule : un relecteur de l'App Store, sur un iPhone, cherche
l'adresse qui ouvre le compte de démonstration. Les notes de relecture disent
`review@apple.com`. Il essaie des variantes. `review2@apple.com` n'est pas reconnue par
l'égalité stricte de `AppStoreReview.matches`, donc elle n'ouvre pas la session de
relecture — elle part comme une vraie demande de lien, chez Apple, qui la refuse.

Ce n'était donc pas un problème de volume ni de spam. C'était un chemin qui envoyait un
courriel là où il ne fallait rien envoyer du tout.

## Ce que le code fait maintenant

Trois changements, tous dans le dépôt, tous couverts par des tests.

**1. Aucun lien ne part chez Apple.** `isAppStoreReviewEmail` (site) et
`AppStoreReview.matches` (app) reconnaissent maintenant **tout le domaine `apple.com`** et
non la seule adresse des notes. Personne chez Apple ne relève une boîte pour essayer une app :
toute adresse de ce domaine ouvre la session de relecture. Ça n'ouvre rien de plus qu'avant —
le mot de passe est dans le paquet JavaScript du site depuis le premier jour, il faut qu'il y
soit pour que l'écran s'en serve.

**2. Les adresses sont triées avant l'envoi.** `web/lib/auth/email.ts` et son pendant
`Micabo/Services/Auth/EmailAddress.swift` classent en trois :

- **malformée** — GoTrue la refuserait aussi, autant l'annoncer sans faire l'aller-retour ;
- **impossible** — un domaine réservé par la RFC 2606 ou la RFC 6761 (`.test`, `.example`,
  `.invalid`, `.localhost`, `.local`, `.internal`) n'a pas de DNS, donc pas de boîte, donc un
  rebond garanti ;
- **douteuse** — `gmial.com` est un domaine valide, vendu, et qui garde le courrier qu'on lui
  donne. On ne bloque pas : on demande « tu voulais dire `gmail.com` ? », et **les deux
  réponses partent**. Personne ne peut jurer à la place de l'élève que ce n'est pas sa boîte,
  et bloquer enfermerait dehors les rares qui ont raison.

C'est le troisième cas qui compte le plus, parce que c'est le seul que l'élève ne voit pas
lui-même : il relit son adresse et la trouve juste. `type="email"` dans le navigateur ne
l'aide pas — il accepte `a@b`, il accepte `gmial.com`, il accepte `.test`. Il vérifie une
forme, pas une boîte.

**3. Les listes de référence sont générées, pas recopiées.** Les domaines connus, les
extensions ratées et les domaines réservés vivent dans le TypeScript et sont exportés en
Swift par `scripts/export-i18n-catalogs.ts` :

```bash
node --experimental-strip-types scripts/export-i18n-catalogs.ts
# ou, si le node local est plus ancien que la v22.15 :
./web/node_modules/.bin/tsx scripts/export-i18n-catalogs.ts
```

C'est délibéré. La dérive entre les deux plateformes est précisément ce qui a coûté le
premier rebond : le site et l'iPhone tenaient chacun leur idée de l'adresse des relecteurs
d'Apple, et les deux étaient trop étroites. **Une liste de référence n'a qu'une source.**

## Ce qui reste à faire, et que le dépôt ne peut pas faire

Le vrai correctif est celui que Supabase demande dans sa lettre : **sortir de l'envoyeur
mutualisé.** Tant qu'on y est, la réputation n'est pas la nôtre, le plafond n'est pas le
nôtre, et l'alerte peut revenir pour les rebonds de quelqu'un d'autre. La documentation de
Supabase est nette : l'envoyeur par défaut est prévu pour explorer et pour essayer des
gabarits, il est fortement plafonné, et il ne porte aucune garantie de livraison.

### 1. Brancher un envoyeur (le seul point vraiment urgent)

*Dashboard → Authentication → Emails → SMTP Settings.* Resend, Postmark, AWS SES, Brevo,
SendGrid et ZeptoMail conviennent tous. Il faut l'hôte, le port, l'utilisateur, le mot de
passe et une adresse d'expédition.

Après l'activation, Supabase repose un plafond bas (30 messages par heure) qu'il faut
remonter dans *Authentication → Rate Limits*.

À faire dans la foulée, chez l'envoyeur choisi :

- **SPF, DKIM et DMARC** sur le domaine d'envoi. Sans eux, une bonne partie des messages
  tombe en indésirable, et un message non lu finit par ressembler à un rebond.
- **Un sous-domaine dédié à l'authentification** (`auth.micabo.app`), séparé de tout envoi
  d'information ou de nouveautés. Si la réputation de l'un tombe, elle n'emporte pas l'autre.
- **Les rebonds durs sur le tableau de bord de l'envoyeur.** C'est là qu'on verra la
  prochaine adresse morte, adresse par adresse — ce que la lettre de Supabase ne donne pas.

### 2. Poser un CAPTCHA

*Dashboard → Authentication → Attack Protection.* Le garde-fou du code arrête les fautes de
frappe ; il n'arrête pas un robot qui déroule une liste d'adresses connues. Supabase décrit
ce scénario comme la source d'abus la plus courante, et le CAPTCHA invisible comme la parade
la plus efficace. Rien à faire tant que le trafic reste ce qu'il est, tout à faire le jour où
l'app est mise en avant.

### 3. Ne pas toucher aux confirmations

`mailer_autoconfirm` reste à `false`. Le désactiver ferait taire les rebonds en supprimant
les courriels — et ouvrirait la création de comptes au nom de n'importe qui.

## Comment relire les envois

Les journaux d'authentification gardent 24 heures. Ce qui est parti :

```sql
select
  log_attributes['mail_to']   as destinataire,
  log_attributes['mail_type'] as genre,
  log_attributes['mail_from'] as envoyeur
from logs
where source = 'auth_logs' and log_attributes['msg'] = 'mail.send'
order by timestamp desc
```

Tant que `mail_from` vaut `noreply@mail.app.supabase.io`, l'envoyeur mutualisé est encore en
place et le point 1 n'est pas fait.

Ce qui a été refusé avant de partir :

```sql
select timestamp, event_message
from logs
where source = 'auth_logs'
  and log_attributes['path'] = '/otp'
  and log_attributes['status'] != '200'
order by timestamp desc
```

Et les comptes nés d'un lien jamais ouvert — chacun est un rebond possible :

```sql
select email, created_at
from auth.users
where raw_app_meta_data->>'provider' = 'email'
  and confirmed_at is null
order by created_at desc
```

## Les adresses qui n'envoient jamais rien

Deux chemins ouvrent une session par mot de passe, sans courriel, et c'est voulu :

- **`@apple.com`** — la relecture de l'App Store, décrite plus haut ;
- **`@micabo.test`** — l'entrée de développement de `web/app/auth/dev/route.ts`, inerte en
  production. `.test` est réservé par la RFC 2606, donc l'adresse ne peut appartenir à
  personne, et le garde-fou la classe « impossible » avant tout envoi.
