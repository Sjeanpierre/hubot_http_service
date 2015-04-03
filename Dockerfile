FROM sjeanpierre/sinatra-base
RUN mkdir -p /usr/src/app/config
RUN mkdir -p /root/.aws
COPY config/rightscale.yml /usr/src/app/config/
COPY config/credentials /root/.aws/
COPY jobs/cron /etc/cron.d/
CMD ["rackup"]