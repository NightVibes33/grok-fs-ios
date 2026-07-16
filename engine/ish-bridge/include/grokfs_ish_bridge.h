#ifndef GROKFS_ISH_BRIDGE_H
#define GROKFS_ISH_BRIDGE_H

#include <stdint.h>

typedef struct {
    int32_t exit_code;
    uint8_t *bytes;
    uintptr_t length;
} GrokFSIshResult;

int32_t grokfs_ish_bootstrap(const char *archive_path, const char *support_path);
GrokFSIshResult grokfs_ish_run(const char *command, const char *cwd, uint64_t timeout_ms);
void grokfs_ish_result_free(uint8_t *bytes, uintptr_t length);

#endif
