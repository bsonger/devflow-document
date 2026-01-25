### Build Static Site
FROM docker.io/hugomods/hugo:reg-ci-0.145.0 AS builder
WORKDIR /src
COPY . .
ARG HUGO_BASEURL=/
RUN hugo --baseURL "${HUGO_BASEURL}" --gc --minify

### Serve with Caddy
FROM docker.io/caddy@sha256:f2b257f20955d6be2229bed86bad24193eeb8c4dc962a4031a6eb42344ffa457
COPY --from=builder /src/public /usr/share/caddy/
EXPOSE 8080
CMD ["caddy", "file-server", "--root", "/usr/share/caddy", "--listen", ":8080"]
