
terraform import google_iam_workload_identity_pool.github_actions github-actions-pool
terraform import google_iam_workload_identity_pool_provider.github_actions github-actions-pool/github-actions-provider


https://xebia.com/blog/how-to-tell-ansible-to-use-gcp-iap-tunneling/


pip install ansible


https://devopscube.com/ansible-dymanic-inventry-google-cloud/


gcloud compute instances list --filter="tags.items=visitor-counter" --format="value(name)"

terraform output -raw cloudflare_zone_id


```shell

go build -o visitor-counter main.go

GITHUB_PR_NUMBER=123

VERSION="dev-${GITHUB_PR_NUMBER}-$(date +%Y%m%d-%H%M%S)"
echo "Version: $VERSION"

INSTANCE_NAME=`gcloud compute instances list --filter="tags.items=visitor-counter" --format="value(name)"`

gcloud compute ssh $INSTANCE_NAME --zone=us-central1-a --project=inbound-trilogy-449714-g7

# Copy binary to server
echo "Copying binary to server..."
gcloud compute scp visitor-counter $INSTANCE_NAME:/tmp/visitor-counter-${VERSION} \
--zone=us-central1-a \
--project=inbound-trilogy-449714-g7

# Deploy using the deployment script
echo "Running deployment script..."
gcloud compute ssh $INSTANCE_NAME \
--zone=us-central1-a \
--project=inbound-trilogy-449714-g7 \
--command="sudo /opt/visitor-counter/shared/deploy.sh development ${VERSION} /tmp/visitor-counter-${VERSION}"

# Clean up temporary file
gcloud compute ssh $INSTANCE_NAME \
--zone=us-central1-a \
--project=inbound-trilogy-449714-g7 \
--command="rm -f /tmp/visitor-counter-${VERSION}"

```


visitor-counter-development.corymurphy.net