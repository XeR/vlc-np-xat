local dialog
local w_status, w_id, w_token, w_chats
local id, token, chats
local activated

-- ----------------------------------------------------------------------------
-- -- VLC functions
-- ----------------------------------------------------------------------------

function descriptor()
	local version = "0.1"
	return {
		title        = "np-xat " .. version,
		version      = version,
		author       = "XeR",
		url          = "https://xat.com/",
		shortdesc    = "Now Playing on xat status",
		description  = "Is this even displayed?",
		capabilities = { "input-listener" }
	}
end

function activate()
	vlc.msg.dbg("[np-xat] Starting")

	activated = false
	dialog    = vlc.dialog("Xat status")

	-- Labels
	w_status = dialog:add_label("", 1, 1, 2, 1)
	dialog:add_label("User ID:", 1, 2)
	dialog:add_label("Token:",   1, 3)
	dialog:add_label("Chats:",   1, 4)

	-- Inputs
	w_id    = dialog:add_text_input("586552", 2, 2)
	w_token = dialog:add_password("0000000000000000", 2, 3)
	w_chats = dialog:add_text_input("xat5,Chat", 2, 4)

	-- Buttons
	dialog:add_button("Start",  goPressed,      1, 5)
	dialog:add_button("Cancel", vlc.deactivate, 2, 5)

	-- Display the dialog
	w_status:set_text("Please enter the following information:")
	dialog:show()
end

function deactivate()
	vlc.msg.dbg("[np-xat] Stopping")
end

-- ----------------------------------------------------------------------------
-- -- Event functions
-- ----------------------------------------------------------------------------

function meta_changed()
	-- vlc.msg.dbg("[np-xat] Meta changed")
end

function input_changed()
	vlc.msg.dbg("[np-xat] Input changed")

	local item   = vlc.input.item()
	local status = status(item)

	vlc.msg.dbg("[np-xat] " .. status)

	-- Not activated > do not send requests
	if not activated then
		return false
	end

	for chat,chatid in pairs(chats) do
		vlc.msg.dbg("[np-xat] " .. chatid)
		update(id, token, chatid, status)
	end
end

function goPressed()
	id    = tonumber(w_id:get_text())
	token = w_token:get_text()
	chats = {}

	-- Invalidate previous settings
	activated = false

	-- Check user input
	if id == nil or id <= 101 then
		w_status:set_text("ID is invalid")
		return false
	end

	if token == nil or token == "" then
		w_status:set_text("Token is invalid")
		return false
	end

	-- Fetch chats
	w_status:set_text("Fetching chats' ID...")
	for c in string.gmatch(w_chats:get_text(), "[^,]+") do
		vlc.msg.dbg("[np-xat] chat = " .. c)

		-- Do not resolve the same chat twice
		if chats[c] == nil then
			chats[c] = resolve(c)
			vlc.msg.dbg("[np-xat] c = " .. chats[c])
		end

		-- If resolve() returned nil, we have an error
		if chats[c] == nil then
			w_status:set_text("Chat " .. c .. " is invalid")
			return false
		end
	end

	-- Test run on xat3
--	w_status:set_text("Loading...")
--	if update(id, token, 3, "") == "" then
--		activated = true
--		dialog:delete()
--	end

	activated = true
	dialog:delete()
end

-- ----------------------------------------------------------------------------
-- -- Helper functions
-- ----------------------------------------------------------------------------

function status(item)
	if item:metas()["title"] == nil then
		return item:name()
	end

	if item:metas()["artist"] == nil then
		return item:metas()["title"]
	end

	if item:metas()["album"] == nil then
		return item:metas()["title"] .. " - " .. item:metas()["artist"]
	end

	return item:metas()["title"] .. " - " .. item:metas()["artist"] ..
		" (" .. item:metas()["album"] .. ")"
end

function getURL(id, token, chat, status)
	-- local url = "http://127.0.0.1:12345/foo"
	local url = "https://xat.com/api/botstat.php"

	url = url .. "?u=" .. vlc.strings.encode_uri_component(id)
	url = url .. "&k=" .. vlc.strings.encode_uri_component(token)
	url = url .. "&r=" .. vlc.strings.encode_uri_component(chat)
	url = url .. "&s=" .. vlc.strings.encode_uri_component(status)

	return url
end

function update(id, token, chat, status)
	local url, stream

	url = getURL(id, token, chat, status)

	vlc.msg.dbg("[np-xat] " .. url)
	stream = vlc.stream(url)
	return stream:readline()
end

function resolve(chat)
	local url, stream, json

	-- Easy case: xatNNNN => return NNNN
 	if string.lower(string.sub(chat, 0, 3)) == "xat" then
 		return tonumber(string.sub(chat, 4))
 	end

	-- Non-trivial case: fetch it from xat's API
	url    = "https://xat.com/web_gear/chat/roomid.php?d=" .. chat
	stream = vlc.stream(url)
	json   = stream:readline()

	vlc.msg.dbg("[np-xat] roomid json = " .. json)
	return tonumber(string.match(json, "\"id\":\"([0-9]+)\""))
end
