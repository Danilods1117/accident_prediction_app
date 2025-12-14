buildscript {
    ext.kotlin_version = '1.9.0'
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath 'com.android.tools.build:gradle:8.1.0'
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = '../build'

subprojects {
    project.buildDir = "${rootProject.buildDir}/${project.name}"
}

subprojects {
    project.evaluationDependsOn(':app')
}

// Define flutter properties for all subprojects
subprojects {
    ext {
        flutter = [
            compileSdkVersion: 35,
            minSdkVersion: 21,
            targetSdkVersion: 35,
            ndkVersion: '25.1.8937393'
        ]
    }
}

// Ensure all plugins use compileSdk 35
subprojects {
    afterEvaluate { project ->
        if (project.hasProperty('android')) {
            project.android {
                if (compileSdkVersion == null) {
                    compileSdkVersion 35
                }
            }
        }
    }
}

tasks.register("clean", Delete) {
    delete rootProject.buildDir
}