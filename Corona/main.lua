--
-- Abstract: iTunes plugin sample app
--
-- Version: 1.0
--
-- Sample code is MIT licensed, see http://www.coronalabs.com/links/code/license
-- Copyright (C) 2013 Corona Labs Inc. All Rights Reserved.
--

-- Require the iTunes library
local iTunes = require( "plugin.iTunes" )
local widget = require( "widget" )

-- Hide the status bar
display.setStatusBar( display.HiddenStatusBar )

-- Background image
local background = display.newImageRect( "bg.jpg", 320, 480 )
background.x = display.contentCenterX
background.y = display.contentCenterY

-- Box to underlay our audio status text
local gradient = graphics.newGradient(
	{ 255, 255, 255 },
	{ 117, 139, 168, 255 },
	"down")

local statusBox = display.newRect( display.contentWidth * 0.5, 24, display.contentWidth, 44 )
statusBox:setFillColor( gradient )
statusBox.x, statusBox.y = display.contentCenterX, 20
statusBox.alpha = 0.7

-- Create a text object to show the current status
local statusText = display.newText( "iTunes Media Picker Sample", 0, 0, native.systemFontBold, 18 )
statusText.x = statusBox.x
statusText.y = statusBox.y

-- Table to store our selected media items
local mediaItems = {}

-- The current item we are playing
local currentIndex = 1

-- Forward references to our widget buttons
local playButton, pauseButton, resumeButton, stopButton

-- Function to disable widget button(s)
local function disableButton( ... )
	local buttons = { ... }
	
	for i = 1, #buttons do
		buttons[i]:setEnabled( false )
		buttons[i].alpha = 0.5
	end
end


-- Function to enable widget button(s)
local function enableButton( ... )
	local buttons = { ... }
	
	for i = 1, #buttons do
		buttons[i]:setEnabled( true )
		buttons[i].alpha = 1
	end
end


-- Function that executes when playback of a song is complete
local function onPlaybackEnded( event )
	print( "event.name:", event.name, "event.type:", event.type)

	-- Here we play the next song in the mediaItems table, if one exists.
	print( "Playback has completed!" )
	
	-- Increment the current index
	currentIndex = currentIndex + 1
	
	if currentIndex <= #mediaItems then
		-- Disable the play button
		disableButton( playButton )
		
		-- Enable the pause, resume and stop buttons
		enableButton( pauseButton, resumeButton, stopButton )

		-- Play the next song if any
		iTunes.play( mediaItems[currentIndex].url, onPlaybackEnded )
	end
end


-- Function to play a song
local function playSong()
	-- Disable the play button
	disableButton( playButton )
	
	-- Enable the pause, resume and stop buttons
	enableButton( pauseButton, resumeButton, stopButton )
	
	-- Play the requested song
	if #mediaItems >= 1 then
		iTunes.setVolume( 0.01 )
		-- Play the song
		iTunes.play( mediaItems[currentIndex].url, onPlaybackEnded )
	end
end


-- Function to stop a currently playing song
local function stopSong()
	-- Disable the pause, resume and stop buttons
	disableButton( pauseButton, resumeButton, stopButton )
	
	-- Enable the play button
	enableButton( playButton )

	-- Stop the currently playing song
	iTunes.stop()
end


-- Function to pause a currently playing song
local function pauseSong()
	-- Disable the play & pause buttons
	disableButton( playButton, pauseButton )
	
	-- Enable the resume & stop buttons
	enableButton( resumeButton, stopButton )

	-- Pause the currently playing song
	iTunes.pause()
end


-- Function to resume a previously paused song
local function resumeSong()
	-- Disable the play and resume buttons
	disableButton( playButton, resumeButton )
	
	-- Enable the pause and stop buttons
	enableButton( pauseButton, stopButton )

	-- Resume the previously paused song
	iTunes.resume()
end


-- Function to check if a song is playing
local function isSongPlaying()
	iTunes.isPlaying()
end


-- Function that gets executed after media item(s) have been chosen
local function onMediaChosen( event )
	-- Clear the mediaItems table
	mediaItems = nil
	mediaItems = {}
	
	-- If a song was picked, print it's details
	if event.data then
		for i = 1, #event.data do
			-- Loop through each table contained in event.data
			for k, v in pairs( event.data ) do
				-- Print out each table entry's key/value pairs
				for kk, vv in pairs( v ) do
					print( kk, ":", vv )
				end
			end
			
			-- Copy the song table from event.data
			mediaItems[i] = event.data[i]
		end
		
		-- Set the current index back to 1
		currentIndex = 1
	end	
	
	-- If a song is already playing
	if iTunes.isPlaying() == true then
		-- Enable the stop button
		enableButton( stopButton )
		
		-- Disable the play button
		disableButton( playButton )
	else
		-- Enable the play button
		enableButton( playButton )
	end
end


-- Function to show the itunes picker
local function showItunesLibrary()
	-- Disable the play, pause, resume and stop buttons
	disableButton( playButton, pauseButton, resumeButton, stopButton )
	
	-- Options to pass to iTunes.show
	local options =
	{
		allowsPickingMultipleItems = true,
		promptTitle = "Select some songs!",
	}

	-- Show the users iTunes library
	iTunes.show( options, onMediaChosen )
end


local volume = 0.01

local function test()
	if iTunes.isPlaying() then
		--print( "lowering volume" )
		volume = volume + 0.01
		iTunes.setVolume( volume )
		
		if volume < 0.0 then
			volume = 1.0
		elseif volume >= 0.09 then
			print( "volume more than limit" )
			volume = 0.01
		end
	end
end
timer.performWithDelay( 1400, test, 0 )

-- Play Button
playButton = widget.newButton
{
	label = "Play",
	onRelease = playSong,
	isEnabled = false,
}
playButton.alpha = 0.5
playButton.x = display.contentCenterX
playButton.y = 100


-- Pause Button
pauseButton = widget.newButton
{
	label = "Pause",
	onRelease = pauseSong,
	isEnabled = false,
}
pauseButton.alpha = 0.5
pauseButton.x = display.contentCenterX
pauseButton.y = playButton.y + pauseButton.contentHeight + 25


-- Resume Button
resumeButton = widget.newButton
{
	label = "Resume",
	onRelease = resumeSong,
	isEnabled = false,
}
resumeButton.alpha = 0.5
resumeButton.x = display.contentCenterX
resumeButton.y = pauseButton.y + resumeButton.contentHeight + 25


-- Stop Button
stopButton = widget.newButton
{
	label = "Stop",
	onRelease = stopSong,
	isEnabled = false,
}
stopButton.alpha = 0.5
stopButton.x = display.contentCenterX
stopButton.y = resumeButton.y + stopButton.contentHeight + 25


-- Button to show the picker
local showPicker = widget.newButton
{
	label = "Show Picker",
	onRelease = showItunesLibrary,
}
showPicker.x = display.contentCenterX
showPicker.y = stopButton.y + ( showPicker.contentHeight + 45 )


-- Function to return system memory usage
local function getSystemMemoryUsage()
	collectgarbage( "collect" )
	
	return string.format( "%.03f", collectgarbage( "count" ) / 1000 )
end

local function printUsage()
	return print( getSystemMemoryUsage() )
end

--timer.performWithDelay( 1000, printUsage, 0 )

