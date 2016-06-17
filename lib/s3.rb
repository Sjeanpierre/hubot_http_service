require 'aws-sdk'

class S3
  def initialize(data)
    puts data
    region = data['region'] ||= 'us-east-1'
    @source_bucket = data['source_bucket']
    @file_name = data['file_name']
    @destination = data['destination']
    @s3 = Aws::S3::Resource.new(
      region: region
    )
  end

  def get_bucket
    @s3.bucket(@source_bucket)
  end

  # does the file exist in the bucket?
  def file_exists
    bucket = get_bucket
    bucket.object(@file_name).exists?
  end

  # copy specific file from one folder to another
  def copy_file
    bucket = get_bucket
    object = bucket.object(@file_name)
    object.copy_to(@destination)
  end

end
