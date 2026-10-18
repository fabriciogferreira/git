#define _GNU_SOURCE
#include <dirent.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

/* virtio's render node returns EPERM for DRM_IOCTL_MODE_CREATE_DUMB.
   hyprtoolkit opens the node the compositor advertises and dies in GBM.
   The matching primary node accepts the ioctl. */

static int open_real(const char *path, int flags, mode_t mode, int creat) {
    static int (*real_open)(const char *, int, ...) = 0;

    if (!real_open)
        real_open = dlsym(RTLD_NEXT, "open");
    if (creat)
        return real_open(path, flags, mode);
    return real_open(path, flags);
}

static const char *primary_for_render(const char *path) {
    static char card[512];
    const char *base;
    DIR *dir;
    struct dirent *ent;

    base = strrchr(path, '/');
    if (!base || strncmp(base + 1, "renderD", 7) != 0)
        return path;
    base++;

    dir = opendir("/dev/dri/by-path");
    if (!dir)
        return path;

    while ((ent = readdir(dir)) != 0) {
        char linkpath[512];
        char target[256];
        char name[256];
        char *suffix;
        ssize_t n;

        suffix = strstr(ent->d_name, "-render");
        if (!suffix || strcmp(suffix, "-render") != 0)
            continue;

        snprintf(linkpath, sizeof linkpath, "/dev/dri/by-path/%s", ent->d_name);
        n = readlink(linkpath, target, sizeof target - 1);
        if (n < 0)
            continue;
        target[n] = 0;
        if (!strstr(target, base))
            continue;

        snprintf(name, sizeof name, "%.*s-card", (int)(suffix - ent->d_name), ent->d_name);
        snprintf(card, sizeof card, "/dev/dri/by-path/%s", name);
        closedir(dir);
        return card;
    }

    closedir(dir);
    return path;
}

int open(const char *path, int flags, ...) {
    mode_t mode = 0;

    if (flags & O_CREAT) {
        va_list ap;
        va_start(ap, flags);
        mode = (mode_t)va_arg(ap, int);
        va_end(ap);
    }

    path = primary_for_render(path);
    return open_real(path, flags, mode, flags & O_CREAT);
}

int open64(const char *path, int flags, ...) {
    mode_t mode = 0;

    if (flags & O_CREAT) {
        va_list ap;
        va_start(ap, flags);
        mode = (mode_t)va_arg(ap, int);
        va_end(ap);
    }

    path = primary_for_render(path);
    return open_real(path, flags, mode, flags & O_CREAT);
}

int openat(int dirfd, const char *path, int flags, ...) {
    static int (*real_openat)(int, const char *, int, ...) = 0;
    mode_t mode = 0;

    if (!real_openat)
        real_openat = dlsym(RTLD_NEXT, "openat");
    if (flags & O_CREAT) {
        va_list ap;
        va_start(ap, flags);
        mode = (mode_t)va_arg(ap, int);
        va_end(ap);
    }

    if (path && path[0] == '/')
        path = primary_for_render(path);
    if (flags & O_CREAT)
        return real_openat(dirfd, path, flags, mode);
    return real_openat(dirfd, path, flags);
}
