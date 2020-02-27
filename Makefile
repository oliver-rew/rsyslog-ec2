CERTDIR=cert
CAPK=$(CERTDIR)/ca-key.pem
PK=$(CERTDIR)/key.pem
REQ=$(CERTDIR)/request.pem
CA=$(CERTDIR)/ca.pem
CERT=$(CERTDIR)/cert.pem

SYSLOG_USER=syslog
SYSLOG_GRP=adm

# cert template
CERTCFG=$(CERTDIR)/cert.cfg
CERTCFGTMPL=$(CERTCFG).tmpl

# find/replace key in ca config
HOSTNAMEKEY=HOSTNAME

# ca template
CACFG=$(CERTDIR)/ca.cfg
CACFGTMPL=$(CACFG).tmpl

# find/replace key in cert config
COMMONNAMEKEY=COMMON_NAME

# keys used in rsyslog config file to insert key paths
CA_KEY=CA_PATH
CERT_KEY=CERT_PATH
PK_KEY=KEY_PATH

# the tls rsyslog config file
RSYSLOG_TLS_CONF=rsyslog/40-rsyslog-tls.conf
RSYSLOG_TLS_CONF_TMPL=$(RSYSLOG_TLS_CONF).tmpl

# HACK! this gets the public url of an EC2 instance for use in the request
# certificate. If this is running on something else, it might not work. 
URL=$(shell host $(shell dig @resolver1.opendns.com ANY myip.opendns.com +short) | sed 's/.*\(ec2.*\.com\).*/\1/')

all:
	@echo "Please install with 'sudo make install'"
	@exit 0

install: certs rsyslog

# 'rsyslog' creates and installs the needed rsyslog and related config files.
rsyslog: rsyslog_cert_path rsyslog_conf rsyslog_start logrotate

# insert keyfile paths into rsyslog tls config file
rsyslog_cert_path:
	# copy the template so we can modify it
	cp $(RSYSLOG_TLS_CONF_TMPL) $(RSYSLOG_TLS_CONF)
	sed -i 's/$(CA_KEY)/$(shell realpath $(CA) | sed 's/\//\\\//g')/g' $(RSYSLOG_TLS_CONF)
	sed -i 's/$(CERT_KEY)/$(shell realpath $(CERT) | sed 's/\//\\\//g')/g' $(RSYSLOG_TLS_CONF)
	sed -i 's/$(PK_KEY)/$(shell realpath $(PK) | sed 's/\//\\\//g')/g' $(RSYSLOG_TLS_CONF)

# append the config patch to the rsyslog conf file, if not there already, and add our config file
rsyslog_conf:
	grep "$(shell cat rsyslog/rsyslog.conf.patch | head -1)" /etc/rsyslog.conf || (echo "" >> /etc/rsyslog.conf && cat rsyslog/rsyslog.conf.patch >> /etc/rsyslog.conf)
	cp $(RSYSLOG_TLS_CONF) /etc/rsyslog.d/

# restart rsyslog with the new changes
rsyslog_start:
	systemctl restart rsyslog

# add the patch to the logrotate rsyslog config if it doesn't exist already
logrotate:
	grep "$(shell cat logrotate/rsyslog.patch | head -1)" /etc/logrotate.d/rsyslog || (echo "" >> /etc/logrotate.d/rsyslog && cat logrotate/rsyslog.patch >> /etc/logrotate.d/rsyslog)

	# make logrotate run every hour, if it hasn't been moved already
	stat /etc/cron.hourly/logrotate > /dev/null 2>&1 || mv /etc/cron.daily/logrotate /etc/cron.hourly/

# 'certs' creates the required certificates for tls rsyslog. It must be run
# before the 'rsyslog' target below. 
certs: init ca pk req cert owner

# insert hostname and server url into CA and cert config templates.
# It is CRITICAL that the URL match the URL of the server!!!
init:
	cat $(CACFGTMPL) | sed 's/$(HOSTNAMEKEY)/$(shell hostname)/g' > $(CACFG)
	cat $(CERTCFGTMPL) | sed 's/$(COMMONNAMEKEY)/$(URL)/g' > $(CERTCFG)

# genereate private key for cert
pk:
	@certtool --generate-privkey --outfile $(PK) --bits 2048

# create CSR
req:
	@certtool --generate-request --load-privkey $(PK) --outfile $(REQ) --template $(CERTCFG)

# generate the servers public cert
cert:
	@certtool --generate-certificate --load-request $(REQ) --outfile $(CERT) --load-ca-certificate $(CA) --load-ca-privkey $(CAPK) --template $(CERTCFG)
	
# generate a self signed CA
ca: 
	@certtool --generate-privkey --outfile $(CAPK) --bits 2048
	@certtool --generate-self-signed --load-privkey $(CAPK) --outfile $(CA) --template $(CACFG) # TODO auto generate ca.cfg

# give the rsyslog service user and group permission to read the key files
owner:
	chown $(SYSLOG_USER):$(SYSLOG_GRP) $(PK)
	chown $(SYSLOG_USER):$(SYSLOG_GRP) $(CERT)

clean:
	rm -rf $(PK) $(CAPK) $(REQ) $(CA) $(CERT) $(CERTCFG) $(CACFG) $(RSYSLOG_TLS_CONF)

.PHONY: all rsyslog rsyslog_start rsyslog_conf rsyslog_cert_path all install init pk req cert ca clean logrotate
