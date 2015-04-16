#!/usr/bin/env ruby
#http://docs.aws.amazon.com/ses/latest/DeveloperGuide/notification-contents.html#bounce-types
#http://docs.aws.amazon.com/sdkforruby/api/Aws/SQS/Client.html

require 'aws-sdk'
require 'json'
require 'time'
require 'yaml'

def log(message)
  puts message
  $stdout.flush
end

$threads = []
start_time = Time.now
log("Starting email stats job at #{start_time}")
# noinspection RubyArgCount
$dynamodb = Aws::DynamoDB::Client.new(region: 'us-east-1')
email_stats_config = YAML.load_file(File.join(File.dirname(__FILE__), '..', 'config', 'email_stats.yml'))
queue_urls = email_stats_config[:queue_urls]

# noinspection RubyArgCount
class MessageProcessor
  Message = Struct.new(:message_id, :account, :date, :recipient, :disposition, :details) do
    def unix_date
      Time.parse(date).to_i
    end

    def format
      {
          :message_id => message_id,
          :recipient => recipient,
          :disposition => disposition,
          :account => account,
          :date => unix_date,
          :details => details
      }
    end
  end

  def initialize(queue_url)
    @queue_url = queue_url
    @messages = []
    @receipt_handles = []
  end

  def process
    collect_sqs_messages
    parse_messages
    dispatch_messages
    $threads.push(Thread.new { persist_processed_messages(@messages) }) unless @messages.empty?
    $threads.push(Thread.new {clean_processed_messages(@receipt_handles, @queue_url)}) unless @messages.empty?
    return @messages
  end

  private
  def collect_sqs_messages
    log "Grabbing messages from #{@queue_url}"
    region = queue_region
    sqs = Aws::SQS::Client.new(:region => region)
    loop do
      received = sqs.receive_message(:queue_url => @queue_url, :max_number_of_messages => 10)
      received_messages = received.messages #todo, we should be collecting the receipt handles to delete the @messages
      log "Retrieved #{received_messages.count} messages"
      break if received_messages.count == 0
      @messages.push(received_messages)
    end
    @messages.flatten!
  end

  def clean_processed_messages(receipt_ids, queue_url)
    log 'Cleaning up processed messages'
    region = queue_region
    sqs = Aws::SQS::Client.new(:region => region)
    receipt_ids.each_slice(10) do |ten_receipts|
      batch = create_receipt_batch(ten_receipts)
      begin
        sqs.delete_message_batch(:queue_url => queue_url, :entries => batch)
      rescue => error
        log "Ran into error attempting to remove batch #{batch}"
        log "#{error.message}"
        log '='*80
        log error.backtrace.join("\n")
      end
    end

  end

  def persist_processed_messages(messages)
    jsonable_messages = messages.map { |message| message.to_h }
    file_name = File.join(File.dirname(__FILE__), '..', 'persisted_data', "messages-#{Time.now.strftime('%Y-%m-%d-%H%M%S')}")
    File.open("#{file_name}.json", 'w') { |f| f.write jsonable_messages.to_json }
    log "persisted messages to #{file_name}"
  end

  def create_receipt_batch(receipt_group)
    entries = []
    receipt_group.each_with_index do |receipt, index|
      entry = {:id => index.to_s, :receipt_handle => receipt}
      entries.push(entry)
    end
    return entries
  end

  def parse_messages
    @messages.map! do |message|
      @receipt_handles.push(message.receipt_handle)
      parsed_message = JSON.parse(message.body)
      parsed_message['Message'] = JSON.parse(parsed_message['Message'])
      parsed_message
    end
  end

  def dispatch_messages
    case queue_type
      when 'ses-delivered-email'
        process_delivered_messages
      when 'ses-complaint-email'
        process_complaint_messages
      when 'ses-bounced-email'
        process_bounced_messages
      else
        log "Unknown queue type: #{queue_type}"
        exit(-1)
    end
  end

  def process_bounced_messages
    @messages.map! do |message|
      m = message['Message']
      details = {
          :bounce_details => {
              :bounce_subtype => m['bounce']['bounceSubType'],
              :bounce_type => m['bounce']['bounceType'],
              :bounce_reason => m['bounce']['bouncedRecipients'][0].fetch('diagnosticCode', nil)
          }
      }
      Message.new(message['MessageId'], account_id, m['mail']['timestamp'], m['mail']['destination'][0], 'bounced', details)
    end
  end

  def process_delivered_messages
    @messages.map! do |message|
      m = message['Message']
      details = {
          :delivery_details => {
              :processing_time => m['delivery']['processingTimeMillis'],
              :status => m['delivery']['smtpResponse']
          }
      }
      Message.new(message['MessageId'], account_id, m['mail']['timestamp'], m['mail']['destination'][0], 'delivered', details)
    end

  end
  #there is a defect here with the complanit_details being in singular form
  #the entries for complaints are already affected and will need to be converted if fix is attempted
  #todo
  def process_complaint_messages
    @messages.map! do |message|
      m = message['Message']
      details = {
          :complaint_detail => {
              :complaint_type => m['complaint'].fetch('complaintFeedbackType', 'N/A'),
              :complaint_date => m['complaint'].fetch('arrivalDate', 'N/A')
          }
      }
      Message.new(message['MessageId'], account_id, m['mail']['timestamp'], m['mail']['destination'][0], 'complaint', details)
    end
  end

  def queue_region
    @queue_url.split('.')[1]
  end

  def queue_type
    @queue_url.split('/').last
  end

  def account_id
    @account_id ||= @queue_url.split('/')[-2]
  end
end

def main(queue_urls)
  setup_dynamo
  queue_urls.each do |queue_url|
    messages = MessageProcessor.new(queue_url).process
    messages.each { |message| write_to_dynamo('email_stats', message) }
  end
end

def setup_dynamo
  options = YAML.load_file(File.join(File.dirname(__FILE__), '..', 'dynamo_schemas', 'email_stats_schema.yml'))
  table_list = $dynamodb.list_tables
  begin
    $dynamodb.create_table(options)
    $dynamodb.wait_until(:table_exists, :table_name => options[:table_name])
  end unless table_list.table_names.include?(options[:table_name])
rescue => error
  log 'Encountered an error setting up Dynamo'
  log "#{error.message}"
  exit(1)
end

def write_to_dynamo(table, message)
  log "Writing #{message.message_id} to dynamo"
  options = {
      :table_name => table,
      :item => message.format
  }
  $dynamodb.put_item(options)
rescue => e
  log 'Encountered an error'
  log "#{e.message}"
end


main(queue_urls)
$threads.each {|thread| thread.join}
end_time = Time.now
log("Completed email stats job at #{end_time}, duration #{end_time - start_time} seconds")
log('='*80)


