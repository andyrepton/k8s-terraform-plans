Nano clusters will create one VPC, one Network, one master and one worker node. The etcd cluster will run on the master, and does not maintain quorum. Useful for quick testing.

###Requirements
 1. aws or cs api/secret keys. These are defined in main.tf
