#include "CSMC.h"

#include <IOKit/IOKitLib.h>
#include <mach/mach.h>
#include <stdint.h>
#include <string.h>

#define KERNEL_INDEX_SMC      2
#define SMC_CMD_READ_KEY      5
#define SMC_CMD_READ_KEYINFO  9

typedef struct {
    uint8_t  major;
    uint8_t  minor;
    uint8_t  build;
    uint8_t  reserved;
    uint16_t release;
} SMCKeyData_vers_t;

typedef struct {
    uint16_t version;
    uint16_t length;
    uint32_t cpuPLimit;
    uint32_t gpuPLimit;
    uint32_t memPLimit;
} SMCKeyData_pLimitData_t;

typedef struct {
    uint32_t dataSize;
    uint32_t dataType;
    uint8_t  dataAttributes;
} SMCKeyData_keyInfo_t;

typedef uint8_t SMCBytes_t[32];

typedef struct {
    uint32_t                key;
    SMCKeyData_vers_t       vers;
    SMCKeyData_pLimitData_t pLimitData;
    SMCKeyData_keyInfo_t    keyInfo;
    uint8_t                 result;
    uint8_t                 status;
    uint8_t                 data8;
    uint32_t                data32;
    SMCBytes_t              bytes;
} SMCKeyData_t;

static io_connect_t g_conn = 0;
static bool         g_opened = false;

bool csmc_open(void) {
    if (g_opened) return true;
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!service) return false;
    kern_return_t r = IOServiceOpen(service, mach_task_self(), 0, &g_conn);
    IOObjectRelease(service);
    if (r != kIOReturnSuccess) {
        g_conn = 0;
        return false;
    }
    g_opened = true;
    return true;
}

void csmc_close(void) {
    if (g_opened) {
        IOServiceClose(g_conn);
        g_conn = 0;
        g_opened = false;
    }
}

static uint32_t to_key(const char *s) {
    return ((uint32_t)(uint8_t)s[0] << 24)
         | ((uint32_t)(uint8_t)s[1] << 16)
         | ((uint32_t)(uint8_t)s[2] <<  8)
         | ((uint32_t)(uint8_t)s[3]);
}

#define TYPE_FLT  0x666c7420u  /* 'flt ' */
#define TYPE_SP78 0x73703738u  /* 'sp78' */
#define TYPE_UI8  0x75693820u  /* 'ui8 ' */
#define TYPE_UI16 0x75693136u  /* 'ui16' */
#define TYPE_UI32 0x75693332u  /* 'ui32' */

bool csmc_read(const char *key, double *outValue) {
    if (!outValue) return false;
    if (!g_opened && !csmc_open()) return false;
    if (!key || strlen(key) != 4) return false;

    SMCKeyData_t input  = {0};
    SMCKeyData_t output = {0};
    size_t       outSz  = sizeof(SMCKeyData_t);

    input.key   = to_key(key);
    input.data8 = SMC_CMD_READ_KEYINFO;

    kern_return_t r = IOConnectCallStructMethod(g_conn, KERNEL_INDEX_SMC,
                                                &input, sizeof(input),
                                                &output, &outSz);
    if (r != kIOReturnSuccess) return false;

    input.keyInfo.dataSize = output.keyInfo.dataSize;
    input.keyInfo.dataType = output.keyInfo.dataType;
    input.data8            = SMC_CMD_READ_KEY;
    outSz                  = sizeof(SMCKeyData_t);

    r = IOConnectCallStructMethod(g_conn, KERNEL_INDEX_SMC,
                                  &input, sizeof(input),
                                  &output, &outSz);
    if (r != kIOReturnSuccess) return false;

    uint32_t type = output.keyInfo.dataType;
    const uint8_t *b = output.bytes;

    switch (type) {
        case TYPE_FLT: {
            float v;
            memcpy(&v, b, sizeof(float));
            *outValue = (double)v;
            return true;
        }
        case TYPE_SP78: {
            int16_t raw = (int16_t)(((uint16_t)b[0] << 8) | (uint16_t)b[1]);
            *outValue = (double)raw / 256.0;
            return true;
        }
        case TYPE_UI8: {
            *outValue = (double)b[0];
            return true;
        }
        case TYPE_UI16: {
            uint16_t v = ((uint16_t)b[0] << 8) | (uint16_t)b[1];
            *outValue = (double)v;
            return true;
        }
        case TYPE_UI32: {
            uint32_t v = ((uint32_t)b[0] << 24) | ((uint32_t)b[1] << 16)
                       | ((uint32_t)b[2] <<  8) | ((uint32_t)b[3]);
            *outValue = (double)v;
            return true;
        }
        default:
            return false;
    }
}
