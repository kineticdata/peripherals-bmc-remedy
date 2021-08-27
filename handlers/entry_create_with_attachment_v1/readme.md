## ARS9 Generic Create
Creates a single Remedy entry given the JSON mapping of field values and form name.

### Parameters
[Error Handling]
  * Error message if an error was encountered and Error Handling is set to "Error Message". 

[Form Name]
  * Name of Remedy form to load data into

[Field Values]
  * JSON mapping of field values

[Attachment Field 1]
  * The Field Name of an attachment question to retrieve an attachment from.

[Attachment Field 2]
  * The Field Name of an attachment question to retrieve an attachment from.

[Attachment Field 3]
  * The Field Name of an attachment question to retrieve an attachment from.

[ARS Attachment Field 1]
  * The ARS Field Name of an attachment question to retrieve an attachment from.

[ARS Attachment Field 2]
  * The ARS Field Name of an attachment question to retrieve an attachment from.

[ARS Attachment Field 3]
  * The ARS Field Name of an attachment question to retrieve an attachment from.

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
   Error, if one is found
[Results]
  Success or failure of specified create as returned by the ARS REST API.
[Record Location]
  Resulting record location (url) as returned by the ARS REST API.
[Record Id]
  Id of the created record.

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
* It is assumed that all attachment fields on the connect form will have only on 
attachment.
