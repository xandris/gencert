# gencert

A small utility to help make certificates. It's basically just all the OpenSSL commands that you normally need to remember written info a Makefile.

## The root CA certificate

Before you can issue certificates, `Makefile` will create a root CA certificate based on `root-ca.subj`. If you customize this file, `Makefile` will generate a new root CA certificate, so be careful!

## Usage

The Makefile can create files using this supply chain:

	root-ca.crt<--+
				  |
	root-ca.key<--+
	              |
	foo.subj<-----+----------+
	                         |
	foo.key<------foo.req<---foo.crt
	      ^                  ^
	      |                  |
	      +-----foo.p12------+
	            ^
		        |
		        foo.jks

`foo.subj` is created by you by hand and should contain an X509 distinguished name (DN) in a format OpenSSL can understand. This can be as simple as

	/CN=Foo Bar

or, more realistically

	/DC=org/DC=example/OU=Users/CN=Foo Bar

Once the `.subj` file is in place, you can create any file along the chain:

	make foo.key
	make foo.req
	make foo.crt
	make foo.p12
	make foo.jks

Just say `make foo.jks` to make everything.

### Java Keystore (JKS) Support

Creating `.jks` files requires `keytool` be on the current `$PATH`.

### OCSP Support

_gencert_ can act like an OCSP responder. First, generate certificates with authority info:

	make EXTENSIONS=v3_req_aia foo.p12

Next, create an `index.txt` based on these certificates:

	TODO, forgot how to do this

Finally, run the OCSP responder:

	make ocsp

## Configuration

### Root CA DN

The DN of the root CA is controlled by `root-ca.subj`.

### X509v3 Extensions

X509 extensions for client certificates are stored in `openssl.cnf`. To customize this, add a new section to the file:

	[ custom_v3_req ]
	# Extensions to add to a certificate request
	basicConstraints = CA:FALSE
	keyUsage = nonRepudiation, digitalSignature, keyEncipherment
	authorityInfoAccess = OCSP;URI:http://localhost:8888

And create the request, certificate, or keystore with an appropriate `EXTENSIONS` argument:

	make EXTENSIONS=custom_v3_req foo.p12

(_gencert_ has to at least create the `.req` file for this to work, so you must remove it to change the extensions a particular cert has.)

### Passwords

Passwords are set in `Makefile` itself:

	# Plain text password for the output files
	PLAINPASS:=password
	
	# Comment these out to have OpenSSL or keytool prompt for passwords
	CAPASS:=pass:$(PLAINPASS)
	KEYPASS:=pass:$(PLAINPASS)
	P12PASS:=pass:$(PLAINPASS)
	JKSPASS:=$(PLAINPASS)

By default, all passwords are `password`. If those variables are unset, `Makefile` will prompt multiple times for various passwords. This can be a  bit confusing if generating a file that is derived from many other files, so it's probably a better idea to generate them one at a time in this configuration. Any one variable can be unset to protect just that one password (e.g. the CA key password).

