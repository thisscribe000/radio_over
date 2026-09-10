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

fun configureNamespace(p: Project) {
    if (p.plugins.hasPlugin("com.android.library")) {
        val androidExt = p.extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
        if (androidExt != null && androidExt.namespace == null) {
            androidExt.namespace = "com.radioover.radio_over.plugin." + p.name.replace("-", "_")
        }
    }
}

subprojects {
    if (state.executed) {
        configureNamespace(this)
    } else {
        afterEvaluate { configureNamespace(this) }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
