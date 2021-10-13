## Ars Rest Generic Create Attachment Ce
Creates a single Remedy entry (with attachment optional) given the JSON mapping of field values and form name.  Attachments are retrieved from filehub referenced by a submission id.  

### Parameters
[Error Handling]
  * Error message if an error was encountered and Error Handling is set to "Error Message". 

[ARS Form Name]
  * The ARS form name that the record will be created in.

[ARS Field Values]
  * JSON mapping of ARS field names along with the desired values.

[ARS Attachment Field 1 Name]
  * The ARS attachment field name to create the attachment in.

[ARS Attachment Field 2 Name]
  * The ARS attachment field name to create the attachment in.

[ARS Attachment Field 3 Name]
  * The ARS attachment field name to create the attachment in.

[CE Attachment Field 1 Name]
  * The CE submission field name to retrieve the attachment from.

[CE Attachment Field 2 Name]
  * The CE submission field name to retrieve the attachment from.

[CE Attachment Field 3 Name]
  * The CE submission field name to retrieve the attachment from.

[Submission ID]
  * The id of the CE submission to retrieve answers for.
  
#### Sample Configuration
Error Handling: Error Message
Form Name:: HPD:LoadTemplate
Field Values::
```javascript
    {
        "Foo":"Bar",
        "Attachment FieldName":"AttachmentBizz",
    }
```

### Results
[Handler Error Message]
  * Error, if one is found
  
[Results]
  * Success or failure of specified create as returned by the ARS REST API.
  
[Record Location]
  * Resulting record location (url) as returned by the ARS REST API.
  
[Record Id]
  * Id of the created record.
  

### Detailed Description
* This handler takes a json as input of a format like
{"DB field Name":"value to place in field"}
and uses this to create a record in the specified form.

* At times, you may need to set Currency Fields in Remedy. This is accomplished
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
<%#
{
  'Text Field 1' #> 'ABCD-EFG',
  'Text Field 2' #> '123456',
  'Currency Field 1' #> {'value' #> @inputs["Currency Input"].to_f, 'currency' #> 'USD' },
}.to_json
%>
```
* It is assumed that all attachment fields on the connect form will have only on attachment.

* Only three attachment can be mapped between a Kinetic Data submission and an ARS entry.  The mapping must be a one to one between fields.  This means the Kinetic Data form must have three attachment fields to attach three documents to a entry.
