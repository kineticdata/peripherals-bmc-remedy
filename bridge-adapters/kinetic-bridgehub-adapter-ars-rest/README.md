# Kinetic Bridgehub Adapter Ars9
This Rest based bridge adapter was designed to work with Remedy Action Request System version 9.  This adapter utilizes the ARS Rest interface.
## Configuration Values
Name | Description | Example Values
------------ | ------------- | -------------
Username | Username of user with privilege on the AR System | user@acme.com
Password | Privileged user's password | secret-password
URL Origin | Web address to AR System server | https://foo.bar.com

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
* The Bridge Adapter limits the number of records returned to 1000.  This can be overridden to return fewer records.
* In reference the Adhoc structure:
  * The Adhoc qualification mapping is split into two segments
    * ex: path?query
  * encoding in the path segment must be done manually.
    *  Due to how frequent spaces are in the path the adapter automatically 
