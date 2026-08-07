# Prefer consumer ProGuard rules from Flutter / plugins over blanket -keep.
# Broad package keeps block R8 optimization (Play Console guidance).

# Flutter JNI / embedding entry points (engine ships its own rules; keep JNI)
-keepclasseswithmembernames class * {
    native <methods>;
}

# Firebase / Play Services — rely on their consumer rules; silence missing classes
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Gson (if pulled transitively)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Parcelable
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# Keep annotation default values
-keepattributes AnnotationDefault

# Keep line numbers for stack traces (Play Console deobfuscation)
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Flutter Play Core (deferred components) - ignore warnings if not used
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
