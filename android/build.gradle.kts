allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    // AGP's unit-test configuration computes paths relative to projectDir.
    // Windows cannot relativize a Pub plugin on C: against build output on D:.
    // Keep cross-drive plugin output beside its sources, isolated per app.
    // The app itself retains Flutter's expected <workspace>/build/app output.
    val sourceRoot = project.projectDir.toPath().toAbsolutePath().root
    val outputRoot = newBuildDir.asFile.toPath().toAbsolutePath().root
    val workspaceId = java.util.UUID.nameUUIDFromBytes(
        rootProject.projectDir.canonicalPath.toByteArray(Charsets.UTF_8)
    ).toString()
    val newSubprojectBuildDir = if (sourceRoot != outputRoot) {
        project.layout.projectDirectory.dir("build/flutter-workspaces/$workspaceId")
    } else {
        newBuildDir.dir(project.name)
    }
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
