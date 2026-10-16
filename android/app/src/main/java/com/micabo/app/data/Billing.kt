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
import com.revenuecat.purchases.getOfferingsWith
import com.revenuecat.purchases.logInWith
import com.revenuecat.purchases.purchaseWith
import com.revenuecat.purchases.restorePurchasesWith
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine

/** Une offre du paywall, avec le prix de la boutique quand elle a répondu. */
data class StorePlan(
    val yearly: Boolean,
    val price: String,
    val pkg: Package?,
    /** Le prix par mois d'un abonnement annuel, dans la devise de la boutique. */
    val monthly: String? = null,
)

private fun monthlyOf(pkg: Package): String? = runCatching {
    val price = pkg.product.price
    val format = java.text.NumberFormat.getCurrencyInstance()
    format.currency = java.util.Currency.getInstance(price.currencyCode)
    format.format(price.amountMicros / 1_000_000.0 / 12.0)
}.getOrNull()

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
class Billing(private val context: Context) {
    val enabled: Boolean get() = BuildConfig.REVENUECAT_KEY.isNotEmpty()

    private val _isPro = MutableStateFlow(false)
    val isPro: StateFlow<Boolean> = _isPro.asStateFlow()

    fun start(userId: String?) {
        if (!enabled) return
        runCatching {
            if (!Purchases.isConfigured) {
                val builder = PurchasesConfiguration.Builder(context.applicationContext, BuildConfig.REVENUECAT_KEY)
                if (!userId.isNullOrEmpty()) builder.appUserID(userId)
                Purchases.configure(builder.build())
            } else if (!userId.isNullOrEmpty() && Purchases.sharedInstance.appUserID != userId) {
                Purchases.sharedInstance.logInWith(userId, onError = {}, onSuccess = { info, _ -> read(info) })
            }
            Purchases.sharedInstance.getCustomerInfoWith(onError = {}, onSuccess = ::read)
        }.onFailure { Log.w("Billing", "RevenueCat indisponible", it) }
    }

    private fun read(info: CustomerInfo) {
        _isPro.value = info.entitlements["pro"]?.isActive == true
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
                        yearly?.let { StorePlan(true, it.product.price.formatted, it, monthlyOf(it)) },
                        weekly?.let { StorePlan(false, it.product.price.formatted, it) },
                    )
                    if (continuation.isActive) continuation.resume(out)
                },
            )
        }
    }

    suspend fun purchase(activity: Activity, plan: StorePlan): PurchaseOutcome {
        val pkg = plan.pkg ?: return PurchaseOutcome.Unavailable
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
                    if (continuation.isActive) continuation.resume(PurchaseOutcome.Success)
                },
            )
        }
    }

    suspend fun restore(): Boolean {
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
