-keep class ai.onnxruntime.** { *; }
# To ensure that stack traces is unambiguous
# https://developer.android.com/studio/build/shrink-code#decode-stack-trace
-keepattributes LineNumberTable,SourceFile

-keep class org.chromium.net.** { *; }
-keep class org.xmlpull.v1.** { *; }

# Flutter logging package rules
-keep class dart.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep the logging package classes
-keep class logging.** { *; }
-keep class dart.logging.** { *; }

# Keep Flutter engine classes
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.view.** { *; }

# Keep Flutter VM and snapshot classes (CRITICAL for preventing crash)
-keep class io.flutter.FlutterInjector { *; }
-keep class io.flutter.FlutterLoader { *; }
-keep class io.flutter.embedding.engine.FlutterEngine { *; }
-keep class io.flutter.embedding.engine.dart.DartExecutor { *; }

# SECURE: Only keep essential classes, allow obfuscation of sensitive code
# DO NOT use broad wildcards that prevent obfuscation

# Keep only Flutter plugins (required for functionality)
-keep class io.flutter.plugin.** { *; }

# Keep only essential public entry points - everything else gets obfuscated
-keep public class io.ente.photos.MainActivity {
    public <init>(...);
    # Keep the static method that LoginActivity calls
    public static java.lang.String generateInternalAuthToken(android.content.Context);
}

-keep public class io.ente.photos.LoginActivity {
    public <init>(...);
}

# Keep widget providers (Android system requirement)
-keep public class * extends android.appwidget.AppWidgetProvider {
    public <init>(...);
    public void onUpdate(...);
}

# IMPORTANT: AccountModel, MethodChannelHandler, and other sensitive classes
# are NOT kept here - they will be obfuscated for security

# Keep Flutter native method channels
-keepclassmembers class * {
    @io.flutter.plugin.common.MethodChannel$MethodCallHandler <methods>;
}

# Exclude Google Play Services classes (for independent builds)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Remove all debug logging in release builds
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
    public static *** wtf(...);
}

# Remove System.out.print calls
-assumenosideeffects class java.lang.System {
    public static void out.println(...);
    public static void err.println(...);
    public static void out.print(...);
    public static void err.print(...);
}

# Remove Kotlin print functions
-assumenosideeffects class kotlin.io.ConsoleKt {
    public static *** println(...);
    public static *** print(...);
}

## Remove Flutter/Dart print calls
-assumenosideeffects class io.flutter.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
    public static *** wtf(...);
}

## Remove Flutter print() calls via System.out
-assumenosideeffects class java.io.PrintStream {
    public void print(...);
    public void println(...);
}

# ENHANCED SECURITY: Advanced obfuscation settings
-repackageclasses ''
-allowaccessmodification
-dontusemixedcaseclassnames

# Enable aggressive obfuscation
-overloadaggressively
-adaptclassstrings

# Protect serialization (required for Kotlin @Serializable)
-keepattributes *Annotation*
-keep class kotlinx.serialization.** { *; }

# String obfuscation for sensitive constants
-adaptclassstrings io.ente.photos.**

# Additional security hardening
-optimizationpasses 5
-dontpreverify