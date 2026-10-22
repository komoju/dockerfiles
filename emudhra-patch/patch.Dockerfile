ARG SOURCE_IMAGE
FROM ${SOURCE_IMAGE}

COPY patch.sh /tmp/emudhra-patch.sh
RUN sh /tmp/emudhra-patch.sh && rm /tmp/emudhra-patch.sh

# Node.js bundles its own root store, which still trusts the compromised chain
# on releases without an upstream fix.
ENV NODE_OPTIONS=--use-openssl-ca
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
