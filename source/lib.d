import std.array;
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
    if (!isInitialized) {
        return luaError(L, "Tried to query num devices on uninitialized nvml handle");
    }
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

bool includeStatic(DeviceInfoType type) =>  type == DeviceInfoType.all || type == DeviceInfoType.static_;
bool includeDynamic(DeviceInfoType type) =>  type == DeviceInfoType.all || type == DeviceInfoType.dynamic;

static const(char)* invalidTypeInfoMessage() {
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

class QueryError : Throwable {
    this(string errormsg, nvmlReturn_t result) {
        Appender!string builder;
        builder.put(errormsg);
        builder.put(": ");
        builder.put(nvmlErrorString(result).fromStringz);
        super(builder.data());
    }
}

void queryDeviceInner(int index, GpuInformation *info, DeviceInfoType type) {
    nvmlReturn_t result;
    nvmlDevice_t device;

    void checkParam(string paramName)(nvmlReturn_t result) {
        if (result != NVML_SUCCESS) {
            throw new QueryError("Failed to get device " ~ paramName, result);
        }
    }

    result = getHandleByIndex(index, &device);
    if (result != NVML_SUCCESS) {
        throw new QueryError("Failed to get device handle", result);
    }

    if (type.includeStatic) {
        result = nvmlDeviceGetName(device, info.name.ptr, NVML_DEVICE_NAME_BUFFER_SIZE);
        checkParam!"name"(result);

        result =
            nvmlDeviceGetTemperatureThreshold(device, NVML_TEMPERATURE_THRESHOLD_SLOWDOWN, &info.slowdownTempCelcius);
        checkParam!"slowdown threshold"(result);

        result =
            nvmlDeviceGetTemperatureThreshold(device, NVML_TEMPERATURE_THRESHOLD_SHUTDOWN, &info.shutdownTempCelcius);
        checkParam!"shutdown threshold"(result);
    }

    if (type.includeDynamic) {
        result = nvmlDeviceGetFanSpeed(device, &info.fanSpeedPercent);
        checkParam!"fan speed percent"(result);

        result = nvmlDeviceGetTemperature(device, NVML_TEMPERATURE_GPU, &info.tempCelcius);
        checkParam!"temperature"(result);

        result = nvmlDeviceGetClockInfo(device, NVML_CLOCK_GRAPHICS, &info.freq);
        checkParam!"graphics clock frequency"(result);

        result = nvmlDeviceGetClockInfo(device, NVML_CLOCK_MEM, &info.memFreq);
        checkParam!"memory clock frequency"(result);
    }
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

    auto index = cast(uint) lua_tointeger(L, -numArgs);

    if (numArgs > 1) {
        if (!lua_isstring(L, -1) || !parseDeviceType(lua_tostring(L, -1).fromStringz, type)) {
            return luaError(L, invalidTypeInfoMessage);
        }
    }
    lua_pop(L, numArgs);

    if (!isInitialized) {
        return luaError(L, "query_device_info: Nvml not initialized");
    }

    if (index >= numDevices) {
        return luaError(L, "query_device_info: Device index out of range");
    }

    GpuInformation info;
    try {
        queryDeviceInner(index, &info, type);
    } catch (QueryError e) {
        return luaError(L, ("query_device_info: " ~ e.msg).toStringz);
    }

    lua_newtable(L);
    if (type.includeStatic()) {
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
