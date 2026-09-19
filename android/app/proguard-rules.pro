# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Hive (reflection-free in this project, but keep generated adapters safe
# in case build_runner adapters are introduced later)
-keep class hive.** { *; }
-keep class * extends com.hivedb.** { *; }

# Syncfusion PDF
-keep class com.syncfusion.** { *; }
-dontwarn com.syncfusion.**

# mobile_scanner / ML Kit barcode scanning
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Gson / reflection used transitively by several plugins
-keepattributes Signature
-keepattributes *Annotation*
-keep class sun.misc.Unsafe { *; }

# Keep our own model classes (defensive; they're plain Dart objects but
# this guards any future platform channel payload classes)
-keep class com.hameed.pdfmastertools.** { *; }
