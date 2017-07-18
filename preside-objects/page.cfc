/**
 * ElasticSearch extension specific decorations of the core preside page object
 * The purpose here is to make certain fields searchable.
 *
 */
component output=false {
	property name="title"              searchEnabled=true;
	property name="navigation_title"   searchEnabled=true;
	property name="teaser"             searchEnabled=true;
	property name="main_content"       searchEnabled=true;
	property name="meta_description"   searchEnabled=true;
	property name="site"               searchEnabled=true searchSearchable=false;
	property name="datecreated"        searchEnabled=true;
}