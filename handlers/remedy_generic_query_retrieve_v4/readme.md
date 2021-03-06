== Remedy Generic Retrieve
This handler returns all the fields of the first matching entry or all entries for the
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
[Result Type]
  	You can choose to return a single (the first) result to the query or all results
    to the query. Choices: single, all  Default: single

=== Sample Configuration
Error Handling:         Error Message
Remedy Form:            User
Request ID:             <%=@results['retrieve user']['Request ID']%>

=== Results
[Handler Error Message]
	Error message if an error was encountered and Error Handling is set to "Error Message".
[Remedy Field Name]
  The value of the Remedy field. (There will be one result for each field retrieved.)

=== Detailed Description
This handler has the ability to have form caching disabled.  To disable form caching set
disable_caching to "Yes".  Disabling caching may negatively impact performance, but it
is also necessary when using a single handler to interact with multiple Remedy
environments.

This handler returns all the fields for the request id provided
in the form specified for the "single" option. For the "all" option, it returns
a json string of the found entries.
