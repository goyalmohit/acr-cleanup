FROM bash:latest

WORKDIR /app

# Instala as dependências necessárias
RUN apk --no-cache add curl openssh-client python3 py3-pip

# https://elliottback.medium.com/python-this-environment-is-externally-managed-error-and-docker-6062aac20a6e
# https://peps.python.org/pep-0668/
RUN rm /usr/lib/python*/EXTERNALLY-MANAGED

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