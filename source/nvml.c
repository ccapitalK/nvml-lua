#include <nvml.h>
#include <stdio.h>

int initNvml(void) {
    unsigned int device_count, i;
    nvmlReturn_t result = nvmlInit();
    if (result != NVML_SUCCESS) {
        fprintf(stderr, "Failed to initialize nvml: %s\n", nvmlErrorString(result));
        return 1;
    }

    result = nvmlDeviceGetCount(&device_count);
    if (result != NVML_SUCCESS) {
        fprintf(stderr, "Failed to get device count: %s\n", nvmlErrorString(result));
        goto Error;
    }

    printf("Have counted %d devices\n", device_count);

Error:
    result = nvmlShutdown();
    if (NVML_SUCCESS != result)
        printf("Failed to shutdown NVML: %s\n", nvmlErrorString(result));

    return 1;
}
/*
#include <stdio.h>
#include <nvml.h>
#include <stdlib.h>

int main(void)
{
    nvmlReturn_t result;
    unsigned int device_count, i;

    // First initialize NVML library
    result = nvmlInit();
    if (NVML_SUCCESS != result)
    {
        printf("Failed to initialize NVML: %s\n", nvmlErrorString(result));
        return 1;
    }

    result = nvmlDeviceGetCount(&device_count);
    if (NVML_SUCCESS != result)
    {
        printf("Failed to query device count: %s\n", nvmlErrorString(result));
        goto Error;
    }

    printf("Found %u device%s\n", device_count, device_count != 1 ? "s" : "");
    printf("Listing devices:\n");

    for (i = 0; i < device_count; i++)
    {
        nvmlDevice_t    device;
        char            name[NVML_DEVICE_NAME_BUFFER_SIZE];
        nvmlPciInfo_t   pci;

        // Query for device handle to perform operations on a device
        // You can also query device handle by other features like:
        // nvmlDeviceGetHandleBySerial
        // nvmlDeviceGetHandleByPciBusId
        result = nvmlDeviceGetHandleByIndex(i, &device);
        if (NVML_SUCCESS != result)
        {
            printf("Failed to get handle for device %u: %s\n", i, nvmlErrorString(result));
            goto Error;
        }

        result = nvmlDeviceGetName(device, name, NVML_DEVICE_NAME_BUFFER_SIZE);
        if (NVML_SUCCESS != result)
        {
            printf("Failed to get name of device %u: %s\n", i, nvmlErrorString(result));
            goto Error;
        }

        // pci.busId is very useful to know which device physically you're talking to
        // Using PCI identifier you can also match nvmlDevice handle to CUDA device.
        result = nvmlDeviceGetPciInfo(device, &pci);
        if (NVML_SUCCESS != result)
        {
            printf("Failed to get pci info for device %u: %s\n", i, nvmlErrorString(result));
            goto Error;
        }

        printf("%u. %s [%s]\n", i, name, pci.busId);

        // This is an example to get the supported vGPUs type names
        unsigned int            vgpuCount = 0;
        nvmlVgpuTypeId_t        *vgpuTypeIds = NULL;
        unsigned int            j;

        result = nvmlDeviceGetSupportedVgpus(device, &vgpuCount, NULL);
        if (NVML_ERROR_INSUFFICIENT_SIZE != result)
            goto Error;

        if (vgpuCount != 0)
        {
            vgpuTypeIds = malloc(sizeof(nvmlVgpuTypeId_t) * vgpuCount);
            if (!vgpuTypeIds)
            {
                printf("Memory allocation of %d bytes failed \n", (int)(sizeof(*vgpuTypeIds)*vgpuCount));
                goto Error;
            }

            result = nvmlDeviceGetSupportedVgpus(device, &vgpuCount, vgpuTypeIds);
            if (NVML_SUCCESS != result)
            {
                printf("Failed to get the supported vGPUs with status %d \n", (int)result);
                goto Error;
            }

            printf("  Displaying vGPU type names: \n");
            for (j = 0; j < vgpuCount; j++)
            {
                char vgpuTypeName[NVML_DEVICE_NAME_BUFFER_SIZE];
                unsigned int bufferSize = NVML_DEVICE_NAME_BUFFER_SIZE;

                if (NVML_SUCCESS == (result = nvmlVgpuTypeGetName(vgpuTypeIds[j], vgpuTypeName, &bufferSize)))
                {
                    printf("  %s\n",vgpuTypeName);
                }
                else
                {
                    printf("Failed to query the vGPU type name with status %d \n", (int)result);
                }
            }
        }
        if (vgpuTypeIds)
            free(vgpuTypeIds);
    }

    result = nvmlShutdown();
    if (NVML_SUCCESS != result)
        printf("Failed to shutdown NVML: %s\n", nvmlErrorString(result));

    printf("All done.\n");
    return 0;

Error:
    result = nvmlShutdown();
    if (NVML_SUCCESS != result)
        printf("Failed to shutdown NVML: %s\n", nvmlErrorString(result));

    return 1;
}
*/
