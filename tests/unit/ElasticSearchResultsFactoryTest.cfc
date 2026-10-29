component extends="testbox.system.BaseSpec" {

	function run() {

		describe( "newSearchResult()", function(){
			it( "should read returned fields from 'fields' when using ElasticSearch 1.7", function(){
				var rawResult = { took=3, hits={ total=1, hits=[ { _type="page", _score=1.5, fields={ title=[ "One" ], tags=[ "a", "b" ] } } ] } };
				var results   = _getFactory( "1.7" ).newSearchResult( rawResult=rawResult, page=1, pageSize=10, returnFields="title,tags" ).getResults();

				expect( results.recordCount ).toBe( 1 );
				expect( results.type[ 1 ]  ).toBe( "page" );
				expect( results.title[ 1 ] ).toBe( "One" );
				expect( results.tags[ 1 ]  ).toBe( [ "a", "b" ] );
			} );

			it( "should read returned fields from '_source' when using ElasticSearch 6.3", function(){
				var rawResult = { took=3, hits={ total=1, hits=[ { _type="doc", _score=1.5, _source={ title="One", tags=[ "a" ] } } ] } };
				var results   = _getFactory( "6.3" ).newSearchResult( rawResult=rawResult, page=1, pageSize=10, returnFields="title,tags" ).getResults();

				expect( results.recordCount ).toBe( 1 );
				expect( results.title[ 1 ] ).toBe( "One" );
				expect( results.tags[ 1 ]  ).toBe( "a" );
			} );

			it( "should join highlights and remove truncated HTML entities", function(){
				var rawResult = { took=3, hits={ total=1, hits=[ { _type="doc", _score=1, _source={}, highlight={ title=[ "one", "two &amp" ] } } ] } };
				var results   = _getFactory( "6.3" ).newSearchResult( rawResult=rawResult, page=1, pageSize=10, highlightFields="title" ).getResults();

				expect( results.title_highlight[ 1 ] ).toBe( "one &##133; two " );
			} );
		} );
	}

// HELPERS
	private any function _getFactory( required string engineVersion ) {
		return new elasticsearch.services.ElasticSearchResultsFactory(
			dialectFactory = new elasticsearch.services.ElasticSearchDialectFactory( engineVersion=arguments.engineVersion )
		);
	}
}
