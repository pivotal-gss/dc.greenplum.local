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

For the purposes of testing, `configure-pdc.sh` script will disable `server require strong auth` which forces BIND over SSL, and disable Password Complexity:

```
sed -i "/\[global\]/a\\\tldap server require strong auth = no" /etc/samba/smb.conf
samba-tool domain passwordsettings set --complexity=off --history-length=0 --min-pwd-age=0 --max-pwd-age=0
```

* **Create A User:** 
  * `sudo samba-tool user add <username> <password>`

* **Enable The User Account:** 
  * `sudo samba-tool user enable <username>`

* **List users:** 
  * `sudo samba-tool user list`

* **Test Access:** 
  * `ldapsearch -x -h greenplum.local -b "dc=greenplum,dc=local" -D "CN=<username>,CN=users,DC=greenplum,DC=local" -w <password> "(objectclass=person)"`

# Cleanup #

* Shut down the cluster with `vagrant halt` and delete it with `vagrant destroy`. 

* You can always run `vagrant up` to turn on or build a brand new cluster.

# License #

See the LICENSE.txt file.

# Credits
niklas-andersson/dcpromo does all the heavy lifting.
