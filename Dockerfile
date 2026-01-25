### Build Static Site
FROM docker.io/hugomods/hugo:reg-ci-0.145.0 AS builder
WORKDIR /src
COPY . .
ARG HUGO_BASEURL=/
RUN hugo --baseURL "${HUGO_BASEURL}" --gc --minify

### Serve with Caddy
FROM docker.io/caddy@sha256:7ed26c87abd76318b35677bef46457f9221113f7d9ab341104096862f182a3eb
COPY --from=builder /src/public /usr/share/caddy/
EXPOSE 8080
CMD ["caddy", "file-server", "--root", "/usr/share/caddy", "--listen", ":8080"]
