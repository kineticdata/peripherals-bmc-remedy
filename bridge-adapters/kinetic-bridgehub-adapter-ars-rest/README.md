# Kinetic Bridgehub Adapter Ars9
This Rest based bridge adapter was designed to work with Remedy Action Request System version 9.
___
## Adapter Configurations
Name | Description
------------ | -------------
Username | Username of user with privilege on the AR System
Password | Privileged user's password
URL Origin | Web address to AR System server (ex: https://foo.bar.com)
___
## Supported structures
* Entry
* Adhoc
___
## Example Qualification Mapping
* Adhoc Structure: 
  * entry/CMT:People?q='Remedy Login ID'="_fooBar"
* Entry > CMT:People Structure:
  * q='Remedy Login ID'="_fooBar"

___
## Notes
* Attributes mappings are case sensitive.
* Fields used in queries to Remedy are case sensitive.
* In reference the Adhoc structure:
  * The Adhoc qualification mapping is split into two segments
    * ex: path?query
  * encoding in the path segment must be done manually.
    *  Due to how frequent spaces are in the path the adapter automatically 