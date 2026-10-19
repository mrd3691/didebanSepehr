val localProperties = java.util.Properties()
rootProject.file("local.properties").inputStream().use { localProperties.load(it) }
val localMavenRepository = localProperties.getProperty("dideban.mavenRepository")
val appAgpVersion = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION
val cachedAnnotationVersion = localProperties.getProperty("dideban.annotationVersion")

allprojects {
    if (cachedAnnotationVersion != null) {
        configurations.configureEach {
            resolutionStrategy.eachDependency {
                if (requested.group == "androidx.annotation" &&
                    requested.name in listOf("annotation", "annotation-jvm")) {
                    useVersion(cachedAnnotationVersion)
                }
            }
        }
    }
    if (localMavenRepository != null) {
        buildscript {
            repositories {
                maven { url = uri(localMavenRepository) }
            }
            // Flutter plugins share the app's AGP classloader. Reuse that AGP
            // when building from cache instead of fetching plugin-specific AGPs.
            configurations.configureEach {
                resolutionStrategy.eachDependency {
                    if (requested.group == "com.android.tools.build" && requested.name == "gradle") {
                        useVersion(appAgpVersion)
                    }
                }
            }
        }
    }
    repositories {
        localMavenRepository?.let { maven { url = uri(it) } }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
