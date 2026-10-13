# VMs for the lab

The playbooks provision OS and K3s on **existing** VMs. Creating the VMs is
left to whichever hypervisor you have (UTM, VirtualBox, Proxmox, cloud
instances). That keeps the Ansible portable, and for drill 6 it means
"destroy the VMs" happens in the hypervisor.

## Requirements

- 3 VMs running Rocky Linux 9 or 10 (minimal install is fine), same architecture.
- SELinux enforcing. The playbook asserts this and fails rather than disabling it.
- A static or DHCP-reserved IP on a network all three VMs share, reachable from the control machine.
- An SSH key for a user with passwordless sudo (`ansible_user` in `hosts.ini`).
  The playbook turns off SSH password auth, so key auth has to work first.
- Sizing: K3s documents a minimum of 2 CPU / 2 GB RAM for a server. Phase 3
  runs `torchrun` workers on the agents, so give the agents more headroom than
  the minimum.

## Ports opened by `rocky_base`

| Port | Nodes | Purpose |
| --- | --- | --- |
| 6443/tcp | server | Kubernetes API |
| 10250/tcp | all | kubelet |
| 8472/udp | all | flannel VXLAN |

The pod CIDR (10.42.0.0/16) and service CIDR (10.43.0.0/16) are added to the
firewalld `trusted` zone, following the K3s docs.

## Single-node VirtualBox (NAT) setup

This is what the lab runs today. The VM keeps its NAT adapter, and the Mac
reaches it through port-forwards:

```bash
VBoxManage controlvm <vm> natpf1 "k3s-api,tcp,127.0.0.1,6443,,6443"   # SSH 2222->22 assumed already present
cp ansible/inventory/hosts.ini.single-node.example ansible/inventory/hosts.ini
```

`kubeconfig_api_url` and `k3s_extra_tls_sans` have to be **host** vars in
the inventory. Inventory group vars lose to the playbook's
`group_vars/all.yml`, and the kubeconfig then points at the VM's unreachable
NAT IP (this happened on the first run).

## Known caveats

- On Rocky 10, the pinned K3s install script falls back to the EL9
  `k3s-selinux` RPM (it has no EL10 branch). If the SELinux policy install
  fails there, use Rocky 9 or check for a newer K3s release.
- ArgoCD pulls from the public GitHub URL in `gitops/bootstrap/`. If the repo
  is private, add a repository credential to ArgoCD. Sealed Secrets arrives in
  phase 2; until then that credential is a one-time manual step outside Git.
