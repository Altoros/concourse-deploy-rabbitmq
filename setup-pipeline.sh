#!/usr/bin/env bash
set -ex

if [[ -z $CONCOURSE_URI || -z $CONCOURSE_TARGET || -z $CONCOURSE_USER || -z $CONCOURSE_PASSWORD || \
      -z $FOUNDATION_NAME || -z $PRODUCT_NAME || \
      -z $BOSH_CLIENT || -z $BOSH_CLIENT_SECRET || -z $BOSH_CA_CERT || -z $BOSH_CA_CERT ]]; then
  echo "one the following environment variables is not set: "
  echo ""
  echo "                 CONCOURSE_URI"
  echo "                 CONCOURSE_TARGET"
  echo "                 CONCOURSE_USER"
  echo "                 CONCOURSE_PASSWORD"
  echo "                 BOSH_CLIENT"
  echo "                 BOSH_CLIENT_SECRET"
  echo "                 BOSH_CA_CERT"
  echo ""
  exit 1
fi

export VAULT_HASH=secret/$PRODUCT_NAME-$FOUNDATION_NAME-props
export CF_VAULT_PASSWORD_HASH=secret/cf-$FOUNDATION_NAME-password
export CF_VAULT_PROPS_HASH=secret/cf-$FOUNDATION_NAME-props

echo "requires files (rootCA.pem, director.pwd, deployment-props.json)"
vault write ${VAULT_HASH} \
  bosh-cacert=@$BOSH_CA_CERT \
  bosh-pass=$BOSH_CLIENT_SECRET \
  bosh-client-secret=$BOSH_CLIENT_SECRET \
  bosh-client-id=director \
  bosh-url=https://$BOSH_ENVIRONMENT \
  bosh-port=25555 \
  bosh-user=admin \
  system-services-password=$(vault read --field=system-services-password $CF_VAULT_PASSWORD_HASH) \
  doppler-zone=$(vault read --field=doppler-zone $CF_VAULT_PASSWORD_HASH) \
  doppler-shared-secret=$(vault read --field=doppler-shared-secret $CF_VAULT_PASSWORD_HASH) \
  nats-pass=$(vault read --field=nats-pass $CF_VAULT_PASSWORD_HASH) \
  @deployment-props.json

vault read --format=json $VAULT_HASH | jq .data > temp/vault-values.json

j2y temp/vault-values.json > temp/vault-values.yml

fly -t $CONCOURSE_TARGET login -c $CONCOURSE_URI -u $CONCOURSE_USER -p $CONCOURSE_PASSWORD

fly -t $CONCOURSE_TARGET set-pipeline -p $PRODUCT_NAME-$FOUNDATION_NAME \
              --config="ci/pipeline.yml" \
              --var="vault-address=$VAULT_ADDR" \
              --var="vault-token=$VAULT_TOKEN" \
              --var="concourse-url=$CONCOURSE_URI" \
              --var="concourse-user=$CONCOURSE_USER" \
              --var="concourse-pass=$CONCOURSE_PASSWORD" \
              --var="deployment-name=$PRODUCT_NAME-$FOUNDATION_NAME" \
              --var="vault_addr=$VAULT_ADDR" \
              --var="vault_token=$VAULT_TOKEN" \
              --var="foundation-name=$FOUNDATION_NAME" \
              --var="pipeline-repo=$PIPELINE_REPO" \
              --var="pipeline-repo-branch=$PIPELINE_REPO_BRANCH" \
              --var="pipeline-repo-private-key=$(cat $PIPELINE_REPO_PRIVATE_KEY_PATH)" \
              --var="product-name=$PRODUCT_NAME" \
              --var="vault_hash_hostvars=secret/$PRODUCT_NAME-$FOUNDATION_NAME-hostvars" \
              --var="vault_hash_ip=secret/$PRODUCT_NAME-$FOUNDATION_NAME-props" \
              --var="vault_hash_keycert=secret/$PRODUCT_NAME-$FOUNDATION_NAME-keycert" \
              --var="vault_hash_misc=secret/$PRODUCT_NAME-$FOUNDATION_NAME-props" \
              --var="vault_hash_password=secret/$PRODUCT_NAME-$FOUNDATION_NAME-password" \
              --var="vault_hash_ert_password=secret/cf-$FOUNDATION_NAME-password" \
              --var="vault_hash_ert_ip=$CF_VAULT_PROPS_HASH" \
              --load-vars-from pipeline-defaults.yml \
              --load-vars-from temp/vault-values.yml 

fly -t $CONCOURSE_TARGET unpause-pipeline -p $PRODUCT_NAME-$FOUNDATION_NAME
