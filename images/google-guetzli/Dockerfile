FROM alpine:latest
LABEL MAINTAINER "Jordan Moore <crikket.007@gmail.com>"

ENV GUETZLI_VERSION=v1.0.1 \
  APPDIR=/usr/src/guetzli

RUN buildDeps=' \
      openssl \
      g++ \
      make \
      libpng-dev \
 	' \
  && apk --no-cache add $buildDeps \
  && mkdir -p ${APPDIR} \
  && wget -qO- http://github.com/google/guetzli/archive/${GUETZLI_VERSION}.tar.gz | tar xz -C ${APPDIR} --strip-components=1 \
  && cd ${APPDIR} && make \
  && apk del $buildDeps \
  && mv ${APPDIR}/bin/Release/guetzli /usr/local/bin/guetzli && rm -rf ${APPDIR}

RUN apk --no-cache add \
  libpng libstdc++ libgcc

WORKDIR /workdir

ENTRYPOINT ["/usr/local/bin/guetzli"]
