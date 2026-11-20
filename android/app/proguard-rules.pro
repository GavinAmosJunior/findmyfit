# Release builds shrink and rename code. Google ML Kit (background removal)
# finds parts of itself by name at run time, so it must be left whole, or
# it fails with a NullPointerException before the model is ever used.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.android.gms.common.internal.** { *; }
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_subject_segmentation.** { *; }
