#include "lua.h"

int dump(lua_State *L);

int hello(lua_State *L) {
    lua_pushstring(L, "Hello");
    return 1;
}

int registerFunctions(lua_State *L) {
    lua_register(L, "hello", hello);
    lua_register(L, "dump", dump);
    return 1;
}
