// ----------------------------------------------------------------------------
// iTunesLibrary.mm
//
// Copyright (c) 2013 Corona Labs Inc. All rights reserved.
// ----------------------------------------------------------------------------

#import "iTunesLibrary.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <Accounts/Accounts.h>
#import <AVFoundation/AVFoundation.h>

#import "CoronaRuntime.h"
#include "CoronaAssert.h"
#include "CoronaEvent.h"
#include "CoronaLua.h"
#include "CoronaLibrary.h"

// Our audio delegate
@interface AudioDelegate : NSObject <AVAudioPlayerDelegate>

@property (nonatomic) int callbackRef; // Reference to store our onComplete function
@property (nonatomic, assign) lua_State *L; // Pointer to the current lua state

@end

// Our media delegate
@interface MediaDelegate : UIViewController <MPMediaPickerControllerDelegate>

@property (nonatomic) int callbackRef; // Reference to store our onComplete function
@property (nonatomic, assign) lua_State *L; // Pointer to the current lua state

@end

// ----------------------------------------------------------------------------

@class UIViewController;

namespace Corona
{

// ----------------------------------------------------------------------------

class iTunesLibrary
{
	public:
		typedef iTunesLibrary Self;

	public:
		static const char kName[];
		
	public:
		static int Open( lua_State *L );
		static int Finalizer( lua_State *L );
		static Self *ToLibrary( lua_State *L );

	protected:
		iTunesLibrary();
		bool Initialize( void *platformContext );
		
	public:
		UIViewController* GetAppViewController() const { return fAppViewController; }

	public:
		static int show( lua_State *L );
		static int play( lua_State *L );
		static int pause( lua_State *L );
		static int resume( lua_State *L );
		static int stop( lua_State *L );
		static int isPlaying( lua_State *L );

	private:
		UIViewController *fAppViewController;
};

// Objective-c members, not part of C++ class.
static AudioDelegate *audioDelegate;
static MediaDelegate *mediaDelegate;
static AVAudioPlayer *audioPlayer;

// ----------------------------------------------------------------------------

// This corresponds to the name of the library, e.g. [Lua] require "plugin.library"
const char iTunesLibrary::kName[] = "plugin.iTunes";

int
iTunesLibrary::Open( lua_State *L )
{
	// Register __gc callback
	const char kMetatableName[] = __FILE__; // Globally unique string to prevent collision
	CoronaLuaInitializeGCMetatable( L, kMetatableName, Finalizer );
	
	//CoronaLuaInitializeGCMetatable( L, kMetatableName, Finalizer );
	void *platformContext = CoronaLuaGetContext( L );

	// Set library as upvalue for each library function
	Self *library = new Self;

	if ( library->Initialize( platformContext ) )
	{
		// Functions in library
		static const luaL_Reg kFunctions[] =
		{
			{ "show", show },
			{ "play", play },
			{ "pause", pause },
			{ "resume", resume },
			{ "stop", stop },
			{ "isPlaying", isPlaying },
			{ NULL, NULL }
		};

		// Register functions as closures, giving each access to the
		// 'library' instance via ToLibrary()
		{
			CoronaLuaPushUserdata( L, library, kMetatableName );
			luaL_openlib( L, kName, kFunctions, 1 ); // leave "library" on top of stack
		}
	}

	return 1;
}

int
iTunesLibrary::Finalizer( lua_State *L )
{
	Self *library = (Self *)CoronaLuaToUserdata( L, 1 );
	delete library;
	
	// Release the audioDelegate
	[audioDelegate release];
	audioDelegate = nil;
	
	// Release the mediaDelegate
	[mediaDelegate release];
	mediaDelegate = nil;
	
	// Release the audioPlayer
	[audioPlayer release];
	audioPlayer = nil;
	
	return 0;
}

iTunesLibrary *
iTunesLibrary::ToLibrary( lua_State *L )
{
	// library is pushed as part of the closure
	Self *library = (Self *)CoronaLuaToUserdata( L, lua_upvalueindex( 1 ) );
	return library;
}

iTunesLibrary::iTunesLibrary()
:	fAppViewController( nil )
{
}

bool
iTunesLibrary::Initialize( void *platformContext )
{
	bool result = ( ! fAppViewController );

	if ( result )
	{
		id<CoronaRuntime> runtime = (id<CoronaRuntime>)platformContext;
		fAppViewController = runtime.appViewController; // TODO: Should we retain?
	}

	return result;
}

// ----------------------------------------------------------------------------

// Function to play a media item
int
iTunesLibrary::play( lua_State *L )
{
	// Free the reference
	lua_unref( audioDelegate.L, audioDelegate.callbackRef );
	
	// Set the callback reference to 0
	audioDelegate.callbackRef = 0;
	
	// Set the delegates callbackRef to reference the onComplete function (if it exists)
	if ( lua_isfunction( L, -1 ) )
	{
		audioDelegate.callbackRef = luaL_ref( L, LUA_REGISTRYINDEX );
	}
	
	// Throw error if song url was not passed to the function
	if ( LUA_TSTRING != lua_type( L, -1 ) )
	{
		luaL_error( L, "Song url expected, got nil" );
	}

	// Set the song 
	NSString *luaSongURL = [NSString stringWithUTF8String:lua_tostring( L, -1 )];
	NSURL *songURL = [NSURL URLWithString:luaSongURL];
	NSError *error = nil;
	
	// If the audioPlayer object is valid, stop any current playback
	if ( nil != audioPlayer )
	{
		[audioPlayer stop];
	}
	
	// Technically it makes sense to release and nil the audioPlayer here before reinstantiating it, however that results in a crash.
	// Stackoverflow research indicates that what we are doing is the right approach, and extensive memory testing concluded that we are not leaking any memory.
		
	// Initialize the audio player
	audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:songURL error:&error];
	
