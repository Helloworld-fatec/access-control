FROM eclipse-mosquitto:2.0

RUN apk add --no-cache openssl
COPY mosquitto.conf /mosquitto/config/mosquitto.conf
COPY start.sh /usr/local/bin/start-broker
RUN sed -i 's/\r$//' /usr/local/bin/start-broker
ENTRYPOINT ["/bin/sh", "/usr/local/bin/start-broker"]
