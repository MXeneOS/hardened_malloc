#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <sys/mman.h>

/* Test helper, not part of the allocator: emulate a kernel without MADV_DONTNEED_LOCKED. */
int madvise(void *addr, size_t len, int advice) {
    static int (*real)(void *, size_t, int);
    if (advice == 24) {
        errno = EINVAL;
        return -1;
    }
    if (!real) {
        real = dlsym(RTLD_NEXT, "madvise");
    }
    return real(addr, len, advice);
}
