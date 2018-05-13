FROM ruby:2.5.1-slim-stretch
MAINTAINER Dave Silva <docker@dmsilva.com>

RUN adduser --system app
RUN mkdir -p /usr/app && chown app /usr/app
WORKDIR /usr/app

USER app

ADD Gemfile .
ADD Gemfile.lock .

RUN bundle install

ADD main.rb .

CMD [ "ruby", "main.rb" ]
