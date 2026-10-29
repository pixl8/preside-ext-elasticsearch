/**
 * Resolves the ElasticSearch dialect to use, based on the configured engine version
 * (settings.elasticSearchConfig.engineVersion) and the registered dialects
 * (settings.elasticSearchConfig.dialects).
 *
 * The dialect used is the one registered against the highest version that is less
 * than or equal to the configured engine version. e.g. with dialects registered for
 * "1.7" and "6.3", an engine version of "6.8" will use the "6.3" dialect.
 *
 * @singleton
 */
component {

// CONSTRUCTOR
	/**
	 * @engineVersion.inject coldbox:setting:elasticSearchConfig.engineVersion
	 * @dialects.inject      coldbox:setting:elasticSearchConfig.dialects
	 */
	public any function init( string engineVersion="6.3", struct dialects={} ) {
		_setEngineVersion( arguments.engineVersion );
		_setDialects( StructIsEmpty( arguments.dialects ) ? getDefaultDialects() : arguments.dialects );

		return this;
	}

// PUBLIC API METHODS
	public any function getDialect() {
		if ( IsNull( variables._dialect ) ) {
			variables._dialect = createDialect( _getEngineVersion() );
		}

		return variables._dialect;
	}

	public any function createDialect( required string version ) {
		var dialectPath = resolveDialectPath( arguments.version );

		if ( !Find( ".", dialectPath ) ) {
			dialectPath = "dialects.#dialectPath#";
		}

		return CreateObject( "component", dialectPath ).init( version=arguments.version );
	}

	public string function resolveDialectPath( required string version ) {
		var dialects        = _getDialects();
		var matchedVersion  = "";

		_validateVersion( arguments.version );

		for( var dialectVersion in dialects ) {
			if ( compareVersions( dialectVersion, arguments.version ) <= 0 ) {
				if ( !Len( matchedVersion ) || compareVersions( dialectVersion, matchedVersion ) > 0 ) {
					matchedVersion = dialectVersion;
				}
			}
		}

		if ( !Len( matchedVersion ) ) {
			throw(
				  type    = "elasticsearch.dialect.unsupportedVersion"
				, message = "ElasticSearch engine version [#arguments.version#] is not supported. Supported versions are: #_listSupportedVersions()#."
			);
		}

		return dialects[ matchedVersion ];
	}

	/**
	 * Compares two dotted version strings numerically. Returns -1, 0 or 1.
	 * Missing parts are treated as zero, so "6.3" and "6.3.0" are equal.
	 */
	public numeric function compareVersions( required string versionA, required string versionB ) {
		var partsA = ListToArray( arguments.versionA, "." );
		var partsB = ListToArray( arguments.versionB, "." );
		var maxLen = Max( partsA.len(), partsB.len() );

		for( var i=1; i<=maxLen; i++ ) {
			var a = i <= partsA.len() ? Val( partsA[ i ] ) : 0;
			var b = i <= partsB.len() ? Val( partsB[ i ] ) : 0;

			if ( a < b ) {
				return -1;
			}
			if ( a > b ) {
				return 1;
			}
		}

		return 0;
	}

	public struct function getDefaultDialects() {
		return {
			  "1.7" = "Es1Dialect"
			, "6.3" = "Es6Dialect"
		};
	}

	public string function getEngineVersion() {
		return _getEngineVersion();
	}

// PRIVATE HELPERS
	private void function _validateVersion( required string version ) {
		if ( !ReFind( "^\d+(\.\d+)*$", Trim( arguments.version ) ) ) {
			throw(
				  type    = "elasticsearch.dialect.invalidVersion"
				, message = "Invalid ElasticSearch engine version [#arguments.version#]. Set settings.elasticSearchConfig.engineVersion (or the ELASTICSEARCH_VERSION environment variable) to a version number such as ""6.3"" or ""1.7""."
			);
		}
	}

	private string function _listSupportedVersions() {
		var versions = StructKeyArray( _getDialects() );

		versions.sort( function( a, b ){
			return compareVersions( a, b );
		} );

		return versions.toList( ", " );
	}

// GETTERS AND SETTERS
	private string function _getEngineVersion() {
		return _engineVersion;
	}
	private void function _setEngineVersion( required string engineVersion ) {
		_engineVersion = Trim( arguments.engineVersion );
	}

	private struct function _getDialects() {
		return _dialects;
	}
	private void function _setDialects( required struct dialects ) {
		_dialects = arguments.dialects;
	}
}
