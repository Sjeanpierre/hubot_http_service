require 'aws-sdk'

class S3
  def client_user
    s3 = Aws::S3::Resource.new(
      region: 'us-east-1'
    )
  end

  def get_bucket(bucket_name)
    s3 = client_user
    s3.bucket(bucket_name)
  end

  # list all the files in the folder of the bucket
  def list_files_in_bucket(bucket_name, folder, limit)
    bucket = get_bucket(bucket_name)
    bucket.objects(prefix: folder).limit(limit).each do |item|
      puts "Name: #{item.key}"
    end
  end

  # does the file exist in the bucket?
  # file_name String is the full path to the file from the root of the bucket
  def file_exist(bucket_name, file_name)
    bucket = get_bucket(bucket_name)
    bucket.object(file_name).exists?
  end

  # copy specific file from one folder to another
  

end
