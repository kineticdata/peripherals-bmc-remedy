== ARS REST Generic Query Retrieve
This handler returns all the fields for the request id provided
in the form specified. 

For more information, see the Detailed Description section below.

=== Parameters
[Remedy Form]
	Remedy Form Name (not display name), eg. People is CTM:People
[Query]
	The query to search by

=== Sample Configuration
Remedy Form::       User
Query::		Request ID' = "<%=@results['retrieve user']['Request ID']%>"

=== Results
[Handler Error Message]
   Error, if one is found
[#FIELD NAME PLACE HOLDER#]
   This will actually be one result for each field on the form with 
   the name of the field name and the result of the field content.
   
=== Detailed Description
This handler returns all the fields for the query provided
in the form specified.  This is returned in XML format (like below).
```
<field_list>
	<field id='Request ID'>000000000000001</field>
	<field id='Creator'>Action Request Installer Account</field>
	<field id='Create Date'>Mon Apr 25 16:42:22 -0400 2011</field>
	<field id='Assigned To'></field>
	<field id='Last Modified By'>Demo</field>
	<field id='Modified Date'>Wed Dec 07 11:46:47 -0500 2011</field>
	<field id='Status'>Current</field>
</field_list>
```
Note that if there is more than one result, only the first is returned.
The sorting (which is returned first) is determined by the server.
