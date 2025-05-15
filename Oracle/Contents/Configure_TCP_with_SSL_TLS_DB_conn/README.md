# Configure Oracle TCP/IP With SSL/TLS


## Prerequisites and Assumptions

This article assumes the following prerequisites are in place.

- A functioning database server. In this case we are using Oracle 12c (12.1.0.2) running on Oracle Linux 7 (OL7) and the server name is "ol7-121.localdomain". The setup is the same for other versions of the database and Linux.
- A client machine with an Oracle Client installed. In this case we are using an Oracle 11.2.0.3 client installed on a Windows 7 PC called "my-computer".
- There are no local or network firewalls blocking communication with the server on port 2484.
- The examples in this article use self signed certificates, but you can just as easily use proper certificate authority certificates if you prefer. This is probably not necessary as you will only be using these certificates inside your own organisation, or possibly to communicate between your on-premise and cloud infrastructure.

## Server Wallet and Certificate


Create a new auto-login wallet.

```bash
$ mkdir -p /u01/app/oracle/wallet

$ orapki wallet create -wallet "/u01/app/oracle/wallet" -pwd WalletPasswd123 -auto_login_local
Oracle PKI Tool : Version 12.1.0.2
Copyright (c) 2004, 2014, Oracle and/or its affiliates. All rights reserved.

$
```

Create a self-signed certificate and load it into the wallet.

```bash
$ orapki wallet add -wallet "/u01/app/oracle/wallet" -pwd WalletPasswd123 \
  -dn "CN=`hostname`" -keysize 1024 -self_signed -validity 3650
Oracle PKI Tool : Version 12.1.0.2
Copyright (c) 2004, 2014, Oracle and/or its affiliates. All rights reserved.

$
```

Check the contents of the wallet. Notice the self-signed certificate is both a user and trusted certificate.

```bash
$ orapki wallet display -wallet "/u01/app/oracle/wallet" -pwd WalletPasswd123
Oracle PKI Tool : Version 12.1.0.2
Copyright (c) 2004, 2014, Oracle and/or its affiliates. All rights reserved.

Requested Certificates:
User Certificates:
**Subject:        CN=ol7-121.localdomain**
Trusted Certificates:
**Subject:        CN=ol7-121.localdomain**
$
```

Export the certificate, so we can load it into the client wallet later.

```bash
$ orapki wallet export -wallet "/u01/app/oracle/wallet" -pwd WalletPasswd123 \
   -dn "CN=`hostname`" -cert /tmp/`hostname`-certificate.crt
Oracle PKI Tool : Version 12.1.0.2
Copyright (c) 2004, 2014, Oracle and/or its affiliates. All rights reserved.

$
```

Check the certificate has been exported as expected.

```bash
$ cat /tmp/`hostname`-certificate.crt
-----BEGIN CERTIFICATE-----
MIIBqzCCARQCAQAwDQYJKoZIhvcNAQEEBQAwHjEcMBoGA1UEAxMTb2w3LTEyMS5sb2NhbGRvbWFp
bjAeFw0xNTA2MjYxNDQyMDJaFw0yNTA2MjMxNDQyMDJaMB4xHDAaBgNVBAMTE29sNy0xMjEubG9j
YWxkb21haW4wgZ8wDQYJKoZIhvcNAQEBBQADgY0AMIGJAoGBAJIrU1fGWAwMxRobFsS0UZBD1jFU
wAvnH9blsynhrQrZSkwyMBWGPRFq5tufRpaifoNVVHSrjJm/nti62A6RXECAKsug9rHL8T11FOgP
3R/+Itw2jLzwpdk7MbHMxpNHz6Y2IPCmBsJ5+625dRxugVKhLsIitAW5cUpT28bkrMl9AgMBAAEw
DQYJKoZIhvcNAQEEBQADgYEABqQaP056WcPNgzSAOhJgTU/6D8uAFGCgUN57HoraXxgAN3HgmeGq
hQfpb8tP+xeTF3ecqvWqJQHGdAJbuhRwpNR1rRovvlOxiv4gl0AplRzRuiygXfi6gst7KNmAdoxr
TOcUQsqf/Ei9TaFl/N8E+88T2fK67JHgFa4QDs/XZWM=
-----END CERTIFICATE-----
$
```

## Client Wallet and Certificate

Create a new auto-login wallet.

```bash
c:\>mkdir -p c:\app\oracle\wallet

c:\>orapki wallet create -wallet "c:\app\oracle\wallet" -pwd WalletPasswd123 -auto_login_local
Oracle PKI Tool : Version 11.2.0.3.0 - Production
Copyright (c) 2004, 2011, Oracle and/or its affiliates. All rights reserved.

c:\>
```

Create a self-signed certificate and load it into the wallet.

