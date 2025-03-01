#!/bin/bash

# Update and upgrade the system
sudo apt update -y && sudo apt upgrade -y

# Create directory and navigate to it
mkdir -p k8s && cd k8s

# Add user to sudo group
sudo usermod -aG sudo $USER

# Setting up the environment
sudo apt-add-repository ppa:ansible/ansible
sudo apt update
sudo apt install ansible
ansible --version



# Create directories and files for Ansible
mkdir k8s-ansible
cd k8s-ansible

# Add content to k8s_worker_node_connection.j2
echo "{{ join_output.stdout }}" > k8s_worker_node_connection.j2

mkdir Remote_Files

# Add content to worker_conn_string
echo "{{ join_output.stdout }}" > Remote_Files/worker_conn_string

# Add content to inventory
echo "[kubernetes]" > inventory
echo "@MasterIp ansible_ssh_user=MasterUsername" >> inventory
echo "@WorkerIp ansible_ssh_user=WorkerUsername" >> inventory
echo "" >> inventory
echo "[masters]" >> inventory
echo "@MasterIp ansible_ssh_user=MasterUsername" >> inventory
echo "" >> inventory
echo "[workers]" >> inventory
echo "@WorkerIp ansible_ssh_user=WorkerUsername" >> inventory



# Create Ansible playbook
cat <<EOL > playbook.yml
---
- name: Setup Prerequisites To Install Kubernetes
  hosts: workers,masters
  become: true
  vars:
    kube_prereq_packages: [curl, ca-certificates, apt-transport-https]
    kube_packages: [kubeadm, kubectl, kubelet]

  tasks:
    - name: Test Reacheability
      ansible.builtin.ping:

    - name: Update Cache
      ansible.builtin.apt:
        update_cache: true
        autoclean: true

    - name: 1. Upgrade All the Packages to the latest
      ansible.builtin.apt:
        upgrade: "full"

    - name: 2. Install Qemu-Guest-Agent
      ansible.builtin.apt:
        name:
          - qemu-guest-agent
        state: present

    - name: 3. Setup a Container Runtime
      ansible.builtin.apt:
        name:
          - containerd
        state: present

    - name: 4. Start Containerd If Stopped
      ansible.builtin.service:
        name: containerd
        state: started

    - name: 5. Create Containerd Directory
      ansible.builtin.file:
        path: /etc/containerd
        state: directory
        mode: '0755'

    - name: 6. Check config.toml Exists
      ansible.builtin.stat:
        path: /etc/containerd/config.toml
      register: pre_file_exist_result

    - name: 6.1 Delete config.toml Exists
      ansible.builtin.file:
        path: /etc/containerd/config.toml
        state: absent
      when: pre_file_exist_result.stat.exists

    - name: 7. Place Default Containerd Config Inside It
      ansible.builtin.shell: |
        set -o pipefail
        containerd config default | sudo tee /etc/containerd/config.toml
      register: output
      changed_when: output.rc != 0
      args:
        executable: /bin/bash
      tags:
        - containerd_config

    - name: 7.1 Check If New config.toml Exists Now
      ansible.builtin.stat:
        path: /etc/containerd/config.toml
      register: post_file_exist_result
      tags:
        - containerd_config

    - name: 7.2 Exit The Play If config.toml Does Not Exist
      ansible.builtin.meta: end_play
      when: not post_file_exist_result.stat.exists
      tags:
        - containerd_config

    - name: 8.1 Disable Swap
      ansible.builtin.command: sudo swapoff -a
      register: output
      changed_when: output.rc != 0
      tags:
        - disable_swap

    - name: 8.2 Disable Swap permanently
      ansible.builtin.replace:
        path: /etc/fstab
        regexp: '^([^#].*?\sswap\s+sw\s+.*)$'
        replace: '# \1'
      tags:
        - disable_swap

    - name: 9. Edit config.toml
      ansible.builtin.replace:
        path: /etc/containerd/config.toml
        after: \[plugins\."io\.containerd\.grpc\.v1\.cri"\.containerd\.runtimes\.runc\.options\]
        regexp: SystemdCgroup = false
        replace: SystemdCgroup = true

    - name: 10. Enable Ipv4 Bridging
      ansible.builtin.replace:
        path: /etc/sysctl.conf
        regexp: ^#net\.ipv4\.ip_forward=1$
        replace: net.ipv4.ip_forward=1

    - name: 11.1 Delete k8s Config If Exists
      ansible.builtin.file:
        path: /etc/modules-load.d/k8s.conf
        state: absent
      tags:
        - kube_config

    - name: 11.2 Add k8s.config and Edit It
      ansible.builtin.lineinfile:
        path: /etc/modules-load.d/k8s.conf
        line: br_netfilter
        create: true
        mode: '0755'
      tags:
        - kube_config

    - name: 12.1 Reboot
      ansible.builtin.reboot:
      register: system_reboot

    - name: 12.2 Verify Reboot Success
      ansible.builtin.ping:
      when: system_reboot.rebooted

    - name: 13.1 Update Cache
      ansible.builtin.apt:
        update_cache: true
        autoclean: true
      tags:
        - install_pre_kube_packages

    - name: 13.2 Remove apt lock file
      ansible.builtin.file:
        state: absent
        path: "/var/lib/dpkg/lock"
      tags:
        - install_pre_kube_packages

    - name: 13.3 Install Prerequisite Packages
      ansible.builtin.apt:
        name: '{{ kube_prereq_packages }}'
      tags:
        - install_pre_kube_packages

    - name: 13.4 Remove GPG Keys If They Exist
      ansible.builtin.file:
        path: "{{ item }}"
        state: absent
      with_items:
        - /usr/share/keyrings/kubernetes-apt-keyring.gpg
        - /usr/share/keyrings/kubernetes-apt-keyring.gpg_armored
      tags:
        - install_pre_kube_packages

    - name: 13.5 Download Kubernetes APT Key
      ansible.builtin.get_url:
        url: https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key
        dest: /usr/share/keyrings/kubernetes-apt-keyring.gpg_armored
        mode: '0755'
      tags:
        - install_pre_kube_packages

    - name: 13.6 De-Armor Kubernetes APT Key
      ansible.builtin.shell: gpg --dearmor < /usr/share/keyrings/kubernetes-apt-keyring.gpg_armored > /etc/apt/keyrings/kubernetes-apt-keyring.gpg
      no_log: true
      args:
        creates: /etc/apt/keyrings/kubernetes-apt-keyring.gpg
      tags:
        - install_pre_kube_packages

    - name: 13.7 Add Kubernetes APT Key
      ansible.builtin.shell: |
        set -o pipefail
        echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' \ | sudo tee /etc/apt/sources.list.d/kubernetes.list 
      register: apt_output
      changed_when: apt_output.rc != 0
      args:
        executable: /bin/bash
      tags:
        - install_pre_kube_packages

    - name: 14.1 Update Cache
      ansible.builtin.apt:
        update_cache: true
        autoclean: true
      tags:
        - install_kube_packages

    - name: 14.2 Remove apt lock file
      ansible.builtin.file:
        state: absent
        path: "/var/lib/dpkg/lock"
      tags:
        - install_kube_packages

    - name: 14.3 Install Required Packages
      ansible.builtin.apt:
        name: '{{ kube_packages }}'
      tags:
        - install_kube_packages

    - name: 14.4 Hold Packages
      ansible.builtin.dpkg_selections:
        name: '{{ item }}'
        selection: hold
      with_items: '{{ kube_packages }}'
      tags:
        - install_kube_packages

    - name: Prompt To Continue On To Configuring Control Nodes
      ansible.builtin.pause:
        prompt: Press RETURN when you want to continue configuring the Control nodes!

