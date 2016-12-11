ansible-virt-host
=================

[![Build Status](https://travis-ci.org/alzadude/ansible-virt-host.svg?branch=master)](https://travis-ci.org/alzadude/ansible-virt-host)

A role for configuring a Linux system to host Libvirt guests, with OVMF UEFI firmware.

Initially focused on supporting Windows guests, with PCI passthrough possible for any non-boot VGA devices.

**No more rebooting into Windows in order to play Windows-only AAA games!**

Requirements
------------

Currently this role has only been tested against Fedora 24/25 hosts, but in future  other Linux variants will hopefully be supported. Pull requests are welcome!

Additional hardware requirements needed for VGA passthrough:

  - An Intel CPU with support for hardware virtualization and IOMMU

    [List of compatible Intel CPUs (Intel VT-x and Intel VT-d)](http://ark.intel.com/search/advanced?s=t&VTX=true&VTD=true)

  - A mainboard with support for IOMMU

    Both the chipset and the BIOS must support it. It is not always easy to confirm this, but there is a [fairly comprehensive list on the Xen wiki](http://wiki.xen.org/wiki/VTdHowTo) as well as [another list on Wikipedia](https://en.wikipedia.org/wiki/List_of_IOMMU-supporting_hardware).

  - A VGA ROM with support for UEFI

    Check that [any ROM in this list](https://www.techpowerup.com/vgabios/) applies to the VGA device intended for passthrough, and is said to support UEFI. All GPUs from 2012 and later should support this, as Microsoft made UEFI a requirement for devices to be marketed as compatible with Windows 8.

  - A spare monitor, or a monitor with two inputs

    The VGA device will not display anything if there is no screen plugged in, and using a VNC or Spice connection will not help your performance.

  - A mouse and a keyboard that can be passed through to the guest

    If anything goes wrong, there will at least be a way to control the host system.

Role Variables
--------------

- `enable_iommu`

  If set to `true`:
  - The kernel boot flags for IOMMU and VFIO-PCI will be set for the grub bootloader, and as such will be active from the next boot.
  - Additionally, on the next boot any non-boot VGA PCI devices on the host will be isolated/reserved by VFIO-PCI, ready for passthrough to a Libvirt guest.
  - Any user in the `kvm` group will have permission to passthrough PCI host devices to a libvirt guest. This allows passthrough to work for KVM/QEMU user sessions, and avoids the need to run guests as root.
  - Any user in the `kvm` group will have their `memlock` limits set to 10GB. This should permit guests to be created with 8GB RAM allocated.

Dependencies
------------

- Fedora 24+ (temporary, this role is intended to eventually work with other Linux distros)

Installation
------------

Install from Ansible Galaxy by executing the following command:

```
ansible-galaxy install alzadude.virt-host
```

Example Playbook
----------------

The following playbook gives an example of usage. It will enable Intel IOMMU and VFIO-PCI on the host, and reserve/isolate any non-boot VGA devices for VFIO-PCI.

Save the following configuration into files with the specified names:

**playbook.yml:**
```
---

- hosts: linux-workstation
  become: true

  roles:
    - { role: alzadude.virt-host, enable_iommu: true }
```

**hosts:**

```
# Dummy inventory for ansible
linux-workstation ansible_host=localhost ansible_connection=local
```
Then run the playbook with the following command:
```
ansible-playbook -i hosts playbook.yml
```
Example Recipe for a Windows Guest
----------------------------------

After running the example playbook shown above and restarting the host system, it should be possible to create a Windows Libvirt guest and pass through PCI devices as follows:

1. Determine the PCI ID of the Host Devices intended for Passthrough

  TODO

1. Create the Guest Definition
  ```
  virt-install \
   --name my-guest \
   --boot uefi \
   --ram 8192 \
   --cpu host \
   --vcpus 4 \
   --os-type windows \
   --os-variant win10 \
   --disk size=100,bus=scsi,discard=unmap,format=qcow2 \
   --disk <path-to-windows-10-iso-image>,device=cdrom,bus=ide \
   --disk /usr/share/virtio-win/virtio-win.iso,device=cdrom,bus=ide \
   --controller type=scsi,model=virtio-scsi \
   --network default,model=virtio \
   --graphics spice,listen=0.0.0.0 \
   --input tablet \
   --host-device <pci-id-of-host-vga-device> \
   --host-device <pci-id-of-host-audio-device> \
   --noautoconsole \
   --print-xml > my-guest.xml
  ```
1. Edit the Libvirt Definition if Necessary

  e.g. for Nvidia GPUs:
  https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF#.22Error_43_:_Driver_failed_to_load.22_on_Nvidia_GPUs_passed_to_Windows_VMs

  TODO Define an XSL transform to automate this step.

1. Define the Guest

  ```
  virsh define my-guest.xml --validate
  ```
1. Start the Guest

  ```
  virsh start my-guest
  ```
1. Complete the Windows Installation

  ```
  virt-viewer my-guest
  ```

Troubleshooting
---------------

- Intel HDMI/DP Audio Broken with `intel_iommu=on`

  Fix - Don't use a Haswell CPU: https://bbs.archlinux.org/viewtopic.php?id=204460, https://bugzilla.kernel.org/show_bug.cgi?id=60769

- Nvidia HDMI/DP Audio Stutter/Slow when Passed Through

  Fix - Enable MSI for the affected device: http://vfio.blogspot.co.uk/2014/09/vfio-interrupts-and-how-to-coax-windows.html

Performance Optimisation and Tuning
-----------------------------------

- CPU Configuration, Topology and Pinning   

  https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF#CPU_pinning

- CPU Frequency Scaling

  http://unix.stackexchange.com/questions/64297/host-cpu-does-not-scale-frequency-when-kvm-guest-needs-it https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF#CPU_frequency_governor

- Huge Pages

  https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF#Static_huge_pages

Development
-----------

### Running the Tests

```
sudo dnf install bats ansible docker
sudo systemctl start docker
git clone https://github.com/alzadude/ansible-virt-host.git
cd ansible-virt-host
bats tests/
```

Credits
-------

- http://vfio.blogspot.co.uk/2015/05/vfio-gpu-how-to-series-part-1-hardware.html (plus parts 2 - 5)
- https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF
- https://fedoraproject.org/wiki/Windows_Virtio_Drivers

License
-------

MIT
