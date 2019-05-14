# vagrant_kerberos #

This simple test environment will emulate an Active Directory environment and allow you to easily test your LDAP and Kerberos enabled Greenplum applications. 

The domain controller is setup on Ubuntu using Samba 4.

# Details #

* See `Vagrantfile` for changes to the IP address.
* See `dcpromo.debconf` for changes to the Domain Controller.

# Prerequsites #

* [Vagrant](https://www.vagrantup.com/downloads.html)
* [Virtual Box](https://www.virtualbox.org/wiki/Downloads)
* Vagrant Hosts Plugin: `vagrant plugin install vagrant-hosts`
  * This allows us to provision the hosts files for all the instances.

# Usage #

- [ ] Clone this repository.
- [ ] Run `vagrant up`. 

This will launch and provision the Domain Controller.
For the purposes of testing, `configure-pdc.sh` script will:

  * Disable `server require strong auth` which forces BIND over SSL:

```
sed -i "/\[global\]/a\\\tldap server require strong auth = no" /etc/samba/smb.conf
```

  * Disable Password Complexity:

```
samba-tool domain passwordsettings set --complexity=off --history-length=0 --min-pwd-age=0 --max-pwd-age=0
```

# Greenplum LDAP BIND Example #

Your gpdb instance will need to be able to resolve the domain controller (default: 192.168.99.10 greenplum.local)
If you are having trouble resolving, make sure your VirtualBox network adapter is correct (default: vboxnet0).

- [ ] Create An LDAP Bind User: 
  * `sudo samba-tool user add samba changeme`

- [ ] Enable The User Account: 
  * `sudo samba-tool user enable samba`

- [ ] Test Simple Bind: 
  * ldapsearch is included with the OpenLDAP Clients (yum install openldap-clients)

```
ldapsearch -x -h greenplum.local -b "dc=greenplum,dc=local" -D "CN=samba,CN=users,DC=greenplum,DC=local" -w changeme "(samAccountName=samba)" dn
 
# extended LDIF
#
# LDAPv3
# base <dc=greenplum,dc=local> with scope subtree
# filter: (samAccountName=samba)
# requesting: dn
#

# samba, Users, greenplum.local
dn: CN=samba,CN=Users,DC=greenplum,DC=local

# search reference
ref: ldap://greenplum.local/CN=Configuration,DC=greenplum,DC=local

# search reference
ref: ldap://greenplum.local/DC=DomainDnsZones,DC=greenplum,DC=local

# search reference
ref: ldap://greenplum.local/DC=ForestDnsZones,DC=greenplum,DC=local

# search result
search: 2
result: 0 Success

# numResponses: 5
# numEntries: 1
# numReferences: 3
```

- [ ] Modify pg_hba.conf

```
host     all         samba     0.0.0.0/0        ldap ldapserver=greenplum.local ldapprefix="cn=" ldapsuffix=",cn=users,dc=greenplum,dc=local"

gpstop -u

20180725:03:54:38:027412 gpstop:gpdb:gpadmin-[INFO]:-Signalling all postmaster processes to reload
...
[gpadmin@gpdb ~]$ psql -U samba -h gpdb
Password for user samba:
psql (8.2.15)
Type "help" for help.
```

# Greenplum LDAP SEARCH+BIND Example #

- [ ] Complete Steps For BIND Example

- [ ] Create SEARCH LDAP Account:
  * `sudo samba-tool user add gpadmin changeme`

- [ ] Enable The User Account: 
  * `sudo samba-tool user enable gpadmin`

- [ ] Test Simple Bind: 

```
ldapsearch -x -h greenplum.local -b "dc=greenplum,dc=local" -D "CN=samba,CN=users,DC=greenplum,DC=local" -w changeme "(samAccountName=samba)" dn
 
# extended LDIF
#
# LDAPv3
# base <dc=greenplum,dc=local> with scope subtree
# filter: (samAccountName=samba)
# requesting: dn
#

# samba, Users, greenplum.local
dn: CN=samba,CN=Users,DC=greenplum,DC=local

# search reference
ref: ldap://greenplum.local/CN=Configuration,DC=greenplum,DC=local

# search reference
ref: ldap://greenplum.local/DC=DomainDnsZones,DC=greenplum,DC=local

# search reference
ref: ldap://greenplum.local/DC=ForestDnsZones,DC=greenplum,DC=local

# search result
search: 2
result: 0 Success

# numResponses: 5
# numEntries: 1
# numReferences: 3
```

- [ ] Modify pg_hba.conf

```
host     all         samba     0.0.0.0/0        ldap ldapserver=greenplum.local ldapbasedn="cn=users,dc=greenplum,dc=local" ldabbindnd="cn=gpadmin,cn=users,dc=greenplum,dc=local" ldapbindpasswd="changeme" ldapsearchattribute="samAccountName"

gpstop -u

20180725:03:54:38:027412 gpstop:gpdb:gpadmin-[INFO]:-Signalling all postmaster processes to reload
...
[gpadmin@gpdb ~]$ psql -U samba -h gpdb
Password for user samba:
psql (8.2.15)
Type "help" for help.
```

# Greenplum Kerberos Example #

To install packages for a Kerberos client:
`yum install krb5-workstation krb5-libs krb5-auth-dialog`

When you set up the Greenplum Database environment by sourcing the greenplum-db_path.sh script, the LD_LIBRARY_PATH environment variable is set to include the Greenplum Database lib directory, which includes Kerberos libraries. 

This may cause Kerberos utility commands such as kinit and klist to fail due to version conflicts. 

The solution is to run Kerberos utilities before you source the greenplum-db_path.sh file or temporarily unset the LD_LIBRARY_PATH variable when you execute Kerberos utilities.

```
[gpadmin@gpdb ~]$ klist
klist: relocation error: klist: symbol krb5_is_config_principal, version krb5_3_MIT not defined in file libkrb5.so.3 with link time reference

export LD_LIBRARY_PATH=/lib64:$LD_LIBRARY_PATH
```

- [ ] Generate a Service Principal Name (SPN) on the DC: 

  * Active directory requires Kerberos service principal names to be mapped to a user account before a keytab can be generated. 
  * Be sure to match the service name with the krb_srvname.
  * Note with SAMBA AD, it's not necessary to add the realm when adding an SPN; it is automatically included.

```
# Create the Account
sudo samba-tool user create gpadmin --random-password (or set a password)
sudo samba-tool user enable gpadmin

# Add the SPN
sudo samba-tool spn add postgresql/gpdb gpadmin
sudo samba-tool spn list gpadmin

User CN=gpdb_service,CN=Users,DC=greenplum,DC=local has the following servicePrincipalName:
	 postgres/gpdb@GREENPLUM.LOCAL

# Export a Keytab
sudo samba-tool domain exportkeytab --principal="postgres/gpdb" krb5.keytab
sudo klist -k krb5.keytab

Keytab name: FILE:krb5.keytab
KVNO Principal
---- --------------------------------------------------------------------------
   1 postgres/gpdb@GREENPLUM.LOCAL
   1 postgres/gpdb@GREENPLUM.LOCAL
   1 postgres/gpdb@GREENPLUM.LOCAL

# Copy to MDW
sudo scp krb5.keytab gpadmin@gpdb:~

# Verify Parameters
[gpadmin@gpdb ~]$ psql -c "show krb_server_keyfile"
    krb_server_keyfile
---------------------------
 /home/gpadmin/krb5.keytab
(1 row)

[gpadmin@gpdb ~]$ psql -c "show krb_srvname"
 krb_srvname
-------------
 postgres
(1 row)

```


- [ ] Modify Greenplum krb5.conf: 

  * In this example, I have only modifed the REALM information from the default /etc/krb5.conf --

```
# Configuration snippets may be placed in this directory as well
includedir /etc/krb5.conf.d/

[logging]
 default = FILE:/var/log/krb5libs.log
 kdc = FILE:/var/log/krb5kdc.log
 admin_server = FILE:/var/log/kadmind.log

[libdefaults]
 dns_lookup_realm = false
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true
 rdns = false
 default_realm = GREENPLUM.LOCAL
 default_ccache_name = KEYRING:persistent:%{uid}

[realms]
 GREENPLUM.LOCAL = {
  kdc = greenplum.local
  admin_server = greenplum.local
 }

[domain_realm]
 .greenplum.local = GREENPLUM.LOCAL
 greenplum.local = GREENPLUM.LOCAL
 ```

- [ ] Modify pg_hba.conf

  * Remember *the FIRST matching rule prevails...*

```
# Edit pg_hba.conf
host     all         samba     0.0.0.0/0        krb5 include_realm=0


# Reload Configuration
gpstop -u

# Authenticate to kerberos 
kdestroy
kinit samba
Password for samba@GREENPLUM.LOCAL:
klist

Ticket cache: KEYRING:persistent:1001:krb_ccache_H4LleCG
Default principal: samba@GREENPLUM.LOCAL

Valid starting       Expires              Service principal
07/30/2018 17:57:13  07/31/2018 03:57:13  krbtgt/GREENPLUM.LOCAL@GREENPLUM.LOCAL


# Login to Postgres
[gpadmin@gpdb ~]$ psql -U samba -h gpdb
Password for user samba:
psql (8.2.15)
Type "help" for help.
```

# Greenplum Command Center Kerberos Example #

- [ ] Create a SPN for GPCC

  * In this example, we will bind the SPN to the gpmon account.
  * If you need to combine keytabs (gpcc and gpdb), use `ktutil` to read all and write a new one.

```
sudo samba-tool user add gpmon changeme
sudo samba-tool user enable gpmon
sudo samba-tool spn add HTTP/gpdb gpmon
sudo samba-tool spn list gpmon

User CN=gpmon,CN=Users,DC=greenplum,DC=local has the following servicePrincipalName:
	 HTTP/gpdb

sudo samba-tool domain exportkeytab --principal="HTTP/gpdb" krb5.gpcc.keytab

# Combining Keytabs

sudo ktutil
ktutil:  rkt krb5.keytab
ktutil:  rkt krb5.gpcc.keytab
ktutil:  list
slot KVNO Principal
---- ---- ---------------------------------------------------------------------
   1    1            postgres/gpdb@GREENPLUM.LOCAL
   2    1            postgres/gpdb@GREENPLUM.LOCAL
   3    1            postgres/gpdb@GREENPLUM.LOCAL
   4    1                HTTP/gpdb@GREENPLUM.LOCAL
   5    1                HTTP/gpdb@GREENPLUM.LOCAL
   6    1                HTTP/gpdb@GREENPLUM.LOCAL

ktutil:  wkt krb5.keytab

# Replace the Greenplum Keytab
sudo scp krb5.keytab gpadmin@gpdb:~/krb5.keytab
```

- [ ] Update the pg_hba.conf

  * You can have local authentication as trust or md5 to continue to use the .pgpass file with md5 authenticaiton.
  * See: https://gpcc.docs.pivotal.io/430/topics/gpmon.html

```
local    gpperfmon   gpmon     			md5 # Local Uses SOCKETS and will always use .pgpass or 
host     all         gpmon     127.0.0.1/28 	md5 
host     all         gpmon     ::1/128      	md5
host     all         gpmon     0.0.0.0/0       gss include_realm=0
```

- [ ] Kerberos Enable GPCC 

  * See: https://gpcc.docs.pivotal.io/330/gpcc/topics/kerberos.html -- or --
  * https://gpcc.docs.pivotal.io/430/topics/kerberos.html
  * The syntax to enable kerberos on an existing installation will be different depnding on the major version.

```
gpcmdr --krbenable gpcc_43210_333_20180718130238
Stopping instance gpcc_43210_333_20180718130238...
Done.
==========================================================

Requirements for using Kerberos with GPCC:

  1. RedHat Linux 5.10 or 6+ (Centos 5 and SLES are not supported)
  2. /etc/krb5.conf file is the same as on the Kerberos server
  3. Greenplum database must already be configured for Kerberos

Confirm webserver name, IP, or DNS from keytab file.

For example, if the HTTP principal in your keytab file is HTTP/gpcc.example.com@KRB.EXAMPLE.COM,
enter "gpcc.example.com".

Enter webserver name for this instance: (default=gpdb)
gpdb

Enter the name of GPDB kerberos service name: (default=postgres)


GPCC supports 3 different kerberos mode:
1. Normal mode: If keytab file provided contains the login user's key entry, GPCC will run queries as the login user. Otherwise, GPCC will run all queries as gpmon user.
2. Strict mode: If keytab file doesn't contain the login user's key entry, the user won't be able to login.
3. Gpmon Only mode: The keytab file can only contain service keys, no user's key entry is needed in keytab file. Only gpmon ticket need to be obtained in GPCC server machine before GPCC runs, and refresh before expiration.


Choose kerberos mode (1.normal/2.strict/3.gpmon_only): (default=1)

Enter path to the keytab file: (default=/home/gpadmin/krb5.keytab)

Start instance Yy/Nn (default=Y)

Kerberos enabled for instance gpcc_43210_333_20180718130238
Starting instance gpcc_43210_333_20180718130238 ...
```

- [ ] Authenticate and Test Access

  * SPNEGO Support on various browsers and OSes may require some addtional startup parameters or tuning.

  * For Example on MacOS:
    * Safari works out of the box if you've created a Kerberos ticket as outlined in step 1; 
    * FireFox just needs a couple settings configured on the about:config page.
    * Chrome -- well, it's just special...I have not been able to configure it for hostname only support yet...
      * https://www.chromium.org/developers/design-documents/http-authentication
      * defaults write com.google.Chrome AuthServerWhitelist “*.example.com”
      * defaults write com.google.Chrome AuthNegotiateDelegateWhitelist “*.example.com”
      * defaults write com.google.Chrome DisableAuthNegotiateCnameLookup -bool true
      * `chrome://policy` and refresh

  * On The Server:

```
gpstop -u
kdestroy
kinit gpmon
Password for gpmon@GREENPLUM.LOCAL:

[gpadmin@gpdb ~]$ psql -U gpmon -h gpdb
psql (8.2.15)
Type "help" for help.
```

  * On the Client:

```
# On Host Ensure resolution to Guest VMs
192.168.99.100 gpdb
192.168.99.10  greenplum.local

defaults write com.google.Chrome AuthNegotiateDelegateWhitelist "*.GREENPLUM.LOCAL"
defaults write com.google.Chrome AuthServerWhitelist "gpdb"
defaults write com.google.Chrome DisableAuthNegotiateCnameLookup -bool true

# Keytab and krb5.conf copied locally and authenticate using keytab.
kinit -t krb5.gpmon.keytab gpmon@GREENPLUM.LOCAL

# On launch of GPCC, you should be auto-negoticated for login:
klist
Credentials cache: API:3B02C83B-2C36-4255-AC28-71D9C3A329A7
        Principal: gpmon@GREENPLUM.LOCAL

  Issued                Expires               Principal
Aug  1 10:58:25 2018  Aug  1 20:58:25 2018  krbtgt/GREENPLUM.LOCAL@GREENPLUM.LOCAL
Aug  1 10:58:40 2018  Aug  1 20:58:25 2018  HTTP/gpdb@GREENPLUM.LOCAL
```

**Dealing With Clock Skew**

It is important that system times on the Active Directory and Greenplum servers not be more than 5 minutes apart. It is suggested that you use Network Time Protocol (NTP) to keep the server times in sync. 

On the Greenplum master you can configure this through /etc/ntp.conf, but keep in mind that the master system clock must also be synced with all of the segment hosts.

See: https://gpdb.docs.pivotal.io/540/install_guide/prep_os_install_gpdb.html#topic_qst_s5t_wy

```
[gpadmin@gpdb ~]$ psql -U samba -h gpdb
psql: Kerberos 5 authentication rejected:  Clock skew too great
```

When there is too much clock skew with the GPCC Web client, this will generally appear as a 500 error for the `/access` url.


# Cleanup #

- [ ] Shut down with `vagrant halt`
- [ ] Delete it with `vagrant destroy`.

# License #

See the LICENSE.txt file.

# Credits
niklas-andersson/dcpromo does all the heavy lifting.
