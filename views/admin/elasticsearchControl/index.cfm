<cfscript>
	stats = prc.stats ?: {};

	errorStatus = translateResource( "cms:elasticSearchControl.statstable.stats.error" );

	canRebuild        = hasCmsPermission( "elasticsearchcontrol.rebuild" );
	showActionsColumn = canRebuild;
</cfscript>

<cfoutput>
	<table class="table table-striped table-hover">
		<thead>
			<tr>
				<th>#translateResource( "cms:elasticSearchControl.statstable.header.index" )#</th>
				<th>#translateResource( "cms:elasticSearchControl.statstable.header.doccount" )#</th>
				<th>#translateResource( "cms:elasticSearchControl.statstable.header.state" )#</th>
				<cfif showActionsColumn>
					<th>#translateResource( "cms:elasticSearchControl.statstable.header.actions" )#</th>
				</cfif>
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
					<cfif showActionsColumn>
						<td>
							<div class="action-buttons btn-group">
								<cfif canRebuild>
									<a href="#event.buildAdminLink( linkTo='elasticSearchControl.rebuildAction', queryString='index=' & index )#" data-context-key="r" class="confirmation-prompt" title="#translateResource( uri='cms:elasticsearchcontrol.rebuildIndex.prompt', data=[index] )#">
										<i class="fa fa-rotate-right blue"></i>
									</a>
								</cfif>
							</div>
						</td>
					</cfif>
				</tr>
			</cfloop>
		</tbody>
</cfoutput>