	// Report the error message to lua
	if ( nil != error )
	{
		NSString *theError = [error localizedDescription];
		luaL_error( L, [theError UTF8String] );
	}
	// No error, play the song
	else
	{
		// Assign the delegate
		audioPlayer.delegate = audioDelegate;
		// Play the selected item
		[audioPlayer prepareToPlay];
		[audioPlayer play];
		[songURL release];
	}

	return 0;
}


// Function to pause a playing media item
int
iTunesLibrary::pause( lua_State *L )
{	
	if ( nil != audioPlayer )
	{
		[audioPlayer pause];
	}
	
	return 0;
}


// Function to resume a paused media item
int
iTunesLibrary::resume( lua_State *L )
{
	if ( nil != audioPlayer )
	{
		[audioPlayer play];
	}
	
	return 0;
}


// Function to stop a playing media item
int
iTunesLibrary::stop( lua_State *L )
{
	if ( nil != audioPlayer )
	{
		[audioPlayer stop];
	}

	return 0;
}


// Function to see if a media item is playing
int
iTunesLibrary::isPlaying( lua_State *L )
{
	bool isPlaying = false;
	
	if ( nil != audioPlayer )
	{
		isPlaying = [audioPlayer isPlaying];
	}
	
	lua_pushboolean( L, isPlaying );
	
	return 1;
}


