# The native game calls back into nothing, but the JNI entry point must keep its name.
-keep class com.hilalsafi.cryptoclicker.core.NativeBridge { *; }
