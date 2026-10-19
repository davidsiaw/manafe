FROM ruby:3.4-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential nodejs npm curl xz-utils \
 && rm -rf /var/lib/apt/lists/*

RUN npm install -g @objj/cappuccino@1.3.1

ENV PATH=/app/scripts:$PATH

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY tests/Gemfile tests/Gemfile.lock tests/
RUN BUNDLE_GEMFILE=/app/tests/Gemfile bundle install

COPY . .

EXPOSE 4444

CMD ["bundle", "exec", "chino"]
