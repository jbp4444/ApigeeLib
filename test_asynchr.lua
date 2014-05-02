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

local apigee = require( "scripts.ApigeeAsynchr" )
local json = require( "json" )

for i=1,5 do
	print( " " )
end

--
--  --  --  --  --  --  --  --  --  --  --  --  --  --
--

-- configure the connection to apigee
local apobj = apigee.new({
	baseurl = apigee_baseurl,
	orgname = apigee_orgname,
	appname = apigee_appname,
	collection = apigee_collection,
	username = apigee_username,
	password = apigee_password,
	-- onComplete will be overwritten later
	--onComplete = "default"
})

-- handle the login-result and initiate the logout command
function handleLogout( e )
	print( "apigee logout result caught:" )
	print( "  isError = "..tostring(e.isError) )
	print( "  status = "..e.status )
	print( "  response = ["..e.response.."]" )
end

-- handle the login-result and initiate the logout command
function handleLogin( e )
	print( "apigee login result caught:" )
	print( "  isError = "..tostring(e.isError) )
	print( "  status = "..e.status )
	print( "  response = ["..e.response.."]" )

	apobj.userLogout({
		onComplete = handleLogout,
	})	
end

-- could specify username/password here
apobj.userLogin({
	onComplete = handleLogin,
})
