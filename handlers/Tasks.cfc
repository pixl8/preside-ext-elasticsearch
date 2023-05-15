component {
	property name="elasticSearchEngine" inject="ElasticSearchEngine";

	/**
	 * @displayName  Rebuild search indexes
	 * @displayGroup Search
	 * @schedule     0 0 4 *\/1 * *
	 * @timeout      120
	 */
	private boolean function rebuildSearchIndexes( event, rc, prc, logger ){
		return elasticSearchEngine.rebuildIndexes( arguments.logger ?: nullValue() );
	}
}