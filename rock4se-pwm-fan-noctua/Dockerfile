FROM alpine:3.22

RUN apk add --no-cache mosquitto-clients python3 py3-libgpiod

COPY run.sh /run.sh
COPY rock4se-pwmctl /usr/local/bin/rock4se-pwmctl
COPY tachometer.py /usr/local/bin/tachometer.py

RUN sed -i 's/\r$//' /run.sh \
    && chmod 755 /run.sh \
    && chmod 755 /usr/local/bin/rock4se-pwmctl \
    && chmod 755 /usr/local/bin/tachometer.py

CMD ["/bin/sh", "/run.sh"]
