#Hubot HTTP service
* Inventory
    - Description: Allows quick lookup of aws/Rightscale instances via their aws UID, private IP or Public IP
    - Dependacies: aws-sdk, right_api_client
    - Routes: `/find`
        - Examples:
            - IP: `curl -X POST -H "Cache-Control: no-cache" -H "Postman-Token: 3180859d-6514-0b5a-987b-29f948f1491a" -H "Content-Type: multipart/form-data -F "identifier=10.183.21.106" http://localhost:4567/find`
            - UID: `curl -X POST -H "Cache-Control: no-cache" -H "Postman-Token: 3180859d-6514-0b5a-987b-29f948f1491a" -H "Content-Type: multipart/form-data -F "identifier=i-b2fd8361" http://localhost:4567/find`
        - Reponse: <pre>{
"public_ip": "NA",
"private_ip": "10.183.00.106",
"deployment_url": "https://my.rightscale.com/acct/4321/deployments/123456789",
"name": "02 - Super Awesome app - PROD #47",
"uid": "i-cd80920e",
"account_id": "4321"
}</pre>
