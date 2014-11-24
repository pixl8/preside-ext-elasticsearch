component output=false {
	public void function configure( required struct config ) output=false {
		var conf     = arguments.config;
		var settings = conf.settings ?: {};

		settings.filters.elasticSearchPageFilter = {
			filter = "page.internal_search_access != 'block'"
		};
	}
}