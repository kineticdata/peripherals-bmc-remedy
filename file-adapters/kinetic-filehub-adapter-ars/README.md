# kinetic-filehub-adapter-ars
Filestore implementation for interacting with attachments stored within BMC Action Request System.

## Developer Notes
To run unit tests: 
1. Add `.test-config` directory to the machine home directory.
1. Add `kinetic-filehub-adapter-ars.properties` file to the directory.
1. Add below config to the file.
    ```
    Server=ars.acme.com
    Port=3000
    Username=User
    Password=$ecretP@55word
    ```
* Running the unit tests will log the location that the adapter expects to find the config file.
* The `KTEST_FilehubArsAdapter_AttachmentForm` is required to be on the server.  The ARS Form can be found within the project under `src/test/resources`.
* The Test suite has code to import the form to the configured environment.
* Building the adapter requires access to Kinetic Data's amazon private maven repo.
