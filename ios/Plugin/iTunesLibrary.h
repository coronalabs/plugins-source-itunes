// ----------------------------------------------------------------------------
// iTunesLibrary.h
//
// Copyright (c) 2013 Corona Labs Inc. All rights reserved.
// ----------------------------------------------------------------------------

#ifndef _iTunesLibrary_H__
#define _iTunesLibrary_H__

#include "CoronaLua.h"
#include "CoronaMacros.h"

// This corresponds to the name of the library, e.g. [Lua] require "plugin.library"
// where the '.' is replaced with '_'
CORONA_EXPORT int luaopen_plugin_iTunes( lua_State *L );



#endif // _iTunesLibrary_H__
