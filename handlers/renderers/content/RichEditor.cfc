component output=false {
	property name="contentRendererService" inject="contentRendererService";

	private string function elasticsearchindex( event, rc, prc, args={} ){
		var content = ( args.data ?: "" );

		content = contentRendererService.renderEmbeddedWidgets( richContent = content );
		content = _deleteIrreleventEmbedCodesToSearch( content );

		return Trim( content );
	}

// PRIVATE
	private string function _deleteIrreleventEmbedCodesToSearch( required string content ) output=false {
		var cleared = arguments.content;

		cleared = ReReplaceNoCase( cleared, "{{image:(.*?):image}}"          , "", "all" );
		cleared = ReReplaceNoCase( cleared, "{{link:(.*?):link}}"            , "", "all" );
		cleared = ReReplaceNoCase( cleared, "{{attachment:(.*?):attachment}}", "", "all" );

		return cleared;
	}

}