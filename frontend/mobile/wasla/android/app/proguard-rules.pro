# ── Flutter Proguard Rules ────────────────────────────────────────
# Keep Flutter classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── Firebase ──────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**

# ── Supabase / OkHttp / Kotlin ────────────────────────────────────
-keep class com.supabase.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }

# ── Gson / JSON ───────────────────────────────────────────────────
-keepattributes EnclosingMethod
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ── WebView (Paymob) ──────────────────────────────────────────────
-keep class android.webkit.** { *; }

# ── Google Maps ───────────────────────────────────────────────────
-keep class com.google.maps.** { *; }

# ── Prevent stripping of app classes ─────────────────────────────
-keep class com.ahmedmaamoun.wasla.** { *; }

# ── Play Store Split Install (Deferred Components) ─────────────────
-dontwarn com.google.android.play.core.**