// Function to show the media picker
int
iTunesLibrary::show( lua_State *L )
{
// Just print a warning message for the iPhone simulator (The plugin is only supported on device)
#if TARGET_IPHONE_SIMULATOR
	printf( "WARNING: This plugin is not supported on the iPhone/iPad simulator, please build for device\n" );
#else
	using namespace Corona;

	Self *context = ToLibrary( L );
	
	if ( context )
	{
		Self& library = * context;
		
		UIViewController *appViewController = library.GetAppViewController();
		mediaDelegate = [[MediaDelegate alloc] init];
		audioDelegate = [[AudioDelegate alloc] init];
		
		// Assign the lua state so we can access it from within the audio delegate
		audioDelegate.L = L;
		
		// Assign the lua state so we can access it from within the media delegate
		mediaDelegate.L = L;
		
		// Set the callback reference to 0
		mediaDelegate.callbackRef = 0;
		
		// Set default properties
		NSString *promptTitle = @"Select song to play";
		bool allowsPickingMultipleItems = false;
		
		// Set the delegates callbackRef to reference the onComplete function (if it exists)
		if ( lua_isfunction( L, -1 ) )
		{
			mediaDelegate.callbackRef = luaL_ref( L, LUA_REGISTRYINDEX );
		}
		
		// If there is a options table
		if ( lua_istable( L, -1 ) )
		{
			lua_getfield( L, -1, "promptTitle");
			if ( LUA_TSTRING == lua_type( L, -1 ) )
			{
				promptTitle = [NSString stringWithUTF8String:lua_tostring( L, -1 )];
			}
			lua_pop( L, 1 );
			
			lua_getfield( L, -1, "allowsPickingMultipleItems");
			if ( LUA_TBOOLEAN == lua_type( L, -1 ) )
			{
				allowsPickingMultipleItems = lua_toboolean( L, -1 );
			}
			lua_pop( L, 1 );
		}
		
		// Show the media picker
		MPMediaPickerController *mediaPicker = [[MPMediaPickerController alloc] initWithMediaTypes: MPMediaTypeAnyAudio];
		if ( nil != mediaPicker )
		{
			mediaPicker.delegate = mediaDelegate;
			mediaPicker.allowsPickingMultipleItems = allowsPickingMultipleItems;
			mediaPicker.showsCloudItems = NO;
			mediaPicker.prompt = promptTitle;
			[appViewController presentModalViewController:mediaPicker animated:YES];
			[mediaPicker release];
		}
	}
#endif
	
	return 0;
}


// ----------------------------------------------------------------------------

} // namespace Corona

//

// Audio Delegate implementation
@implementation AudioDelegate

- (void) audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL) flag
{
	// Stop the player
	[player stop];
	
	// If there is a callback to execute
	if ( 0 != self.callbackRef )
	{
		// Push the onComplete function onto the stack
		lua_rawgeti( self.L, LUA_REGISTRYINDEX, self.callbackRef );
	
		// Create event table
		lua_newtable( self.L );
		
		// Set event.name property
		lua_pushstring( self.L, "itunes" ); // Value ( name )
		lua_setfield( self.L, -2, "name" ); // Key
		
		// Set event.type
		const char *eventName = "completed";
		lua_pushstring( self.L, eventName ); // Value ( function type name )
		lua_setfield( self.L, -2, "type" ); // Key
		
		// Call the onComplete function
		Corona::Lua::DoCall( self.L, 1, 1 ); // Remember < L, num arguments, num results
	}
}

@end


// Media Delegate implementation
@implementation MediaDelegate

