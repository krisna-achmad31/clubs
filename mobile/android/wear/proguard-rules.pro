# Libraries (Compose, Wear, Health Services, Play Services Wearable, WorkManager)
# ship their own consumer rules. App code uses no reflection.

# Readable crash stack traces.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# WorkManager's Room database is created by reflection (no-arg constructor).
# Without this, R8 strips it and the app crashes at startup:
# NoSuchMethodException: androidx.work.impl.WorkDatabase_Impl.<init> []
-keep class * extends androidx.room.RoomDatabase { <init>(); }
