require 'aws-sdk'

class EmailStats
  DISPOSITION_MAPPING = {:complaints => 'complaint', :bounces => 'bounced', :deliveries => 'delivered'}

  def initialize(request_data)
    @type = request_data['type']
    @data = request_data
    @disposition = DISPOSITION_MAPPING[@type.to_sym] unless ['all', 'stats'].include?(@type)
    # noinspection RubyArgCount
    @dynamo_client = Aws::DynamoDB::Client.new(region: 'us-east-1')
  end


  def process
    validate_type
    if @type == 'all'
      count_email_stats
    elsif @type == 'stats' && @data['email']
      count_user_stats
    elsif @type == 'stats'
      count_email_stats
    else
      stat_items
    end
  rescue => e
    if e.message == 'mismatched dates'
      return [400, {:message => 'Your starting date is greater than the end date, please correct'}.to_json]
    else
      raise(e)
    end
  end

  private

  def validate_type
    return [404, {:message => 'Invalid type specified'}.to_json] unless ['all', 'complaints', 'bounces', 'deliveries', 'stats'].include?(@type)
  end

  def query_dynamo(options)
    dates = date
    options[:query_filter]['date'] = {:attribute_value_list => [dates[:start], dates[:end]], :comparison_operator => 'BETWEEN'}
    @dynamo_client.query(options)
  end

  def date
    if @data.has_key?('date')
      long_year = '%m/%d/%Y %H:%M:%S'
      short_year = '%m/%d/%y %H:%M:%S'
      date_parse_format = (@data['date'].split('/').last.length == 4) ? long_year : short_year
      start_of_range = DateTime.strptime("#{@data['date'].to_s} 00:00:01", date_parse_format).to_time.to_i
      end_of_range = DateTime.strptime("#{@data['date']} 23:59:59", date_parse_format).to_time.to_i
    elsif @data.has_key?('date1')
      date1_parse_format = (@data['date1'].split('/').last.length == 4) ? long_year : short_year
      date2_parse_format = (@data['date2'].split('/').last.length == 4) ? long_year : short_year
      start_of_range = DateTime.strptime("#{@data['date1'].to_s} 00:00:01", date1_parse_format).to_time.to_i
      end_of_range = DateTime.strptime("#{@data['date2']} 23:59:59", date2_parse_format).to_time.to_i
      raise('mismatched dates') if start_of_range > end_of_range
    else
      #date logic in today - count&unit format
      now = DateTime.now
      end_of_range = DateTime.new(now.year, now.month, now.day, 23, 59, 59).to_time.to_i
      if ['days', 'day'].include?(@data['unit'])
        days = @data['count'].to_i
        start_day = now - days
        start_of_range = DateTime.new(start_day.year, start_day.month, start_day.day, 00, 00, 01).to_time.to_i
      elsif ['week', 'weeks'].include?(@data['unit'])
        days = @data['count'].to_i * 7
        start_week = now - days
        start_of_range = DateTime.new(start_week.year, start_week.month, start_week.day, 00, 00, 01).to_time.to_i
      end
    end
    {:start => start_of_range, :end => end_of_range}
  end

  def count_email_stats
    stat_counts = {}
    ['delivered', 'bounced', 'complaint'].each do |disposition|
      options = {
          :table_name => 'email_stats',
          :index_name => 'disposition',
          :limit => '30000',
          :select => 'COUNT',
          :key_conditions => {
              'disposition' => {
                  :attribute_value_list => [disposition],
                  :comparison_operator => 'EQ'
              },
          },
          :query_filter => {}

      }
      dynamo_results = query_dynamo(options)
      stat_counts[disposition.to_sym] = dynamo_results.count
    end
    response(stat_counts)
  end

  def count_user_stats
    #determine how to also filter by provided date range, time ago date in unixtimestamp with GT comparison
    stat_counts = {}
    ['delivered', 'bounced', 'complaint'].each do |disposition|
      options = {
          :table_name => 'email_stats',
          :index_name => 'recipient',
          :limit => '30000',
          :select => 'COUNT',
          :key_conditions => {
              'recipient' => {
                  :attribute_value_list => [@data['email']],
                  :comparison_operator => 'EQ'
              }
          },
          :query_filter => {
              'disposition' => {
                  :attribute_value_list => [disposition],
                  :comparison_operator => 'EQ'
              },
          }

      }
      dynamo_results = query_dynamo(options)
      stat_counts[disposition.to_sym] = dynamo_results.count
    end
    response(stat_counts)
  end

  def stat_items
    options = dynamo_options
    dynamo_results = query_dynamo(options) || []
    dynamo_results.items.map! do |message|
      message['date'] = format_time(message['date'])
      message
    end unless (dynamo_results.items.count == 0 || dynamo_results == nil)
    response(dynamo_results)
  end

  def dynamo_options
    options = {
        :table_name => 'email_stats',
        :index_name => 'recipient',
        :limit => '30000',
        :select => 'ALL_PROJECTED_ATTRIBUTES',
        :key_conditions => {
            'recipient' => {
                :attribute_value_list => [@data['email']],
                :comparison_operator => 'EQ'
            }
        },
        :query_filter => {
            'disposition' => {
                :attribute_value_list => [@disposition],
                :comparison_operator => 'EQ'
            }
        }
    } if @data['email']
    options = {
        :table_name => 'email_stats',
        :index_name => 'disposition',
        :limit => '30000',
        :select => 'ALL_PROJECTED_ATTRIBUTES',
        :key_conditions => {
            'disposition' => {
                :attribute_value_list => [@disposition],
                :comparison_operator => 'EQ'
            },
        },
        :query_filter => {}
    } unless @data['email']
    options
  end

  def format_time(time)
    Time.at(time.to_i).strftime('%D %I:%M%p')
  end

  def response(data)
    if data.is_a?(Hash)
      [200, data.to_json]
    elsif data.items.is_a?(Array)
      if data.items.count == 0
        [404, {:message => 'No matching results'}.to_json]
      elsif data.items.count == 1
        [200, data.items.first.to_json]
      else
        [200, data.items.to_json]
      end
    end
  end #write some sort of proper response handler logic to encapsulate this

end

