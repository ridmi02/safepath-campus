allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Flutter tooling expects Android build outputs under ../build (at the repo root).
// Without this, Gradle defaults to android/**/build, and `flutter run` may fail to
// locate the generated APK even though the build succeeded.
rootProject.buildDir = file("../build")

subprojects {
    buildDir = File(rootProject.buildDir, name)
    if (project.name == "telephony") {
        project.afterEvaluate {
            val android = project.extensions.findByName("android")
            if (android != null) {
                try {
                    android.javaClass.getMethod("setNamespace", String::class.java).invoke(android, "com.shounakmulay.telephony")
                } catch (e: Exception) {
                    // Ignore
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
