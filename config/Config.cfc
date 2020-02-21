component output=false {
	public void function configure( required struct config ) output=false {
		var conf     = arguments.config;
		var settings = conf.settings ?: {};

		_setupEnvVars( settings );
		_setupAdminUi( settings );
		_setupGlobalFilters( settings );
		_setupInterceptors( conf );
	}

	private void function _setupEnvVars( settings ) {
		settings.env[ "elasticsearch.default_index"               ] = settings.env[ "elasticsearch.default_index"               ] ?: ( settings.env.ELASTICSEARCH_DEFAULT_INDEX               ?: _getDefaultIndexName()  );
		settings.env[ "elasticsearch.endpoint"                    ] = settings.env[ "elasticsearch.endpoint"                    ] ?: ( settings.env.ELASTICSEARCH_ENDPOINT                    ?: "http://localhost:9200" );
		settings.env[ "elasticsearch.charset"                     ] = settings.env[ "elasticsearch.charset"                     ] ?: ( settings.env.ELASTICSEARCH_CHARSET                     ?: "utf-8"                 );
		settings.env[ "elasticsearch.api_call_timeout"            ] = settings.env[ "elasticsearch.api_call_timeout"            ] ?: ( settings.env.ELASTICSEARCH_API_CALL_TIMEOUT            ?: 10                      );
		settings.env[ "elasticsearch.retry_attempts"              ] = settings.env[ "elasticsearch.retry_attempts"              ] ?: ( settings.env.ELASTICSEARCH_RETRY_ATTEMPTS              ?: 2                       );
		settings.env[ "elasticsearch.reindex_child_pages_on_edit" ] = settings.env[ "elasticsearch.reindex_child_pages_on_edit" ] ?: ( settings.env.ELASTICSEARCH_REINDEX_CHILD_PAGES_ON_EDIT ?: true                    );
		settings.env[ "elasticsearch.skip_single_record_indexing" ] = settings.env[ "elasticsearch.skip_single_record_indexing" ] ?: ( settings.env.ELASTICSEARCH_SKIP_SINGLE_RECORD_INDEXING ?: false                   );
	}

	private void function _setupAdminUi( settings ) {
		settings.adminConfigurationMenuItems.append( "elasticsearchControl" );
	}

	private void function _setupGlobalFilters( settings ) {
		settings.filters.elasticSearchPageFilter = {
			filter = "page.internal_search_access is null or page.internal_search_access != 'block'"
		};

		settings.filters.elasticSearchAssetFilter = {
			filter = "asset_folder.internal_search_access = 'allow' and asset.trashed_path is null"
		};
	}

	private void function _setupInterceptors( conf ) {
		conf.interceptors.prepend(
			{ class="app.extensions.preside-ext-elasticsearch.interceptors.PresideExtensionElasticSearchEngineInterceptor", properties={} }
		);

		conf.interceptorSettings.customInterceptionPoints.append( "preElasticSearchCreateIndex"               );
		conf.interceptorSettings.customInterceptionPoints.append( "postElasticSearchCreateIndex"              );
		conf.interceptorSettings.customInterceptionPoints.append( "preElasticSearchRebuildIndex"              );
		conf.interceptorSettings.customInterceptionPoints.append( "postElasticSearchRebuildIndex"             );
		conf.interceptorSettings.customInterceptionPoints.append( "onElasticSearchRebuildIndexFailure"        );
		conf.interceptorSettings.customInterceptionPoints.append( "postElasticSearchGetIndexSettings"         );
		conf.interceptorSettings.customInterceptionPoints.append( "preElasticSearchIndexDoc"                  );
		conf.interceptorSettings.customInterceptionPoints.append( "postElasticSearchIndexDoc"                 );
		conf.interceptorSettings.customInterceptionPoints.append( "preElasticSearchIndexDocs"                 );
		conf.interceptorSettings.customInterceptionPoints.append( "postElasticSearchIndexDocs"                );
		conf.interceptorSettings.customInterceptionPoints.append( "onElasticSearchIndexDocsTermination"       );
		conf.interceptorSettings.customInterceptionPoints.append( "preElasticSearchGetObjectDataForIndexing"  );
		conf.interceptorSettings.customInterceptionPoints.append( "postElasticSearchGetObjectDataForIndexing" );
		conf.interceptorSettings.customInterceptionPoints.append( "preElasticSearchDeleteRecord"              );
		conf.interceptorSettings.customInterceptionPoints.append( "postElasticSearchDeleteRecord"             );
	}

	private string function _getDefaultIndexName() {
		var appSettings = getApplicationMetadata();

		return ReReplace( appSettings.name ?: CreateUUId(), "\W+", "_", "all" );
	}
}