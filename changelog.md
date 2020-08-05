ARS \[handlers\] (2019-10-4)
  \[bmc_itsm7_change_work_info_create_ce_v1\] (2019-10-4)
    * Updated Submitter field to requried
    * Removed duplicate handler folders inside handler

ARS \[bridge adapters\] (2019-09-17)
  \[kinetic-bridgehub-adapter-ars-rest\] (2019-09-17)
    * Initial development of the ARS version 9 bridge adapter.

ARS \[handlers\] (2019-11-06)
  \[bmc_itsm9_person_create_v1\] (2019-11-06)
    * Initial commit
  \[bmc_itsm9_person_update_v1\] (2019-11-06)
    * Initial commit
  \[bmc_itsm9_support_group_member_add_v1\] (2019-11-06)
    * Initial commit
  \[bmc_itsm9_support_group_member_functional_role_v1\] (2019-11-06)
    * Initial commit
  \[bmc_itsm9_support_group_member_remove_v1\] (2019-11-06)
    * Initial commit

ARS \[handlers\] (2019-12-16)
  \[ars9_generic_query_retrieve_v1\] (2019-12-16)
    * Removed unneeded info values from info.xml file.

ARS \[bridge adapters\] (2019-12-23)
  \[kinetic-bridgehub-adapter-ars\] (2019-12-23)
    * fixed issue with multiple remedy instances using the same bridge adapter.
    Global forms were being set for performance reasons.

ARS \[bridge adapters\] (2019-12-27)
  \[kinetic-bridgehub-adapter-ars\] (2019-12-27) 
    * Removed nexus from the POM.  We're using s3 to store dependencies now.

ARS \[bridge adapters\] (2020-01-22)
  \[kinetic-bridgehub-adapter-ars-rest\] (2020-01-22)
    * PER-180 fixed auth bug issue.
    
ARS \[bridge adapters\] (2020-04-15)
  \[kinetic-bridgehub-adapter-ars-rest\] (2020-04-15)
    * fixed auth issue.

ARS \[bridge adapters\] (2020-05-12)
  \[kinetic-bridgehub-adapter-ars-rest\] (2020-05-12)
    * PER-188 replace spaces for %20 in path segment of qualification mapping
  \[kinetic-bridgehub-adapter-ars-rest\] (2020-05-12)
    * PER-189 return result consistent between retrieve and search

ARS \[bridge adapters\] (2020-07-13)
  \[kinetic-bridgehub-adapter-ars-rest\]
    * PER-193 Refactor adapter to use structure pattern.  In the process fix issue found in last review.
    
ARS \[bridge adapters\] (2020-07-16)
  \[kinetic-bridgehub-adapter-ars-rest\]
    * PER-193 Added JsonPath library.