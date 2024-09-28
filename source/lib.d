import std.stdio;
import std.string;

import lua_bindings;
import nvml;
import util;

class MyThing  {
    ulong x;
    ulong y;
    ulong z;
    ulong w;
}

// TODO(ccapitalK): There should be a better way to set this
extern(C) __gshared string[] rt_options = [ 
    // "gcopt=maxPoolSize:1"
    "gcopt=profile:1"
];

int libNvmlInit(lua_State *L) {
    if (isInitialized) {
        warn("Tried to double initialize nvml");
        return 1;
    }
    int res = initNvml();
    if (!isInitialized) {
        writeln("Didn't initialize?");
    }
    return res;
}

int libNvmlIsInit(lua_State *L) {
    int numArgs = lua_gettop(L);
    lua_pop(L, numArgs);
    lua_pushboolean(L, isInitialized != 0);
    return 1;
}

int libNvmlClose(lua_State *L) {
    if (!isInitialized) {
        warn("Tried to close uninitialized nvml handle");
        return 1;
    }
    int res = closeNvml();
    if (isInitialized) {
        writeln("Didn't close?");
    }
    return res;
}

int libNvmlNumDevices(lua_State *L) {
    // MyThing[] things;
    // foreach (x; 0 .. (1000 * 1000)) {
    //     auto newThing = new MyThing();
    //     newThing.x = x;
    //     things ~= newThing;
    // }
    // writeln(things.length);
    lua_pushinteger(L, 1);
    return 1;
}

extern(C) int luaopen_nvml(lua_State *L) {
    lua_register(L, "hello", &hello);
    lua_register(L, "nvml_init", &libNvmlInit);
    lua_register(L, "nvml_is_initialized", &libNvmlIsInit);
    lua_register(L, "nvml_num_devices", &libNvmlNumDevices);
    lua_register(L, "nvml_query_device_info", &libNvmlQueryDeviceInfo);
    lua_register(L, "nvml_close", &libNvmlClose);
    return 1;
}

int hello(lua_State *L) {
    lua_pushstring(L, "Hello");
    return 1;
}

int libNvmlQueryDeviceInfo(lua_State *L) {
    int numArgs = lua_gettop(L);

    if (numArgs != 1) {
        lua_pushstring(L, "Exactly one argument expected");
        lua_error(L);
        return 0;
    }

    if (!lua_isinteger(L, -1)) {
        lua_pushstring(L, "Integer argument expected");
        lua_error(L);
        return 0;
    }

    auto n = cast(int) lua_tointeger(L, -1);
    lua_pop(L, 1);

    GpuInformation info;
    if (nvmlQueryDevice(n, &info)) {
        lua_pushstring(L, "Failed to query device information");
        lua_error(L);
        return 0;
    }

    lua_newtable(L);

    lua_pushstring(L, "name");
    lua_pushstring(L, info.name.ptr);
    lua_settable(L, -3);
    
    lua_pushstring(L, "fanSpeedPercent");
    lua_pushinteger(L, info.fanSpeedPercent);
    lua_settable(L, -3);
    
    lua_pushstring(L, "freq");
    lua_pushinteger(L, info.freq);
    lua_settable(L, -3);

    lua_pushstring(L, "memFreq");
    lua_pushinteger(L, info.memFreq);
    lua_settable(L, -3);

    lua_pushstring(L, "tempCelcius");
    lua_pushinteger(L, info.tempCelcius);
    lua_settable(L, -3);

    lua_pushstring(L, "slowdownTempCelcius");
    lua_pushinteger(L, info.slowdownTempCelcius);
    lua_settable(L, -3);

    lua_pushstring(L, "shutdownTempCelcius");
    lua_pushinteger(L, info.shutdownTempCelcius);
    lua_settable(L, -3);

    return 1;
}
