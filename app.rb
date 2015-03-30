require 'sinatra'
require_relative 'lib/inventory'
require_relative 'lib/email_stats'
set :show_exceptions, false
set :raise_errors, true

before do
  content_type 'application/json'
end

get '/' do
  {:message => 'Nothing to see here /find'}.to_json
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

