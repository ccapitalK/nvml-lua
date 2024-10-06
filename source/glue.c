#include "lua.h"
#include "lauxlib.h"
#include <nvml.h>
#include <stdio.h>

struct GpuInformation {
    char name[NVML_DEVICE_NAME_BUFFER_SIZE];
    unsigned int fanSpeedPercent;
    unsigned int freq;
    unsigned int memFreq;
    unsigned int tempCelcius;
    unsigned int slowdownTempCelcius;
    unsigned int shutdownTempCelcius;
};

static int isInitialized = 0;
static unsigned int numDevices;

int initNvml(void) {
    nvmlReturn_t result = nvmlInit();
    if (result != NVML_SUCCESS) {
        fprintf(stderr, "Failed to initialize nvml: %s\n", nvmlErrorString(result));
        return 1;
    }

    result = nvmlDeviceGetCount(&numDevices);
    if (result != NVML_SUCCESS) {
        fprintf(stderr, "Failed to get device count: %s\n", nvmlErrorString(result));
        goto Error;
    }

    isInitialized = 1;
    return 0;

Error:
    result = nvmlShutdown();
    if (NVML_SUCCESS != result) {
        fprintf(stderr, "Failed to shutdown NVML: %s\n", nvmlErrorString(result));
    }
    return 1;
}

// FIXME(ccapitalK): This only exists because importC doesn't forward this #define
nvmlReturn_t getHandleByIndex(int index, nvmlDevice_t *device) {
    return nvmlDeviceGetHandleByIndex(index, device);
}
