# Reference solution for gcp-vpc-subnets: build the VPC, answer from gcloud output, clean up.
set -eu
umask 022

NET=ledger-net
gcloud compute networks create "$NET" --subnet-mode custom
gcloud compute networks subnets create ledger-app --region us-central1 --network "$NET" --range 10.40.1.0/24
gcloud compute networks subnets create ledger-db --region europe-west1 --network "$NET" \
  --range 10.40.2.0/24 --enable-private-ip-google-access

{
  echo "PROJECT=$(gcloud config get-value project)"
  echo "DEFAULT_MODE=$(gcloud compute networks list --filter=name=default --format='value(x_gcloud_subnet_mode)')"
  echo "DEFAULT_SUBNETS=$(gcloud compute networks subnets list --network default --format='value(name)' | wc -l | tr -d ' ')"
  created=$(gcloud compute networks describe temp-net --format='value(creationTimestamp)')
  echo "TEMP_NET_CREATED=${created%%T*}"
  a=$(gcloud compute networks subnets list --network default --regions europe-west1 --format='value(ipCidrRange)')
  b=$(gcloud compute networks subnets list --network temp-net --regions europe-west1 --format='value(ipCidrRange)')
  [ "$a" = "$b" ]
  echo "SHARED_RANGE=$a"
} > /root/answers.txt

gcloud --quiet compute networks delete temp-net
for s in ledger-app:us-central1 ledger-db:europe-west1; do
  gcloud compute networks subnets update "${s%%:*}" --region "${s##*:}" --enable-flow-logs
done