```bash
c:\>orapki wallet add -wallet "c:\app\oracle\wallet" -pwd WalletPasswd123 -dn "CN=%computername%" -keysize 1024 -self_signed -validity 3650
Oracle PKI Tool : Version 11.2.0.3.0 - Production
Copyright (c) 2004, 2011, Oracle and/or its affiliates. All rights reserved.

c:\>
```

Check the contents of the wallet. Notice the self-signed certificate is both a user and trusted certificate.

```bash
c:\>orapki wallet display -wallet "c:\app\oracle\wallet" -pwd WalletPasswd123
Oracle PKI Tool : Version 11.2.0.3.0 - Production
Copyright (c) 2004, 2011, Oracle and/or its affiliates. All rights reserved.

Requested Certificates:
User Certificates:
**Subject:        CN=my-computer**
Trusted Certificates:
Subject:        OU=Class 2 Public Primary Certification Authority,O=VeriSign\, Inc.,C=US
Subject:        OU=Secure Server Certification Authority,O=RSA Data Security\, Inc.,C=US
Subject:        CN=GTE CyberTrust Global Root,OU=GTE CyberTrust Solutions\, Inc.,O=GTE Corporation,C=US
**Subject:        CN=my-computer**
Subject:        OU=Class 3 Public Primary Certification Authority,O=VeriSign\, Inc.,C=US
Subject:        OU=Class 1 Public Primary Certification Authority,O=VeriSign\, Inc.,C=US

c:\>
```

Export the certificate so we can load it into the server later.

```bash
c:\>orapki wallet export -wallet "c:\app\oracle\wallet" -pwd WalletPasswd123 -dn "CN=%computername%" -cert c:\%computername%-certificate.crt
Oracle PKI Tool : Version 11.2.0.3.0 - Production
Copyright (c) 2004, 2011, Oracle and/or its affiliates. All rights reserved.

c:\>
```

Check the certificate.

```bash
c:\>more c:\%computername%-certificate.crt
-----BEGIN CERTIFICATE-----
MIIBmzCCAQQCAQAwDQYJKoZIhvcNAQEEBQAwFjEUMBIGA1UEAxMLSVRTLUYxTUxDNUowHhcNMTUw
NjI2MDkzMzE2WhcNMjUwNjIzMDkzMzE2WjAWMRQwEgYDVQQDEwtJVFMtRjFNTEM1SjCBnzANBgkq
hkiG9w0BAQEFAAOBjQAwgYkCgYEAk/oX7ulDhW+DKXdD+qYC9DN7DoTsmeGZaW7EwYr48sw2qQWK
HP3pFb8/eVLHuqd2tX8RCniI6Dy5iMe7aM+BOvtGDT2bkCENO7xflww+L/Jp1JeF4OCawE36/Coy
sWAu4yom7n109ioT2rQsN62ERj8wPa53r8KAB12UnidBzRECAwEAATANBgkqhkiG9w0BAQQFAAOB
gQB7hbEUXM3ur2H2osuaX24mxmw83yxLnvx9BDi10kbTdH02St/EfCNlCWc69L5iAeJVESvaVgJQ
u1AZEeD3jPYMFWTnGfX4txo7+GJWwpxCJXqYYrmYQL2h1W6UtTVsJgQ08wo2bTHTjII6HB6wt8CK
OU46CFGLL+7B7Xrpnk1UwA==
-----END CERTIFICATE-----

c:\>
```

## Exchange Certificates

Each side of the connection needs to trust the other, so we must load the certificate from the server as a trusted certificate into the client wallet and vice versa.

Load the server certificate into the client wallet.

```bash
c:\>orapki wallet add -wallet "c:\app\oracle\wallet" -pwd WalletPasswd123 -trusted_cert -cert c:\ol7-121.localdomain-certificate.crt
Oracle PKI Tool : Version 11.2.0.3.0 - Production
Copyright (c) 2004, 2011, Oracle and/or its affiliates. All rights reserved.

c:\>
```

Check the contents of the client wallet. Notice the server certificate is now included in the list of trusted certificates.

```bash
c:\>orapki wallet display -wallet "c:\app\oracle\wallet" -pwd WalletPasswd123 
Oracle PKI Tool : Version 11.2.0.3.0 - Production
Copyright (c) 2004, 2011, Oracle and/or its affiliates. All rights reserved.

Requested Certificates:
User Certificates:
**Subject:        CN=my-computer**
Trusted Certificates:
Subject:        OU=Secure Server Certification Authority,O=RSA Data Security\, Inc.,C=US
Subject:        OU=Class 2 Public Primary Certification Authority,O=VeriSign\, Inc.,C=US
**Subject:        CN=my-computer**
Subject:        OU=Class 3 Public Primary Certification Authority,O=VeriSign\, Inc.,C=US
Subject:        OU=Class 1 Public Primary Certification Authority,O=VeriSign\, Inc.,C=US
**Subject:        CN=ol7-121.localdomain**
Subject:        CN=GTE CyberTrust Global Root,OU=GTE CyberTrust Solutions\, Inc.,O=GTE Corporation,C=US

c:\>
```

