FROM debian:buster-slim


COPY bin/ /script/

RUN  apt-get update \
  && apt-get install jq curl -y \
  && chmod +x /script/*.sh \
  && chmod +x /script/plugins/*.sh


WORKDIR /script

CMD /script/map.sh
