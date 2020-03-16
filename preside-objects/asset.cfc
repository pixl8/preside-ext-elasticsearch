/**
 * ElasticSearch extension specific decorations of the core preside asset object
 * The purpose here is to make certain fields searchable.
 *
 * @searchEnabled true
 *
 */
component output=false {
	property name="asset_folder"        searchEnabled=true searchType="keyword";
	property name="title"               searchEnabled=true;
	property name="original_title"      searchEnabled=true;
	property name="storage_path"        searchEnabled=true;
	property name="trashed_path"        searchEnabled=true;
	property name="description"         searchEnabled=true;
	property name="author"              searchEnabled=true;
	property name="size"                searchEnabled=true;
	property name="asset_type"          searchEnabled=true;
	property name="raw_text_content"    searchEnabled=true;

	property name="access_restriction"  searchEnabled=true;
	property name="full_login_required" searchEnabled=true;

	property name="site"                searchEnabled=true searchType="keyword";
	property name="datecreated"         searchEnabled=true;
}