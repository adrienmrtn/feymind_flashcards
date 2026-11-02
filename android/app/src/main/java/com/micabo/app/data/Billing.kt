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
import com.revenuecat.purchases.PurchasesError
import com.revenuecat.purchases.PurchasesErrorCode
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
    /** Le prix en micro-unités de la devise : de quoi calculer une remise. */
    val micros: Long = 0,
    /**
     * L'offre dans les événements : l'identifiant produit de l'iPhone (`PaywallPlan.productID`),
     * pour que les deux apps se lisent dans les mêmes colonnes.
     */
    val analyticsId: String = if (yearly) PLAN_YEARLY else PLAN_WEEKLY,
)

const val PLAN_YEARLY = "com.micabo.app.pro.yearly"
const val PLAN_WEEKLY = "com.micabo.app.pro.weekly"
const val PLAN_DISCOUNT = "com.micabo.app.pro.yearly.discount"

/** Pourquoi Google Play n'a pas donné d'offres. */
enum class PlanProblem {
    /** Pas de réseau. */
    NETWORK,
    /** Google Play lui-même : service absent ou en panne, compte Google manquant, offres introuvables. */
    STORE,
    OTHER,
}

/** Ce que Google Play a répondu au paywall : les offres, ou pourquoi il n'y en a pas (et son code). */
data class PlanLoad(val plans: List<StorePlan>, val problem: PlanProblem? = null, val code: String? = null)

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
    /**
     * **L'achat attend une validation** (`PaymentPendingError`) : un parent par Family Link, un
     * paiement en espèces. Ni acheté, ni refusé ; Pro s'ouvrira seul quand Google Play confirmera
     * (`updatedCustomerInfoListener`).
     */
    data object Pending : PurchaseOutcome
    data class Failed(val message: String, val code: String = "") : PurchaseOutcome
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
     * Avant un achat ou une restauration : RevenueCat doit connaître l'invité. Configurée au
     * lancement sans attendre le réseau, l'app peut tourner sous un identifiant anonyme, et
     * l'abonnement n'aurait eu aucun propriétaire côté serveur (la porte du gratuit ne l'aurait
     * jamais vu). Vrai quand RevenueCat parle bien sous l'identifiant de l'invité (ou du compte).
     */
    private suspend fun identify(): Boolean {
        if (!enabled) return false
        val id = runCatching { guestId() }.getOrNull()?.takeIf { it.isNotEmpty() } ?: return false
        return withContext<Boolean>(Dispatchers.Main) {
            if (!Purchases.isConfigured) start(id)
            if (!Purchases.isConfigured) return@withContext false
            if (Purchases.sharedInstance.appUserID == id) return@withContext true
            suspendCancellableCoroutine<Boolean> { continuation ->
                Purchases.sharedInstance.logInWith(
                    id,
                    onError = { if (continuation.isActive) continuation.resume(false) },
                    onSuccess = { info, _ ->
                        read(info)
                        if (continuation.isActive) continuation.resume(true)
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

    private val prefs = context.getSharedPreferences("micabo", Context.MODE_PRIVATE)

    /**
     * **Un essai ou un abonnement Pro a déjà existé sur ce compte**, fini ou non. Gardé une
     * fois vrai : le rappel du jour n'est que pour qui n'a jamais activé l'essai, et un
     * lancement hors ligne ne doit pas le rouvrir.
     */
    private val _everHadPro = MutableStateFlow(prefs.getBoolean(EVER_HAD_PRO, false) || prefs.contains("trial.end"))
    val everHadPro: StateFlow<Boolean> = _everHadPro.asStateFlow()

    private fun markEverHadPro() {
        if (_everHadPro.value) return
        _everHadPro.value = true
        prefs.edit().putBoolean(EVER_HAD_PRO, true).apply()
    }

    private fun read(info: CustomerInfo) {
        val pro = info.entitlements["pro"]?.takeIf { it.isActive }
        _isPro.value = pro != null
        if (pro != null || info.entitlements.all.containsKey("pro")) markEverHadPro()
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

    suspend fun plans(): List<StorePlan> = loadPlans().plans

    /**
     * **Les offres du paywall, ou pourquoi il n'y en a pas** : le réseau, Google Play lui-même,
     * ou autre chose, avec le code de RevenueCat pour les événements.
     */
    suspend fun loadPlans(): PlanLoad {
        if (!enabled) return PlanLoad(emptyList(), PlanProblem.OTHER, "disabled")
        // Configurée au lancement ; une configuration tombée se retente ici, sous un identifiant
        // anonyme : l'achat, lui, passe toujours par `identify`.
        if (!Purchases.isConfigured) withContext(Dispatchers.Main) { start(null) }
        if (!Purchases.isConfigured) return PlanLoad(emptyList(), PlanProblem.STORE, "not_configured")
        return suspendCancellableCoroutine { continuation ->
            Purchases.sharedInstance.getOfferingsWith(
                onError = { error ->
                    if (continuation.isActive) continuation.resume(PlanLoad(emptyList(), problemOf(error), error.code.name))
                },
                onSuccess = { offerings ->
                    val packages = (offerings.current?.availablePackages.orEmpty() +
                        offerings.all.values.flatMap { it.availablePackages })
                    val yearly = packages.firstOrNull { it.packageType == PackageType.ANNUAL && !it.product.id.contains("discount") }
                        ?: packages.firstOrNull { it.product.id.contains("yearly") && !it.product.id.contains("discount") }
                    val weekly = packages.firstOrNull { it.packageType == PackageType.WEEKLY }
                        ?: packages.firstOrNull { it.product.id.contains("weekly") }
                    val out = listOfNotNull(
                        yearly?.let { StorePlan(true, it.product.price.formatted, it, monthlyOf(it), trialDaysOf(it), it.product.price.amountMicros) },
                        weekly?.let { StorePlan(false, it.product.price.formatted, it, trialDays = trialDaysOf(it), micros = it.product.price.amountMicros) },
                    )
                    val load = if (out.isEmpty()) PlanLoad(out, PlanProblem.OTHER, "no_packages") else PlanLoad(out)
                    if (continuation.isActive) continuation.resume(load)
                },
            )
        }
    }

    private fun problemOf(error: PurchasesError): PlanProblem = when (error.code) {
        PurchasesErrorCode.NetworkError -> PlanProblem.NETWORK
        // `BILLING_UNAVAILABLE` arrive en `PurchaseNotAllowedError`, un service Play en panne en
        // `StoreProblemError`, des produits que Play ne rend pas en `ConfigurationError`.
        PurchasesErrorCode.StoreProblemError, PurchasesErrorCode.PurchaseNotAllowedError, PurchasesErrorCode.ConfigurationError -> PlanProblem.STORE
        else -> PlanProblem.OTHER
    }

    /** Le pays de la boutique Google Play, quand RevenueCat le connaît déjà. */
    fun storefront(): String? =
        if (enabled && Purchases.isConfigured) runCatching { Purchases.sharedInstance.storefrontCountryCode }.getOrNull() else null

    /**
     * **L'annuel à tarif réduit du cadeau** (offering `discount`, comme sur iPhone), ou `null`
     * quand la boutique ne répond pas.
     */
    suspend fun discountPlan(): StorePlan? {
        if (!enabled || !Purchases.isConfigured) return null
        return suspendCancellableCoroutine { continuation ->
            Purchases.sharedInstance.getOfferingsWith(
                onError = { if (continuation.isActive) continuation.resume(null) },
                onSuccess = { offerings ->
                    val packages = offerings.all["discount"]?.availablePackages.orEmpty()
                    val pkg = packages.firstOrNull { it.product.id.contains("discount") } ?: packages.firstOrNull()
                    val plan = pkg?.let { StorePlan(true, it.product.price.formatted, it, monthlyOf(it), 0, it.product.price.amountMicros, PLAN_DISCOUNT) }
                    if (continuation.isActive) continuation.resume(plan)
                },
            )
        }
    }

    suspend fun purchase(activity: Activity, plan: StorePlan): PurchaseOutcome {
        val pkg = plan.pkg ?: return PurchaseOutcome.Unavailable
        // Sans l'identifiant de l'invité, pas d'achat : il partirait sous un identifiant anonyme.
        if (!identify()) return PurchaseOutcome.Unavailable
        if (!Purchases.isConfigured) return PurchaseOutcome.Unavailable
        return suspendCancellableCoroutine { continuation ->
            Purchases.sharedInstance.purchaseWith(
                PurchaseParams.Builder(activity, pkg).build(),
                onError = { error, cancelled ->
                    if (continuation.isActive) {
                        continuation.resume(
                            when {
                                cancelled -> PurchaseOutcome.Cancelled
                                error.code == PurchasesErrorCode.PaymentPendingError -> PurchaseOutcome.Pending
                                else -> PurchaseOutcome.Failed(error.message, error.code.name)
                            },
                        )
                    }
                },
                onSuccess = { _, info ->
                    read(info)
                    markEverHadPro()
                    if (continuation.isActive) continuation.resume(PurchaseOutcome.Success)
                },
            )
        }
    }

    suspend fun restore(): Boolean {
        val identified = identify()
        if (!enabled || !Purchases.isConfigured) return false
        // Restaurer sous un identifiant anonyme y déplacerait l'abonnement, loin de l'invité.
        if (!identified && Purchases.sharedInstance.isAnonymous) return false
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

private const val EVER_HAD_PRO = "pro.everHad"
