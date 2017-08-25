component output=false singleton=true {

// CONSTRUCTOR
	public any function init() output=false {
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
	) output=false {
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
	private query function _hitsToResults( required array hits, required string fieldList, required string highlightFields ) output=false {
		var fields     = ListToArray( arguments.fieldList );
		var highlights = ListToArray( arguments.highlightFields );
		var results    = QueryNew( _calculateResultQueryColumns( arguments.fieldList, highlights ) );
		var field      = "";
		var i          = 0;
		var n          = 0;

		for( i=1; i lte ArrayLen( arguments.hits ); i=i+1 ){
			var hit = arguments.hits[i];

			QueryAddRow( results );
			QuerySetCell( results, "type" , hit._type  );

			if ( not IsNull (hit._score) ) {
				QuerySetCell( results, "score", hit._score );
			} else {
				QuerySetCell( results, "score", 0 );
			}

			if ( StructKeyExists( hit, 'highlight' ) ) {
				for( n=1; n lte ArrayLen( highlights ); n=n+1 ){
					QuerySetCell(
						  results
						, highlights[n] & "_highlight"
						, _formatHighlight( hit.highlight, highlights[n] )
					);
				}
			}

			for( n=1; n lte ArrayLen( fields ); n=n+1 ){
				field = fields[ n ];
				if ( StructKeyExists( hit.fields, field ) ) {
					if ( IsArray( hit.fields[ field ] ) && hit.fields[ field ].len() < 2 ) {
						hit.fields[ field ] = hit.fields[ field ].toList();
					}
					QuerySetCell( results, field, hit.fields[ field ] );
				}
			}
		}

		return results;
	}

	private string function _calculateResultQueryColumns( required string fieldList, required array highlightFields ) output=false {
		var columns = ListAppend( arguments.fieldList, "type,score" );

		for( var field in arguments.highlightFields ){
			columns = ListAppend( columns, field & "_highlight" );
		}

		return columns;
	}

	private string function _formatHighlight( required struct highlights, required string highlightField ) output=false {
		var highlight      = "";
		var highLightArray = "";
		var maxHighlights  = 3;
		var dotdotdot      = " &##133; ";
		var i              = 0;

		if ( StructKeyExists( arguments.highlights, arguments.highlightField ) ) {
			highlightArray = arguments.highlights[ arguments.highlightField ];

			for( i=1; i lte ArrayLen( highlightArray ) and i lte maxHighlights; i=i+1 ) {
				highlight = ListAppend( highlight, highlightArray[i], "|" );
			}
			highlight = Replace( highlight, '|', dotdotdot, 'all' );
		}

		return highlight;
	}

	private struct function _transformFacets( required struct facets ) output=false {
		var transformed = StructNew();
		var facet       = "";
		var facetKeys   = StructKeyArray( arguments.facets );
		var i           = "";
		var n           = "";

		for( i=1; i lte ArrayLen( facetKeys ); i=i+1 ){
			facet = facetKeys[i];

			transformed[ facet ] = QueryNew('id,label,count');

			for( n=1; n lte ArrayLen( arguments.facets[ facet ].terms ); n=n+1 ){
				QueryAddRow( transformed[ facet ] );
				QuerySetCell(transformed[ facet ] , 'id'   , arguments.facets[ facet ].terms[n].term  );
				QuerySetCell(transformed[ facet ] , 'label', arguments.facets[ facet ].terms[n].term  );
				QuerySetCell(transformed[ facet ] , 'count', arguments.facets[ facet ].terms[n].count );
			}
		}

		return transformed;
	}
}