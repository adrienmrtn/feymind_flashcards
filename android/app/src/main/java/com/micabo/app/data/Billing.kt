package com.micabo.app.data

import android.app.Activity
import android.content.Context
import android.util.Log
import com.micabo.app.BuildConfig
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PackageType
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.revenuecat.purchases.getCustomerInfoWith
import com.revenuecat.purchases.interfaces.UpdatedCustomerInfoListener
import com.revenuecat.purchases.getOfferingsWith
import com.revenuecat.purchases.logInWith
import com.revenuecat.purchases.purchaseWith
import com.revenuecat.purchases.restorePurchasesWith
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlin.coroutines.resume
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext

/** Une offre du paywall, avec le prix de la boutique quand elle a répondu. */
data class StorePlan(
    val yearly: Boolean,
    val price: String,
    val pkg: Package?,
    /** Le prix par mois d'un abonnement annuel, dans la devise de la boutique. */
    val monthly: String? = null,
    /** Les jours offerts par la boutique, 0 sans essai (ou s'il a déjà servi). */
    val trialDays: Int = 0,
)

/** Les jours d'essai gratuit d'une offre, d'après Google Play. */
private fun trialDaysOf(pkg: Package): Int = runCatching {
    val period = pkg.product.defaultOption?.freePhase?.billingPeriod ?: return@runCatching 0
    when (period.unit) {
        com.revenuecat.purchases.models.Period.Unit.DAY -> period.value
        com.revenuecat.purchases.models.Period.Unit.WEEK -> period.value * 7
        com.revenuecat.purchases.models.Period.Unit.MONTH -> period.value * 30
        com.revenuecat.purchases.models.Period.Unit.YEAR -> period.value * 365
        else -> 0
    }
}.getOrDefault(0)

private fun monthlyOf(pkg: Package): String? = runCatching {
    val price = pkg.product.price
    val format = java.text.NumberFormat.getCurrencyInstance()
    format.currency = java.util.Currency.getInstance(price.currencyCode)
    format.format(price.amountMicros / 1_000_000.0 / 12.0)
}.getOrNull()

/**
 * **Où l'abonnement a été pris**, donc où il se gère (`EntitlementInfo.store`). Un compte payé
 * sur l'iPhone ou sur le site est Pro ici aussi, et la page de Google Play n'y pouvait rien.
 */
enum class ProStore {
    PLAY,
    APP_STORE,
    /** Le site : Stripe, par RevenueCat. */
    WEB,
    /** Offert : il n'y a rien à résilier. */
    GIFT,
    OTHER,
}

sealed interface PurchaseOutcome {
    data object Success : PurchaseOutcome
    data object Cancelled : PurchaseOutcome
    data object Unavailable : PurchaseOutcome
    data class Failed(val message: String) : PurchaseOutcome
}

/**
 * **Les achats**, par RevenueCat et Google Play Billing, comme sur iPhone : l'entitlement
 * `pro`, l'`app_user_id` égal à l'identifiant Supabase de l'invité (sans ça, le serveur ne
 * verrait pas l'abonnement). Sans clé Android (`BuildConfig.REVENUECAT_KEY` vide), le SDK
 * reste éteint et le paywall dit « bientôt disponible ».
 */
