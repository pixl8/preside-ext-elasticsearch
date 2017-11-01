/**
 * A queue to store entities that have changed and will require re-indexing AFTER an active full index has completed
 *
 * @nolabel   true
 * @versioned false
 */
component {
	property name="index_name"  type="string"  dbtype="varchar" required=true maxlength=100 indexes="indexname";
	property name="object_name" type="string"  dbtype="varchar" required=true maxlength=255 indexes="objectname";
	property name="record_id"   type="string"  dbtype="varchar" required=true maxlength=255 indexes="recordid";
	property name="is_deleted"  type="boolean" dbtype="boolean" required=false default=false;
}