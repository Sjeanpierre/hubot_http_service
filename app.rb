require 'sinatra'
require_relative 'lib/inventory'
require_relative 'lib/email_stats'
set :show_exceptions, false
set :raise_errors, true
JOBS = ['email_stats_job.rb', 'inventory_job.rb']

before do
  content_type 'application/json'
end

get '/' do
  {:message => 'Nothing to see here /find'}.to_json
end

get '/run/:job' do |job_name|
  job = "#{job_name}.rb"
  if JOBS.include?(job)
    log_name = "logs/#{job_name}.log"
    Thread.new {system("./jobs/#{job} >> #{log_name}")}
  else
    status 404
    {:message => 'job not found'}.to_json
  end
end

post '/inventory' do
  http_status, data = Inventory.new(params[:identifier]).details
  status http_status
  data
end

post '/email_stats' do
  http_status, data = EmailStats.new(params).process
  status http_status
  data
end