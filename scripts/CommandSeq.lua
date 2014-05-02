--
--   Copyright 2013-2014 John Pormann
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

local CommandSeq = {}

function CommandSeq.new( clObj, params )
	local csObj = {}
	csObj.cloudObj = clObj
	csObj.seq = {}
	csObj.onComplete = function(e)
			print( "default ComandSeq.onComplete function called" )
		end

	-- send an event back to the caller
	local function callbackToUser( e )
		-- TODO: check for name, isError, status, response
		if( csObj.userOnComplete ~= nil ) then
			csObj.userOnComplete( e )
		end
	end	

	local function catchCloudResult( e )
		-- TODO: have a user-option for progress/no-progress
		callbackToUser( e )
				
		-- see if there are more commands in this sequence
		if( table.getn(csObj.seq) <= 0 ) then
			print( "no more commands to run" )
			callbackToUser({
				name = "CommandSeqResponse",
				isError = false,
				status = 9900,
				response = "Sequence complete",
			})
		else
			csObj.exec()
		end
	end
	
	function csObj.exec()
		-- TODO: make sure onComplete funcs (cloudObj and cmdSeq) 
		-- are configured properly
		local tfx = table.remove( csObj.seq, 1 )
		local t = tfx[1]
		local f = tfx[2]
		local x = tfx[3]
		-- save the user's onComplete function, even if nil
		csObj.userOnComplete = x.onComplete
		-- we need to intercept the onComplete handler
		x.onComplete = catchCloudResult
		print( "running "..t.." command" )
		f( x )
	end

	function csObj.add( txt, cmd, opts )
		-- TODO: check args/list for validity
		if( type(txt) == "table" ) then
			-- assume this is a list of commands to add
			for i,j in ipairs(txt) do
				table.insert( csObj.seq, j )
			end
		else
			table.insert( csObj.seq, {txt,cmd,opts} )
		end
	end

	--
	-- initialize the cmdseq object
	--
	
	-- check for user-params
	if( params ~= nil ) then
		if( params.list ~= nil ) then
			-- do a deep-copy since we'll be removing objects one at a time
			for i,x in ipairs(params.list) do
				csObj.seq[i] = x
			end
		end
		if( params.onComplete ~= nil ) then
			csObj.userOnComplete = params.onComplete
		end
	end
	
	return csObj
end

return CommandSeq
