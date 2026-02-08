### Build Static Site
FROM ghcr.io/gohugoio/hugo:v0.147.6 AS builder
WORKDIR /src
COPY --chown=hugo:hugo . .
ARG HUGO_BASEURL=/
RUN hugo --baseURL "${HUGO_BASEURL}" --gc --minify

### Serve with Caddy
FROM docker.io/caddy:2.10.2-alpine
COPY --from=builder /src/public /usr/share/caddy/
USER caddy
EXPOSE 8080
CMD ["caddy", "file-server", "--root", "/usr/share/caddy", "--listen", ":8080"]
