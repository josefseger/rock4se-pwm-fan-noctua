FROM alpine:3.22

RUN apk add --no-cache mosquitto-clients

COPY run.sh /run.sh
COPY rock4se-pwmctl /usr/local/bin/rock4se-pwmctl

RUN sed -i 's/\r$//' /run.sh \
    && chmod 755 /run.sh \
    && chmod 755 /usr/local/bin/rock4se-pwmctl

CMD ["/bin/sh", "/run.sh"]
