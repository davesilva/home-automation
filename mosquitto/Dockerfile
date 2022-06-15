FROM alpine

LABEL Author="Dave Silva <docker@dmsilva.com>"
LABEL Description="Mosquitto MQTT broker"
LABEL Version="2.0.14"

EXPOSE 1883 9001

RUN apk --no-cache add mosquitto=2.0.14-r0 mosquitto-clients
RUN mkdir -p /mosquitto/config /mosquitto/data && chown -R mosquitto /mosquitto
ADD mosquitto.conf /mosquitto/config/mosquitto.conf

VOLUME [ "/mosquitto/config", "/mosquitto/data" ]

CMD ["/usr/sbin/mosquitto", "-c", "/mosquitto/config/mosquitto.conf"]
