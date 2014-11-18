component output=false {

// CONSTRUCTOR
	/**
	 * @presideObjectService.inject       presideObjectService
	 * @systemConfigurationService.inject systemConfigurationService
	 *
	 */
	public any function init( required any presideObjectService, required any systemConfigurationService ) output=false {
		_setPresideObjectService( arguments.presideObjectService );
		_setSystemConfigurationService( arguments.systemConfigurationService );

		return this;
	}

// PUBLIC API METHODS
	public array function listSearchEnabledObjects() output=false {
		var poService = _getPresideObjectService();

		return poService.listObjects().filter( function( objectName ){
			var searchEnabled = objectName != "page" && poService.getObjectAttribute( objectName, "searchEnabled", false );

			return IsBoolean( searchEnabled ) && searchEnabled;
		} );
	}

	public struct function getObjectConfiguration( required string objectName ) output=false {
		var poService     = _getPresideObjectService();
		var configuration = {};

		configuration.indexName    = poService.getObjectAttribute( objectName, "searchIndex" );
		configuration.documentType = poService.getObjectAttribute( objectName, "searchDocumentType" );
		configuration.fields       = [];

		if ( !Len( Trim( configuration.indexName ) ) ) {
			configuration.indexName = _getDefaultIndexName();
		}
		if ( !Len( Trim( configuration.documentType ) ) ) {
			configuration.documentType = arguments.objectName;
		}

		for( var prop in poService.getObjectProperties( arguments.objectName ) ){
			var searchEnabled = poService.getObjectPropertyAttribute( arguments.objectName, prop.getAttribute( "name" ), "searchEnabled" );

			if ( IsBoolean( searchEnabled ) && searchEnabled ){
				configuration.fields.append( prop.getAttribute( "name" ) );
			}
		}
		if ( !configuration.fields.find( "id" ) ) {
			configuration.fields.append( "id" );
		}

		return configuration;
	}

	public struct function getFieldConfiguration( required string objectName, required string fieldName ) output=false {
		var poService     = _getPresideObjectService();
		var configuration = {};
		var fieldType     = poService.getObjectPropertyAttribute( arguments.objectName, arguments.fieldName, "type" );

		if ( fieldType == "string" ) {
			configuration.searchable = poService.getObjectPropertyAttribute( arguments.objectName, arguments.fieldName, "searchSearchable" );
			if ( !Len( Trim( configuration.searchable ) ) ) {
				configuration.searchable = true;
			} else {
				configuration.searchable = IsBoolean( configuration.searchable ) && configuration.searchable;
			}

			configuration.analyzer = poService.getObjectPropertyAttribute( arguments.objectName, arguments.fieldName, "searchAnalyzer" );
			if ( !Len( Trim( configuration.analyzer ) ) ) {
				configuration.analyzer = "default";
			}
		} else {
			configuration.searchable = false;

			if ( fieldType == "date" ) {
				configuration.dateFormat = poService.getObjectPropertyAttribute( arguments.objectName, arguments.fieldName, "searchDateFormat" );
				configuration.ignoreMalformedDates = poService.getObjectPropertyAttribute( arguments.objectName, arguments.fieldName, "searchIgnoreMalformed" );

				if ( !Len( Trim( configuration.dateFormat ) ) ) {
					configuration.delete( "dateFormat" );
				}
				if ( !Len( Trim( configuration.ignoreMalformedDates ) ) ) {
					configuration.ignoreMalformedDates = true;
				} else {
					configuration.ignoreMalformedDates = IsBoolean( configuration.ignoreMalformedDates ) && configuration.ignoreMalformedDates;
				}
			}
		}

		configuration.sortable = poService.getObjectPropertyAttribute( arguments.objectName, arguments.fieldName, "searchSortable" );
		configuration.sortable = IsBoolean( configuration.sortable ) && configuration.sortable;

		return configuration;
	}

// PRIVATE HELPERS

// GETTERS AND SETTERS
	private any function _getPresideObjectService() output=false {
		return _presideObjectService;
	}
	private void function _setPresideObjectService( required any presideObjectService ) output=false {
		_presideObjectService = arguments.presideObjectService;
	}

	private any function _getSystemConfigurationService() output=false {
		return _systemConfigurationService;
	}
	private void function _setSystemConfigurationService( required any systemConfigurationService ) output=false {
		_systemConfigurationService = arguments.systemConfigurationService;
	}

	private any function _getDefaultIndexName() output=false {
		return _getSystemConfigurationService().getSetting( "elasticsearch", "default_index" );
	}

}