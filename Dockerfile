FROM debian:buster-slim


COPY bin/ /script/
COPY front/ /var/www/html/

RUN  apt-get update \
  && apt-get install jq curl nginx -y \
  && service nginx start


WORKDIR /script

CMD /script/map.sh && nginx -g 'daemon off;'
