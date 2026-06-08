pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "compressi_android"

include(":compressor-core")
include(":sample-app")
project(":compressor-core").projectDir = file("../compressor-core")
project(":sample-app").projectDir = file("../sample-app")
