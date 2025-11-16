
# Create user
*On remote VPS*
```bash
# Creating user
sudo adduser tunnel
sudo passwd -l tunnel
# Create dirs
sudo mkdir -p /home/tunnel/.ssh
sudo chown tunnel:tunnel /home/tunnel/.ssh
chmod 700 /home/tunnel/.ssh
# Edit config. Att this at start
nano /home/tunnel/.ssh/authorized_keys
command="echo 'This account is only for reverse SSH tunneling'",no-agent-forwarding,no-X11-forwarding,no-pty
sudo systemctl restart ssh
```

# Edit sshd config
*On remote VPS*
Set here `GatewayPorts yes`
```bash
nano /etc/ssh/sshd_config
sudo systemctl restart ssh
```

# Create ssh keys
*On local VPS*
```bash
TUNNEL_IP=YOUR_REMOTE_IP
mkdir ssh
# Create ssh with empty passphrase
ssh-keygen -t ed25519 -f ./ssh/id_rsa
# Copy onto remote VPS
ssh-copy-id -i ./ssh/id_rsa.pub tunnel@$TUNNEL_IP
# Create known_hosts
ssh-keyscan -t ed25519 $TUNNEL_IP >> ./ssh/known_hosts
# Setup permissions
chmod 700 ssh
chmod 600 ssh/id_rsa
chmod 644 ssh/id_rsa.pub
chmod 644 ssh/known_hosts
```
# Add into docker
```yaml
  reverse-tunnel-YOUR_DOCKER_SERVICE:
    image: alpine:latest
    container_name: reverse-tunnel-YOUR_DOCKER_SERVICE
    restart: unless-stopped
    command: >
      sh -c "apk add --no-cache openssh && ssh -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /root/.ssh/id_rsa -N -R 0.0.0.0:YOUR_DOCKER_PORT:YOUR_DOCKER_SERVICE:YOUR_DOCKER_PORT tunnel@YOUR_REMOTE_IP"
    volumes:
      - ./ssh:/root/.ssh:ro
    depends_on:
      - YOUR_DOCKER_SERVICE
```
