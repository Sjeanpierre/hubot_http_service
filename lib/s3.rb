require 'aws-sdk'

class S3
  def initialize(data)
    # puts data
    region = data['region'] ||= 'us-east-1'
    @source_bucket = data['source_bucket']
    @file_name = data['file_name']
    @destination = data['destination']
    @s3 = Aws::S3::Resource.new(
      region: region
    )
  end

  def get_bucket(bucket)
    @s3.bucket(bucket)
  end

  # does the file exist in the bucket?
  def check_file(bucket, file)
    bucket = get_bucket(bucket)
    response = bucket.object(file).exists?
    if response
      return true
    else
      return false
    end
  end

  def file_exists
    if check_file(@source_bucket, @file_name)
      [200,{ message: "#{@file_name} exists." }.to_json]
    else
      [404,{ message: "#{@file_name} not found." }.to_json]
    end
  end

  # copy specific file from one folder to another
  def copy_file
    bucket = get_bucket(@source_bucket)
    object = bucket.object(@file_name)
    destination_bucket = @destination.split('/').first
    destination_file = @destination.gsub("#{destination_bucket}/",'')
    dest_file_already_there = check_file(destination_bucket,destination_file)
    if check_file(@source_bucket, @file_name)
      if dest_file_already_there
        [200,{ message: "#{@file_name} exists." }.to_json]
      else
        object.copy_to(@destination)
        # if object copies, return a 201
        [201,{ message: "#{@file_name} copied." }.to_json]
        # if object does not copy, return appropriate error
      end
    else
      [404,{ message: "#{@file_name} not found." }.to_json]
    end
  end

end
