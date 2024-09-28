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

    printf("Have counted %d devices\n", numDevices);
    isInitialized = 1;

    return 0;

Error:
    result = nvmlShutdown();
    if (NVML_SUCCESS != result) {
        fprintf(stderr, "Failed to shutdown NVML: %s\n", nvmlErrorString(result));
    }
    return 1;
}

int nvmlNumDevices() { return numDevices; }

int nvmlQueryDevice(int index, struct GpuInformation *info) {
    if (index >= numDevices) {
        return 1;
    }
    nvmlReturn_t result;
    nvmlDevice_t device;

    result = nvmlDeviceGetHandleByIndex(index, &device);
    if (result != NVML_SUCCESS) {
        fprintf(stderr, "Failed to get device handle: %s\n", nvmlErrorString(result));
        return 1;
    }

    result = nvmlDeviceGetName(device, info->name, NVML_DEVICE_NAME_BUFFER_SIZE);
    if (result != NVML_SUCCESS) {
        fprintf(stderr, "Failed to get device name: %s\n", nvmlErrorString(result));
        return 1;
    }

    result = nvmlDeviceGetFanSpeed(device, &(info->fanSpeedPercent));
    if (result != NVML_SUCCESS) {
        fprintf(stderr, "Failed to get device fan speed percent: %s\n", nvmlErrorString(result));
        return 1;
    }

    result = nvmlDeviceGetTemperature(device, NVML_TEMPERATURE_GPU, &(info->tempCelcius));
    if (result != NVML_SUCCESS) {
        fprintf(stderr, "Failed to get device temperature: %s\n", nvmlErrorString(result));
        return 1;
    }

    result =
        nvmlDeviceGetTemperatureThreshold(device, NVML_TEMPERATURE_THRESHOLD_SLOWDOWN, &(info->slowdownTempCelcius));
    if (result != NVML_SUCCESS) {
        fprintf(stderr, "Failed to get device slowdown threshold: %s\n", nvmlErrorString(result));
        return 1;
    }

    result =
        nvmlDeviceGetTemperatureThreshold(device, NVML_TEMPERATURE_THRESHOLD_SHUTDOWN, &(info->shutdownTempCelcius));
    if (result != NVML_SUCCESS) {
        fprintf(stderr, "Failed to get device shutdown threshold: %s\n", nvmlErrorString(result));
        return 1;
    }

    result = nvmlDeviceGetClockInfo(device, NVML_CLOCK_GRAPHICS, &(info->freq));
    if (result != NVML_SUCCESS) {
        fprintf(stderr, "Failed to get graphics clock frequency: %s\n", nvmlErrorString(result));
        return 1;
    }

    result = nvmlDeviceGetClockInfo(device, NVML_CLOCK_MEM, &(info->memFreq));
    if (result != NVML_SUCCESS) {
        fprintf(stderr, "Failed to get memory clock frequency: %s\n", nvmlErrorString(result));
        return 1;
    }

    return 0;
}

int closeNvml(void) {
    nvmlReturn_t result = nvmlShutdown();
    isInitialized = 0;
    if (NVML_SUCCESS != result) {
        fprintf(stderr, "Failed to shutdown NVML: %s\n", nvmlErrorString(result));
        return 1;
    }
    printf("Successfully closed handle\n");

    return 0;
}
