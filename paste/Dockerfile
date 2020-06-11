FROM alpine:3

RUN apk add --no-cache \
	perl \
	perl-io-socket-ssl \
	perl-app-cpanminus \
	perl-mojolicious \
	perl-text-csv \
	git

RUN git clone https://github.com/jhthorsen/app-mojopaste /app-mojopaste \
	&& git -C /app-mojopaste checkout 1.04

VOLUME /app/data

ENV MOJO_MODE production
ENV PASTE_DIR /app/data
ENV PASTE_ENABLE_CHARTS 0
EXPOSE 8080

USER nobody:nobody
ENTRYPOINT ["/usr/bin/perl", "/app-mojopaste/script/mojopaste", "prefork", "-l", "http://*:8080"]
