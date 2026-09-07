plugins {
    kotlin("jvm") version "2.2.21"
    application
}

val material3Version = "1.5.0-alpha27"

dependencies {
    implementation("androidx.compose.material3:material3:$material3Version")
}

application {
    mainClass = "ExportMaterialShapesKt"
}

tasks.named<JavaExec>("run") {
    systemProperty("material3Version", material3Version)
}
