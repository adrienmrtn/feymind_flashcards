/** The three content pages. Titles, excerpts, body: nothing left hardcoded. */
export const articlesEn = {
  shared: {
    navAria: "Pages",
    nextTitle: "Read next",
    ctaTitle: "Drop a course, see what it becomes.",
    ctaBody: "On the site and on iPhone, with the same account and the same plan.",
  },
  method: {
    metaTitle: "The method: spaced repetition and active recall",
    metaDescription:
      "Rereading a course does not make it stick. What you retrieve from memory does, especially if the question comes back just before you forget. How Micabo applies spaced repetition, with the real intervals.",
    h1: "Rereading is not enough. Remembering is.",
    lead1:
      "A page reread four times gives a feeling of mastery that does not survive the exam. What improves is recognition: “yes, I've seen this”. And recognition is not what an exam asks for.",
    lead2:
      "What holds is what you had to **retrieve from memory**, and what comes back **just before you forget it**. Two old ideas, measured for more than a century, and two ideas that are painful to apply by hand. That is all of Micabo's work.",
    activeTitle: "Active recall: the question before the answer",
    active1:
      "Testing yourself is more effective than rereading, even when you get it wrong. The effort of retrieval is what strengthens the trace: an answer you search for for three seconds is worth more than an answer you read in one.",
    active2:
      "That is also why a card carries **one thing to retrieve**. A card that asks for five items at once cannot be graded: you recall three, and there is no button for “three fifths”.",
    spacingTitle: "Spacing: coming back at the last useful moment",
    spacing1:
      "Without review, what you retain from a course falls to almost nothing in a month. Each recall resets the counter to a hundred, and the drop that follows is **slower than the previous one**. Reviewing at the right moment does not take more time: it takes less, as memory stabilizes.",
    spacing2:
      "What matters is not the shape of each curve, it is **where they split**: the first review. What spaced repetition automates is the choice of that instant, card by card.",
    plannerTitle: "What Micabo calculates on every rating",
    planner1:
      "Micabo schedules with **SM-2**, Anki's rule in its default settings. A new card goes through short steps, {steps}, before graduating to days. After that, each rating multiplies the interval by an ease that belongs to the card, starting at {ease} and moving with your answers.",
    planner2:
      "Four buttons, not two: “I know / I don't” does not distinguish the card retrieved with effort from the one that came on its own, and that gap is exactly what decides the next date. Here is what the four buttons announce on a new card:",
    buttonsCaption: "The intervals are computed by the app's scheduler, not written by hand.",
    planner3:
      "The interval is written on the button **before** you press it. A scheduler that decides on its own is quickly disobeyed: you rate “easy” to go faster, the card leaves for three weeks, and you rediscover it on exam day.",
    stepMinutes: "{n} min",
    stepJoin: ", then ",
    paceTitle: "Pace: what the workload asks for, not a quota",
    pace1:
      "Micabo asks neither for a number of cards per day nor for a budget of minutes. It looks at what your deadlines require today, serves all of it, and tells you how long it will take. A student sees about {seen} cards in an hour.",
    pace2:
      "There used to be a cap on new cards, calibrated on the {reps} passes a card needs before it sticks. It had one decisive flaw: three days before a midterm, it turned down cards from that very midterm in the name of the day's pace. Holding back work on the day it matters most is the wrong job.",
    paceNote:
      "What the plan spreads out are the passes until exam day. A missed day therefore leaves no hole: it shifts, and the plan is rebuilt on the next calculation.",
    sheetTitle: "The sheet first, the cards after",
    sheet1:
      "A card assumes you already understood. Testing yourself on a notion you have not read is learning an answer by heart without knowing what it is about: the card will be right, and the exam will not.",
    sheetFigure:
      "The dropped document becomes **a sheet**: the course put back in order, the passages that matter marked. The cards come out of it next. This is the same sheet component as in the app, on the demo course.",
    sheet2:
      "That is why Micabo first writes **the sheet** from your document: the course put back in order, the passages that matter marked. The cards are drawn from that sheet, not from the raw document. You read, then you test yourself.",
    sheet3:
      "Micabo never defines a term the document does not mention. When the context does not decide, the doubtful word does not appear on the sheet: an invented definition is perfectly credible, and that is what makes it dangerous.",
    formatsTitle: "Four ways to be questioned on the same sheet",
    formats1:
      "Active recall is not limited to front and back. On one sheet, Micabo asks quizzes, fill-in-the-blanks and cards, and composes graded mock exams. The questions come from your documents, and the scheduler treats them all the same way: an answer you retrieve pushes the next one further out.",
    formatsFigure:
      "A quiz is recognized by its bullets, a fill-in-the-blank by its empty line, a card by its silent front. **All four formats are drawn from the same sheet**, and graded on the same scale.",
    limitsTitle: "What the method does not do",
    limits1:
      "Spaced repetition places the reviews. It does not understand for you, it does not write an essay, and it does not catch up a chapter started the night before: there is no possible spacing over one night.",
    limits2:
      "It also ignores dates, by design: SM-2 does not know an exam is in three weeks. That is exactly what [[exam]] is here to fix.",
    examLink: "exam mode",
  },
  exam: {
    metaTitle: "Exam mode: set the date, the plan tightens",
    metaDescription:
      "Spaced repetition ignores exam day. Micabo's exam mode gives it a deadline, tightens the passes as the test approaches, and stops a card from leaving past that date.",
    h1: "You set the date. Micabo reorganizes everything.",
    lead1:
      "Spaced repetition places each card at the last useful moment, indefinitely. It does not know there is an exam on the 14th. A card rated “easy” today leaves for three weeks, even if the test is in ten days, and it will not come back before.",
    lead2:
      "Exam mode gives the scheduler what it is missing: **a deadline**, and the grade you are aiming for. You set exam day, it replans the deck around it.",
    trapTitle: "Why a normal schedule gets trapped",
    trap1:
      "A deck of two hundred cards in spaced review is perfect for continuous assessment and bad for a fixed date. Three things go wrong: some cards fall after the exam, others were never introduced, and the weakest ones come back too early to be useful on exam day.",
    trap2:
      "The manual answer is to review the whole deck the night before. That is exactly what the method avoids: a session of three hundred cards in one evening leaves nothing the next day, and you know it before you start.",
    capTitle: "No card leaves past exam day",
    cap1:
      "This is the rule that holds everything together, and it is more radical than it looks. During an active exam, the interval a card receives is **capped at the exam date**.",
    cap2:
      "Without this cap, the first good answer undoes the plan: the card leaves for three weeks and drops out of view. With it, it comes back one last time before exam day. The intervals shown under the buttons are therefore shorter than usual, and the session says so at the top of the screen, otherwise you would think the scheduler was broken.",
    planTitle: "The plan, announced before it is applied",
    plan1:
      "Micabo shows the projection **before** moving anything: how many cards are covered, how many passes are placed, over how many days. A replan you discover after the fact is a replan you undo.",
    plan2:
      "The load tightens toward the end without stacking on the night before: the last passes spread over the last {days} days, staggered from one card to the next.",
    dailyTitle: "Every day carries named work",
    daily1:
      "A plan that says “review for 30 minutes” is no different from a timer. Micabo's plan says what there is to do: a quiz on chapter 3, a mock exam, an explanation out loud, a day off. You open the app, and the day is already written.",
    dailyFigure:
      "The plan reads in the order of time, and the last line is the exam. **A missed day shifts the work, it does not dig a hole**: the plan is rebuilt on the next calculation.",
    intensityTitle: "Three intensities, according to the grade you want",
    intensityLead:
      "How many times each card should come back before the exam is not the same question for “I want to pass” and for “I want the top mark”. You set the target grade, Micabo derives the intensity:",
    intensityLight: "Light",
    intensityStandard: "Normal",
    intensityIntense: "Intensive",
    intensityPasses: "passes per card",
    intensityScale:
      "The grade scale follows the country you study in: a French 20, a Quebec 100 and a British A-Level do not compare, and a slider that would work everywhere would mean nothing anywhere.",
    severalTitle: "Several exams, several courses",
    several1:
      "An exam covers the courses you give it, and a course can be in several exams. When two dates compete for the same card, **the nearest one** caps it: it is the first constraint, and honoring the second first would miss both.",
    severalNote:
      "Once exam day has passed, the exam stops constraining and the deck returns to its normal schedule. Nothing to turn off: a date that has passed is no longer a date.",
    limitsTitle: "What exam mode does not do",
    limits1:
      "It does not manufacture time. Declaring an exam for tomorrow on two hundred new cards gives an honest and unsustainable plan, and Micabo shows it as it is rather than reassuring you.",
    limits2:
      "It does not replace the method either: [[method]] do the work, exam mode only gives them a deadline. If you are coming from Anki, the [[anki]] says exactly what changes.",
    methodLink: "active recall and spacing",
    ankiLink: "comparison",
  },
  anki: {
    metaTitle: "Micabo or Anki: what actually changes",
    metaDescription:
      "Anki is open, proven, and excellent. Micabo writes the cards from your course and replans everything around an exam date. An honest comparison, including where Anki wins.",
    eyebrow: "Comparison",
    h1: "Micabo or Anki: what actually changes",
    lead1:
      "Anki is a very good program. It is open, it has twenty years of track record and a community that has documented everything. If you already use it and it works for you, you have no reason to switch.",
    lead2:
      "The difference is not in the scheduling: **it is the same SM-2**. It is before, in the time it takes to have cards, and after, in what happens when an exam date lands.",
    tableTitle: "Line by line",
    tableLead: "Three lines go to Anki, and they are written as they are.",
    tableCaption: "Comparison of Micabo and Anki, criterion by criterion.",
    colCriterion: "Criterion",
    rowAlgo: "The algorithm",
    rowAlgoMicabo: "SM-2, with Anki's default settings.",
    rowAlgoAnki: "SM-2 historically, FSRS today, and both can be configured.",
    rowWrite: "Writing the cards",
    rowWriteMicabo: "The course becomes a sheet, the sheet becomes cards. You reread and you correct.",
    rowWriteAnki: "That's on you. That is where most of the time goes.",
    rowDate: "An exam date",
    rowDateMicabo: "The deck replans around exam day, and nothing leaves past it.",
    rowDateAnki: "No notion of a deadline. You advance the deck by hand.",
    rowQuestions: "Ways to be questioned",
    rowQuestionsMicabo: "Cards, quizzes, fill-in-the-blanks, graded mock exams, explaining out loud.",
    rowQuestionsAnki: "Front and back, and the card types you build yourself.",
    rowPlatforms: "The platforms",
    rowPlatformsMicabo: "iPhone and browser, the same account on both sides.",
    rowPlatformsAnki: "Computer, Android, iPhone, browser.",
    rowDecks: "Ready-made decks",
    rowDecksMicabo: "No catalog. Your courses, and the ones your friends share.",
    rowDecksAnki: "Thousands of public decks, of uneven quality.",
    rowFriends: "Your classmates' courses",
    rowFriendsMicabo: "A shared course is picked up in one gesture, and becomes yours.",
    rowFriendsAnki: "A file to send each other.",
    rowStart: "Getting started",
    rowStartMicabo: "A document dropped, a sheet to read, a session that same evening.",
    rowStartAnki: "Settings to understand before the first card.",
    costTitle: "What Anki really costs: time",
    cost1:
      "A useful Anki deck for a college course is two to four hours of typing per chapter: splitting, writing one question per idea, not stacking five items on a card. That work is instructive, and denying it would be dishonest. But it is the work that makes you open Anki in September and not again in November.",
    costFigure:
      "Handout, photos, Word, PowerPoint, video, audio: **everything goes in as it is**, and so does an Anki deck. The typing disappears, the rereading stays.",
    cost2:
      "Micabo takes that step. The course becomes a sheet put back in order, then cards drawn from that sheet. You reread, you correct what is wrong, you delete what does not help. It is still your work, but it starts at rereading instead of starting at a blank page.",
    costNote:
      "The downside is real: a generated card can be poorly worded or drawn from a badly read scan. That is why the sheet comes before the cards, and why Micabo does not define a term the document does not mention. A sheet that is wrong does not look like a mistake.",
    dateTitle: "What Anki does not do: the date",
    date1:
      "This is the real mechanical difference. Spaced repetition places each card at the last useful moment, without end. It does not know there is an exam on the 14th: a card rated “easy” leaves for three weeks and does not come back before the test.",
    date2:
      "In Anki, you get by advancing the deck by hand, or by reviewing everything the night before. In Micabo, you set the date and the deck replans around it, with a cap that stops a card from leaving past exam day. [[exam]] explains how.",
    examLink: "Exam mode",
    pickTitle: "Which one to pick",
    pickAnki:
      "**Stay on Anki** if you like tuning your scheduler, if you want FSRS, if you are on Android, or if you want an open tool whose files you own.",
    pickMicabo:
      "**Try Micabo** if what is blocking you is not the review but making the cards, or if your reviews are organized around exam dates rather than a continuous stream.",
    pickBoth:
      "And if you are unsure: [[method]] is the same in both. That is what does the work, not the software that carries it.",
    methodLink: "the method",
  },
} as const;
