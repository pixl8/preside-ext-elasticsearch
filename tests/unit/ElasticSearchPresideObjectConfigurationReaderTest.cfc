component extends="testbox.system.BaseSpec" {

	function run() output=false {
		describe( "listSearchEnabledObjects()", function(){
			it( "should return an array of objects who have 'searchEnabled' flag set to true", function(){
				var svc = _getService();
				var objects = {
					  object_a = true
					, object_b = false
					, object_c = false
					, object_d = true
					, object_e = true
					, object_f = false
					, object_g = true
				};
				var objNameArray = objects.keyArray().sort( "textnocase" );

				mockPresideObjectService.$( "listObjects", objNameArray );
				for( objectname in objects ){
					mockPresideObjectService.$( "getObjectAttribute" ).$args( objectName, "searchEnabled", false ).$results( objects[ objectName ] );
				}

				expect( svc.listSearchEnabledObjects() ).toBe( [ "object_a", "object_d", "object_e", "object_g" ] );
			} );

			it( "should ignore the 'page' object", function(){
				var svc = _getService();
				var objects = {
					  object_a = true
					, page     = true
					, object_c = false
					, object_d = true
				};
				var objNameArray = objects.keyArray().sort( "textnocase" );

				mockPresideObjectService.$( "listObjects", objNameArray );
				for( objectname in objects ){
					mockPresideObjectService.$( "getObjectAttribute" ).$args( objectName, "searchEnabled", false ).$results( objects[ objectName ] );
				}

				expect( svc.listSearchEnabledObjects() ).toBe( [ "object_a", "object_d" ] );
			} );
		} );

		describe( "getObjectConfiguration()", function(){
			it( "should return index name configured on object", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var indexName  = "testdefaultindex";

				mockPresideObjectService.$( "getObjectAttribute" ).$args( objectName, "searchIndex" ).$results( indexName );
				mockPresideObjectService.$( "getObjectAttribute", "dummy" );
				mockPresideObjectService.$( "getObjectProperties", [] );


				var configuration = svc.getObjectConfiguration( objectName );
				expect( configuration.indexName ?: "" ).toBe( indexName );
			} );

			it( "should return default index name when object does not define its own", function(){
				var svc          = _getService();
				var objectName   = "someobject";
				var defaultIndex = "testdefaultindex";

				mockPresideObjectService.$( "getObjectAttribute" ).$args( objectName, "searchIndex" ).$results( "" );
				mockPresideObjectService.$( "getObjectAttribute", "dummy" );
				mockPresideObjectService.$( "getObjectProperties", [] );

				mockConfigurationService.$( "getSetting" ).$args( "elasticsearch", "default_index" ).$results( defaultIndex );

				var configuration = svc.getObjectConfiguration( objectName );
				expect( configuration.indexName ?: "" ).toBe( defaultIndex );
			} );

			it( "should return document type configured on the object", function(){
				var svc          = _getService();
				var objectName   = "someobject";
				var documentType = "testtype";

				mockPresideObjectService.$( "getObjectAttribute" ).$args( objectName, "searchDocumentType" ).$results( documentType );
				mockPresideObjectService.$( "getObjectAttribute", "dummy" );
				mockPresideObjectService.$( "getObjectProperties", [] );


				var configuration = svc.getObjectConfiguration( objectName );
				expect( configuration.documentType ?: "" ).toBe( documentType );
			} );

			it( "should return object name for the document type when document type not specifically configured", function(){
				var svc          = _getService();
				var objectName   = "someobject";
				var documentType = "";

				mockPresideObjectService.$( "getObjectAttribute" ).$args( objectName, "searchDocumentType" ).$results( documentType );
				mockPresideObjectService.$( "getObjectAttribute", "dummy" );
				mockPresideObjectService.$( "getObjectProperties", [] );


				var configuration = svc.getObjectConfiguration( objectName );
				expect( configuration.documentType ?: "" ).toBe( objectName );
			} );

			it( "should return array of fields that are configured for the index, always including 'id'", function(){
				var svc        = _getService();
				var objectName = "some_object";
				var props      = [];

				for( var i=1; i<=5; i++ ){
					var prop = getMockBox().createStub();
					prop.$( "getAttribute" ).$args( "name" ).$results( "prop_" & i );
					mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, "prop_" & i, "searchEnabled" ).$results( i mod 2 );

					props.append( prop );
				}

				mockPresideObjectService.$( "getObjectProperties" ).$args( objectName ).$results( props );
				mockPresideObjectService.$( "getObjectAttribute", "dummy" );


				var configuration = svc.getObjectConfiguration( objectName );
				expect( configuration.fields ?: [] ).toBe( [ "prop_1", "prop_3", "prop_5", "id" ] );
			} );
		} );

		describe( "getFieldConfiguration()", function(){
			it( "should return default configuration when no attributes set on field", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";
				var defaultConfig = {
					  searchable = true
					, sortable   = true
					, analyzer   = ""
					, type       = "string"
				};

				mockPresideObjectService.$( "getObjectPropertyAttribute", "" );

				expect( svc.getFieldConfiguration( objectName, fieldName ) ).toBe( defaultConfig );
			} );
		} );
	}



// HELPERS
	private any function _getService() output=false {
		mockPresideObjectService = getMockBox().createStub();
		mockConfigurationService = getMockBox().createStub();


		return new elasticsearch.services.ElasticSearchPresideObjectConfigurationReader(
			  presideObjectService       = mockPresideObjectService
			, systemConfigurationService = mockConfigurationService
		);
	}

}