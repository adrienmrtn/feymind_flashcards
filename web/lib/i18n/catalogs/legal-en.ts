/** The two legal pages. Legal “you” — not the informal voice of the rest of the site. */

export const legalEn = {
  backHome: "Back to home",
  eyebrow: "Micabo · iPhone and site",
  updated: "Last updated: {date}.",
  updatedDate: "2 September 2026",
  privacy: {
    metaTitle: "Privacy",
    metaDescription:
      "What Micabo keeps about you, on iPhone and on the site, and what you can do with it.",
    heading: "Privacy policy",
    linkLabel: "privacy policy",
    intro1:
      "This policy describes the data Micabo processes when you use the site [[site]] or the iPhone app (identifier {bundle}). Both clients share the same account and the same database. It also applies if you do not yet have an account and are only browsing the site.",
    intro2:
      "The controller is {editor}. For any question, correction or deletion: [[contact]].",
    whatTitle: "What Micabo is",
    whatBody:
      "Micabo turns a course (PDF, photo, document, video) into a sheet and flashcards, then brings them back before you forget them. An exam mode tightens revision as a date approaches. You can share a course with friends, or keep it to yourself.",
    dataTitle: "What data we process",
    dataAccount:
      "**The account.** Email address, identifiers provided by Apple or Google if you choose those sign-in methods, and a username. We do not store your password: email sign-in uses a link, not a secret we would keep.",
    dataSchool:
      "**The academic path.** Country of study, level, subjects, and school if you give it. This is used to write the sheet in the right language and the right system, and to show you classmates from the same school if a course is shared.",
    dataCourses:
      "**Your courses.** The files or links you upload, the text extracted from them, the generated sheets and cards, diagram images, exams (name, date, target grade) and the revision history (when a card comes back, how you rated it).",
    dataFriends:
      "**Friends.** Friend requests, your friends list, and the visibility you set on each course at import: you only, your friends, or classmates at your school. There is no public catalogue where a stranger would stumble on your sheets.",
    dataSubscription:
      "**The subscription.** The status of your Pro access (active, trial, cancelled), not your card number. Payment is collected by Apple on iPhone, by Stripe on the site. RevenueCat holds the right, so that the iPhone and the browser agree.",
    dataWaitlist:
      "**The waitlist.** If you leave your address before you have an account, we keep it to notify you of the opening, together with the page you came from. It is not linked to an account and is not visible through the app.",
    dataFeedback:
      "**Feedback.** If you send a bug or an idea from the app, we keep the message, the type (bug or idea), and the link to your account, so we can reply. They are kept for 24 months, then deleted. They are not used to profile you.",
    dataUsage:
      "**Generation usage.** A counter per day and per function (sheet, cards, explanation), without the course content. It is used to limit abuse, not to profile you.",
    dataDirectory:
      "**The directory.** Your username and, if you have given it, your school. That is what a friend or classmate sees, not your email or your preferences.",
    dataDevice:
      "**What stays on the device.** On iPhone, some pieces (occlusion images, audio for a card) may never leave the phone. Answers from the onboarding path stay on the device first, then are written to the database once the account is opened.",
    dataNoSell:
      "We do not sell your data. We do not show advertising. We do not train a language model on your courses, unless an explicit setting offers that one day — and that setting does not exist today.",
    whyTitle: "Why we process them",
    whyLead: "The legal bases, within the meaning of the GDPR:",
    whyContract:
      "**Performance of the contract** — creating the account, importing a course, writing the sheet and the cards, reviewing them, syncing iPhone and site, managing the subscription.",
    whyLegitimate:
      "**Legitimate interest** — securing the service, preventing abuse, diagnosing a fault, measuring the site's audience in aggregated form, and reading the feedback you send us. This interest does not come before yours: the isolation is in the database, not only in the application.",
    whyLegal:
      "**Legal obligation** — retaining what billing or accounting require, for the prescribed time.",
    whyConsent:
      "**Consent** — when you choose to share a course, open the camera, or sign in with Apple or Google.",
    accessTitle: "Who has access",
    accessBody:
      "Your courses are readable only by you, unless you have shared them. Every request to the database is evaluated with your identity: there is no query that can ask for someone else's courses. Feedback you send is read by the team, at [[contact]]. Nobody else has access to it from the application.",
    accessLead:
      "Service providers see some of the data, solely to provide the service:",
    accessSupabase:
      "**Supabase** (European Union, Stockholm region) — account, database, files.",
    accessVercel:
      "**Vercel** — hosting of the site, technical logs (IP address, URL) and audience measurement: the number of page views, the page you came from, the country and the device type, without a cookie and without an identifier that follows you. Processing may take place outside the European Union, under the provider's standard contractual clauses.",
    accessApple:
      "**Apple and Google** — if you sign in with them, or if you pay on the App Store.",
    accessStripe: "**Stripe** — payment on the site.",
    accessRevenuecat:
      "**RevenueCat** — subscription status, shared between iPhone and site.",
    accessFal:
      "**fal.ai and the models it calls** (today, language models, notably from Google) — the text or image of your course, for the time it takes to write the sheet or the cards. They are not allowed to use it for anything other than that generation.",
    accessYoutube:
      "**YouTube / Google** — if you import a video, we read its metadata and subtitles.",
    accessTransfer:
      "Some of these providers are established outside the European Union. The transfer then takes place only to provide the service, and relies on the safeguards provided by the GDPR (adequacy decision or the provider's standard contractual clauses).",
    cookiesTitle: "Cookies and trackers",
    cookiesWeb:
      "The site sets the cookies needed for the session (to recognise you from one page to the next once you are signed in) and an interface-language preference cookie (`micabo.ui_locale`), kept for one year, which remembers English, French, German, Spanish or Turkish. We do not set an audience-measurement cookie, nor an advertising cookie, nor cross-site tracking. The site does count its visits, but without writing anything on your device: the measurement keeps a page view, its origin, a country, a device type, and nothing that would let us recognise you from one visit to the next or on another site. That is why there is no consent banner: there is nothing to refuse on that side.",
    cookiesIos:
      "The iPhone does not use cookies. It keeps a session token in the device's Keychain.",
    retentionTitle: "How long we keep them",
    retentionWhile:
      "For as long as the account exists. Feedback is deleted after 24 months at the latest. If you delete it, from Settings on the site or in the iPhone app, or by writing to us, we erase the profile, the courses (including the extracted text), the sheets, the cards, the history, the exams, the friendships, the usage counters, the feedback and any address left on the waitlist.",
    retentionShared:
      "A course you have shared disappears for your friends when you delete it. A friend who has already reviewed your cards keeps their own history, not your document.",
    retentionAfter:
      "After deletion, providers retain what the law or their contract requires: Stripe or Apple invoices, a RevenueCat subscription identifier, technical logs (Vercel, Supabase) for a few weeks. fal.ai receives the text for the time it takes to write the sheet; we do not ask it to keep it.",
    rightsTitle: "Your rights",
    rightsBody:
      "You can access your data, correct it, export it, object to processing, or request erasure. To download a copy: Settings → “Download my data”. To delete the account: Settings → “Delete account”, on the site or in the iPhone app. You can also write to [[contact]]. We reply within a month.",
    rightsCnil: "You can also lodge a complaint with the CNIL (cnil.fr).",
    minorsTitle: "Minors",
    minorsBody:
      "Micabo is aimed at students, including those in secondary school. We do not ask for a date of birth. If you are under fifteen, use of the service must be with the agreement of a person with parental authority. We do not use a minor's data for advertising, nor for commercial profiling.",
    iosTitle: "The iPhone, in addition to the site",
    iosBody:
      "The app may ask for access to your photos or camera to import a course. This is not required: the site accepts an uploaded file. Notifications, if you allow them, are only used to remind you of a review. The same account opens the app and the site.",
    changesTitle: "Changes",
    changesBody:
      "If this policy changes in a material way, we update the date at the top of the page. Continued use after that date applies to the new version, unless the law requires a separate agreement.",
    changesAlso: "The [[terms]] complement this text.",
  },
  terms: {
    metaTitle: "Terms of use",
    metaDescription:
      "The rules of the Micabo service, for iPhone and the site: account, courses, subscription, liabilities.",
    heading: "Terms of use",
    linkLabel: "terms of use",
    intro1:
      "These terms govern the use of Micabo — the site [[site]] and the iPhone app ({bundle}). By creating an account or using the service, you accept them. If you do not agree, do not open an account.",
    intro2: "The publisher is {editor}. Contact: [[contact]].",
    serviceTitle: "The service",
    serviceBody:
      "Micabo reads a course document you upload and writes a sheet and flashcards from it. It brings them back according to spaced repetition (the same SM-2 rule on iPhone and on the site). You can set an exam date: the revision plan then tightens towards that day. The same account opens both clients.",
    servicePro:
      "Part of the service is available without a subscription. Pro access (courses and cards beyond the free cap, according to the offer shown at the time of purchase) is paid.",
    accountTitle: "The account",
    accountBody:
      "You can sign in with Apple, Google, or a link sent by email. You are responsible for access to your mailbox and to those third-party accounts. One account per person.",
    accountDelete:
      "You can delete the account from Settings, on the site or in the iPhone app. This erases your courses, your cards and your history. Purchases already collected by Apple or Stripe remain subject to their refund rules.",
    coursesTitle: "Your courses",
    coursesOwn:
      "You keep ownership of what you upload. You give us only the limited, revocable right to read it, store it and transform it into a sheet and cards, to provide you the service — including by sending it to a language model for the duration of the generation.",
    coursesRights:
      "You upload only documents you have the right to use. A handout from your teacher, your notes, a video whose import is authorised: yes. An entire copied work, someone else's assignment, illegal content: no. We may remove a course or close an account that breaks this rule.",
    coursesShare:
      "Visibility is decided at import. A private course stays with you. A shared course is visible only to the people you have chosen (friends, or classmates at the school). This is not a library open to everyone.",
    notTitle: "What Micabo is not",
    notBody:
      "The sheet and the cards are generated automatically. They can be wrong, omit a passage, or misread a scan. Micabo is not a teacher, nor a grade guarantee. You remain responsible for what you learn and for what you submit on exam day.",
    notInvent:
      "We try not to invent a definition when the document does not carry one. That does not make the result infallible.",
    subTitle: "The subscription",
    subPrices:
      "Prices, duration and any trial are those shown before payment. They may change for new purchases; a subscription already in progress keeps its terms until renewal.",
    subIos:
      "**On iPhone**, payment goes through the App Store. Cancellation, renewal and refunds follow Apple's rules. Manage the subscription in your Apple account settings.",
    subWeb:
      "**On the site**, payment goes through Stripe. Cancellation is done from the billing area indicated in the profile, or by writing to us. A trial, if offered, only becomes a charge if you let it run to the end.",
    subBoth:
      "Pro access bought on one side applies on the other: the same account is Pro on iPhone and on the site. A payment incident may open a grace period; we do not close access in the first hour.",
    forbidTitle: "What you do not do",
    forbidHarm:
      "Use the service to harm someone, harass, or cheat in a way that violates your school's rules.",
    forbidAccess:
      "Attempt to access another account's courses, to circumvent the isolation, or to deliberately overload the service.",
    forbidResell:
      "Resell access, extract the service through a bot beyond normal human use, or copy Micabo to make a competing product from our generations.",
    forbidIllegal:
      "Upload illegal or hateful content, or content that infringes someone else's privacy.",
    availTitle: "Availability",
    availBody:
      "We do our best to keep iPhone and site reachable. Maintenance, a provider outage (host, model, store) or a generation error may interrupt the service. We do not offer a guarantee of academic results, nor of uninterrupted availability.",
    liabilityTitle: "Liability",
    liabilityConsumer:
      "If you are a consumer, your statutory rights (warranty, mediation, unfair terms) apply and these terms do not set them aside.",
    liabilityLimit:
      "Beyond that, Micabo is not liable for grades obtained, an incomplete sheet, forgetting on the day, or indirect damage (lost time, a missed exam). Our liability, if it were upheld for a breach attributable to us, is limited to the amount you paid us over the last twelve months — except in cases of gross negligence, fraud, or injury to a person's physical integrity.",
    minorsTitle: "Minors",
    minorsBody:
      "If you are under fifteen, a person with parental authority must accept these terms and supervise use. Sharing a course with friends remains your responsibility, and theirs.",
    lawTitle: "Governing law",
    lawBody:
      "These terms are governed by French law. In the event of a dispute, and after an attempt at written resolution to [[contact]], the French courts have jurisdiction — subject to any consumer-protection rules that would be more favourable to you.",
    changesTitle: "Changes",
    changesBody:
      "We may update these terms. The date at the top of the page is authoritative. A change that affects the price of a subscription in progress is announced to you before renewal.",
    changesAlso: "The [[privacy]] describes the processing of your data.",
  },
} as const;
