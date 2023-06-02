import java.text.SimpleDateFormat
import java.util.Date
plugins {
    java
    `maven-publish`
    id("net.nemerosa.versioning") version "2.14.0"
}

repositories {
  mavenLocal()
  maven {
    url = uri("https://s3.amazonaws.com/maven-repo-public-kineticdata.com/releases")
  }

  maven {
    url = uri("s3://maven-repo-private-kineticdata.com/releases")
    authentication {
      create<AwsImAuthentication>("awsIm")
    }

  }

  maven {
    url = uri("https://s3.amazonaws.com/maven-repo-public-kineticdata.com/snapshots")
  }

  maven {
    url = uri("s3://maven-repo-private-kineticdata.com/snapshots")
    authentication {
      create<AwsImAuthentication>("awsIm")
    }
  }

  maven {
    url = uri("https://repo.maven.apache.org/maven2/")
  }

  maven {
    url = uri("https://repo.springsource.org/release/")
  }

}

dependencies {
    implementation("com.kineticdata.filehub:kinetic-filehub-adapter:1.1.0")
    implementation("com.bmc:arapi:8.0.0.build001")
    implementation("com.google.guava:guava:18.0")
    implementation("org.apache.tika:tika-core:1.22")
    testImplementation("junit:junit:4.13.1")
}

group = "com.kineticdata.filehub.adapters.ars"
version = "1.0.3"
description = "kinetic-filehub-adapter-ars"
java.sourceCompatibility = JavaVersion.VERSION_1_8

publishing {
    publications.create<MavenPublication>("maven") {
        from(components["java"])
    }
  repositories {
    maven {
      val releasesUrl = uri("s3://maven-repo-private-kineticdata.com/releases")
      val snapshotsUrl = uri("s3://maven-repo-private-kineticdata.com/snapshots")
      url = if (version.toString().endsWith("SNAPSHOT")) snapshotsUrl else releasesUrl
      authentication {
        create<AwsImAuthentication>("awsIm")
      }
    }
  }
}

tasks.withType<JavaCompile>() {
    options.encoding = "UTF-8"
}
versioning {
  gitRepoRootDir = "../../"
}
tasks.processResources {
  duplicatesStrategy = DuplicatesStrategy.INCLUDE
  val currentDate = SimpleDateFormat("yyyy-MM-dd").format(Date())
  from("src/main/resources"){
    filesMatching("**/*.version") {    
      expand(    
        "buildNumber" to versioning.info.build,
        "buildDate" to currentDate,    
        "timestamp" to System.currentTimeMillis(),    
        "version" to project.version    
      )    
    }
  }
}
