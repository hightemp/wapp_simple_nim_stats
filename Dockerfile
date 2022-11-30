FROM nginx:alpine

RUN apk add --update --no-cache supervisor ffmpeg && \
    mkdir /etc/supervisor.d

COPY ./counter.supervisor.conf /etc/supervisor.d/counter.supervisor.ini
RUN rm /etc/nginx/conf.d/default.conf
COPY ./docker/nginx/hosts/default.conf /etc/nginx/conf.d/default.conf

COPY run-server /usr/local/bin

VOLUME ["/var/www/app"]

# RUN chmod -R a+w /var/log/nginx/
# RUN chmod -R a+w /var/

EXPOSE 80 443

# USER nginx

CMD ["run-server"]