component extends="testbox.system.BaseSpec" {

	function run() {

		describe( "resolveDialectPath()", function(){
			it( "should return the dialect registered against an exact version match", function(){
				var factory = _getFactory();

				expect( factory.resolveDialectPath( "1.7" ) ).toBe( "Es1Dialect" );
				expect( factory.resolveDialectPath( "6.3" ) ).toBe( "Es6Dialect" );
			} );

			it( "should return the dialect registered against the highest version that is less than or equal to the given version", function(){
				var factory = _getFactory();

				expect( factory.resolveDialectPath( "1.7.6" ) ).toBe( "Es1Dialect" );
				expect( factory.resolveDialectPath( "6.3.2" ) ).toBe( "Es6Dialect" );
				expect( factory.resolveDialectPath( "6.8"   ) ).toBe( "Es6Dialect" );
				expect( factory.resolveDialectPath( "5.6"   ) ).toBe( "Es1Dialect" );
			} );

			it( "should use dialects registered by the application", function(){
				var factory = _getFactory( dialects={ "1.7"="Es1Dialect", "6.3"="Es6Dialect", "7.10"="my.app.Es7Dialect" } );

				expect( factory.resolveDialectPath( "7.17" ) ).toBe( "my.app.Es7Dialect" );
				expect( factory.resolveDialectPath( "7.9"  ) ).toBe( "Es6Dialect" );
			} );

			it( "should throw an informative error when the version is lower than any registered dialect", function(){
				var factory = _getFactory();

				expect( function(){
					factory.resolveDialectPath( "0.90" );
				} ).toThrow( "elasticsearch.dialect.unsupportedVersion" );
			} );

			it( "should throw an informative error when the version is not a valid version number", function(){
				var factory = _getFactory();

				expect( function(){
					factory.resolveDialectPath( "latest" );
				} ).toThrow( "elasticsearch.dialect.invalidVersion" );
			} );
		} );

		describe( "compareVersions()", function(){
			it( "should compare version numbers numerically, part by part", function(){
				var factory = _getFactory();

				expect( factory.compareVersions( "6.3"  , "6.3.0" ) ).toBe( 0  );
				expect( factory.compareVersions( "6.10" , "6.9"   ) ).toBe( 1  );
				expect( factory.compareVersions( "1.7.6", "6.3"   ) ).toBe( -1 );
			} );
		} );

		describe( "getDialect()", function(){
			it( "should return an Es1Dialect instance for ElasticSearch 1.7", function(){
				var dialect = _getFactory( engineVersion="1.7" ).getDialect();

				expect( dialect ).toBeInstanceOf( "elasticsearch.services.dialects.Es1Dialect" );
				expect( dialect.getVersion() ).toBe( "1.7" );
				expect( dialect.getMajorVersion() ).toBe( 1 );
			} );

			it( "should return an Es6Dialect instance for ElasticSearch 6.x", function(){
				var dialect = _getFactory( engineVersion="6.3.2" ).getDialect();

				expect( dialect ).toBeInstanceOf( "elasticsearch.services.dialects.Es6Dialect" );
				expect( dialect.getMajorVersion() ).toBe( 6 );
			} );

			it( "should default to ElasticSearch 6.3", function(){
				var factory = new elasticsearch.services.ElasticSearchDialectFactory();

				expect( factory.getEngineVersion() ).toBe( "6.3" );
				expect( factory.getDialect() ).toBeInstanceOf( "elasticsearch.services.dialects.Es6Dialect" );
			} );

			it( "should return the same dialect instance on subsequent calls", function(){
				var factory = _getFactory();
				var system  = CreateObject( "java", "java.lang.System" );

				expect( system.identityHashCode( factory.getDialect() ) ).toBe( system.identityHashCode( factory.getDialect() ) );
			} );
		} );
	}

// HELPERS
	private any function _getFactory( string engineVersion="6.3", struct dialects={} ) {
		return new elasticsearch.services.ElasticSearchDialectFactory( argumentCollection=arguments );
	}
}
