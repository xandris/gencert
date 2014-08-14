# CA certificate file
CACERT=root-ca.crt

# CA private key
CAKEY=root-ca.key

# CA serial file; will be generated if it doesn't exist
CASRL=root-ca.srl

# CA's DN
CASUBJ=root-ca.subj

# Plain text password for the output files
PLAINPASS:=password

# Comment these out to have OpenSSL or keytool prompt for passwords
CAPASS:=pass:$(PLAINPASS)
KEYPASS:=pass:$(PLAINPASS)
P12PASS:=pass:$(PLAINPASS)
JKSPASS:=$(PLAINPASS)

DAYS:=365

EXTENSIONS:=v3_req

# The targets

# Only use this to generate the standard four certs for the ONR RI
all: $(P12S) $(JKSES) $(CRTS) $(REQS)

# Copies the certs to the appropriate VMs
ssh: $(addsuffix .ssh,$(NAMES))

# Removes only the standard certs
clean:
	-rm $(P12S) $(JKSES) $(CRTS) $(REQS) 2>/dev/null

# Make an arbitrary JKS; depends on/will make the PKCS#12 archive
%.jks : %.p12
	keytool -importkeystore -srckeystore "$<" -srcstoretype pkcs12 $(if $(findstring pass:,$(P12PASS)),-srcstorepass '$(subst pass:,,$(P12PASS))') -destkeystore "$@" $(if $(JKSPASS), -deststorepass '$(JKSPASS)')

# Make an arbitrary PKCS#12 archive; depends on/will make the certificate and key files
%.p12 : %.crt %.key
	openssl pkcs12 -export -in "$*.crt" -inkey "$*.key" -out "$@" $(if $(KEYPASS),-passin '$(KEYPASS)') $(if $(P12PASS),-passout '$(P12PASS)')

# Make the root certificate
$(CACERT) : $(CAKEY)
	openssl req -new -x509 -days 3650 -key '$(CAKEY)' -out '$(CACERT)' -config openssl.cnf $(if $(CAPASS),-passin '$(CAPASS)') -subj "$$(cat '$(CASUBJ)')"

# Make an arbitrary X509 certificate, depends on/will make a certificate request
%.crt : %.req $(CACERT) $(CAKEY) $(CASUBJ)
	openssl x509 -req -in "$<" -out "$@" -CA '$(CACERT)' -CAkey '$(CAKEY)' -CAserial '$(CASRL)' -CAcreateserial -days 365 $(if $(CAPASS),-passin '$(CAPASS)') -extfile openssl.cnf -extensions $(EXTENSIONS)

# Make an arbitrary certificate request. Depends on/will make the private key
#
# Uses a file named something.subj; that file should contain just the DN on
# one line.

%.req : %.key %.subj
	openssl req -new -subj "$$(cat '$*.subj')" -key "$<" -out "$@" $(if $(KEYPASS),-passin '$(KEYPASS)') -config openssl.cnf -extensions $(EXTENSIONS)

%.subj :
	@echo $@ must exist first... >&2
	exit 1

# Make an arbitrary, encrypted, private key.
%.key :
	openssl genrsa -des -out "$@" $(if $(KEYPASS),-passout '$(KEYPASS)') 4096

$(CAKEY) :
	openssl genrsa -des -out "$@" $(if $(CAPASS),-passout '$(CAPASS)') 4096

ocsp.req : ocsp.key ocsp.subj
	openssl req -new -subj "$$(cat 'ocsp.subj')" -key "$<" -out "$@" $(if $(KEYPASS),-passin '$(KEYPASS)') -config openssl.cnf -extensions v3_ocsp

ocsp.crt : ocsp.req $(CACERT) $(CAKEY) $(CASUBJ)
	openssl x509 -req -in "$<" -out "$@" -CA '$(CACERT)' -CAkey '$(CAKEY)' -CAserial '$(CASRL)' -CAcreateserial -days 365 $(if $(CAPASS),-passin '$(CAPASS)') -extfile openssl.cnf -extensions v3_ocsp

ocsp : ocsp.crt ocsp.key root-ca.crt index.txt
	openssl ocsp -rsigner ocsp.crt -rkey ocsp.key -port 8888 -CA '$(CACERT)' -index index.txt -text

truststore.jks : $(CACERT) ocsp.crt
	keytool -importcert -keystore "$@" $(if $(JKSPASS),-storepass "$(JKSPASS)") -file $(CACERT) -alias $(CACERT)
	keytool -importcert -keystore "$@" $(if $(JKSPASS),-storepass "$(JKSPASS)") -file ocsp.crt  -alias ocsp.crt
 
.SECONDARY :

.PHONY : ocsp

