== ARS REST Generic Update
Updates a single Remedy entry given the entry id, JSON mapping of field values,
 and form name.

=== Parameters
[Error Handling]
  Error message if an error was encountered and Error Handling is set to "Error Message".
[Form Name]
  Name of Remedy form to load data into
[Field Values]
  JSON mapping of field values
[Entry ID]
  ID of the entry to be updated

==== Sample Configuration
Error Handling: Error Message
Form Name:: HPD:Template
Field Values::
```javascript
    {
        "Status Template":"<%=@answers['Template Status']%>",
    }
```

=== Results
[Handler Error Message]
   Error, if one is found
[Results]
  Success or failure of specified create as returned by the ARS REST API.

=== Detailed Description
This handler takes a json as input of a format like
{"DB field Name":"value to place in field"}
and uses this to update those fields on the record specified by the
entry id in the specified form.

At times, you may need to set Currency Fields in Remedy. This is accomplished
by formatting the value as follows:
```
{
 ...
 "My Currency Field":{"value":100.0,"currency":"USD"},
 ...
}
```
The value portion must be parsed as a float. You can accomplish this as follows
in the Field Values parameter:
```
<%=
{
  'Text Field 1' => 'ABCD-EFG',
  'Text Field 2' => '123456',
  'Currency Field 1' => {'value' => @inputs["Currency Input"].to_f, 'currency' => 'USD' },
}.to_json
%>
```
