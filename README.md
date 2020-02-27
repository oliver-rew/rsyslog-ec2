# tls-rsyslog config

This repo provides a quick way to setup a tls rsyslog server that backs up to S3. It is specifically tuned for EC2 instances, but could easily be adopted for other servers.

### Install
- Install necessary packages:
```
sudo apt update
sudo apt install -y make gnutls-bin rsyslog-gnutls awscli
```

- Generate certs and install rsyslog config
```
$ sudo make install
```

### Client Config
To configure an `rsyslog` client, you with need to provide it with the URL of the server and  public cert we just generated. 
- You can get the public URL of your server from AWS, but you can also get it with this command:
```
$ host $(dig @resolver1.opendns.com ANY myip.opendns.com +short) | sed 's/.*\(ec2.*\.com\).*/\1/'
ec2-xx-xxx-xx-xxx.us-west-2.compute.amazonaws.com
```
- The client should use port 6514 to connect to the server, but this can be configured.

- The cert is located at `cert/cert.pem`, it can be base64 encoded for clients that are configured that way:
```
$ cat cert/cert.pem | base64 | tr -d \\n
LS0tLS1CRUdJTi...
```

### Notes
- WARNING: This setup uses a self signed CA. This is OK for now, but in the future it would ideally use a real CA
- WARNING: This server setup does not authenticate clients.
- Incoming port 6514 must be open on the server to accept client connections
- The server needs permission to access the destination S3 bucket.
- After the above setup, when some logs have already been spooled to the server, it is helpful to force a log rotation to ensure it is working properly. Use the below command to force a log rotation and check your S3 bucket for the log files.
```
sudo logrotate /etc/logrotate.conf --verbose --force
```
