plugins {
    java
    `maven-publish`
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
  }

  dependencies {
    implementation("com.kineticdata.filehub:kinetic-filehub-adapter:1.1.0"){
      exclude(group="org.slf4j", module="slf4j-api")
    }
    implementation("com.bmc:arapi:8.0.0.build001")
    implementation("com.google.guava:guava:18.0")
    implementation("org.apache.tika:tika-core:1.22")

    implementation("org.apache.logging.log4j:log4j-api:2.17.1")
    implementation("org.apache.logging.log4j:log4j-core:2.17.1")
    implementation("org.apache.logging.log4j:log4j-slf4j-impl:2.17.1")
    testImplementation("junit:junit:4.13.1")
  }

  group = "com.kineticdata.filehub.adapters.ars"
  version = "1.0.2"
  description = "kinetic-filehub-adapter-ars"
  java.sourceCompatibility = JavaVersion.VERSION_1_8

  publishing {
    publications.create<MavenPublication>("maven") {
      from(components["java"])
    }
  }

  tasks.withType<JavaCompile>() {
    options.encoding = "UTF-8"
  }
