FROM registry.cn-hangzhou.aliyuncs.com/devflow/alpine:3.22
COPY public /usr/share/caddy
EXPOSE 8080
CMD ["busybox", "httpd", "-f", "-p", "8080", "-h", "/usr/share/caddy"]
