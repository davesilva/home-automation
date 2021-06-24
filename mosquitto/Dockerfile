FROM alpine

MAINTAINER Dave Silva <docker@dmsilva.com>

EXPOSE 1883 9001

RUN apk --no-cache add mosquitto mosquitto-clients
RUN mkdir -p /mosquitto/config /mosquitto/data && chown -R mosquitto /mosquitto
ADD mosquitto.conf /mosquitto/config/mosquitto.conf

VOLUME [ "/mosquitto/config", "/mosquitto/data" ]

CMD [ "/usr/sbin/mosquitto", "-c", "/mosquitto/config/mosquitto.conf" ]
