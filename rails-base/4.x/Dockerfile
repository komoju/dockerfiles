ARG RUBY_TAG=latest
FROM public.ecr.aws/docker/library/ruby:${RUBY_TAG}

ENV APP_HOME=/app
ENV PATH=$APP_HOME/bin:$PATH

RUN useradd --user-group --create-home app
RUN mkdir -p $APP_HOME && chown -R app:app $APP_HOME
WORKDIR $APP_HOME

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      curl \
      file \
      git \
      fonts-ipafont-gothic \
      fonts-unfonts-core \
      imagemagick \
      librsvg2-bin \
      wkhtmltopdf \
      xvfb \
      xauth \
      default-libmysqlclient-dev \
      libxslt1.1 \
      libxml2 \
 && curl -sL https://deb.nodesource.com/setup_lts.x | bash - \
 && apt-get update \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/*

# Setup wkhtmltopdf
RUN echo '#!/bin/bash\nxvfb-run -a --server-args="-screen 0, 1024x768x24" /usr/bin/wkhtmltopdf --enable-local-file-access -q $*' > /usr/bin/wkhtmltopdf.sh && \
    chmod a+x /usr/bin/wkhtmltopdf.sh && \
    ln -s /usr/bin/wkhtmltopdf.sh /usr/local/bin/wkhtmltopdf
