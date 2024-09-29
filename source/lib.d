import std.stdio;
import std.string;

import lua_bindings;
import nvml;
import util;

class MyThing {
    ulong x;
    ulong y;
    ulong z;
    ulong w;
}

extern (C) __gshared bool rt_envvars_enabled = true;

// TODO(ccapitalK): There should be a better way to set this
// extern (C) __gshared string[] rt_options = [
//     "gcopt=profile:1"
// ];

// TODO(ccapitalK): Move nvml logic into D, separate from lua handling logic
// TODO(ccapitalK): Make separate query option for static parameters, since nvml takes a surprising
//                  amount of compute that scales with the number of parameters you query.

extern (C) int libNvmlInit(lua_State* L) {
    if (isInitialized) {
        warn("Tried to double initialize nvml");
        return 1;
    }
    int res = initNvml();
    if (!isInitialized) {
        lua_pushstring(L, "Failed to initialize");
        lua_error(L);
    }
    return res;
}

extern (C) int libNvmlIsInit(lua_State* L) {
    int numArgs = lua_gettop(L);
    lua_pop(L, numArgs);
    lua_pushboolean(L, isInitialized != 0);
    return 1;
}

extern (C) int libNvmlClose(lua_State* L) {
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

extern (C) int libNvmlNumDevices(lua_State* L) {
    // MyThing[] things;
    // foreach (x; 0 .. (1000 * 1000)) {
    //     auto newThing = new MyThing();
    //     newThing.x = x;
    //     things ~= newThing;
    // }
    // writeln(things.length);
    lua_pushinteger(L, numDevices);
    return 1;
}

void tableSet(T)(lua_State* L, int offset, const char* name, T value) {
    lua_pushstring(L, name);
    static if (is(T == char*)) {
        lua_pushstring(L, value);
    } else static if (is(T == uint)) {
        lua_pushinteger(L, value);
    } else {
        static assert(false, "Unsupported type: " ~ T.stringof);
    }
    lua_settable(L, offset - 2);
}

extern (C) int libNvmlQueryDeviceInfo(lua_State* L) {
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

    if (!isInitialized) {
        lua_pushstring(L, "Nvml not initialized");
        lua_error(L);
        return 0;
    }

    auto n = cast(int) lua_tointeger(L, 1);
    lua_pop(L, 1);

    if (n < 0 || n >= numDevices) {
        lua_pushstring(L, "Device index out of range");
        lua_error(L);
        return 0;
    }

    GpuInformation info;
    if (nvmlQueryDevice(n, &info)) {
        lua_pushstring(L, "Failed to query device information");
        lua_error(L);
        return 0;
    }

    lua_newtable(L);
    tableSet(L, -1, "name", info.name.ptr);
    tableSet(L, -1, "fanSpeedPercent", info.fanSpeedPercent);
    tableSet(L, -1, "freq", info.freq);
    tableSet(L, -1, "memFreq", info.memFreq);
    tableSet(L, -1, "tempCelcius", info.tempCelcius);
    tableSet(L, -1, "slowdownTempCelcius", info.slowdownTempCelcius);
    tableSet(L, -1, "shutdownTempCelcius", info.shutdownTempCelcius);

    return 1;
}

static luaL_Reg[] funcTable = [
    {"init", &libNvmlInit},
    {"is_initialized", &libNvmlIsInit},
    {"num_devices", &libNvmlNumDevices},
    {"query_device_info", &libNvmlQueryDeviceInfo},
    {"close", &libNvmlClose},
    {null, null},
];

extern (C) int luaopen_nvml(lua_State* L) {
    luaL_newlibtable(L, funcTable.ptr);
    luaL_setfuncs(L, funcTable.ptr, 0);
    return 1;
}
