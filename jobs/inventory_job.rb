#!/usr/bin/env ruby

require 'rubygems'
require 'right_api_client'
require 'aws-sdk'
require 'yaml'

# noinspection RubyArgCount
$dynamodb = Aws::DynamoDB::Client.new(region: 'us-east-1')

def main
  credential_file = YAML.load_file('../config/rightscale.yml')
  rightscale_credentials = credential_file[:rightscale]
  setup_dynamo
  rs_email = rightscale_credentials[:email]
  rs_password = rightscale_credentials[:password]
  rs_accounts = rightscale_credentials[:account_id]
  rs_accounts.each do |rs_account|
    rs_client = RightApi::Client.new(:email => rs_email, :password => rs_password, :account_id => rs_account)
    inventory(rs_client)
  end
end

def inventory(rs_client)
  regions = %w(us-east-1 us-west-1 us-west-2)
  clouds = rs_client.clouds.index
  all_instances = []
  regions.each do |region|
    selected_cloud = clouds.detect { |cloud| cloud.name.split(' ').last == region }.show
    instances = selected_cloud.instances(:view => 'full', :filter => ['state==operational']).index
    formatted_instances = ServerInstance.new(rs_client.account_id, instances).process unless instances.empty?
    all_instances.push(formatted_instances)
  end
  all_instances = all_instances.flatten
  dyn_table = 'servers'
  all_instances.each do |instance|
    write_to_dynamo(dyn_table, instance) unless instance == nil
  end
end

def persist_data(instance_array)
  file_name = "servers-#{Time.now.strftime('%Y-%m-%d-%H%M%S')}"
  File.open("../persisted_data/#{file_name}.json", 'w') { |f| f.write instance_array.to_json }
  puts "persisted servers to #{file_name}"
end

def setup_dynamo
  options = YAML.load_file('../dynamo_schemas/inventory_schema.yml')
  table_list = $dynamodb.list_tables
  $dynamodb.create_table(options) unless table_list.table_names.include?(options[:table_name])
  $dynamodb.wait_until(:table_exists, :table_name => options[:table_name])
rescue => error
  puts 'Encountered an error setting up Dynamo'
  puts "#{error.message}"
  exit(1)
end

def write_to_dynamo(table, instance)
  options = {
      :table_name => table,
      :item => {
          :uid => instance[:uid],
          :name => instance[:name],
          :public_ip => instance[:public_ip],
          :private_ip => instance[:private_ip],
          :deployment_url => instance[:deployment_url],
          :account_id => instance[:account_id]
      }
  }
  $dynamodb.put_item(options)
rescue => e
  puts 'Encountered an error'
  puts "#{e.message}"
end

class ServerInstance
  def initialize(account_number, instance_array)
    @account = account_number
    @instances_array = instance_array
    @instances = []
  end

  def process
    @instances_array.each do |instance|
      @instances.push(create_instance_object(instance))
    end
    @instances
  end

  private
  def create_instance_object(instance)
    {
        :name => instance.name,
        :uid => instance.resource_uid,
        :public_ip => instance.public_ip_addresses.first || 'NA',
        :private_ip => instance.private_ip_addresses.first || 'NA',
        :deployment_url => generate_url(instance),
        :account_id => @account.to_s
    }
  end

  def generate_url(instance)
    href = instance.links.detect { |link| link['rel'] == 'deployment' }['href'].sub('/api/', '')
    return "https://my.rightscale.com/acct/#{@account}/#{href}"
  rescue
    'N/A'
  end
end

main


