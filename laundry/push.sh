#!/bin/sh

scp -r $PWD/* pi@laundry-view.local:laundry-view
ssh pi@laundry-view.local "\
  sudo systemctl stop laundry-view.service && \
  cd ~/laundry-view && \
  bundle install && \
  sudo cp ~/laundry-view/laundry-view.service /lib/systemd/system/laundry-view.service && \
  sudo systemctl daemon-reload && \
  sudo systemctl enable laundry-view.service && \
  sudo systemctl start laundry-view.service \
"
