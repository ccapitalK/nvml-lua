# What is this

A simple lua wrapper for libnvidia-ml, that allows querying some basic information about
attached nvidia devices. I mostly wrote this so that my conky script would work on wayland.

## How to build

Dependencies:

- A working dlang toolchain (dmd, libphobos, dub)
- libnvidia-ml (should ship with your nvidia driver)
- nvml.h header (ships with cuda)
- lua 5.4

```
$ dub build
$ ls nvml.so # You can now run 'require("nvml") in lua'
```

## Using with conky

Install `libnvml.so` as `/usr/local/lib/lua/5.4/nvml.so`. This should be enough to be able for
nvml to be resolvable by lua when loading modules. For examples of using this module from lua,
look at lua-source/test.lua .
