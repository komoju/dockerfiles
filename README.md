Dockerfiles
-----------

This repository is used to automate building and stashing specific versions of dependencies that our applications rely on. This prevents sudden changes such as

- changes of the base image from bookworm to buster
- supply chain vulnerabilities

that create unexpected breakages in our applications.

# rails-base

rails-base contains common dependencies that our applications use. You can use `public.ecr.aws/degica/rails-base:<version>` to build your rails application.

## Older base images

Here is a list of base images with older versions of Ruby:

```
public.ecr.aws/degica/rails-base:3.1.4
public.ecr.aws/degica/rails-base:3.2.1
public.ecr.aws/degica/rails-base:3.2.2
public.ecr.aws/degica/rails-base:3.2.3
public.ecr.aws/degica/rails-base:3.2.4
public.ecr.aws/degica/rails-base:3.2.6
public.ecr.aws/degica/rails-base:3.3.1
public.ecr.aws/degica/rails-base:3.3.7
public.ecr.aws/degica/rails-base:3.4.0
public.ecr.aws/degica/rails-base:3.4.1
public.ecr.aws/degica/rails-base:3.4.2
```


# rails-buildpack

rails-buildpack image includes common dependencies required to build a rails application.
You can use `rails-buildpack` for your CI or builder of a multi-stage build.

## Older buildpacks

Here is a list of buildpacks with older versions of Ruby:

```
public.ecr.aws/degica/rails-buildpack:2.7
public.ecr.aws/degica/rails-buildpack:2.7.3
public.ecr.aws/degica/rails-buildpack:2.7.5
public.ecr.aws/degica/rails-buildpack:2.7.7
public.ecr.aws/degica/rails-buildpack:3.0
public.ecr.aws/degica/rails-buildpack:3.1
public.ecr.aws/degica/rails-buildpack:3.1.4
public.ecr.aws/degica/rails-buildpack:3.2.1
public.ecr.aws/degica/rails-buildpack:3.2.2
public.ecr.aws/degica/rails-buildpack:3.2.3
public.ecr.aws/degica/rails-buildpack:3.2.4
public.ecr.aws/degica/rails-buildpack:3.2.6
public.ecr.aws/degica/rails-buildpack:3.2.8
public.ecr.aws/degica/rails-buildpack:3.3.0
public.ecr.aws/degica/rails-buildpack:3.3.1
public.ecr.aws/degica/rails-buildpack:3.4.0
public.ecr.aws/degica/rails-buildpack:3.4.1
public.ecr.aws/degica/rails-buildpack:3.4.2
```

Additional older buildpacks can be found at https://gallery.ecr.aws/degica/rails-buildpack

# Multi-stage example build

```
FROM degica/rails-buildpack:3.4.2 AS builder

COPY Gemfile $APP_HOME/
COPY Gemfile.lock $APP_HOME/
RUN bundle install --without development test

ADD package.json $APP_HOME/
ADD yarn.lock $APP_HOME/
RUN yarn

ADD . $APP_HOME

RUN bundle exec rake assets:precompile RAILS_ENV=production


FROM degica/rails-base:3.4.2

ENV APP_HOME=/app

RUN useradd --user-group app
RUN mkdir -p $APP_HOME && chown -R app:app $APP_HOME
WORKDIR $APP_HOME

COPY --from=builder /usr/local/bundle /usr/local/bundle
ADD --chown=app:app . $APP_HOME
COPY --from=builder --chown=app:app public/assets public/assets

USER app
```
