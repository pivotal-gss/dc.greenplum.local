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

1. Clone this repository.
2. Run `vagrant up`. 

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

1. Create An LDAP Bind User: 
  * `sudo samba-tool user add samba changeme`

2. Enable The User Account: 
  * `sudo samba-tool user enable samba`

3. Test Simple Bind: 

ldapsearch is included with the OpenLDAP Clients

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

4. Modify pg_hba.conf

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

1. Complete Steps 1-3 For BIND Example

2. Create SEARCH LDAP Account:
  * `sudo samba-tool user add gpadmin changeme`

3. Enable The User Account: 
  * `sudo samba-tool user enable gpadmin`

4. Test Simple Bind: 

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

5. **Modify pg_hba.conf**

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

When you set up the Greenplum Database environment by sourcing the greenplum-db_path.sh script, the LD_LIBRARY_PATH environment variable is set to include the Greenplum Database lib directory, which includes Kerberos libraries. This may cause Kerberos utility commands such as kinit and klist to fail due to version conflicts. The solution is to run Kerberos utilities before you source the greenplum-db_path.sh file or temporarily unset the LD_LIBRARY_PATH variable when you execute Kerberos utilities

```
[gpadmin@gpdb ~]$ klist
klist: relocation error: klist: symbol krb5_is_config_principal, version krb5_3_MIT not defined in file libkrb5.so.3 with link time reference

export LD_LIBRARY_PATH=/lib64:$LD_LIBRARY_PATH
```

1. Generate a Service Principal Name (SPN) on the DC: 

Active directory requires Kerberos service principal names to be mapped to a user account before a keytab can be generated. 
Be sure to match the service name with the krb_srvname.

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


2. Modify Greenplum krb5.conf: 

In this example, I have only modifed the REALM information from the default /etc/krb5.conf --

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

3. Modify pg_hba.conf

Remember that the FIRST matching rule prevails...

```
# Edit pg_hba.conf
host     all         samba     0.0.0.0/0        krb5 include_realm=0


# Reload Configuration
gpstop -u

20180725:03:54:38:027412 gpstop:gpdb:gpadmin-[INFO]:-Signalling all postmaster processes to reload

# Authenticate to kerberos 
kdestroy
kinit samba
Password for samba@GREENPLUM.LOCAL:
klist

Ticket cache: KEYRING:persistent:1001:krb_ccache_H4LleCG
Default principal: samba@GREENPLUM.LOCAL

Valid starting       Expires              Service principal
07/30/2018 17:57:13  07/31/2018 03:57:13  krbtgt/GREENPLUM.LOCAL@GREENPLUM.LOCAL
	renew until 08/06/2018 17:57:10

# Login to Postgres
[gpadmin@gpdb ~]$ psql -U samba -h gpdb
Password for user samba:
psql (8.2.15)
Type "help" for help.
```

**Dealing With Clock Skew**
It is important that system times on the Active Directory and Greenplum servers not be more than 5 minutes apart. It is suggested that you use Network Time Protocol (NTP) to keep the server times in sync. 

On the Greenplum master you can configure this through /etc/ntp.conf, but keep in mind that the master system clock must also be synced with all of the segment hosts.

See: https://gpdb.docs.pivotal.io/540/install_guide/prep_os_install_gpdb.html#topic_qst_s5t_wy

```
[gpadmin@gpdb ~]$ psql -U samba -h gpdb
psql: Kerberos 5 authentication rejected:  Clock skew too great
```

# Cleanup #

* Shut down the cluster with `vagrant halt` and delete it with `vagrant destroy`. 

* You can always run `vagrant up` to turn on or build a brand new cluster.

# License #

See the LICENSE.txt file.

# Credits
niklas-andersson/dcpromo does all the heavy lifting.
