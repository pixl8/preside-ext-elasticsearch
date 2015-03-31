/**
 * Extends the asset folder storage location for assets object (see :doc:`/reference/presideobjects/asset`)
 */
component {
	property name="internal_search_access"  type="string"  dbtype="varchar" maxLength="7" required=false default="block"   format="regex:(allow|block)" control="select" values="allow,block" labels="preside-objects.asset_folder:internal_search_access.option.allow,preside-objects.asset_folder:internal_search_access.option.deny";
}