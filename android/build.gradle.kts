allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = file("../build")

subprojects {
    buildDir = File(rootProject.buildDir, name)
    evaluationDependsOn(":app")

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