# flutter_local_notifications — preserve TypeToken generic signatures
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# Keep Gson generics
-keepattributes Signature
-keepattributes *Annotation*

# flutter_local_notifications plugin internals
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**
