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

* Clone this repository.
* Run `vagrant up`. 

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

# Greenplum LDAP Example #

Your gpdb instance will need to be able to resolve the domain controller (default: 192.168.99.10 greenplum.local)
If you are having trouble resolving, make sure your VirtualBox network adapter is correct (default: vboxnet0).

* **Create A User:** 
  * `sudo samba-tool user add samba changeme`

* **Enable The User Account:** 
  * `sudo samba-tool user enable samba`

* **Test Simple Bind:** 

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

* **Modify pg_hba.conf**

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

# Greenplum Kerberos Example #

* **Modify krb5.conf:** 

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
 
 

# Cleanup #

* Shut down the cluster with `vagrant halt` and delete it with `vagrant destroy`. 

* You can always run `vagrant up` to turn on or build a brand new cluster.

# License #

See the LICENSE.txt file.

# Credits
niklas-andersson/dcpromo does all the heavy lifting.
