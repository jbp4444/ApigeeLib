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
		headers = {},
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
	function grp.handleLoginResponse( event, resp )
		if( resp.access_token ~= nil ) then
			grp.sessionauth = resp.access_token
			grp.user = resp.user
			grp.useruuid = resp.user.uuid
			print( "got authtoken ["..grp.sessionauth.."]" )
		else
			-- TODO: network login error
			print( "Network login error - no access_token" )
		end
	end

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
		
		if( event.isError ) then
			print( "Network error!")
			if( grp.network_num_tries > 0 ) then
				print( "  trying again" )
				grp.network_num_tries = grp.network_num_tries + 1
			else
				print( " too many retries" )
				if( grp.onComplete ~= nil ) then
					ee.isError = true
					grp.onComplete( ee )
				else
					print( "onComplete is nil (error)" )
				end
			end
		else
			print( "response is ok" )
			if( grp.command == "up_file" ) then
				print( "found an upload response" )
				grp.handleUploadResponse( event )
			elseif( grp.command == "dn_file" ) then
				print( "found a download response" )
				grp.handleDownloadResponse( event )
			else
				--print( "response ["..event.response.."]" )
				local resp = json.decode( event.response )
				--print( "resp = "..tostring(resp) )
				grp.last_response = resp
				if( grp.command == "login" ) then
					print( "found a login response" )
					grp.handleLoginResponse( event, resp )
				end
			end
			if( grp.onComplete ~= nil ) then
				--print( "calling func "..tostring(grp.onComplete) )
				grp.onComplete( ee )
			else
				print( "onComplete is nil" )
			end
		end
	end

	function grp.ApigeeWorker( command, httpverb, url, auxdata )
		grp.command = command
		grp.inProgress = true
		grp.network_num_tries = 1

		print( "final command ["..command.."] ("..httpverb..") ["..url.."]" )
		if( grp.sessionauth ~= nil ) then
			if( grp.sessionauth ~= "default" ) then
				print( "  valid sessionauth token found" )
			end
		end
		if( auxdata.headers ~= nil ) then
			print( "  extra headers found" )
		end
		if( auxdata.body ~= nil ) then
			print( "  body data found ["..auxdata.body.."]" )
		end
		
		network.request( url, httpverb, grp.baseNetworkListener, auxdata )
	end

	-- TODO: may need to put this behind timer.performWithDelay
	-- or else main thread will throw error/onComplete func before
	-- the program ever had a chance to respond 
	function grp.throwError( resp )
		local ee = {
			name = "ApigeeResponse",
			target = grp,
			isError = true,
			status = 400,
			response = resp,
		}		
		if( grp.onComplete ~= nil ) then
			grp.onComplete( ee )
		end
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
				if( grp.last_response ~= nil ) then
					if( grp.last_response.entities ~= nil ) then
						if( grp.last_response.entities[1].uuid ~= nil ) then
							grp.uuid = grp.last_response.entities[1].uuid
						end
					end
				end
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
		grp.ApigeeWorker( "login", "POST", url, auxdata )
	end
	function grp.userLogout( xtra )
		grp.handleXtra( xtra )
		local auxdata = grp.initAuxdata()
		local url = grp.baseUrl() .. "/users/"
				.. grp.username .. "/revoketokens?token="
				.. grp.sessionauth
			-- TODO: should verify that authorization is by session-token
		grp.ApigeeWorker( "logout", "POST", url, auxdata )
	end


	--
	-- data-items (entities) objects
	function grp.createDataObject( xtra )
		grp.handleXtra( xtra )
		if( grp.data == nil ) then
			grp.throwError( "No data specified" )
			return
		end
		local auxdata = grp.initAuxdata()
		auxdata.headers["Content-Type"] = "application/json"
		auxdata.body = json.encode( grp.data )
		local url = grp.baseUrl() .. "/"
				.. grp.collection
		grp.ApigeeWorker( "c_data", "POST", url, auxdata )
	end
	function grp.retrieveDataObject( xtra )
		grp.handleXtra( xtra )
		if( grp.uuid == nil ) then
			grp.throwError( "No UUID specified" )
			return
		end
		local auxdata = grp.initAuxdata()
		local url = grp.baseUrl() .. "/"
				.. grp.collection .. "/"
				.. grp.uuid
		grp.ApigeeWorker( "r_data", "GET", url, auxdata )
	end
	function grp.updateDataObject( xtra )
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
		grp.ApigeeWorker( "u_data", "PUT", url, auxdata )
	end
	function grp.deleteDataObject( xtra )
		grp.handleXtra( xtra )
		if( grp.uuid == nil ) then
			grp.throwError( "No UUID specified" )
			return
		end
		local auxdata = grp.initAuxdata()
		local url = grp.baseUrl() .. "/"
				.. grp.collection .. "/"
				.. grp.uuid
		grp.ApigeeWorker( "d_data", "DELETE", url, auxdata )
	end


	--
	-- collections/database objects
	function grp.createCollectionObject( xtra )
		grp.handleXtra( xtra )
		if( grp.collection == nil ) then
			grp.throwError( "No collection specified" )
			return
		end
		-- TODO: check that collection is pluralized
		local auxdata = grp.initAuxdata()
		local url = grp.baseUrl() .. "/"
				.. grp.collection
		grp.ApigeeWorker( "c_coll", "POST", url, auxdata )
	end
	function grp.retrieveCollectionObject( xtra )
		grp.handleXtra( xtra )
		if( grp.collection == nil ) then
			grp.throwError( "No collection specified" )
			return
		end
		-- TODO: check that collection is pluralized
		local auxdata = grp.initAuxdata()
		local url = grp.baseUrl() .. "/"
				.. grp.collection
		grp.ApigeeWorker( "r_coll", "GET", url, auxdata )
	end
	function grp.updateCollectionObject( xtra )
		grp.throwError( "No way to update a collection" )
	end
	function grp.deleteCollectionObject( xtra )
		grp.throwError( "No way to delete a collection" )
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
		grp.ApigeeWorker( "c_file", "POST", url, auxdata )
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
		grp.ApigeeWorker( "r_file", "GET", url, auxdata )
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
		grp.ApigeeWorker( "u_file", "PUT", url, auxdata )
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
		grp.ApigeeWorker( "d_file", "DELETE", url, auxdata )
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
				.. grp.uuid .. "/data"
		grp.ApigeeWorker( "up_file", "POST", url, auxdata )
	end
	function grp.downloadFileObject( xtra )
		grp.handleXtra( xtra )
		if( grp.uuid == nil ) then
			grp.throwError( "No UUID specified" )
			return
		end
		local auxdata = grp.initAuxdata()
		if( grp.data.filename == nil ) then
			grp.throwError( "No upload file specified" )
			return
		end
		if( grp.data.baseDirectory == nil ) then
			grp.data.baseDirectory = system.CachesDirectory
		end
		local url = grp.baseUrl() .. "/"
				.. grp.collection .. "/"
				.. grp.uuid .. "/data"
		grp.ApigeeWorker( "dn_file", "GET", url, auxdata )
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
		grp.ApigeeWorker( "c_act", "POST", url, auxdata )	
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
		grp.ApigeeWorker( "c_act", "GET", url, auxdata )	
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
		grp.ApigeeWorker( "c_act", "POST", url, auxdata )	
	end
	function grp.retrieveEventObject( xtra )
		grp.handleXtra( xtra )
		local auxdata = grp.initAuxdata()
		local url = grp.baseUrl() .. "/events"
		grp.ApigeeWorker( "c_act", "GET", url, auxdata )	
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
		grp.ApigeeWorker( "c_count", "GET", url, auxdata )	
	end

	return grp
end


return Apigee