Load the client certificate into the server wallet.

```bash
$ orapki wallet add -wallet "/u01/app/oracle/wallet" -pwd WalletPasswd123 \
   -trusted_cert -cert /tmp/my-computer-certificate.crt
Oracle PKI Tool : Version 12.1.0.2
Copyright (c) 2004, 2014, Oracle and/or its affiliates. All rights reserved.

$
```

Check the contents of the server wallet. Notice the client certificate is now included in the list of trusted certificates.

```bash
$ orapki wallet display -wallet "/u01/app/oracle/wallet" -pwd WalletPasswd123
Oracle PKI Tool : Version 12.1.0.2
Copyright (c) 2004, 2014, Oracle and/or its affiliates. All rights reserved.

Requested Certificates:
User Certificates:
**Subject:        CN=ol7-121.localdomain**
Trusted Certificates:
**Subject:        CN=my-computer**
**Subject:        CN=ol7-121.localdomain**
$
```

## Server Network Configuration

On the server, add the following entries into the "$ORACLE_HOME/network/admin/sqlnet.ora" file.

```bash
WALLET_LOCATION =
   (SOURCE =
     (METHOD = FILE)
     (METHOD_DATA =
       (DIRECTORY = /u01/app/oracle/wallet)
     )
   )

SQLNET.AUTHENTICATION_SERVICES = (TCPS,NTS,BEQ)
SSL_CLIENT_AUTHENTICATION = FALSE
SSL_CIPHER_SUITES = (SSL_RSA_WITH_AES_256_CBC_SHA, SSL_RSA_WITH_3DES_EDE_CBC_SHA)
```

>You probably need to think about what cipher suites you want to support. You may wish to avoid those that support SSLv3 in favor of those that support TLS only. Your decision my vary depending on the Oracle database and client versions.

Configure the listener to accept SSL/TLS encrypted connections. Edit the "$ORACLE_HOME/network/admin/listener.ora" file, adding the wallet information, as well as the TCPS entry.

```bash
**SSL_CLIENT_AUTHENTICATION = FALSE

WALLET_LOCATION =
  (SOURCE =
    (METHOD = FILE)
    (METHOD_DATA =
      (DIRECTORY = /u01/app/oracle/wallet)
    )
  )**

LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ol7-121.localdomain)(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
      **(ADDRESS = (PROTOCOL = TCPS)(HOST = ol7-121.localdomain)(PORT = 2484))**
    )
  )

ADR_BASE_LISTENER = /u01/app/oracle
```

Restart the listener.

```
$ lsnrctl stop
$ lsnrctl start
```

The server is now configured.

## Client Network Configuration

Edit the "$ORACLE_HOME/network/admin/sqlnet.ora" file, adding the following lines.

```
WALLET_LOCATION =
   (SOURCE =
     (METHOD = FILE)
     (METHOD_DATA =
       (DIRECTORY = c:\app\oracle\wallet)
     )
   )

SQLNET.AUTHENTICATION_SERVICES = (TCPS,NTS)
SSL_CLIENT_AUTHENTICATION = FALSE
SSL_CIPHER_SUITES = (SSL_RSA_WITH_AES_256_CBC_SHA, SSL_RSA_WITH_3DES_EDE_CBC_SHA)
```

>Make sure the client cipher suites match the server configuration.

Edit the "$ORACLE_HOME/network/admin/tnsnames.ora" file, making sure the port corresponds to that configured for SSL on the server and the protocol is TCPS.

```
pdb1_ssl=
  (DESCRIPTION=
    (ADDRESS=
      (PROTOCOL=TCPS)
      (HOST=ol7-121.localdomain)
      (PORT=2484)
    )
    (CONNECT_DATA=
      (SERVER=dedicated)
      (SERVICE_NAME=pdb1)
    )
  )
```

The client is now configured.

## Test Connection

You should now be able to make a connection to the server using the SSL/TLS enabled TNS entry.


```
c:\>sqlplus test/test@pdb1_ssl

SQL*Plus: Release 11.2.0.3.0 Production on Fri Jun 26 16:23:28 2015

Copyright (c) 1982, 2011, Oracle.  All rights reserved.

Connected to:
Oracle Database 12c Enterprise Edition Release 12.1.0.2.0 - 64bit Production
With the Partitioning, OLAP, Advanced Analytics and Real Application Testing options

SQL>
```

