== Remedy Generic Retrieve
This handler returns all the fields of the first matching entry for the
specified Remedy form name and query.

For more information, see the Detailed Description section below.

=== Parameters
[Error Handling]
  Determines what to return if an error is encountered (Error Message or Raise
  Error).
[Remedy Form]
	Remedy Form Name (not display name), eg. People is CTM:People
[Query]
	Advanced Search Query of the record to retrieve

=== Sample Configuration
Error Handling:         Error Message
Remedy Form:            User
Request ID:             <%=@results['retrieve user']['Request ID']%>

=== Results
[Handler Error Message]
	Error message if an error was encountered and Error Handling is set to "Error Message".
[<Remedy Field Name>]
  The value of the Remedy field. (There will be one result for each field retrieved.)

=== Detailed Description
This handler returns all the fields for the request id provided
in the form specified.
