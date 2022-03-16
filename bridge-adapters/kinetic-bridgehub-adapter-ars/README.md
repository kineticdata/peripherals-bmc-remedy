# BMC Remedy ARS Bridgehub Adapter
A Kinetic Bridgehub adapter for the BMC Remedy ARS platform.  This adapter leverages the ARS Java interface.
## Configuration Values
| Name                    | Description | Example Values
| :---------| :------------------- | :------------------- |
| Username  | Remedy login name | Demo |
| Password  | Remedy password | secret-password |
| Server    | Remedy server name or IP Address | remedy-server.acme.com |
| Port      | Remedy TCP Port | 3000 |
| Prognum   | Remedy RPC Prognum | 0 |

Supported Structures
| Name                    | Description | Example Values
| :---------| :------------------- | :------------------- |
| {Table Name} | A table name is the supported structures | CTM:People

Attributes and Fields
Only fields configured in the Attribute mapping will be returned.

## Notes
* This adapter has dependence's on the [Java BMC ARS](https://www.ibm.com/docs/en/netcoolomnibus/8?topic=91-installing-bmc-remedy-ars-jar-files) jar files and KD ArsHelpers project.
    * BMC ARS version 8.0.0 and build 001 are the current tested version.
    * KD ArsHelpers in an internal KD project, please request to get the jar file.