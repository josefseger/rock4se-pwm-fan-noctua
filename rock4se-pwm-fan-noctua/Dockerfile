FROM alpine:3.22 AS builder

RUN apk add --no-cache gcc musl-dev binutils

COPY pwmctl.c /tmp/pwmctl.c

RUN gcc -O2 -Wall -Wextra -Werror \
        -o /rock4se-pwmctl /tmp/pwmctl.c \
    && strip /rock4se-pwmctl

FROM alpine:3.22

RUN apk add --no-cache mosquitto-clients python3 py3-libgpiod

COPY run.sh /run.sh
COPY --from=builder /rock4se-pwmctl /usr/local/bin/rock4se-pwmctl
COPY tachometer.py /usr/local/bin/tachometer.py

RUN sed -i 's/\r$//' /run.sh \
    && chmod 755 /run.sh \
    && chmod 755 /usr/local/bin/rock4se-pwmctl \
    && chmod 755 /usr/local/bin/tachometer.py

CMD ["/bin/sh", "/run.sh"]
