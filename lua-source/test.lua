local nvml = require('nvml')

local success, result = pcall(nvml.numDevices)
assert(not success)
print("Error message on uninit query deviceCount: " .. result)

assert(not nvml.is_initialized())
nvml.init()
assert(nvml.is_initialized(3))
assert(nvml.is_initialized(1, 2, 3))

local success, result = pcall(nvml.init)
assert(not success)
print("Error returned on double startup: " .. result)

local n = nvml.num_devices()
print("Num devices: " .. tostring(n))
local n2 = nvml.num_devices()
assert(n == n2)

function printInfo(i, data)
    print('Response ' .. tostring(i) .. ': ' .. tostring(data))
    for k, v in pairs(data) do
        print(k .. ': ' .. tostring(v))
    end
end

types = {'all', 'static', 'dynamic'}
for i = 0, n-1 do
    for j = 1, 3 do
        local type = types[j]
        local data = nvml.query_device_info(i, type)
        printInfo(i, data)
    end
end

local success, result = pcall(nvml.query_device_info)
assert(not success)
print("Error returned 0 params: " .. result)

local success, result = pcall(nvml.query_device_info, 1, 2, 3)
assert(not success)
print("Error returned 3 params: " .. result)

local success, result = pcall(nvml.query_device_info, 0, 'foo')
assert(not success)
print("Error returned on invalid type: " .. result)
local success, result = pcall(nvml.query_device_info, 'static')
assert(not success)
print("Error returned on invalid index: " .. result)

local success, result = pcall(nvml.close)
assert(success)
assert(not nvml.is_initialized())
local success, result = pcall(nvml.close)
assert(not success)
