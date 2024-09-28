import std.stdio;
import std.string;

import lua_bindings;
import nvml;

extern(C) int dump() {
    initNvml();
    return 1;
}

extern(C) int luaopen_nvml(lua_State *L) {
    return registerFunctions(L);
}
