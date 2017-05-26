component output=false {

	variables._result              = {};
	variables._result.results      = QueryNew('');
	variables._result.timetaken    = 0;
	variables._result.page         = 1;
	variables._result.pageSize     = 5;
	variables._result.totalResults = 0;
	variables._result.success      = true;
	variables._result.error        = "";
	variables._result.facets       = {};
	variables._result.aggregations = {};
	variables._result.suggestions  = {};
	variables._result.sortBy       = "RELEVANCE";

// CONSTRUCTOR
	public any function init(
		  query   results      = QueryNew( '' )
		, numeric timetaken    = 0
		, numeric page         = 1
		, numeric pageSize     = 0
		, numeric totalResults = 0
		, boolean success      = true
		, string  error        = ""
		, string  sortBy       = ""
		, struct  facets       = {}
		, struct  aggregations = {}
		, struct  suggestions  = {}
	) output=false {
		_result.append( arguments );

		return this;
	}

// PUBLIC API METHODS
	public query function getResults() output=false {
		return _result.results;
	}

	public struct function getSuggestion() output=false {
		return _result.suggestions;
	}

	public numeric function getTimeTaken() output=false {
		return _result.timetaken;
	}

	public numeric function getPage() output=false {
		if ( getTotalResults() ) {
			return _result.page;
		}

		return 0;
	}

	public numeric function getPageSize() output=false {
		return _result.pageSize;
	}

	public numeric function getTotalResults() output=false {
		return _result.totalResults;
	}

	public boolean function getSuccess() output=false {
		return _result.success;
	}

	public string function getError() output=false {
		return _result.error;
	}

	public string function getSortBy() output=false {
		return _result.sortBy;
	}

	public struct function getFacets() output=false {
		return _result.facets;
	}

	public struct function getAggregations() output=false {
		return _result.aggregations;
	}

	public numeric function getTotalPages() output=false {
		return Ceiling( getTotalResults() / getPageSize() );
	}

	public boolean function hasNextPage() output=false {
		return getPage() LT getTotalPages();
	}

	public boolean function hasPreviousPage() output=false {
		return getPage() GT 1;
	}

	public numeric function getNextPage() output=false {
		return getPage() + 1;
	}

	public numeric function getPreviousPage() output=false {
		return getPage() - 1;
	}

	public numeric function getStartRow() output=false {
		return ( ( getPage() - 1 ) * getPageSize() ) + 1;
	}

	public numeric function getFirstPage( numeric offset=0 ) output=false {
		var offsetPage = 1;
		var minPage = 1;
		var maxPage = getTotalPages() - ( arguments.offset * 2 );

		if ( maxPage lt minPage ) {
			maxPage = minPage;
		}

		if ( arguments.offset ) {
			offsetPage = getPage() - arguments.offset;
			if ( offsetPage GT maxPage ) {
				offsetPage = maxPage;
			} else if ( offsetPage LT minPage ) {
				offsetPage = minPage;
			}
		}

		return offsetPage;
	}

	public numeric function getLastPage( numeric offset=0 ) output=false {
		var offsetPage = 1;
		var total   = getTotalPages();
		var minPage = (offset * 2) + 1;
		var maxPage = total;

		if ( minPage lt 1 ){
			minPage = 1;
		} else if ( minPage gt maxPage ) {
			minPage = maxPage;
		}

		if ( arguments.offset ) {
			offsetPage = getPage() + arguments.offset;
			if ( offsetPage GT maxPage ) {
				offsetPage = maxPage;
			} else if ( offsetPage LT minPage ) {
				offsetPage = minPage;
			}
		}

		return offsetPage;
	}

	public numeric function getEndRow() output=false {
		var endRow = ( getStartRow() + getPageSize() ) - 1;

		if ( endRow gt getTotalResults() ) {
			endRow = getTotalResults();
		}

		return endRow;
	}

	public struct function getMemento() output=false {
		var memento = _result;

		memento.totalPages      = getTotalPages();
		memento.hasnextPage     = hasNextPage();
		memento.haspreviousPage = hasPreviousPage();
		memento.nextPage        = getNextPage();
		memento.previousPage    = getPreviousPage();
		memento.startRow        = getStartRow();
		memento.endRow          = getEndRow();
		memento.facets          = getFacets();

		return memento;
	}
}