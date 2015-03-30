require 'aws-sdk'

# noinspection RubyArgCount
DYNAMO = Aws::DynamoDB::Client.new(
    region: 'us-east-1'
)

class Inventory
  def initialize(identifier)
    @identifier = identifier
  end

  def categorize_identifier
    instance_uid_regex = /i-\w*/
    private_ip_regex = /^(10\.\d+|172\.(1[6-9]|2\d|3[0-1])|192\.168)(\.\d+){2}$/
    ipv4_ip_regex = /^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/
    case @identifier
      when instance_uid_regex
        :uid
      when private_ip_regex
        :private_ip
      when ipv4_ip_regex
        :public_ip
      else
        :invalid
    end
  end

  def details
    attribute_name = categorize_identifier
    return {:message => 'Invalid resource specified'}.to_json if attribute_name == :invalid
    options = {
        :table_name => 'servers',
        :index_name => attribute_name,
        :select => 'ALL_PROJECTED_ATTRIBUTES',
        :limit => 1,
        :key_conditions => {
            attribute_name => {
                :attribute_value_list => [@identifier],
                :comparison_operator => 'EQ'
            },
        }

    }
    dynamo_results = DYNAMO.query(options)
    response(dynamo_results)
  end

  def response(data)
    if data.items.count == 0
      [404,{:message => 'No matching results'}.to_json]
    else
      [200,data.items.first.to_json]
    end
  end

end