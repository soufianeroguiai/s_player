content = """allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // Force compileSdk for all subprojects including pub packages
    subprojects {
        afterEvaluate { project ->
            if (project.hasProperty("android")) {
                project.android {
                    if (compileSdkVersion < 36) {
                        compileSdkVersion 36
                    }
                }
            }
        }
    }
}

rootProject.buildDir = "../build"

tasks.register("clean", Delete) {
    delete rootProject.buildDir
}
"""
with open("android/build.gradle", "w") as f:
    f.write(content)
print("root build.gradle written")
