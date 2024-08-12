#sudo useradd -m -s /bin/bash  TOAST
sudo mkdir -p /Inbound/Encrypted
sudo chown -R ubuntu:ubuntu /Inbound
sudo mkdir ~ubuntu/.ssh
sudo chmod 700 ~ubuntu/.ssh
sudo apt update
sudo apt install openssh-server -y 
sudo service ssh start
sudo aws secretsmanager get-secret-value --secret-id \
	"playground/rsaKey/chasesftp-public" --version-stage AWSCURRENT --query SecretString --output text --region us-east-1 >>  ~ubuntu/.ssh/authorized_keys
sudo chown -R ubuntu:ubuntu ~ubuntu/
