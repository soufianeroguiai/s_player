// هذا ملف root build.gradle.kts (مهم لتثبيت Kotlin بشكل صحيح)

buildscript {
    repositories {
        google()
        mavenCentral()
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}