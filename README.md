WIP

Prerequisites:

Add DNS

aws route53 create-hosted-zone \
--name aws.mrida.ng \
--caller-reference $(date +%s) \
--hosted-zone-config Comment="EKS demo subdomain"


nslookup -type=NS aws.mrida.ng

aws route53 list-hosted-zones --query "HostedZones[?Name=='aws.mrida.ng.'].Id" --output text


TypeNameContentTTLNSawsns-1234.awsdns-12.orgAutoNSawsns-5678.awsdns-34.comAutoNSawsns-9012.awsdns-56.netAutoNSawsns-3456.awsdns-78.co.ukAuto
Should point to AWS.




terraform login

terraform init
