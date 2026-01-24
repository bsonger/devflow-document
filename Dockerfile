### Build Static Site
FROM docker.io/hugomods/hugo:reg-ci-0.145.0 AS builder
WORKDIR /src
COPY . .
ARG HUGO_BASEURL=/
RUN hugo --baseURL "${HUGO_BASEURL}" --gc --minify

### Serve with Caddy
FROM docker.io/caddy:2-alpine
COPY --from=builder /src/public /usr/share/caddy/
EXPOSE 8080
CMD ["caddy", "file-server", "--root", "/usr/share/caddy", "--listen", ":8080"]
