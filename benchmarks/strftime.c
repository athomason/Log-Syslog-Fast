#include <stdio.h>
#include <sys/time.h>
#include <sys/types.h>
#include <time.h>

void bench(int count, const char* fmt) {
    struct timeval start, end;
    char buf[25];
    time_t t = time(0);
    const struct tm* x = localtime(&t);
    int i;

    gettimeofday(&start, 0);
    for (i = 0; i < count; i++) {
        strftime(buf, 25, fmt, x);
    }
    gettimeofday(&end, 0);

    double elapsed = end.tv_sec - start.tv_sec + (((double) end.tv_usec - start.tv_usec) / 1000000);
    printf("%s: %.6f (%.6f/s)\n", fmt, elapsed, count / elapsed);
}

int main(int argc, char** argv) {
    int count = 1000;
    if (argc > 1) {
        count = atoi(argv[1]);
    }
    bench(count, "%FT%T%z");
    bench(count, "%Y-%m-%dT%T%z");
    bench(count, "%FT%H:%M:%S%z");
    bench(count, "%Y-%m-%dT%H:%M:%S%z");

    bench(count, "%h %e %T");
    bench(count, "%h %e %H:%M:%S");
    return 0;
}
