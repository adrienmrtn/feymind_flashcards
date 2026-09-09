import {
  DEFAULT_SHEET_LENGTH,
  entitlement,
  isSheetLength,
  sheetLanguage,
} from "@micabo/core";
import Link from "next/link";

import { DeleteAccount } from "@/components/app/DeleteAccount";
import { ExportData } from "@/components/app/ExportData";
import { FeedbackCard } from "@/components/app/FeedbackCard";
import { ProfileSettings } from "@/components/app/ProfileSettings";
import { ReplayOnboarding } from "@/components/app/ReplayOnboarding";
import { ReplayPaywallOnboarding } from "@/components/app/ReplayPaywallOnboarding";
import { ReplayTour } from "@/components/app/ReplayTour";
import { ReadingSizeRow } from "@/components/app/settings/ReadingSizeRow";
import { SettingsGroup, SettingsRow } from "@/components/app/settings/Rows";
import { AppearanceSwitcher } from "@/components/appearance/AppearanceSwitcher";
import { LanguageSwitcher } from "@/components/i18n/LanguageSwitcher";
import { T } from "@/components/i18n/T";
import { SheetLanguageCard } from "@/components/app/SheetLanguageCard";
import { SubscriptionCard } from "@/components/app/SubscriptionCard";
import { readEntitlement } from "@/lib/data/entitlement";
import { readProfile } from "@/lib/data/profile";
import { currentUser } from "@/lib/data/user";
import { canReadInbox } from "@/lib/feedback";

/**
 * Les réglages : **quatre groupes, une ligne par réglage.**
 *
 * L'écran a d'abord été dix cartes en vrac, puis trois sections de cartes. La deuxième version
 * rangeait les intentions mais gardait le défaut de la première : chaque réglage restait une
 * carte de sa taille dans une grille à deux colonnes, donc le mur de matières prenait la
 * moitié d'une page pour une question qu'on règle une fois l'an, et un formulaire de retours
 * déplié faisait un trou de onze lignes en face de l'abonnement. Il fallait deux mille deux
 * cents pixels pour dire trois choses.
 *
 * Les groupes répondent à quatre intentions : **ton étude** est ce qui change ce que l'app
 * t'écrit, **l'app** est son apparence et sa langue, **ton compte** est l'abonnement et les
 * données, **l'aide** est ce qu'on rejoue quand on a raté quelque chose. Et à l'intérieur,
 * chaque réglage est une ligne - intitulé à gauche, commande à droite, alignée avec les
 * autres. Ce qui est large (les matières, le curseur, la recherche d'école) descend sous son
 * intitulé au lieu de comprimer la colonne.
 */
export default async function SettingsPage() {
  const [user, profile, right] = await Promise.all([
    currentUser(),
    readProfile(),
    readEntitlement(),
  ]);

  const handle = profile?.username ?? "";

  return (
    <>
      <header>
        <h1 className="page-title">
          <T k="settings.title" />
        </h1>
        <p className="page-lead">
          <T k="settings.lead" />
        </p>
      </header>

      <ProfileSettings
        initialName={profile?.display_name ?? ""}
        initialUsername={handle}
        initialLength={
          isSheetLength(profile?.sheet_length) ? profile.sheet_length : DEFAULT_SHEET_LENGTH
        }
        initialSubjects={Array.isArray(profile?.subjects) ? profile.subjects : []}
        initialSchool={profile?.institution_name ?? ""}
        initialSchoolId={profile?.institution_id ?? null}
        initialCountry={profile?.country_code}
      >
        <SheetLanguageCard
          initial={sheetLanguage(profile?.sheet_language, profile?.country_code)}
        />
      </ProfileSettings>

      <SettingsGroup
        icon="🎨"
        title={<T k="settings.section.app" />}
        hint={<T k="settings.section.appHint" />}
      >
        <LanguageSwitcher variant="row" />
        <AppearanceSwitcher />
        <ReadingSizeRow />
      </SettingsGroup>

      <SettingsGroup
        icon="👤"
        title={<T k="settings.section.account" />}
        hint={<T k="settings.section.accountHint" />}
      >
        <SubscriptionCard
          paid={entitlement.isPaid(right)}
          store={right.store ?? null}
          periodType={right.periodType ?? null}
          expiresAt={right.expiresAt ? right.expiresAt.toISOString() : null}
          willRenew={Boolean(right.willRenew)}
          productId={right.productId ?? null}
        />
        <ExportData />
        <DeleteAccount email={user?.email ?? ""} />
      </SettingsGroup>

      <SettingsGroup
        icon="🛟"
        title={<T k="settings.section.help" />}
        hint={<T k="settings.section.helpHint" />}
      >
        <FeedbackCard />
        <ReplayTour />
        <ReplayOnboarding />
        <ReplayPaywallOnboarding />
        {canReadInbox(user?.email) ? (
          <SettingsRow
            label={<T k="app.settings.inbox.title" />}
            hint={<T k="app.settings.inbox.body" />}
            control={
              <Link
                href={"/app/retours" as never}
                className="pressable flex h-10 items-center rounded-button bg-surface-muted px-4 text-[13.5px] font-medium text-ink"
              >
                <T k="app.settings.readFeedback" />
              </Link>
            }
          />
        ) : null}
      </SettingsGroup>
    </>
  );
}
