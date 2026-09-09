allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Audit W4.x rename/build fix: flutter_secure_storage 11.0.0 hardcodes
// compileSdk = 37, but API 37 is not published on the stable sdkmanager
// channel (probed live — CI 'Failed to find package platforms;android-37').
// The plugin uses no API-37-only calls, so force it to the app's compileSdk
// (36); its AAR metadata then accepts the app too.
gradle.beforeProject {
    if (name == "flutter_secure_storage") {
        afterEvaluate {
            extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
                compileSdk = 36
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
