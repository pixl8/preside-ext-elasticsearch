component output=false {
	public void function configure( required struct config ) output=false {
		var conf     = arguments.config;
		var settings = conf.settings ?: {};

		settings.filters.elasticSearchPageFilter = {
			filter = "page.internal_search_access != 'block'"
		};

		conf.interceptorSettings.customInterceptionPoints.append( "preElasticSearchCreateIndex"               );
		conf.interceptorSettings.customInterceptionPoints.append( "postElasticSearchCreateIndex"              );
		conf.interceptorSettings.customInterceptionPoints.append( "preElasticSearchRebuildIndex"              );
		conf.interceptorSettings.customInterceptionPoints.append( "postElasticSearchRebuildIndex"             );
		conf.interceptorSettings.customInterceptionPoints.append( "postElasticSearchGetIndexSettings"         );
		conf.interceptorSettings.customInterceptionPoints.append( "preElasticSearchIndexDoc"                  );
		conf.interceptorSettings.customInterceptionPoints.append( "postElasticSearchIndexDoc"                 );
		conf.interceptorSettings.customInterceptionPoints.append( "preElasticSearchIndexDocs"                 );
		conf.interceptorSettings.customInterceptionPoints.append( "postElasticSearchIndexDocs"                );
		conf.interceptorSettings.customInterceptionPoints.append( "preElasticSearchGetObjectDataForIndexing"  );
		conf.interceptorSettings.customInterceptionPoints.append( "postElasticSearchGetObjectDataForIndexing" );
		conf.interceptorSettings.customInterceptionPoints.append( "preElasticSearchDeleteRecord"              );
		conf.interceptorSettings.customInterceptionPoints.append( "postElasticSearchDeleteRecord"             );
	}
}