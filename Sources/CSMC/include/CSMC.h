#ifndef CSMC_H
#define CSMC_H

#include <stdbool.h>

bool csmc_open(void);
void csmc_close(void);
bool csmc_read(const char *key, double *outValue);

#endif
