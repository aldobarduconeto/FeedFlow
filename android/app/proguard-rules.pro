# Flutter & Flutter Plugins
-keep class io.flutter.** { *; }
-keep interface io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep interface io.flutter.plugins.** { *; }

# SharedPreferences (JNI bindings require exact method signatures preserved)
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep interface io.flutter.plugins.sharedpreferences.** { *; }
-keepclassmembers class io.flutter.plugins.sharedpreferences.** { *; }
-keepclassmembernames class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.sharedpreferences.SharedPreferencesApiRegistrar {
    public *;
    protected *;
    *;
}
-keepclassmembers class io.flutter.plugins.sharedpreferences.SharedPreferencesApiRegistrar {
    public *;
    protected *;
    *;
}

# JNI & Pigeon
-keep class io.flutter.plugin.common.** { *; }
-keepclassmembers class * implements io.flutter.plugin.common.MethodChannel$MethodCallHandler {
    *;
}

# Audioplayers
-keep class xyz.luan.audioplayers.** { *; }
-keep interface xyz.luan.audioplayers.** { *; }
-keepclassmembers class xyz.luan.audioplayers.** { *; }

# Path Provider
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep interface io.flutter.plugins.pathprovider.** { *; }
-keepclassmembers class io.flutter.plugins.pathprovider.** { *; }

# Kotlin Coroutines & Reflection
-keep class kotlin.coroutines.** { *; }
-keep interface kotlin.coroutines.** { *; }
-keepclassmembers class kotlin.coroutines.** { *; }
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,SourceFile,LineNumberTable

