// L'app Android de Micabo. Pour l'instant, un écran d'accueil : elle sert à ouvrir la fiche
// Google Play et la chaîne d'envoi (test interne). L'app elle-même viendra ensuite.
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

rootProject.name = "Micabo"
include(":app")