class Billing(
    private val context: Context,
    /** L'identifiant Supabase de l'invité, son compte ouvert s'il le faut ; `null` sans réseau. */
    private val guestId: suspend () -> String? = { null },
) {
    val enabled: Boolean get() = BuildConfig.REVENUECAT_KEY.isNotEmpty()

    private val _isPro = MutableStateFlow(false)
    val isPro: StateFlow<Boolean> = _isPro.asStateFlow()

    private val _store = MutableStateFlow<ProStore?>(null)
    /** La boutique de l'abonnement actif ; `null` sans abonnement. */
    val store: StateFlow<ProStore?> = _store.asStateFlow()

    fun start(userId: String?) {
        if (!enabled) return
        runCatching {
            if (!Purchases.isConfigured) {
                val builder = PurchasesConfiguration.Builder(context.applicationContext, BuildConfig.REVENUECAT_KEY)
                if (!userId.isNullOrEmpty()) builder.appUserID(userId)
                Purchases.configure(builder.build())
                // Un renouvellement, une fin d'abonnement, un achat en attente validé : Pro suit.
                Purchases.sharedInstance.updatedCustomerInfoListener = object : UpdatedCustomerInfoListener {
                    override fun onReceived(customerInfo: CustomerInfo) = read(customerInfo)
                }
            } else if (!userId.isNullOrEmpty() && Purchases.sharedInstance.appUserID != userId) {
                Purchases.sharedInstance.logInWith(userId, onError = {}, onSuccess = { info, _ -> read(info) })
            }
            Purchases.sharedInstance.getCustomerInfoWith(onError = {}, onSuccess = ::read)
        }.onFailure { Log.w("Billing", "RevenueCat indisponible", it) }
    }

    /**
     * Avant un achat ou une restauration : RevenueCat doit connaître l'invité. Lancée hors
     * ligne, l'app a configuré un identifiant anonyme, et l'abonnement n'aurait eu aucun
     * propriétaire côté serveur (la porte du gratuit ne l'aurait jamais vu).
     */
    private suspend fun identify() {
        if (!enabled) return
        val id = runCatching { guestId() }.getOrNull()?.takeIf { it.isNotEmpty() } ?: return
        withContext<Unit>(Dispatchers.Main) {
            if (!Purchases.isConfigured) {
                start(id)
                return@withContext
            }
            if (Purchases.sharedInstance.appUserID == id) return@withContext
            suspendCancellableCoroutine<Unit> { continuation ->
                Purchases.sharedInstance.logInWith(
                    id,
                    onError = { if (continuation.isActive) continuation.resume(Unit) },
                    onSuccess = { info, _ ->
                        read(info)
                        if (continuation.isActive) continuation.resume(Unit)
                    },
                )
            }
        }
    }

    /**
     * L'élève vient de se connecter (ou de se déconnecter) : RevenueCat suit le nouvel
     * identifiant (`PaywallPurchases.syncIdentity`). Un abonnement pris sous l'invité est
     * rapatrié par `syncPurchases`, sinon le compte le verrait gratuit.
     */
    fun follow(userId: String, fromGuest: Boolean) {
        if (!enabled || userId.isEmpty()) return
        runCatching {
            if (!Purchases.isConfigured) return start(userId)
            if (Purchases.sharedInstance.appUserID == userId) return
            Purchases.sharedInstance.logInWith(userId, onError = {}, onSuccess = { info, _ ->
                read(info)
                if (fromGuest && !_isPro.value) {
                    runCatching { Purchases.sharedInstance.syncPurchases() }
                    Purchases.sharedInstance.getCustomerInfoWith(onError = {}, onSuccess = ::read)
                }
            })
        }.onFailure { Log.w("Billing", "RevenueCat indisponible", it) }
    }

    private fun read(info: CustomerInfo) {
        val pro = info.entitlements["pro"]?.takeIf { it.isActive }
        _isPro.value = pro != null
        // Par le nom : une boutique ajoutée au SDK (`RC_BILLING`, `PADDLE`…) ne casse rien ici.
        _store.value = pro?.let {
            when (it.store.name) {
                "PLAY_STORE" -> ProStore.PLAY
                "APP_STORE", "MAC_APP_STORE" -> ProStore.APP_STORE
                "STRIPE", "RC_BILLING", "PADDLE" -> ProStore.WEB
                "PROMOTIONAL" -> ProStore.GIFT
                else -> ProStore.OTHER
            }
        }
    }

    suspend fun plans(): List<StorePlan> {
        if (!enabled || !Purchases.isConfigured) return emptyList()
        return suspendCancellableCoroutine { continuation ->
            Purchases.sharedInstance.getOfferingsWith(
                onError = { if (continuation.isActive) continuation.resume(emptyList()) },
                onSuccess = { offerings ->
                    val packages = (offerings.current?.availablePackages.orEmpty() +
                        offerings.all.values.flatMap { it.availablePackages })
                    val yearly = packages.firstOrNull { it.packageType == PackageType.ANNUAL && !it.product.id.contains("discount") }
                        ?: packages.firstOrNull { it.product.id.contains("yearly") && !it.product.id.contains("discount") }
                    val weekly = packages.firstOrNull { it.packageType == PackageType.WEEKLY }
                        ?: packages.firstOrNull { it.product.id.contains("weekly") }
                    val out = listOfNotNull(
                        yearly?.let { StorePlan(true, it.product.price.formatted, it, monthlyOf(it), trialDaysOf(it)) },
                        weekly?.let { StorePlan(false, it.product.price.formatted, it, trialDays = trialDaysOf(it)) },
                    )
                    if (continuation.isActive) continuation.resume(out)
                },
            )
        }
    }

    suspend fun purchase(activity: Activity, plan: StorePlan): PurchaseOutcome {
        val pkg = plan.pkg ?: return PurchaseOutcome.Unavailable
        identify()
        if (!Purchases.isConfigured) return PurchaseOutcome.Unavailable
        return suspendCancellableCoroutine { continuation ->
            Purchases.sharedInstance.purchaseWith(
                PurchaseParams.Builder(activity, pkg).build(),
                onError = { error, cancelled ->
                    if (continuation.isActive) {
                        continuation.resume(if (cancelled) PurchaseOutcome.Cancelled else PurchaseOutcome.Failed(error.message))
                    }
                },
                onSuccess = { _, info ->
                    read(info)
                    // Un essai commence : le rappel de la veille de la fin, comme promis.
                    if (plan.trialDays > 0) TrialReminder.schedule(context, plan.trialDays)
                    if (continuation.isActive) continuation.resume(PurchaseOutcome.Success)
                },
            )
        }
    }

    suspend fun restore(): Boolean {
        identify()
        if (!enabled || !Purchases.isConfigured) return false
        return suspendCancellableCoroutine { continuation ->
            Purchases.sharedInstance.restorePurchasesWith(
                onError = { if (continuation.isActive) continuation.resume(false) },
                onSuccess = { info ->
                    read(info)
                    if (continuation.isActive) continuation.resume(_isPro.value)
                },
            )
        }
    }
}
