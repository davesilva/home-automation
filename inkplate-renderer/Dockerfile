FROM ruby:3.1.1-slim-bullseye
LABEL maintainer="Dave Silva <docker@dmsilva.com>"

RUN groupadd --gid 99 app_user \
&& useradd --gid 99 --uid 99 --system app_user
RUN mkdir -p /usr/app /home/app_user && chown app_user /usr/app /home/app_user
WORKDIR /usr/app

RUN apt update && apt install build-essential -y
USER app_user

COPY --chown=app_user Gemfile .
COPY --chown=app_user Gemfile.lock .

RUN bundle install

COPY --chown=app_user . .

CMD [ "ruby", "main.rb" ]
