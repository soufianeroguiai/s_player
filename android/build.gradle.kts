buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.0.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 🔥 FORCE Kotlin 2.0 everywhere (حل مشكل 2.2)
configurations.all {
    resolutionStrategy {
        force("org.jetbrains.kotlin:kotlin-stdlib:2.0.0")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}