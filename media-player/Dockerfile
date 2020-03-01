FROM node:12.12.0-slim

RUN groupadd --gid 99 app_user \
&& useradd --gid 99 --uid 99 --system app_user
RUN mkdir -p /usr/app /home/app_user && chown app_user /usr/app /home/app_user
WORKDIR /usr/app

USER app_user

COPY --chown=app_user package.json .
COPY --chown=app_user package-lock.json .

RUN npm install

COPY --chown=app_user . .

CMD [ "node", "index.js" ]
