// 构建脚本配置块 - 用于配置构建过程本身
buildscript {
    // 构建脚本的仓库配置
    repositories {
        // 阿里云镜像放在最前面，加速依赖下载
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        // 官方源作为备用
        google()
        mavenCentral()
    }

    // 构建脚本的依赖
    dependencies {
        // Android Gradle 插件
        classpath("com.android.tools.build:gradle:8.1.0")
        // Kotlin Gradle 插件
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.0")
    }
}

// 所有项目的通用配置
allprojects {
    repositories {
        // 同样配置阿里云镜像，用于项目依赖下载
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        google()
        mavenCentral()
    }
}

// 以下是你的原有配置，保持不动
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

// 清理任务
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}