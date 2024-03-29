ARS [handlers] (2019-10-4)
 * [bmc_itsm7_change_work_info_create_ce_v1] 
    * Updated Submitter field to requried
    * Removed duplicate handler folders inside handler

ARS [bridge adapters] (2019-09-17)
 * [kinetic-bridgehub-adapter-ars-rest] 
    * Initial development of the ARS version 9 bridge adapter.

ARS [handlers] (2019-11-06)
 * [bmc_itsm9_person_create_v1] 
    * Initial commit
 * [bmc_itsm9_person_update_v1] 
    * Initial commit
 * [bmc_itsm9_support_group_member_add_v1] 
    * Initial commit
 * [bmc_itsm9_support_group_member_functional_role_v1] 
    * Initial commit
 * [bmc_itsm9_support_group_member_remove_v1] 
    * Initial commit

ARS [handlers] (2019-12-16)
 * [ars9_generic_query_retrieve_v1]
    * Removed unneeded info values from info.xml file.

ARS [bridge adapters] (2019-12-23)
 * [kinetic-bridgehub-adapter-ars] (2019-12-23)
    * fixed issue with multiple remedy instances using the same bridge adapter.
    Global forms were being set for performance reasons.

ARS [bridge adapters] (2019-12-27)
 * [kinetic-bridgehub-adapter-ars] (2019-12-27) 
    * Removed nexus from the POM.  We're using s3 to store dependencies now.

ARS [bridge adapters] (2020-01-22)
 * [kinetic-bridgehub-adapter-ars-rest] 
    * PER-180 fixed auth bug issue.
    
ARS [bridge adapters] (2020-04-15)
 * [kinetic-bridgehub-adapter-ars-rest] 
    * fixed auth issue.

ARS [bridge adapters] (2020-05-12)
 * [kinetic-bridgehub-adapter-ars-rest] 
    * PER-188 replace spaces for %20 in path segment of qualification mapping
 * [kinetic-bridgehub-adapter-ars-rest] 
    * PER-189 return result consistent between retrieve and search

ARS [bridge adapters] (2020-07-13)
 * [kinetic-bridgehub-adapter-ars-rest]
    * PER-193 Refactor adapter to use structure pattern.  In the process fix issue found in last review.
    
ARS [bridge adapters] (2020-07-16)
 * [kinetic-bridgehub-adapter-ars-rest]
    * PER-193 Added JsonPath library.

ARS [handlers] (2020-09-30)
 * [remedy_generic_query_retrieve_v2] 
    * Bug Fix
 * [remedy_generic_query_retrieve_v3] 
    * Bug Fix
 * [remedy_generic_query_retrieve_v4] 
    * Bug Fix
	
ARS [handlers] (2021-01-06)
 * [ars9_generic_query_retrieve_v1] 
    * Updated escape method.

ARS [bridge-adapter] (2021-02-25)
 * [kinetic-bridgehub-adapter-ars]
    * PER-204 fixed issue that caused field to large for sort error to be thrown.
    * versioned adapter to v1.0.4

ARS [handlers] (2021-08-27)
 * [ars9_generic_create_v1] 
    * PER-224 cleaned up code formatting
 * [bmc_itsm7_work_order_work_info_create_ce_v1] 
    * PER-224 cleaned up code formatting
 * [ars_entry_create_attachment_ce_v1]
    * PER-224 initial create
	
ARS [handlers] (2021-10-13)
 * [ars_rest_generic_create_v1] 
    * Renamed and updated descriptions
 * [ars_rest_generic_query retrieve_v1] 
    * Renamed and updated descriptions
 * [ars_rest_generic_update_v1] 
    * Renamed and updated descriptions
 * [ars_rest_generic_create_attachment_ce_v1] 
    * Renamed and updated descriptions

ARS [handlers] (2021-11-10)
 * [ars_rest_api_v1] 
    * PER-239 Initial development of new handler.

ARS [bridge adapters] (2022-01-05)
  * [kinetic-bridgehub-adapter-ars-rest]
    * PER-248 fixed bug in rest v2 adapter with refresh token

ARS [bridge adapters] (2022-01-04)
  * [kinetic-bridgehub-adapter-ars-rest]
    * bumped dependencies flagged by debendabot.

ARS [handlers] (2022-02-16)
  * [bmc_itsm7_change_work_info_create_ce_v2] 
    * PER-256 Initial development of new handler.


ARS [bridge-adapters] (2024-02-20)
  * [kinetic-bridgehub-adapter-ars-rest] v2.0.3
    * updated snakeyaml version due to vulnerability
