# concourse-deploy-rabbitmq

Deploy RabbitMQ with [omg](https://github.com/enaml-ops) in a Concourse pipeline.

## Prerequisites

1. [Git](https://git-scm.com)
1. [Vault](https://www.vaultproject.io)
1. [Concourse](http://concourse.ci)
1. [direnv](http://direnv.net)

## Steps to use this pipeline

```
git clone https://github.com/Altoros/concourse-deploy-rabbitmq.git
cp .envrc{.example,}
vi .envrc
direnv allow
./setup-pipeline.sh
```
