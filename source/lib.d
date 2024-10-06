import std.stdio;
import std.string;
import std.traits;

import glue;

// TODO: Should these be enabled?
// extern (C) __gshared string[] rt_options = [
//     "initReserve:1 incPoolSize:1"
// ];

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

int luaError(lua_State* L, const char* msg) {
    lua_pushstring(L, msg);
    lua_error(L);
    return 0;
}

extern (C) int libNvmlInit(lua_State* L) {
    if (isInitialized) {
        return luaError(L, "Tried to double initialize nvml");
    }
    int res = initNvml();
    if (!isInitialized) {
        return luaError(L, "Failed to initialize");
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
        return luaError(L, "Tried to close uninitialized nvml handle");
    }
    nvmlReturn_t result = nvmlShutdown();
    if (result != NVML_SUCCESS) {
        auto msg = format("Failed to shutdown NVML: %s\n", nvmlErrorString(result));
        return luaError(L, msg.toStringz);
    }
    isInitialized = false;
    return 0;
}

extern (C) int libNvmlNumDevices(lua_State* L) {
    int numArgs = lua_gettop(L);
    lua_pop(L, numArgs);
    lua_pushinteger(L, numDevices);
    return 1;
}

enum DeviceInfoType : string {
    all = "all",
    dynamic = "dynamic",
    static_ = "static",
}

static const(char)* invalidTypeInfoMessage() {
    import std.array;
    import std.algorithm;

    auto names = map!((a) => cast(string) a)([EnumMembers!DeviceInfoType]).array;
    return format("query_device_info: type must one of %s", names).toStringz;
}

bool parseDeviceType(const char[] inputString, ref DeviceInfoType type) {
    static foreach (member; EnumMembers!DeviceInfoType) {
        if (inputString == member) {
            type = member;
            return true;
        }
    }
    return false;
}

extern (C) int libNvmlQueryDeviceInfo(lua_State* L) {
    int numArgs = lua_gettop(L);
    DeviceInfoType type = DeviceInfoType.all;

    if (numArgs < 1 || numArgs > 2) {
        return luaError(L, "Args: query_device_info(n[, type])");
    }

    if (!lua_isinteger(L, -numArgs)) {
        return luaError(L, "query_device_info: Integer argument expected");
    }

    auto n = cast(uint) lua_tointeger(L, -numArgs);

    if (numArgs > 1) {
        if (!lua_isstring(L, -1) || !parseDeviceType(lua_tostring(L, -1).fromStringz, type)) {
            return luaError(L, invalidTypeInfoMessage);
        }
    }
    lua_pop(L, numArgs);

    if (!isInitialized) {
        return luaError(L, "query_device_info: Nvml not initialized");
    }

    if (n >= numDevices) {
        return luaError(L, "query_device_info: Device index out of range");
    }

    GpuInformation info;
    if (nvmlQueryDevice(n, &info)) {
        return luaError(L, "query_device_info: Failed to query device information");
    }

    lua_newtable(L);
    if (type == DeviceInfoType.all || type == DeviceInfoType.static_) {
        tableSet(L, -1, "name", info.name.ptr);
        tableSet(L, -1, "slowdownTempCelcius", info.slowdownTempCelcius);
        tableSet(L, -1, "shutdownTempCelcius", info.shutdownTempCelcius);
    }
    if (type == DeviceInfoType.all || type == DeviceInfoType.dynamic) {
        tableSet(L, -1, "fanSpeedPercent", info.fanSpeedPercent);
        tableSet(L, -1, "freq", info.freq);
        tableSet(L, -1, "memFreq", info.memFreq);
        tableSet(L, -1, "tempCelcius", info.tempCelcius);
    }

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

static bool runtimeIsInit = false;

void singletonRuntimeInit() {
    import core.runtime;
    import core.stdc.stdlib;

    if (runtimeIsInit) {
        return;
    }
    extern (C) void runtimeClose() {
        Runtime.terminate();
    }

    Runtime.initialize();
    runtimeIsInit = true;
    atexit(&runtimeClose);
}

extern (C) int luaopen_nvml(lua_State* L) {
    singletonRuntimeInit();
    luaL_newlibtable(L, funcTable.ptr);
    luaL_setfuncs(L, funcTable.ptr, 0);
    return 1;
}
