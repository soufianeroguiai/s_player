buildscript {
    extra["kotlin_version"] = "2.1.20"
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.5.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:${extra["kotlin_version"]}")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.layout.buildDirectory.set(file("../build"))

subprojects {
    project.layout.buildDirectory.set(
        rootProject.layout.buildDirectory.get().dir(project.name)
    )
    project.evaluationDependsOn(":app")
}

tasks.register("clean", Delete::class) {
    delete(rootProject.layout.buildDirectory)
}