component output="false" {
	this.name = "Sync Service Test Suite";

	this.mappings[ '/tests'   ] = ExpandPath( "/" );
	this.mappings[ '/testbox' ] = ExpandPath( "/tests/testbox" );
	this.mappings[ '/elasticSearch' ] = ExpandPath( "../" );

	setting requesttimeout="6000";

	public void function onRequest( required string requestedTemplate ) output=true {
		_checkTestboxMapping();

		include template=arguments.requestedTemplate;
	}

// private helpers
	private void function _checkTestboxMapping() output=true {
		if ( !DirectoryExists( "/tests/testbox" ) ) {
			if ( !( application.downloadingTestBox ?: false ) ) {
				thread name=CreateUUId() {
					application.downloadingTestBox = true;

					var zipUrl     = "http://downloads.ortussolutions.com/ortussolutions/testbox/2.0.0/testbox-2.0.0.zip";
					var tmpZipFile = "/tests/" & ListLast( zipUrl, "/" );

					http url=zipUrl path=tmpZipFile;

					zip file=tmpZipFile action="unzip" destination=ExpandPath( "/tests" ) entrypath="testbox/" storepath=true;

					FileDelete( tmpZipFile );

					application.downloadingTestBox = false;
				}
				WriteOutput( "First time loading test suite. Downloading testbox... please be patient (refresh the page to check progress" );abort;
			} else {
				WriteOutput( "Still downloading testbox..." );abort;
			}
		}

	}

}