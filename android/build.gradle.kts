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

// Workaround: Some third-party plugins (older versions) may not specify the
// required `namespace` property in their Android build files. Recent AGP
// versions require a namespace for library modules. As a safe fallback, set
// a namespace for any Android library modules that haven't declared one yet.
// This avoids editing files in the pub cache and keeps the fix local to the
// project build.
// Use a projectsEvaluated hook to avoid calling afterEvaluate on an already
// evaluated project. This iterates over subprojects after the Gradle project
// graph is evaluated and sets a fallback namespace for Android library
// modules that do not declare one.
gradle.projectsEvaluated {
    subprojects.forEach { proj ->
        try {
            if (proj.plugins.hasPlugin("com.android.library")) {
                val androidExt = proj.extensions.findByName("android")
                if (androidExt != null) {
                    try {
                        val getNs = androidExt::class.java.getMethod("getNamespace")
                        val current = getNs.invoke(androidExt) as? String
                        if (current == null || current.isEmpty()) {
                            val setNs = androidExt::class.java.getMethod("setNamespace", String::class.java)
                            // Use a safe default namespace for third-party libraries.
                            setNs.invoke(androidExt, "com.example.flutterlibrary")
                        }
                    } catch (_: Throwable) {
                        // Ignore reflection failures; best-effort only.
                    }
                }
            }
        } catch (_: Throwable) {
            // Swallow any errors to avoid failing the build configuration.
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