// Responds to the user tapping Done after choosing music.
- (void) mediaPicker:(MPMediaPickerController *)mediaPicker didPickMediaItems:(MPMediaItemCollection *) mediaItemCollection
{
	// If there is a callback to execute
	if ( 0 != self.callbackRef )
	{
		// Push the onComplete function onto the stack
		lua_rawgeti( self.L, LUA_REGISTRYINDEX, self.callbackRef );
		
		// Create event table
		lua_newtable( self.L );
		
		// Create event.data table
		lua_newtable( self.L );
		
		// Our iterator index
		int i = 1;

		// Loop through the chosen items in the media collection
		for ( MPMediaItem *song in mediaItemCollection.items )
		{
			// The song url
			NSURL *songURL = [song valueForProperty:MPMediaItemPropertyAssetURL];
			
			// If the song is on the device, it will return a url and we will add this song to the callback table
			if ( nil != songURL )
			{
				// Create a table for this item
				lua_newtable( self.L );
				
				// Song URL
				NSString *songUrl = [songURL absoluteString];
				lua_pushstring( self.L, [songUrl UTF8String] );
				lua_setfield( self.L, -2, "url" );
											
				// Album Artist
				NSString *albumArtist = [song valueForProperty:MPMediaItemPropertyAlbumArtist];
				lua_pushstring( self.L, [albumArtist UTF8String] );
				lua_setfield( self.L, -2, "albumArtist" );
				
				// Song title
				NSString *title = [song valueForProperty:MPMediaItemPropertyTitle];
				lua_pushstring( self.L, [title UTF8String] );
				lua_setfield( self.L, -2, "songTitle" );
				
				// Album Title
				NSString *albumTitle = [song valueForProperty:MPMediaItemPropertyAlbumTitle];
				lua_pushstring( self.L, [albumTitle UTF8String] );
				lua_setfield( self.L, -2, "albumTitle" );
				
				// Performing Artist
				NSString *performingArtist = [song valueForProperty:MPMediaItemPropertyArtist];
				lua_pushstring( self.L, [performingArtist UTF8String] );
				lua_setfield( self.L, -2, "performingArtist" );
								
				// Composer
				NSString *composer = [song valueForProperty:MPMediaItemPropertyComposer];
				lua_pushstring( self.L, [composer UTF8String] );
				lua_setfield( self.L, -2, "composer" );
				
				// Genre
				NSString *genre = [song valueForProperty:MPMediaItemPropertyGenre];
				lua_pushstring( self.L, [genre UTF8String] );
				lua_setfield( self.L, -2, "genre" );
				
				// Duration
				NSNumber *duration = [song valueForProperty:MPMediaItemPropertyPlaybackDuration];
				lua_pushnumber( self.L, [duration intValue] );
				lua_setfield( self.L, -2, "duration" );
								
				// Rating
				NSNumber *rating = [song valueForProperty:MPMediaItemPropertyRating];
				lua_pushnumber( self.L, [rating intValue] );
				lua_setfield( self.L, -2, "rating" );
				
				// Play count
				NSNumber *playCount = [song valueForProperty:MPMediaItemPropertyPlayCount];
				lua_pushnumber( self.L, [playCount intValue] );
				lua_setfield( self.L, -2, "playCount" );
				
				// Lyrics
				NSString *lyrics = [song valueForProperty:MPMediaItemPropertyLyrics];
				lua_pushstring( self.L, [lyrics UTF8String] );
				lua_setfield( self.L, -2, "lyrics" );
				
				// Podcast Title
				NSString *podcastTitle = [song valueForProperty:MPMediaItemPropertyPodcastTitle];
				lua_pushstring( self.L, [podcastTitle UTF8String] );
				lua_setfield( self.L, -2, "podcastTitle" );
				
				lua_rawseti( self.L, -2, i );
				i++;
			}
		}
				
		// Set event.data
		lua_setfield( self.L, -2, "data" );
		
		// Set event.name property
		lua_pushstring( self.L, "itunes" ); // Value ( name )
		lua_setfield( self.L, -2, "name" ); // Key
		
		// Set event.type
		const char *eventName = "selected";
		lua_pushstring( self.L, eventName ); // Value ( function type name )
		lua_setfield( self.L, -2, "type" ); // Key

		// Call the onComplete function
		Corona::Lua::DoCall( self.L, 1, 1 );
		
		// Free the reference
		lua_unref( self.L, self.callbackRef );
	}
	
	// Dismiss the modal view controller
	[mediaPicker dismissModalViewControllerAnimated: YES];
}


// Responds to the user tapping done having chosen no music.
- (void) mediaPickerDidCancel:(MPMediaPickerController *) mediaPicker
{
	// If there is a callback to execute
	if ( 0 != self.callbackRef )
	{
		// Push the onComplete function onto the stack
		lua_rawgeti( self.L, LUA_REGISTRYINDEX, self.callbackRef );
		
		// Create event table
		lua_newtable( self.L );
		
		// Set event.name property
		lua_pushstring( self.L, "itunes" ); // Value ( name )
		lua_setfield( self.L, -2, "name" ); // Key
		
		// Set event.type
		const char *eventName = "cancelled";
		lua_pushstring( self.L, eventName ); // Value ( function type name )
		lua_setfield( self.L, -2, "type" ); // Key

		// Call the onComplete function
		Corona::Lua::DoCall( self.L, 1, 1 );
		
		// Free the reference
		lua_unref( self.L, self.callbackRef );
	}

	// Dismiss the modal view controller
	[mediaPicker dismissModalViewControllerAnimated: YES];
}

@end


// ----------------------------------------------------------------------------

CORONA_EXPORT
int luaopen_plugin_iTunes( lua_State *L )
{
	return Corona::iTunesLibrary::Open( L );
}
