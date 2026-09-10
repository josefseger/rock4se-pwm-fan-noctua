// ROCK 4 SE RK3399 PWM controller
//
// Controls PWM0 at 0xff420000 directly through /dev/mem.
// This implementation preserves the verified register layout, cold-start
// initialization, safety checks and readback behavior from the original
// controller. Non-zero fan speeds below 10% are refused; explicit 0% is
// allowed for controlled fan-off use.

#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>

#define PWM0_BASE 0xff420000UL
#define PWM_MAP_SIZE 0x1000UL

#define PWM_PERIOD_OFFSET 0x04U
#define PWM_DUTY_OFFSET 0x08U
#define PWM_CONTROL_OFFSET 0x0cU

#define PWM_PERIOD_TICKS 1931U
#define PWM_CONTROL_VALUE 0x13U
#define MIN_NONZERO_SPEED 10U

static inline void memory_barrier(void)
{
    __sync_synchronize();
}

static inline volatile uint32_t *reg32(void *base, unsigned int offset)
{
    return (volatile uint32_t *)((volatile unsigned char *)base + offset);
}

static int cleanup_and_return(void *map, int fd, int status)
{
    if (map != MAP_FAILED) {
        (void)munmap(map, PWM_MAP_SIZE);
    }
    if (fd >= 0) {
        (void)close(fd);
    }
    return status;
}

int main(int argc, char **argv)
{
    char *end = NULL;
    unsigned long parsed_speed;
    unsigned int speed;
    int fd = -1;
    void *map = MAP_FAILED;
    volatile uint32_t *period_reg;
    volatile uint32_t *duty_reg;
    volatile uint32_t *control_reg;
    uint32_t period;
    uint32_t control;
    uint32_t old_duty;
    uint32_t duty;
    uint32_t readback;
    int initialized = 0;

    if (argc != 2) {
        fprintf(stderr, "Usage: %s SPEED_PERCENT\n", argv[0]);
        return 1;
    }

    errno = 0;
    parsed_speed = strtoul(argv[1], &end, 10);
    if (errno != 0 || end == argv[1] || *end != '\0' || parsed_speed > 100UL) {
        fprintf(stderr, "Invalid speed: %s\n", argv[1]);
        return 1;
    }

    speed = (unsigned int)parsed_speed;

    if (speed != 0U && speed < MIN_NONZERO_SPEED) {
        fprintf(stderr, "Refusing speed below 10%% except explicit 0%%.\n");
        return 1;
    }

    fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) {
        perror("open /dev/mem");
        return 1;
    }

    map = mmap(NULL, PWM_MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED,
               fd, (off_t)PWM0_BASE);
    if (map == MAP_FAILED) {
        perror("mmap");
        (void)close(fd);
        return 1;
    }

    period_reg = reg32(map, PWM_PERIOD_OFFSET);
    duty_reg = reg32(map, PWM_DUTY_OFFSET);
    control_reg = reg32(map, PWM_CONTROL_OFFSET);

    period = *period_reg;
    control = *control_reg;
    old_duty = *duty_reg;

    if ((period | control) == 0U) {
        /*
         * Verified cold-start sequence. Disable PWM first, then program the
         * period and fail-safe 100% fan duty, and finally enable the exact
         * control mode used by the working RK3399 configuration.
         */
        *control_reg = 0U;
        memory_barrier();

        *period_reg = PWM_PERIOD_TICKS;
        memory_barrier();

        *duty_reg = 0U;
        memory_barrier();

        *control_reg = PWM_CONTROL_VALUE;
        memory_barrier();

        period = *period_reg;
        control = *control_reg;

        if (period != PWM_PERIOD_TICKS || control != PWM_CONTROL_VALUE) {
            fprintf(stderr,
                    "Cold-start initialization failed: period=0x%08X control=0x%08X\n",
                    period, control);
            return cleanup_and_return(map, fd, 1);
        }

        initialized = 1;
    } else if (period != PWM_PERIOD_TICKS || control != PWM_CONTROL_VALUE) {
        /*
         * Do not write to an unexpectedly configured PWM block. This protects
         * against controlling the wrong peripheral or clobbering another
         * configuration.
         */
        fprintf(stderr,
                "Safety check failed: period=0x%08X control=0x%08X. No write performed.\n",
                period, control);
        return cleanup_and_return(map, fd, 1);
    }

    /*
     * The verified ROCK 4 SE / Noctua configuration uses inverted PWM
     * polarity (control 0x13), so register duty is the complement of the
     * requested fan-speed percentage. Add 50 before /100 for nearest-integer
     * rounding, matching the original controller.
     */
    duty = (uint32_t)((((uint64_t)(100U - speed) * PWM_PERIOD_TICKS) + 50U) /
                      100U);

    *duty_reg = duty;
    memory_barrier();

    readback = *duty_reg;
    if (readback != duty) {
        fprintf(stderr,
                "Readback mismatch: requested=%u readback=%u\n",
                duty, readback);
        return cleanup_and_return(map, fd, 1);
    }

    printf("initialized=%d speed=%u period=%u old_duty=%u duty=%u\n",
           initialized, speed, PWM_PERIOD_TICKS, old_duty, duty);

    return cleanup_and_return(map, fd, 0);
}
