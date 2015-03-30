FROM sjeanpierre/sinatra-base
RUN mkdir -p /usr/src/app/config
COPY secure/rightscale.yml /usr/src/app/config/
COPY secure/credentials /usr/src/app/config/
CMD ["rackup"]