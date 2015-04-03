FROM sjeanpierre/centos66-ruby21
RUN mkdir -p /usr/src/app/config
RUN mkdir -p /root/.aws
COPY config/rightscale.yml /usr/src/app/config/
COPY config/email_stats.yml /usr/src/app/config/
COPY config/credentials /root/.aws/
RUN crontab /usr/src/app/jobs/cron
CMD ["rackup"]