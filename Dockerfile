FROM bash:latest

WORKDIR /app

# Instala as dependências necessárias
RUN apk --no-cache add curl openssh-client python3 py3-pip

# Instala a CLI do Azure
RUN apk --no-cache add --virtual .build-deps gcc libffi-dev musl-dev openssl-dev python3-dev \
    && pip3 install azure-cli \
    && apk del .build-deps

COPY ./acr-cleanup.sh .
# Verifica se o arquivo .env existe antes de copiá-lo
RUN if [ -f .env ]; then \
    cp .env /app/.env; \
    fi

CMD ["bash", "./acr-cleanup.sh"]
