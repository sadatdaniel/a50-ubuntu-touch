/* Reproduce an old kernel's ENOSYS in this test process only. */
#include <errno.h>
#include <seccomp.h>
#include <unistd.h>

int main(int argc, char **argv)
{
    if (argc < 2) return 2;
    scmp_filter_ctx filter = seccomp_init(SCMP_ACT_ALLOW);
    if (!filter) return 3;
    if (seccomp_rule_add(filter, SCMP_ACT_ERRNO(ENOSYS), SCMP_SYS(openat2), 0) < 0
        || seccomp_load(filter) < 0) return 4;
    seccomp_release(filter);
    execvp(argv[1], argv + 1);
    return 5;
}
