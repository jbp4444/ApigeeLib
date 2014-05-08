-- test code for running Corona against apigee cloud resources
--
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

local apigee = require( "scripts.ApigeeSynchr" )
local json = require( "json" )

for i=1,5 do
	print( " " )
end

--
--  --  --  --  --  --  --  --  --  --  --  --  --  --
--

-- handle the return-result
function printResult( e )
	print( "returned value:" )
	print( "  isError = "..tostring(e.isError) )
	print( "  status = "..e.status )
	print( "  response = ["..json.encode(e.response).."]" )
end

--
--  --  --  --  --  --  --  --  --  --  --  --  --  --
--

-- configure the connection to apigee
-- -- the apigee_* vars are set in apigeeInfo.lua
local apobj = apigee.new({
	baseurl = apigee_baseurl,
	orgname = apigee_orgname,
	appname = apigee_appname,
	collection = apigee_collection,
	username = apigee_username,
	password = apigee_password,
})

local rtn = {}

print( "login" )
rtn = apobj.userLogin()
printResult( rtn )

--
--  --  --  --  --  --  --  --  --  --  --  --  --  --
--

-- data-entity manipulations
if( entity_tests ) then
	print( "retrive known entity" )
	rtn = apobj.retrieveEntity({
		uuid = "7b6ef8fa-b686-11e3-b523-29a1e08cd3ce",
	})
	printResult( rtn )
	print( "create new entity" )
	rtn = apobj.createEntity({
		data = {
			foofoo = "foo",
			barbar = "bar",
			bazbaz = "baz",
		},
	})
	printResult( rtn )
	print( "retrieve last entity" )
	rtn = apobj.retrieveEntity({
		uuid = "LAST",
	})
	printResult( rtn )
	print( "update last entity" )
	rtn = apobj.updateEntity({
		uuid = "LAST",
		data = {
			barbar = "newnewnewnew"
		},
	})
	printResult( rtn )
	print( "delete last entity" )
	rtn = apobj.deleteEntity({
		uuid = "LAST",
	})
	printResult( rtn )
end

--
--  --  --  --  --  --  --  --  --  --  --  --  --  --
--

-- collection tests
if( collection_tests ) then
	print( "retrieve known collection" )
	rtn = apobj.retrieveCollectionObject({
		collection = "lotsofstuffs",
	})
	printResult( rtn )
	print( "create new collection" )
	rtn = apobj.createCollectionObject({
		collection = "newcolls",
	})
	printResult( rtn )
	rtn = apobj.retrieveCollectionObject({
		collection = "newcolls",
	})
	printResult( rtn )
	rtn = apobj.updateCollectionObject({
		collection = "newcolls",
	})
	printResult( rtn )
	rtn = apobj.deleteCollectionObject({
		collection = "newcolls",
	})
	printResult( rtn )
end

if( file_tests ) then
	-- create a new object, retrieve it, then delete it
	print( "create new file" )
	rtn = apobj.createFileObject({
		collection = "assets",
		data = {
			name = "data.txt",
			path = "/data.txt",
		},
	})
	printResult( rtn )
	print( "retrieve file" )
	rtn = apobj.retrieveFileObject({
		collection = "assets",
		uuid = "LAST",
	})
	printResult( rtn )
	print( "update file" )
	rtn = apobj.updateFileObject({
		collection = "assets",
		data = {
			myextradata = "foobarbaz",
		},
		uuid = "LAST",
	})
	printResult( rtn )
	print( "upload file" )
	rtn = apobj.uploadFileObject({
		collection = "assets",
		data = {
			filename = "data.txt",
			baseDirectory = system.CachesDirectory,
		},
		uuid = "LAST",
	})
	printResult( rtn )
	print( "download file" )
	rtn = apobj.downloadFileObject({
		collection = "assets",
		data = {
			filename = "data_dn.txt",
			baseDirectory = system.CachesDirectory,
		},
		uuid = "LAST",
	})
	printResult( rtn )
	print( "delete file" )
	rtn = apobj.deleteFileObject({
		collection = "assets",
		uuid = "LAST",
	})
	printResult( rtn )
end

--
--  --  --  --  --  --  --  --  --  --  --  --  --  --
--

print( "logout" )
rtn = apobj.userLogout()
printResult( rtn )
