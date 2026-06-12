# Kinetic Bridgehub Adapter Ars9
This Rest based bridge adapter was designed to work with Remedy Action Request System version 9.  This adapter utilizes the ARS Rest interface.
## Configuration Values
Name | Description | Example Values
------------ | ------------- | -------------
Username | Username of user with privilege on the AR System | user@acme.com
Password | Privileged user's password | secret-password
URL Origin | Web address to AR System server | https://foo.bar.com
Max Records | Optional.  Hard ceiling on total records returned per request when the limit parameter exceeds 1000 (default 10000) | 10000

## Supported structures
Name | Description | Example Values
------------ | ------------- | -------------
Entry | This allows for get operations on the [entry object](https://docs.bmc.com/docs/ars91/en/operations-on-entry-objects-609071437.html).  Include the table to interact with. | Entry >  CMT:People
Adhoc | This allows for the full path to be entered in the qualification mapping | Adhoc

## Attributes and Fields
If no fields were provided the adapter will return all fields.  This can be useful when testing the bridge model.
* Attributes field mappings are case sensitive.

## Qualification (Query)
`/api/arsys/v1` is appended to the Origin URL on every query to make the start of the API path.  For the Adhoc Structure the qualification mapping value is appended to the end of the API path, see Notes for more details.
* Adhoc Structure: 
  * /entry/CMT:People?q='Remedy Login ID'="_fooBar"
* Entry > CMT:People Structure:
  * q='Remedy Login ID'="_fooBar"

## Notes
* [JsonPath](https://github.com/json-path/JsonPath#path-examples) can be used to access nested values. The root of the path is values.
* Fields used in queries to Remedy are case sensitive.
* A limit parameter of 1000 or less behaves as a single request page size.  A limit parameter greater than 1000 is treated as the total records desired and the v2 adapter aggregates paged requests internally in chunks of 1000, up to the Max Records configurable property (default 10000).
  * When the Max Records ceiling cuts results short a `truncated` indicator is set on the response metadata.
  * An explicit sort is recommended when aggregating (ex: `sort=Request ID.asc`).  Paging without a sort relies on the ARS server's default ordering.
  * Raising Max Records increases agent memory usage; size the agent JVM accordingly.
* In reference the Adhoc structure:
  * The Adhoc qualification mapping is split into two segments
    * ex: path?query
  * encoding in the path segment must be done manually.
    *  Due to how frequent spaces are in the path the adapter automatically 
