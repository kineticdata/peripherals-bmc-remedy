== ARS REST Generic Create
Creates a single Remedy entry given the JSON mapping of field values and form name.

=== Parameters
[Error Handling]
  Error message if an error was encountered and Error Handling is set to "Error Message". 
[Form Name]
  Name of Remedy form to load data into
[Field Values]
  JSON mapping of field values


==== Sample Configuration
Error Handling: Error Message
Form Name:: HPD:LoadTemplate
Field Values::
```javascript
    {
        "Template Identifier":"<%=@answers['Template Identifier']%>",
        "Template Name":"<%=@answers['Template Name']%>",
        "Status Template":"<%=@answers['Template Status']%>",
        "Template Category Tier 1":"<%=@answers['Template Category Tier 1']%>",
        "Description":"<%=@answers['Summary']%>",
        "Detailed Decription":"<%=@answers['Notes']%>",
        "Reported Source":"<%=@answers['Reported Source']%>",
        "Service Type":"<%=@answers['Incident Type']%>",
        "Status":"<%=@answers['Status']%>",
        "Impact":"<%=@answers['Impact']%>",
        "Urgency":"<%=@answers['Urgency']%>",
        "Assigned Support Company":"<%=@answers['Assigned Support Company']%>",
        "Assigned Support Organization":"<%=@answers['Assigned Support Organization']%>",
        "Assigned Group":"<%=@answers['Authoring Group']%>",
        "Authoring Company":"<%=@answers['Authoring Company']%>",
        "Authoring Organization":"<%=@answers['Authoring Organization']%>",
        "Authoring Group":"<%=@answers['Authoring Group']%>"
    }
```

=== Results
[Handler Error Message]
   Error, if one is found
[Results]
  Success or failure of specified create as returned by the ARS REST API.
[Record Location]
  Resulting record location (url) as returned by the ARS REST API.
[Record Id]
  Id of the created record.

=== Detailed Description
This handler takes a json as input of a format like
{"DB field Name":"value to place in field"}
and uses this to create a record in the specified form.

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
