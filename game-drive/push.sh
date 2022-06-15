#!/bin/sh

scp -r $PWD/* rock@game-drive.local:game-drive
ssh rock@game-drive.local "\
  sudo systemctl stop game-drive.service && \
  cd ~/game-drive && \
  sudo cp ~/game-drive/game-drive.service /lib/systemd/system/game-drive.service && \
  sudo systemctl daemon-reload && \
  sudo systemctl enable game-drive.service && \
  sudo systemctl start game-drive.service \
"
