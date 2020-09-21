FROM golang

WORKDIR /home/nordvpn-mux
ADD . /home/nordvpn-mux

ENV OVPN_FILES_LOCATION /home/nordvpn-mux/ovpn_tcp

RUN apt-get update && \
	 apt-get install -y apt-utils libsqlite3-mod-spatialite unzip libnss3-tools && \
	 curl -L https://github.com/FiloSottile/mkcert/releases/download/v1.4.1/mkcert-v1.4.1-linux-amd64 -o mkcert && \
	 chmod +x mkcert && ./mkcert -install && ./mkcert localhost 127.0.0.1 ::1 && \
	 wget https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip && \
	 unzip ovpn.zip && rm ovpn.zip

RUN go build -i -o nordvpn-srv cmd/nordvpn-srv/main.go && \
	 mv nordvpn-srv /usr/local/bin/

EXPOSE 8080

ENTRYPOINT ["nordvpn-srv"]