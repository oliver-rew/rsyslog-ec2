CERTDIR=cert
CAPK=$(CERTDIR)/ca-key.pem
PK=$(CERTDIR)/key.pem
REQ=$(CERTDIR)/request.pem
CA=$(CERTDIR)/ca.pem
CERT=$(CERTDIR)/cert.pem

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

RSYSLOG_TLS_CONF=rsyslog/tlsserver.conf

# TODO PERMISSIONs?
# TODO gate sudo

# HACK! this gets the public url of an EC2 instance for use in the request
# certificate. If this is running on something else, it might not work. 
URL=$(shell host $(shell dig @resolver1.opendns.com ANY myip.opendns.com +short) | sed 's/.*\(ec2.*\.com\).*/\1/')

all: init ca pk req cert

#install:

rsyslog_cert_path:
	#cat rsyslog/tlsserver.conf | sed 's/$(CA_KEY)/$(shell realpath $(CA) | sed 's/\//\\\//g')/g'
	#cat rsyslog/tlsserver.conf | sed 's/$(CERT_KEY)/$(shell realpath $(CERT) | sed 's/\//\\\//g')/g'
	#cat rsyslog/tlsserver.conf | sed 's/$(PK_KEY)/$(shell realpath $(PK) | sed 's/\//\\\//g')/g'
	sed -i 's/$(CA_KEY)/$(shell realpath $(CA) | sed 's/\//\\\//g')/g' $(RSYSLOG_TLS_CONF)
	sed -i 's/$(CERT_KEY)/$(shell realpath $(CERT) | sed 's/\//\\\//g')/g' $(RSYSLOG_TLS_CONF)
	sed -i 's/$(PK_KEY)/$(shell realpath $(PK) | sed 's/\//\\\//g')/g' $(RSYSLOG_TLS_CONF)


# insert hostname and server url into CA and cert config templates.
# It is CRITICAL that the URL match the URL of the server!!!
init:
	cat $(CACFGTMPL) | sed 's/$(HOSTNAMEKEY)/$(shell hostname)/g' > $(CACFG)
	cat $(CERTCFGTMPL) | sed 's/$(COMMONNAMEKEY)/$(URL)/g' > $(CERTCFG)

# genereate private key for cert
pk:
	certtool --generate-privkey --outfile $(PK) --bits 2048

# create CSR
req:
	certtool --generate-request --load-privkey $(PK) --outfile $(REQ) --template $(CERTCFG)

# generate the servers public cert
cert:
	certtool --generate-certificate --load-request $(REQ) --outfile $(CERT) --load-ca-certificate $(CA) --load-ca-privkey $(CAPK) --template $(CERTCFG)
	
# generate a self signed CA
ca: 
	certtool --generate-privkey --outfile $(CAPK) --bits 2048
	certtool --generate-self-signed --load-privkey $(CAPK) --outfile $(CA) --template $(CACFG) # TODO auto generate ca.cfg

clean:
	rm -rf $(PK) $(CAPK) $(REQ) $(CA) $(CERT) $(CERTCFG) $(CACFG)

