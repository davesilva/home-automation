#!/bin/sh

scp -r $PWD/* pi@volume-control.local:volume-control
ssh pi@volume-control.local "\
  sudo systemctl stop volume-control.service && \
  cd ~/volume-control && \
  bundle install && \
  sudo cp ~/volume-control/volume-control.service /lib/systemd/system/volume-control.service && \
  sudo systemctl daemon-reload && \
  sudo systemctl enable volume-control.service && \
  sudo systemctl start volume-control.service \
"
