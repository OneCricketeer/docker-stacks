# Rancher OS Cluster Bootstrap

> *Only tested on macOS*

Uses `docker-machine` and VirualBox to bootstrap a cluster of nodes running Rancher OS. 

General use-cases:
  - Rancher 1.6 (Cattle)
  - Rancher 2 (Kubernetes)
  - Hashistack (Consul, Nomad, Vault)

# Usage

Peek at `rancher.env` and see if properties need changed. For example, external IPs, versions, and server names are likely to change over time. 

You will run `./startup.sh`, but peek at the top of the file if you want to edit any Virtualbox properties such as number of VMs or their memory settings 

*TODO: Document variable overrides in the script*

While this is running, you will be prompted to open http://localhost:8080/env/1a5/infra/hosts/add?driver=custom. This page just needs to load, but nothing done within. This is needed for the Rancher registration token to get created. *TODO: Find a way to automate this all in the script*

Once complete, a collection of nodes should be shown at http://localhost:8080/env/1a5/infra/hosts

# Teardown

To stop VMs and Docker Compose. Set to false, or exclude variable to only stop VMs (keep Docker Registry and Rancher Server running)

`COMPOSE_DOWN=true ./destroy.sh`
