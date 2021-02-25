ARS v1.0.1 (12-23-19)
    * fixed issue with multiple remedy instances using the same bridge adapter.
    Global forms were being set for performance reasons.

ARS v1.0.3 (12-27-19)
    * Removed nexus from the POM.  We're using s3 to store dependencies now.

ARS v1.0.4 (02-25-21)
    * PER-204 fixed issue that caused field to large for sort error to be thrown.  A character limit of 1000 was added. 
