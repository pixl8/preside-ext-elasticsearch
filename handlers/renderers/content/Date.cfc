component output=false {

	public string function elasticsearchindex( event, rc, prc, args={} ){
		var data = args.data ?: "";

		if ( IsDate( data ) ) {
			return DateFormat( data, "yyyy-mm-dd" );
		}

		return data;
	}

}

