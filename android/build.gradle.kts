buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.0")   // 👈 تم التحديث إلى 2.2.0
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ❌ تم حذف قسم resolutionStrategy بالكامل - لم يعد ضرورياً ويسبب التعارض

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}