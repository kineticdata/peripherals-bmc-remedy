# BMC Remedy ARS Bridgehub Adapter
A Kinetic Bridgehub adapter for the BMC Remedy ARS platform

* [BMC Remedy ARS Bridgehub Adapter Information](#bmc-remedy-ars-bridgehub-adapter-information)
  * [Configuration Values](#configuration-values)
  * [Example Configuration](#example-configuration)
  * [Changelog](#changelog)
* [General Bridgehub Information](#general-bridgehub-information)
  * [What is a Bridgehub adapter?](#what-is-a-bridgehub-adapter)
  * [Bridgehub adapter basics](#bridgehub-adapter-basics)
  * [How is the adapter tested?](#how-is-the-adapter-tested)
  * [How is the adapter built?](#how-is-the-adapter-built)
  * [Adding the adapter to Bridgehub](#adding-the-adapter-to-bridgehub)

# BMC Remedy ARS Bridgehub Adapter Information
---
## Configuration Values
| Name                    | Description |
| :---------| :------------------------- |
| Username  | Remedy login name |
| Password  | Remedy password |
| Server    | Remedy server name or IP Address |
| Port      | Remedy TCP Port |
| Prognum   | Remedy RPC Prognum |

## Example Configuration
| Name | Value |
| :---- | :--- |
| Username | Demo |
| Password | secret-password |
| Server   | remedy-server.acme.com |
| Port     | 3000 |
| Prognum  | 0 |

## Changelog
### 1.0.0
* Initial Version

# General Bridgehub Information
---
## What is a Bridgehub adapter?
A Bridgehub adapter is an extension to be used with the [Kinetic Bridgehub](http://community.kineticdata.com/10_Kinetic_Request/Kinetic_Request_Core_Edition/Resources/Bridgehub) project. Each adapter allows Kinetic Bridgehub to retrieve data from the data source specified by the adapter.

---
## Bridgehub adapter basics
### Properties
Bridgehub properties are a set of parameters specific to each Bridgehub adapter. These parameters are normally configuration values for properties like username, password, server location, etc. 

### Initialize
A one time initialization method for the Bridgehub adapter that is required to successfully complete before any of the implementation methods (count,retrieve,search) can be executed. This allows an adapter author to pre-load operations to improve the speed of the implementation methods, validate the adapter properties, and set variables that can be used by other methods.

### Count
An implementation method that returns the amount of records for a given Structure and Query.

### Retrieve
An implementation method that returns a single record containing the specified Fields for a given Structure and Query. If there is more than one record that matches the Structure/Query combination, an error is thrown.

### Search
An implementation method that returns multiple records containing the specified Fields for a given Structure and Query. A search request can also optionally specify metadata (order,pagination,query parameters) to further refine the search results.

### Using Parameters
To allow for the use of query parameters when calling the implementation methods, make sure that the adapter substitutes the query parameters before making its call. The following is an example of this being done using the Kinetic Core Adapter:

```
KineticCoreQualificationParser parser = new KineticCoreQualificationParser();
String substitutedQuery = parser.parse(request.getQuery(),request.getParameters());
```

### Want more detail?
If you want more detail about how a Bridgehub adapter is structured and the various classes available to it, look at the Kinetic Bridgehub Adapter javadoc.

---
## How is the adapter tested?
Kinetic Bridgehub adapters are tested using JUnit tests. To import a set of standard JUnit tests that all bridge adapters need to be able to pass, extend the JUnit class for an adapter with the BridgeAdapterTestBase class. To go along with the BridgeAdapterTestBase, a bridge-config.yml file needs to be included with the test resources at `/src/test/resource/bridge-config.yml`. An empty file with instructions on how to fill it out should be included in the repository by default.

---
## How is the adapter built?
Kinetic Bridgehub adapters are built as Maven projects. To build the project from the command line, run the command `mvn package` from inside the adapter directory.

**NOTE:** Before building the adapter you will need to make sure that the kinetic-bridgehub-adapter JAR has been added to the Maven project. Currently the kinetic-bridgehub-adapter is only available as a 3rd party JAR file (included in this repository), so it will need to be manually installed before the project will successfully build. *Information on installing 3rd party JARs to Maven can be found [here](https://maven.apache.org/guides/mini/guide-3rd-party-jars-local.html).*

---
## Adding the adapter to Bridgehub
### Discovery file
Kinetic Bridgehub find and loads new adapters by looking for and loading up a file containing the main class of the Bridgehub Adapter. The name of the file is *com.kineticdata.bridgehub.adapter.BridgeAdapter* and it is located at `/src/resources/META-INF/adapters/com.kineticdata.bridgehub.adapter.BridgeAdapter`. The only thing that file should contain is the location of the main java adapter class. The following example shows the contents of the file for the Kinetic Core Adapter:

```
com.kineticdata.bridgehub.adapter.kineticcore.KineticCoreAdapter
```

### Adding the JAR to Kinetic Bridgehub
Once it has been built, the adapter JAR goes into the `WEB-INF\lib` of the Kinetic Bridgehub installation. After restarting the server containing Kinetic Bridgehub, the newly installed adapter should now show up in the adapter list.
