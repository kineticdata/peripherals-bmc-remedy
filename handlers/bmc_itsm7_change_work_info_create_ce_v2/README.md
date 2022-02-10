# BMC_ITSM7_ChangeWorkInfo_Create_Remote_ARS
Creates a BMC ITSM7 Infrastructure Change Work Info record based upon the
parameters provided.

This handler provides options to include a link to the Review Request view of
the triggering Kinetic Request submission, include a string of question answer
pairs for the triggering Kinetic Request submission, or to attach files from an
Attachment question on the triggering Kinetic Request submission to the Work
Log record.

The BMC ITSM7 Infrastructure Change Work Info record is associated to the
Infrastructure Change worklog by submitting the processed information to the
'CHG:Worklog' form.

For more information, see the Detailed Description section below.

## Parameters
[Change Number]
  The change number of the Change to associate the Change Work Info entry with.

[Include Review Request]
  Option to prepend the review request URL to the Notes of the Change Work
  Info entry. Options: Yes, No

[Include Question Answers]
  Option to append the question answer pairs to the Notes of the Change Work
  Info entry.  Options: Yes, No

[Work Info Summary]
  Sets the Summary of the Change Work Info entry.

[Work Info Notes]
  Sets the Notes of the Change Work Info entry.

[Work Info Submit Date]
  Sets the Date of the Change Work Info entry.

[Attachment Input Type]
  Choose Field if the input for the attachment info as a Field Name or choose JSON if the input is 
  a (single) attachment's JSON from the Get Attachment Info handler. Note that if Field is specified, the 
  fields entered should only allow one attachment. Options: Field, JSON (Default: Field)

[Attachment Field 1]
  The field name of an attachment question to retrieve an attachment from. Displayed if Attachment Input Type is Field.

[Attachment Field 2]
  The field name of an attachment question to retrieve an attachment from. Displayed if Attachment Input Type is Field.

[Attachment Field 3]
  The field name of an attachment question to retrieve an attachment from. Displayed if Attachment Input Type is Field.

[Attachment JSON 1]
  The JSON of an attachment question to retrieve an attachment from. Displayed if Attachment Input Type is JSON.

[Attachment JSON 2]
  The JSON of an attachment question to retrieve an attachment from. Displayed if Attachment Input Type is JSON.

[Attachment JSON 3]
  The JSON of an attachment question to retrieve an attachment from. Displayed if Attachment Input Type is JSON.

[Submitter]
  Sets the Submitter of the Change Work Info entry.

[Locked]
	Sets the Change Work Info entry Locked status. Valid choices:Yes,No				   

[View Access]
	Sets the Change Work Info entry to Public or Internal. Valid choices: Public,Internal

[Work Info Source]
	Sets the Change Work Info Communication Source value.  Options include: 
	Email, Fax, Phone, Voice Mail, Walk In, Pager, System Assignment, Web, and Other. Defaults to Web

[Work Info Type]
	Sets the Change Work Info Type value.  Many options exist for this field.  
	The most commonly used is 'General Information'. Defaults to General Information

[Submission ID]
	The instance id of the submission you want data returned from.  Typically the 
	originating service item in a parent/child scenario.

[Space Slug]
	Space this is being used in. Can override provided info parameter.

### Sample Configuration
Change ID::                     <%= @results['Create Change']['Change ID'] %>

Include Review Request::              No

Include Question Answers::            No

Work Info Summary::                   <%= @inputs['Summary'] %>

Work Info Notes::                     <%= @inputs['Notes'] %>

Work Info Submit Date::               <%= @inputs['Date'] %>

Attachment Input Type::	Field

Attachment Field 1::    Attachment Question A

Attachment Field 2::    Attachment Question B

Attachment Field 3::    Attachment Question C

Submitter::                           <%= @inputs['Login Id'] %>

Locked::							  Yes

View Access::						  Public

Work Info Source::					  Web

Work Info Type::					  General Information

Submission ID::				  <%= @inputs['Submission Id'] %>

Space Slug::				  

## Results
[Entry Id]
  The Request Id of the generated Change Work Info entry.

## Detailed Description
Creates Work Info entries related to a Change Request.  The relationship is
established by placing the Change Number in the Infrastructure Change ID field 
on the CHG:Work Log form.

The Include Review Request parameter invokes a method that builds and places
a link in the Notes field on the Work Info entry.  When this link is clicked,
the original service request submission is opened in the read-only Review
Request mode.

The Include Question Answers parameter invokes a method which builds a question 
and answer pair display of the service request submittal. These data elements
are  placed in the Notes field of the Work Info entry.  This provides a quick
view of the triggering service request submittal data.

The Work Info entry accommodates up to three file attachments.  When configuring
the task, this handler expects the value Menu Label of the attachment question.
The handler will use this name to locate the attachment file within the Remedy
forms of the Kinetic Request application. If more than three attachments are 
needed, it is recommended to create additional Work Info entries.

This handler is safe to use in a subtree because it does not rely on any @base 
information to process. All data is passed into the handler as parameters.

This handler allows for a configuration where the ARS system used for Kinetic
and the ARS system used for BMC Remedy ITSM7 are different.

The following data is used to create the 'CHG:Worklog' record:
* Sets the 'Detailed Description' field to a concatenation of the following:
  - The URL link to the Review Request view of the triggering Kinetic Request 
    submission (if provided).
  - The value of the "Work Info Notes" parameter.
  - The formatted string of Question name to full answer pairs (if provided).
* Sets the 'Infra. Change Entry ID' field to the result of a lookup to the
  CHG:Infrastructure Change form.  The lookup is done using the change number
  parameter and the resulting entry's request id is used.
* Attaches the files associated to the specified Attachment field menu label 
  parameters to the specified fields:
  - 'z2AF Work Log01'          => "Attachment Question Menu Label 1"
  - 'z2AF Work Log02'          => "Attachment Question Menu Label 2"
  - 'z2AF Work Log03'          => "Attachment Question Menu Label 3"
* Sets the following field values to the specified values:
  - 'Communication Source'     => "Web"
  - 'z1D Previous Operation'   => "SET"
  - 'Status'                   => "Enabled"
  - 'Work Log Type'            => "General Information"
* Sets the following field values to the values of the specified parameters:
  - 'Infra. Change Entry ID'   => "Change Number"
  - 'Infrastructure Change ID' => "Change Number"
  - 'Description'              => "Work Info Summary"
  - 'Detailed Description'     => "Work Info Notes"
  - 'Work Log Date'            => "Work Info Submit Date"
  - 'Work Log Submitter'       => "Submitter"
  - 'Secure Work Log'          => "Locked"
  - 'View Access'              => "View Access"