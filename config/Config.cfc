component output=false {
	public void function configure( required struct config ) output=false {
		var conf     = arguments.config;
		var settings = conf.settings;

		settings.elasticsearch                           = settings.elasticsearch                           ?: {};
		settings.elasticsearch.endpoint                  = settings.elasticsearch.endpoint                  ?: "http://localhost:9200";
		settings.elasticsearch.charset                   = settings.elasticsearch.charset                   ?: "UTF-8";
		settings.elasticsearch.requestTimeoutInSeconds   = settings.elasticsearch.requestTimeoutInSeconds   ?: "30";
		settings.elasticsearch.nullResponseRetryAttempts = settings.elasticsearch.nullResponseRetryAttempts ?: "3";
	}
}

