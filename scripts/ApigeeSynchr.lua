--
--   Copyright 2014 John Pormann, Duke University
--
--   Licensed under the Apache License, Version 2.0 (the "License");
--   you may not use this file except in compliance with the License.
--   You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
--   Unless required by applicable law or agreed to in writing, software
--   distributed under the License is distributed on an "AS IS" BASIS,
--   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--   See the License for the specific language governing permissions and
--   limitations under the License.
--

local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require( "json" )

local Apigee = {}

function Apigee.new( params )

	-- defaults	
	local grp = {
		baseurl = "https://api.usergrid.com",
		appname = "default",
		orgname = "default",
		collection = "lotsofstuffs",
		username = "default",
		password = "default",
		sessionauth = "default",
		uuid = 0,
		data = 0,
		last_uuid = "LAST",
		headers = {},
		source_collection = "default",
		source_entity = "default",
		relationship = "connected",
		target_collection = "default",
		target_entity = "default",
		onComplete = function(e)
			print( "default ApigeeObj.onComplete function called" ) 
		end
	}
	
	if( params ~= nil ) then
		for k,v in pairs(params) do
			if( grp[k] == nil ) then
				-- there is no such key in the default object
				-- so let's skip it
			else
				grp[k] = v
			end
		end
	end

	--
	-- the "internal" worker-functions
	--

	function grp.handleUploadResponse( event )
		-- need to fudge a last_response table
		-- so that uuid="LAST" still works
		grp.last_response = {}
		grp.last_response.entities = {}
		grp.last_response.entities[1] = {}
		grp.last_response.entities[1].uuid = grp.old_uuid
	end
	
	function grp.handleDownloadResponse( event )
		-- need to fudge a last_response table
		-- so that uuid="LAST" still works
		grp.last_response = {}
		grp.last_response.entities = {}
		grp.last_response.entities[1] = {}
		grp.last_response.entities[1].uuid = grp.old_uuid
		
		-- store the file
		local path = system.pathForFile( grp.old_data.filename, grp.old_data.baseDirectory )
		print( "path ["..path.."]" )
		local fp = io.open( path, "w" )
		if( event.response ~= nil ) then
			print( "response ["..event.response.."]" )
			fp:write( event.response )
		end
		fp:close()
		
		event.downloadInfo = {
			filename = grp.old_data.filename,
			baseDirectory = grp.old_data.baseDirectory,
			path = path,
		}
	end

	function grp.baseNetworkListener( event )
		print( "network_num_tries = "..grp.network_num_tries )
		
		-- regardless of whether there is an error or not,
		-- we need to clear out the old uuid/data areas
		grp.old_uuid = grp.uuid
		grp.old_data = grp.data
		grp.uuid = 0
		grp.data = 0
		
		local ee = {
			name = "ApigeeResponse",
			target = grp,
			isError = event.isError,
			status = event.status,
			response = event.response,
		}
		
		if ( event.isError ) then
			print( "Network error!")
			if( grp.network_num_tries > 0 ) then
				print( "  trying again" )
				grp.network_num_tries = grp.network_num_tries + 1
			else
				print( " too many retries" )
				if( grp.onComplete ~= nil ) then
					ee.isError = true
					grp.onComplete( ee )
				end
			end
		else
			if( grp.command == "up_file" ) then
				print( "found an upload response" )
				grp.handleUploadResponse( event )
			elseif( grp.command == "dn_file" ) then
				print( "found a download response" )
				grp.handleDownloadResponse( event )
			else
				local resp = json.decode( event.response )
				grp.last_response = resp
				if( grp.command == "login" ) then
					print( "found a login response" )
					grp.handleLoginResponse( event, resp )
				end
			end
			if( grp.onComplete ~= nil ) then
				grp.onComplete( ee )
			end
		end
	end

	function grp.ApigeeWorker( httpverb, url, auxdata )
		grp.command = command
		grp.inProgress = true
		grp.network_num_tries = 1

		print( "final http request ("..httpverb..") ["..url.."]" )
		if( grp.sessionauth ~= nil ) then
			if( grp.sessionauth ~= "default" ) then
				print( "  valid sessionauth token found" )
			end
		end
		if( auxdata.body ~= nil ) then
			auxdata.headers["Content-Length"] = string.len(auxdata.body)
		end
		if( auxdata.headers ~= nil ) then
			print( "  extra headers found ["..json.encode(auxdata.headers).."]" )
		end
		if( auxdata.body ~= nil ) then
			print( "  body data found ["..auxdata.body.."]" )
		end
		
		local response_body = {}
		local idx,statusCode,headers,statusString = http.request({
			method = httpverb,
			url = url,
			headers = auxdata.headers,
			source = ltn12.source.string(auxdata.body),
			sink = ltn12.sink.table(response_body),
		})

		if( idx ~= 1 ) then
			print( "** ERROR: http.request returned idx="..idx.." (expected 1)" )
		end

		-- we may have more than 1 chunk of data .. stitch it all together
		local n = #response_body
		print( "found "..n.." chunks of data" )
		local resp_txt = ""
		for i=1,n do
			resp_txt = resp_txt .. response_body[i]
		end
		-- then decode the json
		local response = json.decode( resp_txt )
		
		local rtn = {
			isError = false,
			status = statusCode,
			statusString = statusString,
			headers = headers,
			response = response,
		}
		return rtn
	end
	
	function grp.handleXtra( xtra )
		if( xtra ~= nil ) then
			-- now overwrite with xtra data
			for k,v in pairs(xtra) do
				if( grp[k] ~= nil ) then
					grp[k] = v
				end
			end
			if( grp.uuid == "LAST" ) then
				grp.uuid = grp.last_uuid
				print( "using LAST uuid ["..grp.uuid.."]" )
			end
		end
	end
	
	function grp.baseUrl()
		local url = grp.baseurl .. "/"
					.. grp.orgname .. "/"
					.. grp.appname
		return url
	end
	
	function grp.initAuxdata()
		local ad = {}
		ad.headers = {}
		if( grp.sessionauth == "default" ) then
			-- no auth yet
		else
			ad.headers["Authorization"] = "Bearer "
					.. grp.sessionauth
		end
		return ad
	end
	
	function grp.findLastUuid( tbl )
		local last_uuid = "LAST"
		if( tbl == nil ) then
			-- take the last uuid stored in the grp
			last_uuid = grp.last_uuid
		else
			if( tbl.entities ~= nil ) then
				if( tbl.entities[1] ~= nil ) then
					if( tbl.entities[1].uuid ~= nil ) then
						last_uuid = tbl.entities[1].uuid
					end
				end
			end
		end
		return last_uuid
	end

	--
	-- user login/logout
	function grp.userLogin( xtra )
		grp.handleXtra( xtra )
		local auxdata = grp.initAuxdata()
		local url = grp.baseUrl() .. "/token"
		auxdata.headers["Content-Type"] = "application/json"
		auxdata.body = json.encode({
			grant_type = "password",
			username = grp.username,
			password = grp.password
		})
		local rtn = grp.ApigeeWorker( "POST", url, auxdata )
		local resp = rtn.response
		if( resp.access_token ~= nil ) then
			grp.sessionauth = resp.access_token
			grp.user = resp.user
			grp.useruuid = resp.user.uuid
			print( "got authtoken ["..grp.sessionauth.."]" )
		else
			-- TODO: network login error
			print( "Network login error - no access_token" )
		end
		return rtn
	end

	function grp.userLogout( xtra )
		grp.handleXtra( xtra )
		local auxdata = grp.initAuxdata()
		local url = grp.baseUrl() .. "/users/"
				.. grp.username .. "/revoketokens?token="
				.. grp.sessionauth
			-- TODO: should verify that authorization is by session-token
		return grp.ApigeeWorker( "POST", url, auxdata )
	end


	--
	-- data-items (entities) objects
	function grp.createEntity( xtra )
		grp.handleXtra( xtra )
		if( grp.data == nil ) then
			return {
				isError = true,
				status = 9900,
				statusString = "No data specified",
			}
		end
		local auxdata = grp.initAuxdata()
		auxdata.headers["Content-Type"] = "application/json"
		auxdata.body = json.encode( grp.data )
		local url = grp.baseUrl() .. "/"
				.. grp.collection
		local rtn = grp.ApigeeWorker( "POST", url, auxdata )
		grp.last_uuid = grp.findLastUuid( rtn.response )
		return rtn
	end
	function grp.retrieveEntity( xtra )
		grp.handleXtra( xtra )
		if( grp.uuid == nil ) then
			return {
				isError = true,
				status = 9900,
				statusString = "No UUID specified",
			}
		end
		local auxdata = grp.initAuxdata()
		local url = grp.baseUrl() .. "/"
				.. grp.collection .. "/"
				.. grp.uuid
		local rtn = grp.ApigeeWorker( "GET", url, auxdata )
		grp.last_uuid = grp.findLastUuid( rtn.response )
		return rtn
	end
	function grp.updateEntity( xtra )
		grp.handleXtra( xtra )
		if( grp.uuid == nil ) then
			return {
				isError = true,
				status = 9900,
				statusString = "No UUID specified",
			}
		elseif( grp.data == nil ) then
			return {
				isError = true,
				status = 9900,
				statusString = "No data specified",
			}
		end
		local auxdata = grp.initAuxdata()
		auxdata.headers["Content-Type"] = "application/json"
		auxdata.body = json.encode( grp.data )
		local url = grp.baseUrl() .. "/"
				.. grp.collection .. "/"
				.. grp.uuid
		local rtn = grp.ApigeeWorker( "PUT", url, auxdata )
		grp.last_uuid = grp.findLastUuid( rtn.response )
		return rtn
	end
	function grp.deleteEntity( xtra )
		grp.handleXtra( xtra )
		if( grp.uuid == nil ) then
			return {
				isError = true,
				status = 9900,
				statusString = "No UUID specified",
			}
		end
		local auxdata = grp.initAuxdata()
		local url = grp.baseUrl() .. "/"
				.. grp.collection .. "/"
				.. grp.uuid
		local rtn = grp.ApigeeWorker( "DELETE", url, auxdata )
		grp.last_uuid = grp.findLastUuid( rtn.response )
		return rtn
	end


	--
	-- collections/database objects
	function grp.createCollectionObject( xtra )
		grp.handleXtra( xtra )
		if( grp.collection == nil ) then
			return {
				isError = true,
				status = 9900,
				statusString = "No collection specified",
			}
		end
		-- TODO: check that collection is pluralized
		local auxdata = grp.initAuxdata()
		local url = grp.baseUrl() .. "/"
				.. grp.collection
		local rtn = grp.ApigeeWorker( "POST", url, auxdata )
		grp.last_uuid = grp.findLastUuid( rtn.response )
		return rtn
	end
	function grp.retrieveCollectionObject( xtra )
		grp.handleXtra( xtra )
		if( grp.collection == nil ) then
			return {
				isError = true,
				status = 9900,
				statusString = "No collection specified",
			}
		end
		-- TODO: check that collection is pluralized
		local auxdata = grp.initAuxdata()
		local url = grp.baseUrl() .. "/"
				.. grp.collection
		local rtn = grp.ApigeeWorker( "GET", url, auxdata )
		grp.last_uuid = grp.findLastUuid( rtn.response )
		return rtn
	end
	function grp.updateCollectionObject( xtra )
		return {
			isError = true,
			status = 9900,
			statusString = "No way to update a collection",
		}
	end
	function grp.deleteCollectionObject( xtra )
		return {
			isError = true,
			status = 9900,
			statusString = "No way to delete a collection",
		}
	end


	--
	-- file objects are really just data objects with attachments
	function grp.createFileObject( xtra )
		grp.handleXtra( xtra )
		if( grp.data == nil ) then
			grp.throwError( "No data specified" )
			return
		end
		local auxdata = grp.initAuxdata()
		auxdata.headers["Content-Type"] = "application/json"
		-- assume we want the current user to be the owner
		grp.data.owner = grp.useruuid
		auxdata.body = json.encode( grp.data )
		local url = grp.baseUrl() .. "/"
				.. grp.collection
		local rtn = grp.ApigeeWorker( "POST", url, auxdata )
		grp.last_uuid = grp.findLastUuid( rtn.response )
		return rtn
	end
	function grp.retrieveFileObject( xtra )
		grp.handleXtra( xtra )
		if( grp.uuid == nil ) then
			grp.throwError( "No UUID specified" )
			return
		end
		local auxdata = grp.initAuxdata()
		local url = grp.baseUrl() .. "/"
				.. grp.collection .. "/"
				.. grp.uuid
		local rtn = grp.ApigeeWorker( "GET", url, auxdata )
		grp.last_uuid = grp.findLastUuid( rtn.response )
		return rtn
	end
	function grp.updateFileObject( xtra )
		grp.handleXtra( xtra )
		if( grp.uuid == nil ) then
			grp.throwError( "No UUID specified" )
			return
		elseif( grp.data == nil ) then
			grp.throwError( "No data specified" )
			return
		end
		local auxdata = grp.initAuxdata()
		auxdata.headers["Content-Type"] = "application/json"
		auxdata.body = json.encode( grp.data )
		local url = grp.baseUrl() .. "/"
				.. grp.collection .. "/"
				.. grp.uuid
		local rtn = grp.ApigeeWorker( "PUT", url, auxdata )
		grp.last_uuid = grp.findLastUuid( rtn.response )
		return rtn
	end
	function grp.deleteFileObject( xtra )
		grp.handleXtra( xtra )
		if( grp.uuid == nil ) then
			grp.throwError( "No UUID specified" )
			return
		end
		local auxdata = grp.initAuxdata()
		local url = grp.baseUrl() .. "/"
				.. grp.collection .. "/"
				.. grp.uuid
		local rtn = grp.ApigeeWorker( "DELETE", url, auxdata )
		grp.last_uuid = grp.findLastUuid( rtn.response )
		return rtn
	end
	function grp.uploadFileObject( xtra )
		grp.handleXtra( xtra )
		if( grp.data == nil ) then
			grp.throwError( "No data specified" )
			return
		end
		local auxdata = grp.initAuxdata()
		--auxdata.headers["Content-Type"] = "application/json"
		auxdata.headers["Content-Type"] = "application/octet-stream"
		if( grp.data.filename == nil ) then
			grp.throwError( "No upload file specified" )
			return
		end
		-- load the file into memory
		-- TODO: make this stream straight from the file
		local basedir = grp.data.baseDirectory
		if( basedir == nil ) then
			basedir = system.CachesDirectory
		end
		local path = system.pathForFile( grp.data.filename, basedir )
		local fp = io.open( path, "r" )
		if( fp == nil ) then
			grp.throwError( "Cannot read file ["..path.."]" )
			return
		end
		auxdata.body = fp:read("*a")
		print( "upload ["..auxdata.body.."]" )
		fp:close()
		local url = grp.baseUrl() .. "/"
				.. grp.collection .. "/"
				.. grp.uuid
		local rtn = grp.ApigeeWorker( "POST", url, auxdata )
		grp.last_uuid = grp.findLastUuid( rtn.response )
		return rtn
	end
	function grp.downloadFileObject( xtra )
		grp.handleXtra( xtra )
		if( grp.uuid == nil ) then
			grp.throwError( "No UUID specified" )
			return
		end
		local auxdata = grp.initAuxdata()
		-- make sure we retrieve the asset, not the entity
		auxdata.headers["Content-Type"] = "application/octet-stream"
		if( grp.data.filename == nil ) then
			grp.throwError( "No upload file specified" )
			return
		end
		if( grp.data.baseDirectory == nil ) then
			grp.data.baseDirectory = system.CachesDirectory
		end
		local url = grp.baseUrl() .. "/"
				.. grp.collection .. "/"
				.. grp.uuid
		local rtn = grp.ApigeeWorker( "GET", url, auxdata )
		grp.last_uuid = grp.findLastUuid( rtn.response )
		return rtn
	end
	
	--
	-- user "activity" postings
	function grp.createActivityObject( xtra )
		grp.handleXtra( xtra )
		if( grp.useruuid == nil ) then
			grp.throwError( "No User-UUID specified" )
			return
		end
		if( grp.data == nil ) then
			grp.throwError( "No data specified" )
			return
		end
		local auxdata = grp.initAuxdata()		
		local d = grp.data
		if( d.actor == nil ) then
			d.actor = {}
			d.actor.username = grp.username
			-- Apigee web-ui uses displayName
			d.actor.displayName = "DN-"..grp.username
			d.actor.uuid = grp.useruuid
		end
		-- TODO: check that there is a "verb" in the data
		-- http://activitystrea.ms/head/activity-schema.html#verbs
		if( d.verb == nil ) then
			d.verb = "post"
		end
		if( d.published == nil ) then
			-- we need an RFC3339 timestamp
			-- e.g. 2002-10-02T10:00:00-05:00
			-- TODO: corona's %z docs are wrong, but the following works:
			d.published = os.date( "%Y-%m-%dT%H:%M:%S%z" )
		end
		auxdata.body = json.encode( grp.data )
		local url
		if( d.group ~= nil ) then
			url = grp.baseUrl() .. "/groups/"
				.. d.group .. "/activities"
		else
			-- could use user-uuid instead of 'me'
			url = grp.baseUrl() .. "/users/me/activities"
		end
		local rtn = grp.ApigeeWorker( "POST", url, auxdata )
		grp.last_uuid = grp.findLastUuid( rtn.response )
		return rtn	
	end
	function grp.retrieveActivityObject( xtra )
		grp.handleXtra( xtra )
		if( grp.useruuid == nil ) then
			grp.throwError( "No User-UUID specified" )
			return
		end
		local auxdata = grp.initAuxdata()
		local d = grp.data		
		local url
		if( (d==nil) or (d==0) or (d.group==nil) ) then
			-- could use user-uuid instead of 'me'
			url = grp.baseUrl() .. "/users/me/activities"
		else
			url = grp.baseUrl() .. "/groups/"
				.. d.group .. "/activities"
		end
		local rtn = grp.ApigeeWorker( "GET", url, auxdata )	
		grp.last_uuid = grp.findLastUuid( rtn.response )
		return rtn	
	end


	--
	-- "event" data
	function grp.createEventObject( xtra )
		grp.handleXtra( xtra )
		if( grp.data == nil ) then
			grp.throwError( "No data specified" )
			return
		end
		local auxdata = grp.initAuxdata()		
		local d = grp.data
		if( d.timestamp == nil ) then
			d.timestamp = 0
		end
		-- TODO: check that there is a "verb" in the data
		-- http://activitystrea.ms/head/activity-schema.html#verbs
		if( d.category == nil ) then
			d.category = "default"
		end
		if( d.counters == nil ) then
			d.counters = {
				default = 1
			}
		end
		auxdata.body = json.encode( grp.data )
		local url = grp.baseUrl() .. "/events"
		local rtn = grp.ApigeeWorker( "POST", url, auxdata )	
		grp.last_uuid = grp.findLastUuid( rtn.response )
		return rtn	
	end
	function grp.retrieveEventObject( xtra )
		grp.handleXtra( xtra )
		local auxdata = grp.initAuxdata()
		local url = grp.baseUrl() .. "/events"
		local rtn = grp.ApigeeWorker( "GET", url, auxdata )	
		grp.last_uuid = grp.findLastUuid( rtn.response )
		return rtn	
	end
	function grp.retrieveCounterObject( xtra )
		grp.handleXtra( xtra )
		if( grp.data == nil ) then
			grp.throwError( "No data specified" )
			return
		end
		local auxdata = grp.initAuxdata()
		-- TODO: add query options
		local d = grp.data
		if( d.counter == nil ) then
			grp.throwError( "No counter specified" )
			return
		end
		local url = grp.baseUrl() .. "/counters?counter="
				.. d.counter
		local rtn = grp.ApigeeWorker( "GET", url, auxdata )	
		grp.last_uuid = grp.findLastUuid( rtn.response )
		return rtn	
	end
	
	--
	-- make a connection between two objects
	function grp.makeConnection( xtra )
		grp.handleXtra( xtra )
		if( grp.source_collection == nil ) then
			return {
				isError = true,
				status = 9900,
				statusString = "No source-collection specified",
			}
		elseif( grp.source_entity == nil ) then
			return {
				isError = true,
				status = 9900,
				statusString = "No source-entity specified",
			}
		elseif( grp.relationship == nil ) then
			return {
				isError = true,
				status = 9901,
				statusString = "No relationship specified",
			}
		elseif( grp.target_collection == nil ) then
			return {
				isError = true,
				status = 9902,
				statusString = "No target-collection specified",
			}
		elseif( grp.target_entity == nil ) then
			return {
				isError = true,
				status = 9903,
				statusString = "No target-entity specified",
			}
		end
		local auxdata = grp.initAuxdata()
		auxdata.body = nil
		local url = grp.baseUrl() .. "/"
				.. grp.source_collection .. "/" .. grp.source_entity .. "/"
				.. grp.relationship .. "/"
				.. grp.target_collection .. "/" .. grp.target_entity
		local rtn = grp.ApigeeWorker( "POST", url, auxdata )
		grp.last_uuid = grp.findLastUuid( rtn.response )
		return rtn
	end
	

	return grp
end


return Apigee
