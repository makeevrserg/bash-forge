# Download manually
# https://github.com/amnezia-vpn/amnezia-client/releases/latest
# https://www.jetbrains.com/toolbox-app/download/download-thanks.html?platform=linux

# Fix IntelCPU+SamsungSSD in boot config
# GT0: GUC: TLB Invalidation response timed out for seqno 45531 -> i915.enable_guc=3
# Random freeze on Samsung SSD -> elevator=bfq nvme_core.default_ps_max_latency_us=5500 pcie_aspm=off intel_idle.max_cstate=1 i915.enable_fbc=0 i915.enable_psr=0 i915.enable_dc=0 ahci.mobile_lpm_policy=1
# sudo find / -name "arch.conf"
# sudo nano /etc/kernel/cmdline
# sudo nano /usr/share/systemd/bootctl/arch.conf
# Add at the end: i915.enable_guc=3 elevator=bfq nvme_core.default_ps_max_latency_us=5500 pcie_aspm=off intel_pstate=active
# sudo bootctl update
# sudo reinstall-kernels
# sudo reboot now