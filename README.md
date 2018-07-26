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

# LDAP Example (Assuming GPDB can resolve greemplum.local) #

* **Create A User:** 
  * `sudo samba-tool user add samba changeme`

* **Enable The User Account:** 
  * `sudo samba-tool user enable samba`

* **Test Simple Bind:** 
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

# Cleanup #

* Shut down the cluster with `vagrant halt` and delete it with `vagrant destroy`. 

* You can always run `vagrant up` to turn on or build a brand new cluster.

# License #

See the LICENSE.txt file.

# Credits
niklas-andersson/dcpromo does all the heavy lifting.
