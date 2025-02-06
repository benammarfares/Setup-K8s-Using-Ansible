# Kubernetes Ansible Setup
## About The Project
![Image](https://github.com/user-attachments/assets/84c65343-71b5-413f-8af4-5171cd7ea05f)<br>
## Getting Started

First , clone the repository to your Worker Node:
```bash
git clone https://github.com/benammarfares/Setup-K8s-Using-Ansible.git
```
Then All you need to do is Run the Script

```bash
cd Setup-K8s-Using-Ansible
chmod +x Script-Worker-Nb1.sh
./Script-Worker-Nb1.sh
````

Next Step , clone the repository to your Master Node:
```bash
git clone https://github.com/benammarfares/Setup-K8s-Using-Ansible.git
```
Then All you need to do is Run the Script

```bash
cd Setup-K8s-Using-Ansible
chmod +x Script-Master-Nb1.sh
./Script-Master-Nb1.sh
````

Next Step On you Controller Node :

Set up SSH key pair
Generate an SSH key pair. You will be prompted to enter a name for your key pair.
You can either type a custom name or press Enter to use the default name `id_rsa` within the `.ssh` directory. In our case we will use the default and type Enter.

```bash
ssh-keygen
````

Change this based on your needs and when the script is executing the next command you will need to type the password of the remote host
```bash
ssh-copy-id Worker@remote_hostIp 
````

Next : Move back to the Master Node 

```bash
cd Setup-K8s-Using-Ansible
chmod +x Script-Master-Nb2.sh
./Script-Master-Nb2.sh
````

Next : Move back to the Worker Node 

```bash
cd Setup-K8s-Using-Ansible
chmod +x Script-Worker-Nb2.sh
./Script-Worker-Nb2.sh
````

And the Final Step After all the requirement are set up , Move To the Controller Node :

First, clone the repository to your local machine Controller:

```bash
git clone https://github.com/benammarfares/Setup-K8s-Using-Ansible.git
```
Next Execute the script that will Install Ansible , Create Inventory and the playbbok :
```bash
cd Setup-K8s-Using-Ansible
chmod +x K8s-Ansible.sh
./K8s-Ansible.sh
````






