# Kinetic Bridgehub Adapter Ars9

This Rest based bridge adapter was designed to work with Remedy Action Reqeust System version 9.
___
## Adapter Configurations
Name | Description
------------ | -------------
Username | Username of user with privlage on the AR System
Password | Privileged user's password
URL Origin | Web address to AR System server (ex: https://foo.bar.com)
___
## Supported structures
* Entry
___
## Example Qualification Mapping
* entry/CMT:People?q='Remedy Login ID'="_fooBar"
* The qualification mapping is two parts
  * entry/CMT:People is the path segment
  * q='Remedy Login ID'="_fooBar" is the query segment

___
## Notes
* Attributes mappings are case sensitive.
* Fields used in queries to Remedy are case sensitive.
* encoding in the path segment must be done manually.
  *  Due to how frequent spaces are in the path the adapter automatically 