- name: Setup Controller Nodes
  gather_facts: true
  hosts: masters
  become: true

  tasks:
    - name: 1. Initialize Cluster
      ansible.builtin.shell: |
        set -o pipefail
        sudo kubeadm init --control-plane-endpoint={{ hostvars[inventory_hostname]['ansible_default_ipv4']['address'] }} --pod-network-cidr=10.244.0.0/16
      register: init_cluster_output
      changed_when: init_cluster_output.rc != 0
      args:
        executable: /bin/bash

    - name: 2.1 Create .kube Directory
      ansible.builtin.file:
        path: .kube
        state: directory
        mode: '0755'
      tags:
        - kube_admin_config

    - name: 2.2 Copy Kubernetes Admin Config
      ansible.builtin.copy:
        remote_src: true
        src: /etc/kubernetes/admin.conf
        dest: .kube/config
        mode: '0755'
      tags:
        - kube_admin_config

    - name: 2.3 Change Config File Permission
      ansible.builtin.command: chown {{ ansible_env.USER }}:{{ ansible_env.USER }} ".kube/config"
      changed_when: false
      when: not ansible_env.HOME is undefined
      tags:
        - kube_admin_config

    - name: 3. Install An Overlay Network
      ansible.builtin.shell: |
        set -o pipefail
        kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
      register: init_cluster_output
      become: false
      changed_when: init_cluster_output.rc != 0
      args:
        executable: /bin/bash

    - name: 4.1 Execute Join String Generation Command
      ansible.builtin.command: kubeadm token create --print-join-command
      become: false
      register: join_output
      changed_when: false
      tags:
        - join_string

    - name: 4.2 Display Join String
      ansible.builtin.debug:
        msg: 'Join Command : {{ join_output.stdout }}'
      tags:
        - join_string

    - name: Copy Connection String To A Remote File
      ansible.builtin.template:
        src: k8s_worker_node_connection.j2
        dest: worker_conn_string
        mode: '0755'

    - name: Check Connection String File Exists
      ansible.builtin.stat:
        path: worker_conn_string
      register: conn_file_path_remote

    - name: Fetch The Remote File
      ansible.builtin.fetch:
        src: worker_conn_string
        dest: Remote_Files/worker_conn_string
        flat: true
      when: conn_file_path_remote.stat.exists

    - name: Prompt To Continue On To Configuring Worker Nodes
      ansible.builtin.pause:
        prompt: Press RETURN when you want to continue configuring the Worker nodes!

- name: Join Worker Nodes
  gather_facts: true
  hosts: workers
  become: true
  vars:
    node_conn_string: "{{ lookup('ansible.builtin.file', 'Remote_Files/worker_conn_string') }}"

  tasks:
    - name: 1. Add Worker Nodes To The Controller
      ansible.builtin.command: '{{ node_conn_string }}'
      changed_when: false
      throttle: 1
EOL

# Run the Ansible playbook
ansible-playbook -i inventory playbook.yml --ask-become-pass
