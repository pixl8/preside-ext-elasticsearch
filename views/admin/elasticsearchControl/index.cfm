<cfscript>
	stats = prc.stats ?: {};

	errorStatus = translateResource( "cms:elasticSearchControl.statstable.stats.error" );
</cfscript>

<cfoutput>
	<table class="table table-striped table-hover">
		<thead>
			<tr>
				<th>#translateResource( "cms:elasticSearchControl.statstable.header.index" )#</th>
				<th>#translateResource( "cms:elasticSearchControl.statstable.header.doccount" )#</th>
				<th>#translateResource( "cms:elasticSearchControl.statstable.header.state" )#</th>
				<th>#translateResource( "cms:elasticSearchControl.statstable.header.actions" )#</th>
			</tr>
		</thead>
		<tbody data-nav-list="1" data-nav-list-child-selector="> tr">
			<cfloop collection="#stats#" index="index">
				<tr class="clickable" data-context-container="1">
					<td>#index#</td>
					<td>
						<cfif IsNumeric( stats[ index ].totalDocs ?: "" )>
							#NumberFormat( stats[ index ].totalDocs )#
						<cfelse>
							<em>#errorStatus#</em>
						</cfif>
					</td>
					<td>#renderContent( "boolean", true, [ "admin", "admindatatable" ] )#</td>
					<td>
						<div class="action-buttons btn-group">
							<a href="##" data-context-key="r">
								<i class="fa fa-rotate-right blue"></i>
							</a>
						</div>
					</td>
				</tr>
			</cfloop>
		</tbody>
</cfoutput>