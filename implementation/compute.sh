#This is a script to spin up compute resources on desired cloud
#Kubernetes requires a set of machines to host the Kubernetes control
# plane and the worker nodes where containers are ultimately run

#The Kubernetes networking model assumes a flat network in which containers and nodes can communicate with each other

echo "Create the kubernetes-the-hard-way custom VPC network:"

gcloud compute networks create kubernetes-the-hard-way --subnet-mode custom
sleep 5
echo "Create the kubernetes subnet in the kubernetes-the-hard-way VPC network:"

#The 10.240.0.0/24 IP address range can host up to 254 compute instances.
gcloud compute networks subnets create kubernetes \
  --network kubernetes-the-hard-way \
  --range 10.240.0.0/24
sleep 5
echo "Create a firewall rule that allows internal communication across all protocols:"

gcloud compute firewall-rules create kubernetes-the-hard-way-allow-internal \
  --allow tcp,udp,icmp \
  --network kubernetes-the-hard-way \
  --source-ranges 10.240.0.0/24,10.200.0.0/16
sleep 5
echo "Create a firewall rule that allows external SSH, ICMP, and HTTPS:"

gcloud compute firewall-rules create kubernetes-the-hard-way-allow-external \
  --allow tcp:22,tcp:6443,icmp \
  --network kubernetes-the-hard-way \
  --source-ranges 0.0.0.0/0
sleep 5
echo "An external load balancer will be used to expose the Kubernetes API Servers to remote clients."

echo "List the firewall rules in the kubernetes-the-hard-way VPC network:"
gcloud compute firewall-rules list --filter="network:kubernetes-the-hard-way"

sleep 5

echo "Allocate a static IP address that will be attached to the external load balancer fronting the Kubernetes API Servers:"

gcloud compute addresses create kubernetes-the-hard-way \
  --region $(gcloud config get-value compute/region)

sleep 5

echo "Verify the kubernetes-the-hard-way static IP address was created in your default compute region:"

gcloud compute addresses list --filter="name=('kubernetes-the-hard-way')"

#Compute Instances
#The compute instances in this lab will be provisioned using Ubuntu Server 18.04, 
#which has good support for the containerd container runtime. 
#Each compute instance will be provisioned with a fixed private IP address to 
#simplify the Kubernetes bootstrapping process.

echo "Spin compute for K8s Controllers"

sleep 5

echo "Create three compute instances which will host the Kubernetes control plane:"

for i in 0 1 2; do
  gcloud compute instances create controller-${i} \
    --async \
    --boot-disk-size 200GB \
    --can-ip-forward \
    --image-family ubuntu-1804-lts \
    --image-project ubuntu-os-cloud \
    --machine-type n1-standard-1 \
    --private-network-ip 10.240.0.1${i} \
    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    --subnet kubernetes \
    --tags kubernetes-the-hard-way,controller
done

echo "Spin Compute for K8s Worker Nodes"

#Each worker instance requires a pod subnet allocation from the Kubernetes cluster CIDR range. 
#The pod subnet allocation will be used to configure container networking in a later exercise. 
#The pod-cidr instance metadata will be used to expose pod subnet allocations to compute instances at runtime.

echo "The Kubernetes cluster CIDR range is defined by the Controller Manager's --cluster-cidr flag. 
In this tutorial the cluster CIDR range will be set to 10.200.0.0/16, which supports 254 subnets."

for i in 0 1 2; do
  gcloud compute instances create worker-${i} \
    --async \
    --boot-disk-size 200GB \
    --can-ip-forward \
    --image-family ubuntu-1804-lts \
    --image-project ubuntu-os-cloud \
    --machine-type n1-standard-1 \
    --metadata pod-cidr=10.200.${i}.0/24 \
    --private-network-ip 10.240.0.2${i} \
    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    --subnet kubernetes \
    --tags kubernetes-the-hard-way,worker
done

sleep 5

echo "List the compute instances in your default compute zone:"

gcloud compute instances list

sleep 5

echo "Start Configuring SSH Access for each of the machines"

