/**
 * @nolabel   true
 * @versioned false
 */
component output=false {
	property name="index_name"                 type="string"  dbtype="varchar"  required=true  maxlength=100 indexes="indexstatus|1" uniqueindexes="indexname";
	property name="is_indexing"                type="boolean" dbtype="boolean"  required=true                indexes="indexstatus|2";
	property name="indexing_started_at"        type="date"    dbtype="datetime" required=false;
	property name="indexing_expiry"            type="date"    dbtype="datetime" required=false;
	property name="last_indexing_success"      type="boolean" dbtype="boolean"  required=false;
	property name="last_indexing_completed_at" type="date"    dbtype="datetime" required=false;
	property name="last_indexing_timetaken"    type="numeric" dbtype="int"      required=false;
}
