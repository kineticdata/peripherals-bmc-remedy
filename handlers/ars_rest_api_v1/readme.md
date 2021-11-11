# ARS REST API
ARS REST API V1 Client

## Parameters
[Error Handling]
  Select between returning an error message, or raising an exception.
[Method]
  HTTP Method to use for the ARS API call being made.
  Options are:
    - GET
    - POST
    - PUT
    - DELETE
[Path]
  The relative API path (to the `api_server` info value) that will be called.
  This value should begin with a forward slash `/`.
  Example - All Fields: /CTM:People?q='Profile Status'="Enabled"
  Example - Specific Fields: /CTM:People?fields=values(Profile Status,Remedy Login ID)&q='Profile Status'="Enabled"
[Body]
  The body content (JSON) that will be sent for POST and PUT requests.
  Example - {"values":{"Field 1":"Test 1","Field 2":"Test 2"}}

## Results
[Response Body]
  The returned value from the Rest Call (JSON format)
 
## Notes
  This handler is for the V1 version of the BMC Remedy AR System REST API.
  /arsys/v1/entry is hardcoded in lines 36 and 39 of the init.rb for ease of use.
  
## Helpful BMC Documentation
  https://docs.bmc.com/docs/ars1902/learning-about-the-rest-api-931131942.html
