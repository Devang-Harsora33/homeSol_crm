allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}


subprojects {
    project.extra.set("kotlin.jvm.target.validation.mode", "ignore")

    project.configurations.all {
        resolutionStrategy {
            force("androidx.browser:browser:1.8.0")
            force("androidx.activity:activity-ktx:1.9.3")
            force("androidx.activity:activity:1.9.3")
            force("androidx.core:core-ktx:1.15.0")
            force("androidx.core:core:1.15.0")
        }
    }

    // Suppress obsolete Java 8 warnings and other compiler noise, and force Java 17
    project.tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.add("-Xlint:-options")
        options.compilerArgs.add("-Xlint:-deprecation")
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }

    // Force Kotlin to 17
    project.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions {
            jvmTarget = "17"
        }
    }

    val applyNamespace = {
        if (project.plugins.hasPlugin("com.android.library")) {
            val android = project.extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
            if (android != null) {
                if (android.namespace == null) {
                    android.namespace = "com.homesol.plugins.${project.name.replace("-", ".")}"
                }
                // Force compileSdk to 36 to support newest symbols
                android.compileSdk = 36
            }
            
            // Fix for "Setting the namespace via the package attribute in the source AndroidManifest.xml is no longer supported"
            project.tasks.withType(com.android.build.gradle.tasks.ProcessLibraryManifest::class.java).configureEach {
                doFirst {
                    val manifestFile = mainManifest.get().asFile
                    if (manifestFile.exists()) {
                        val content = manifestFile.readText()
                        if (content.contains("package=")) {
                            val newContent = content.replace(Regex("package=\"[^\"]*\""), "")
                            manifestFile.writeText(newContent)
                        }
                    }
                }
            }
        }
    }

    if (project.state.executed) {
        applyNamespace()
    } else {
        project.afterEvaluate { applyNamespace() }
    }
}