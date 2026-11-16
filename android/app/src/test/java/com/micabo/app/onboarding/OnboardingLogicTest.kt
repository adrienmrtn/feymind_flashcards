package com.micabo.app.onboarding

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.Locale

/**
 * **La logique du parcours, portée de l'iPhone** : les dates de l'essai, le plafond d'une heure
 * des séances, le récit par pays, la reprise d'un parcours sur un écran retiré, les sauts.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class OnboardingLogicTest {

    // MARK: Les dates de l'essai

    private val zones = listOf("Europe/Paris", "America/Los_Angeles", "Pacific/Auckland", "Asia/Tokyo", "America/Sao_Paulo", "UTC")

    @Test
    fun trialEndsThreeDaysLaterAndTheReminderTheDayBefore() {
        val now = Instant.parse("2026-11-12T21:30:00Z").toEpochMilli()
        val end = TrialDates.end(now, 3)
        val reminder = TrialDates.reminder(now, 3)
        assertEquals(now + 3 * 86_400_000L, end)
        assertEquals(end - 86_400_000L, reminder)
    }

    @Test
    fun trialDatesAreTheSameDayInEveryTimeZone() {
        // Le paywall et l'écran du rappel lisent la même source : la fin, le jour du calendrier
        // de l'élève, trois jours après l'achat, dans son fuseau.
        val now = Instant.parse("2026-11-12T23:30:00Z").toEpochMilli()
        for (id in zones) {
            val zone = ZoneId.of(id)
            val today = Instant.ofEpochMilli(now).atZone(zone).toLocalDate()
            val end = Instant.ofEpochMilli(TrialDates.end(now, 3)).atZone(zone).toLocalDate()
            val reminder = Instant.ofEpochMilli(TrialDates.reminder(now, 3)!!).atZone(zone).toLocalDate()
            assertEquals("fin, $id", today.plusDays(3), end)
            assertEquals("rappel, $id", today.plusDays(2), reminder)
        }
    }

    @Test
    fun theDayTextIsWrittenInTheGivenTimeZone() {
        // 23 h 30 à Paris le 14 novembre est déjà le 15 à Auckland : la date suit le fuseau donné.
        val at = Instant.parse("2026-11-14T22:30:00Z").toEpochMilli()
        assertTrue(TrialDates.dayText(at, Locale.FRANCE, ZoneId.of("Europe/Paris")).startsWith("14"))
        assertTrue(TrialDates.dayText(at, Locale.FRANCE, ZoneId.of("Pacific/Auckland")).startsWith("15"))
        assertTrue(TrialDates.dayText(at, Locale.FRANCE, ZoneId.of("Europe/Paris")).contains("novembre"))
    }

    @Test
    fun aOneDayTrialHasNoReminder() {
        val now = System.currentTimeMillis()
        assertNull(TrialDates.reminder(now, 1))
        assertNull(TrialDates.reminder(now, 0))
        assertNotNull(TrialDates.reminder(now, 2))
    }

    // MARK: Les séances d'une heure au plus

    @Test
    fun focusSessionsNeverExceedOneHour() {
        for (minutes in DailyLoad.steps + listOf(0, 1, 200, 500)) {
            val sessions = FocusPlan.sessionLengths(minutes)
            assertTrue("$minutes min : $sessions", sessions.all { it in FocusPlan.MIN_SESSION..FocusPlan.MAX_MINUTES })
        }
    }

    @Test
    fun beyondAnHourThePlanIsSplit() {
        assertEquals(listOf(45), FocusPlan.sessionLengths(45))
        assertEquals(listOf(60), FocusPlan.sessionLengths(60))
        assertEquals(listOf(40, 40), FocusPlan.sessionLengths(75))
        assertEquals(listOf(45, 45), FocusPlan.sessionLengths(90))
        assertEquals(listOf(60, 60), FocusPlan.sessionLengths(120))
        assertEquals(listOf(15), FocusPlan.sessionLengths(5))
    }

    @Test
    fun oldDurationsAreBroughtBackToSixty() {
        assertEquals(60, FocusPlan.clamp(90))
        assertEquals(60, FocusPlan.clamp(120))
        assertEquals(25, FocusPlan.clamp(25))
    }

    @Test
    fun theFocusDemoShowsTheRealXp() {
        assertEquals(25, FocusPlan.demoMinutes(15))
        assertEquals(45, FocusPlan.demoMinutes(45))
        assertEquals(40, FocusPlan.demoXp(15))
        assertEquals(40, FocusPlan.demoXp(45))
        assertEquals(80, FocusPlan.demoXp(60))
    }

    // MARK: Le récit d'exemple selon le pays

    @Test
    fun theStoryFollowsTheCountry() {
        val expected = mapOf(
            "fr" to HistoryStory.france, "uk" to HistoryStory.uk, "us" to HistoryStory.us, "de" to HistoryStory.germany,
            "it" to HistoryStory.italy, "es" to HistoryStory.spain, "pt" to HistoryStory.portugal, "pl" to HistoryStory.poland,
            "tr" to HistoryStory.turkey, "be" to HistoryStory.world, "ma" to HistoryStory.world, "ro" to HistoryStory.world,
        )
        for ((country, story) in expected) assertEquals(country, story, HistoryStory.of(country, Countries.regionCode(country)))
        assertEquals(HistoryStory.germany, HistoryStory.of("other", "DE"))
        assertEquals(HistoryStory.uk, HistoryStory.of("other", "GB"))
        assertEquals(HistoryStory.world, HistoryStory.of("other", "JP"))
        assertEquals(HistoryStory.world, HistoryStory.of("other", null))
    }

    @Test
    fun franceKeepsItsRevolution() {
        assertEquals("ios.onb14.story.lesson", HistoryStory.france.lessonKey)
        assertEquals("1789", HistoryStory.france.rightYear)
        assertEquals("ios.onb16.story.uk.lesson", HistoryStory.uk.lessonKey)
        assertEquals("1215", HistoryStory.uk.rightYear)
        assertEquals("1989", HistoryStory.germany.rightYear)
    }

    // MARK: La reprise

    @Test
    fun aRemovedStepResumesOnItsReplacement() {
        val store = MemoryOnboardingStore()
        store.putString("onb.name", "Lina")
        store.putString("onb.step", "notJustChat")
        val model = OnboardingModel(store = store, deviceLanguages = listOf("fr-FR"), deviceRegion = "FR")
        model.resume()
        assertEquals(OnboardingStep.research, model.step)
        assertTrue(model.isResumed)
    }

    @Test
    fun everyRetiredStepHasAReplacement() {
        for (retired in listOf("notJustChat", "chatDemo", "cardsDemo", "examDemo", "sampleCard", "lessonBuilding", "lessonReady", "whyNow", "trialReminder", "language")) {
            assertNotNull(retired, OnboardingStep.replacement(retired))
        }
    }

    @Test
    fun theHookIsRedoneWithoutAName() {
        val store = MemoryOnboardingStore()
        store.putString("onb.step", "goal")
        val model = OnboardingModel(store = store, deviceLanguages = listOf("fr-FR"), deviceRegion = "FR")
        model.resume()
        assertEquals(OnboardingStep.hookLogo, model.step)
    }

    @Test
    fun answersComeBackOnResume() {
        val first = OnboardingModel.lina(OnboardingStep.dailyTime)
        val store = MemoryOnboardingStore()
        val model = OnboardingModel(store = store, deviceLanguages = listOf("fr-FR"), deviceRegion = "FR")
        model.displayName = first.displayName
        model.selectCountry("fr")
        model.chooseTrack(first.schoolTrack!!)
        model.chooseYear(first.schoolYear!!)
        model.subjects.addAll(first.subjects)
        model.chooseGender(StudentGender.female)
        model.dailyMinutes = 45
        model.place(OnboardingStep.dailyTime)
        model.advance()
        val again = OnboardingModel(store = store, deviceLanguages = listOf("en-US"), deviceRegion = "US")
        again.resume()
        assertEquals(OnboardingStep.organizeIntro, again.step)
        assertEquals("fr", again.country)
        assertEquals("fr.terminale", again.schoolYear?.id)
        assertEquals(45, again.dailyMinutes)
        assertEquals(StudentGender.female, again.gender)
    }

    // MARK: Les écrans sautés

    @Test
    fun aDescribedCountryAsksTheTrackNotTheLevel() {
        val model = OnboardingModel.lina()
        assertTrue(model.isSkipped(OnboardingStep.level))
        assertFalse(model.isSkipped(OnboardingStep.schoolType))
        model.selectWorld("JP")
        assertEquals("other", model.country)
        assertFalse(model.isSkipped(OnboardingStep.level))
        assertTrue(model.isSkipped(OnboardingStep.year))
    }

    @Test
    fun theScannerNeedsAScienceSubject() {
        val model = OnboardingModel.lina()
        assertFalse(model.isSkipped(OnboardingStep.scanDemo))
        model.subjects.clear()
        model.subjects.addAll(listOf("Philosophie", "Histoire-Géographie"))
        assertTrue(model.isSkipped(OnboardingStep.scanDemo))
    }

    @Test
    fun noTrialSkipsBothTrialScreens() {
        val model = OnboardingModel.lina(OnboardingStep.firstLesson, trial = false)
        assertTrue(model.isSkipped(OnboardingStep.freeTrialIntro))
        assertTrue(model.isSkipped(OnboardingStep.trialOffer))
        model.firstLessonChoice = FirstLessonChoice.IMPORT
        model.confirmFirstLesson()
        assertEquals(OnboardingStep.paywall, model.step)
    }

    @Test
    fun theTrialIsOfferedWhenTheStoreHasNotAnswered() {
        val model = OnboardingModel.lina(OnboardingStep.firstLesson, trial = true)
        model.skipFirstLesson()
        assertEquals(OnboardingStep.freeTrialIntro, model.step)
        model.advance()
        assertEquals(OnboardingStep.trialOffer, model.step)
        model.advance()
        assertEquals(OnboardingStep.paywall, model.step)
    }

    @Test
    fun theWholeFlowGoesFromStoriesToPaywall() {
        val model = OnboardingModel.lina()
        model.hasAccount = true
        val seen = mutableListOf(model.step)
        while (model.step != OnboardingStep.paywall && seen.size < 100) {
            if (model.step == OnboardingStep.firstLesson) model.skipFirstLesson() else model.advance()
            seen += model.step
        }
        assertEquals(OnboardingStep.paywall, model.step)
        assertFalse(OnboardingStep.level in seen)
        assertTrue(OnboardingStep.scanDemo in seen)
        assertTrue(OnboardingStep.freeTrialIntro in seen)
        assertEquals(seen.size, seen.toSet().size)
    }

    @Test
    fun skippingTheAverageSkipsTheTarget() {
        val model = OnboardingModel.lina(OnboardingStep.currentAverage)
        model.skipAverages()
        assertEquals(OnboardingStep.startingPoint, model.step)
        assertNull(model.currentScore)
        model.goBack()
        assertEquals(OnboardingStep.currentAverage, model.step)
    }

    // MARK: Le genre et les statistiques

    @Test
    fun theGenderComesRightAfterTheName() {
        assertEquals(OnboardingStep.gender, OnboardingStep.yourName.next)
        assertEquals(OnboardingStep.country, OnboardingStep.gender.next)
        assertEquals("gender", OnboardingStep.gender.analyticsName)
        assertEquals(listOf(OnboardingStep.gender, OnboardingStep.currentAverage), OnboardingStep.entries.filter { it.isSkippable })
        assertEquals(listOf("male", "female", "other"), StudentGender.entries.map { it.name })
    }

    @Test
    fun choosingOrSkippingTheGenderIsTracked() {
        val events = mutableListOf<Pair<String, Map<String, Any>>>()
        val model = OnboardingModel(track = { name, props -> events += name to props }, deviceLanguages = listOf("fr-FR"), deviceRegion = "FR")
        model.place(OnboardingStep.gender)
        model.chooseGender(StudentGender.male)
        assertEquals(OnboardingStep.gender, model.step)
        assertEquals("onboarding_answer" to mapOf<String, Any>("field" to "gender", "value" to "male"), events.last())
        model.skipGender()
        assertNull(model.gender)
        assertEquals(OnboardingStep.country, model.step)
        assertTrue(("onboarding_answer" to mapOf<String, Any>("field" to "gender", "value" to "passer")) in events)
        assertEquals("passer", model.analyticsProfile("fr")["gender"])
    }

    @Test
    fun leavingTheSubjectsSendsThemSorted() {
        val events = mutableListOf<Pair<String, Map<String, Any>>>()
        val model = OnboardingModel(track = { name, props -> events += name to props }, deviceLanguages = listOf("fr-FR"), deviceRegion = "FR")
        model.subjects.addAll(listOf("Philosophie", "Mathématiques"))
        model.place(OnboardingStep.subjects)
        model.advance()
        assertTrue(("onboarding_answer" to mapOf<String, Any>("field" to "subjects", "value" to "Mathématiques,Philosophie")) in events)
    }

    @Test
    fun aLongListIsSentInChunksOfWholeNames() {
        val names = (1..30).map { "Matière numéro %02d".format(it) }
        val chunks = OnboardingModel.analyticsList("subjects", names)
        assertEquals(setOf("subjects", "subjects_2", "subjects_3"), chunks.keys)
        assertTrue(chunks.values.all { (it as String).length <= 120 })
        assertEquals(names.take(6).joinToString(","), chunks["subjects"])
        assertEquals(60, (OnboardingModel.analyticsList("value", listOf("x".repeat(200)))["value"] as String).length)
        assertTrue(OnboardingModel.analyticsList("value", emptyList()).isEmpty())
    }

    @Test
    fun theProfileCarriesEveryAnswerButTheName() {
        val profile = OnboardingModel.lina(OnboardingStep.trialOffer).analyticsProfile("fr")
        assertFalse(profile.values.any { it == "Lina" })
        assertEquals("fr", profile["ui_language"])
        assertEquals("fr", profile["country"])
        assertEquals("fr.terminale", profile["year"])
        assertEquals("fr.bac", profile["exam"])
        assertEquals("Histoire-Géographie,Mathématiques,Philosophie,Physique-Chimie", profile["subjects"])
        assertEquals(4, profile["subject_count"])
        assertEquals("forgetting,examStress", profile["worries"])
        assertEquals(45, profile["daily_minutes"])
        assertEquals("later", profile["first_lesson"])
        assertEquals(false, profile["skipped_averages"])
        assertTrue(profile.values.all { it is String || it is Int || it is Boolean })
        assertTrue(profile.values.all { it !is String || it.length <= 120 })
    }

    @Test
    fun theBackButtonStepsOverTheLoading() {
        val model = OnboardingModel.lina(OnboardingStep.profileSummary)
        assertFalse(model.canGoBack)
        model.place(OnboardingStep.storyIntro)
        model.goBack()
        assertEquals(OnboardingStep.profileSummary, model.step)
    }

    // MARK: Le maintien

    @Test
    fun aShortPressNeverCommits() {
        val hold = CommitHold()
        hold.press(1_000)
        assertFalse(hold.release(1_300))
        assertFalse(hold.tick(1_400))
    }

    @Test
    fun aFullHoldCommits() {
        val hold = CommitHold()
        hold.press(0)
        assertFalse(hold.tick(1_499))
        assertTrue(hold.tick(1_500))
        hold.press(10_000)
        assertTrue(hold.release(12_000))
    }

    @Test
    fun aCancelledGestureNeverCommits() {
        val hold = CommitHold()
        hold.press(0)
        hold.cancel()
        assertFalse(hold.tick(5_000))
        assertEquals(0f, hold.progress(5_000), 0f)
    }

    // MARK: Le système scolaire

    @Test
    fun everyDescribedCountryHasTracksYearsAndKnownExams() {
        for (code in SchoolSystem.describedRegions) {
            val tracks = SchoolSystem.tracks(code)
            assertTrue(code, tracks.isNotEmpty())
            for (track in tracks) {
                assertTrue(track.id, track.years.isNotEmpty())
                for (id in track.exams + track.years.flatMap { it.exams }) assertNotNull("$code $id", SchoolExams.catalog[id])
            }
        }
    }

    @Test
    fun theBacIsSuggestedOnItsDay() {
        val choice = SchoolExams.choice("fr.bac")!!
        assertEquals(LocalDate.of(2027, 6, 15), SchoolExams.suggestedDate(choice, LocalDate.of(2026, 11, 12)))
        assertEquals(LocalDate.of(2026, 11, 26), SchoolExams.suggestedDate(ExamChoice.Test, LocalDate.of(2026, 11, 12)))
    }

    @Test
    fun theGradeGapCountsWholePoints() {
        val scale = StudentGradeScale.of("FR", "fr", null)
        val gap = GradeGap.of(12, 16, scale, "12/20", "16/20")
        assertEquals(GradeGap.Size.MEDIUM, gap.size)
        assertEquals("4", gap.amount)
        assertTrue(gap.isWhole)
        assertEquals(GradeGap.Size.HOLD, GradeGap.of(14, 14, scale, "14/20", "14/20").size)
    }
}
