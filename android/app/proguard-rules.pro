# Compose et RevenueCat fournissent leurs propres règles.

# kotlinx.serialization : les modèles des leçons (`com.micabo.app.data`) et leurs sérialiseurs.
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }
-keepclasseswithmembers class kotlinx.serialization.json.** { kotlinx.serialization.KSerializer serializer(...); }
-keep,includedescriptorclasses class com.micabo.app.**$$serializer { *; }
-keepclassmembers class com.micabo.app.** {
    *** Companion;
}
-keepclasseswithmembers class com.micabo.app.** {
    kotlinx.serialization.KSerializer serializer(...);
}
