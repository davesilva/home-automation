#!/bin/sh

scp -r . pi@tv-control.local:tv
ssh pi@tv-control.local "\
  sudo cp ~/tv/tv-control.service /lib/systemd/system/tv-control.service && \
  sudo systemctl daemon-reload && \
  sudo systemctl enable tv-control.service && \
  sudo systemctl start tv-control.service \
"
