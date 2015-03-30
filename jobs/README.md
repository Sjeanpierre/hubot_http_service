#Jobs via cron in support of HTTP service
* Inventory Job
    - Description: Crawls defined rightscale accounts and saves list of instances to a dynamodb table
    - Purpose: Supports hubot's ability to quickly lookup aws instances by UID, private IP and Public IP
    - Dependacies: aws-sdk, right_api_client
    - Frequency: recommneded every 20 minutes `*/20 * * * * /path/to/inventory.rb`