FROM alpine:latest

# Set WeeWX version to install (see http://weewx.com/downloads/)
ARG WEEWX=4.1.1

# Comma-separated list of plugins (URLs) to install
ARG INSTALL_PLUGINS="\
https://github.com/matthewwall/weewx-mqtt/archive/master.zip,\
https://github.com/makob/weewx-mqtt-input/releases/download/0.1/weewx-mqtt-input-0.1.tar.gz"

# Entrypoint helper and userdir
ENTRYPOINT ["/entrypoint.sh"]
WORKDIR /home/weewx
COPY entrypoint.sh /entrypoint.sh
RUN mkdir /var/user; \
    ln -s /home/weewx/.ssh /var/user/ssh; \
    chmod 755 /entrypoint.sh

# Install WeeWX dependencies
# ephem requires gcc so we use a virtual apk environment for that
RUN apk add --no-cache \
    	socat \
    	mysql-client \
	python3 \
    	py3-configobj \
	py3-cheetah \
	py3-pip \
	py3-mysqlclient \
	py3-pillow \
	py3-paho-mqtt &&\
    apk add --no-cache --virtual .build-deps build-base python3-dev &&\
    pip3 install ephem &&\
    apk del .build-deps

# Install WeeWX
ADD http://weewx.com/downloads/weewx-$WEEWX.tar.gz .
RUN tar xvzf weewx-$WEEWX.tar.gz && \
    cd weewx-$WEEWX && \
    python3 ./setup.py build &&\
    python3 ./setup.py install --no-prompt &&\
    cd .. &&\
    rm -rf weewx-$WEEWX weewx-$WEEWX.tar.gz

# Patch WeeWX logger to output to stdout
RUN sed -i 's/handlers = syslog/handlers = console/g' /home/weewx/bin/weeutil/logger.py

# Patch weewx.conf to use userdir for files that needs modifications
RUN sed -i 's/HTML_ROOT = public_html/HTML_ROOT = \/var\/user\/public_html/g' /home/weewx/weewx.conf
RUN sed -i 's/SQLITE_ROOT.*/SQLITE_ROOT = \/var\/user\/archive/g' /home/weewx/weewx.conf

# Install plugins
RUN if [ ! -z "${INSTALL_PLUGINS}" ]; then \
      OLDIFS=$IFS; \
      IFS=','; \
      for PLUGIN in ${INSTALL_PLUGINS}; do \
        IFS=$OLDIFS; \
	wget $PLUGIN &&\
	bin/wee_extension --install `basename $PLUGIN` ; \
	rm -f `basename $PLUGIN`; \
      done; \
    fi; \
    rm -f /home/weewx/weewx.conf.*
