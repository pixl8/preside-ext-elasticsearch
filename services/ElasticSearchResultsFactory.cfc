component singleton=true {

// CONSTRUCTOR
	/**
	 * @dialectFactory.inject elasticSearchDialectFactory
	 */
	public any function init( required any dialectFactory ) {
		_setDialectFactory( arguments.dialectFactory );

		return this;
	}

// PUBLIC API METHODS
	public any function newSearchResult(
		  required struct  rawResult
		, required numeric page
		, required numeric pageSize
		,          string  returnFields    = ""
		,          string  highlightFields = ""
		,          string  q               = ""
	) {
		var args = StructNew();

		args.page     = arguments.page;
		args.pageSize = arguments.pageSize;

		if ( StructKeyExists( arguments.rawResult, 'error' ) ) {
			args.success = false;
			args.error   = arguments.rawResult.error;
		} else {
			args.timetaken    = arguments.rawResult.took;
			args.totalResults = arguments.rawResult.hits.total;
			args.results      = _hitsToResults( arguments.rawResult.hits.hits, arguments.returnFields, arguments.highlightFields );
			if ( StructKeyExists( arguments.rawResult, 'facets' ) ) {
				args.facets = _transformFacets( arguments.rawResult.facets );
			}
			if ( StructKeyExists( arguments.rawResult, 'aggregations' ) ) {
				args.aggregations = arguments.rawResult.aggregations;
			}
			if ( StructKeyExists( arguments.rawResult, 'suggest' ) ) {
				args.suggestions = arguments.rawResult.suggest;
			}
		}

		return new ElasticSearchResult( argumentCollection = args );
	}


// PRIVATE HELPERS
	private query function _hitsToResults( required array hits, required string fieldList, required string highlightFields ) {
		var fields     = ListToArray( arguments.fieldList );
		var highlights = ListToArray( arguments.highlightFields );
		var results    = QueryNew( _calculateResultQueryColumns( arguments.fieldList, highlights ) );
		var dialect    = _getDialect();
		var field      = "";
		var i          = 0;
		var n          = 0;

		for( i=1; i <= ArrayLen( arguments.hits ); i=i+1 ){
			var hit = arguments.hits[i];

			QueryAddRow( results );
			QuerySetCell( results, "type" , dialect.getHitType( hit ) );

			if ( !IsNull( hit._score ) ) {
				QuerySetCell( results, "score", hit._score );
			} else {
				QuerySetCell( results, "score", 0 );
			}

			if ( StructKeyExists( hit, 'highlight' ) ) {
				for( n=1; n <= ArrayLen( highlights ); n=n+1 ){
					QuerySetCell(
						  results
						, highlights[n] & "_highlight"
						, _formatHighlight( hit.highlight, highlights[n] )
					);
				}
			}

			var hitFields = dialect.getHitFields( hit );
			for( n=1; n <= ArrayLen( fields ); n=n+1 ){
				field = fields[ n ];
				if ( StructKeyExists( hitFields, field ) ) {
					if ( IsArray( hitFields[ field ] ) && ArrayLen( hitFields[ field ] ) < 2 ) {
						hitFields[ field ] = ArrayToList( hitFields[ field ] );
					}
					QuerySetCell( results, field, hitFields[ field ] );
				}
			}
		}

		return results;
	}

	private string function _calculateResultQueryColumns( required string fieldList, required array highlightFields ) {
		var columns = ListAppend( arguments.fieldList, "type,score" );

		for( var field in arguments.highlightFields ){
			columns = ListAppend( columns, field & "_highlight" );
		}

		return columns;
	}

	private string function _formatHighlight( required struct highlights, required string highlightField ) {
		var highlight      = [];
		var highlightArray = [];
		var maxHighlights  = 3;
		var dotdotdot      = " &##133; ";
		var i              = 0;

		if ( StructKeyExists( arguments.highlights, arguments.highlightField ) ) {
			highlightArray = arguments.highlights[ arguments.highlightField ];

			for( i=1; i <= ArrayLen( highlightArray ) && i <= maxHighlights; i=i+1 ) {
				ArrayAppend( highlight, ReReplace( highlightArray[i], "&[a-z]*$", "" ) );
			}
		}

		return ArrayToList( highlight, dotdotdot );
	}

	private struct function _transformFacets( required struct facets ) {
		var transformed = StructNew();
		var facet       = "";
		var facetKeys   = StructKeyArray( arguments.facets );
		var i           = "";
		var n           = "";

		for( i=1; i <= ArrayLen( facetKeys ); i=i+1 ){
			facet = facetKeys[i];

			transformed[ facet ] = QueryNew('id,label,count');

			for( n=1; n <= ArrayLen( arguments.facets[ facet ].terms ); n=n+1 ){
				QueryAddRow( transformed[ facet ] );
				QuerySetCell(transformed[ facet ] , 'id'   , arguments.facets[ facet ].terms[n].term  );
				QuerySetCell(transformed[ facet ] , 'label', arguments.facets[ facet ].terms[n].term  );
				QuerySetCell(transformed[ facet ] , 'count', arguments.facets[ facet ].terms[n].count );
			}
		}

		return transformed;
	}

// GETTERS AND SETTERS
	private any function _getDialectFactory() {
		return _dialectFactory;
	}
	private void function _setDialectFactory( required any dialectFactory ) {
		_dialectFactory = arguments.dialectFactory;
	}

	private any function _getDialect() {
		return _getDialectFactory().getDialect();
	}
}