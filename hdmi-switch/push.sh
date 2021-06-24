#!/bin/sh

scp -r $PWD/* pi@snips-projector-room.local:hdmi-switch-control
ssh pi@snips-projector-room.local "\
  sudo systemctl stop hdmi-switch-control && \
  cd ~/hdmi-switch-control && \
  bundle install && \
  sudo cp ~/hdmi-switch-control/hdmi-switch-control.service /lib/systemd/system/hdmi-switch-control.service && \
  sudo systemctl daemon-reload && \
  sudo systemctl enable hdmi-switch-control && \
  sudo systemctl start hdmi-switch-control \
"
