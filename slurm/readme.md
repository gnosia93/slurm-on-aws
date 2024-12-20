
## Super Quick Start ##

* Make sure the clocks, users and groups (UIDs and GIDs) are synchronized across the cluster.
    * NOTE: The SlurmUser must exist prior to starting Slurm and must exist on all nodes of the cluster.
        ```
        sudo addgroup -gid 1111 munge
        sudo addgroup -gid 1121 slurm
        sudo adduser -u 1111 munge --disabled-password --gecos "" -gid 1111
        sudo adduser -u 1121 slurm --disabled-password --gecos "" -gid 1121
        ```  

* Install MUNGE for authentication. Make sure that all nodes in your cluster have the same munge.key. Make sure the MUNGE daemon, munged, is started before you start the Slurm daemons.
    * Install munge on the master:
        ```
        sudo apt-get install libmunge-dev libmunge2 munge -y
        sudo systemctl enable munge
        sudo systemctl start munge
        
        sudo cp /etc/munge/munge.key /storage/            # /storage is nfs mount path
        sudo chown munge /storage/munge.key
        sudo chmod 400 /storage/munge.key
        ```
    * Install munge on worker nodes:
        ```
        sudo apt-get install libmunge-dev libmunge2 munge
        sudo cp /storage/munge.key /etc/munge/munge.key
        sudo systemctl enable munge
        sudo systemctl start munge
        ```
  
* Build Manually from source (for developers or advanced users)
  * NOTE: The parent directories for Slurm's log files, process ID files, state save directories, etc. are not created by Slurm. They must be created and made writable by SlurmUser as needed prior to starting Slurm daemons.
  * Download source from https://www.schedmd.com/download-slurm/
  * As of Dec 20 2024, version 24.11.0 is the lastest version, and download url is https://download.schedmd.com/slurm/slurm-24.11.0.tar.bz2  

      ```
      curl https://download.schedmd.com/slurm/slurm-24.11.0.tar.bz2 -o slurm-24.11.0.tar.bz2
      tar -xaf slurm-24.11.0.tar.bz2
      cd slurm-24.11.0
      ./configure
      sudo make install
      ```

* Install the configuration file in `<sysconfdir>`/slurm.conf.
  * NOTE: You will need to install this configuration file on all nodes of the cluster.
  * `<sysconfdir>` is /usr/local if you compile source code by your self and didn't set prefix  

* systemd (optional): enable the appropriate services on each system:
  * Controller: sudo systemctl enable slurmctld
  * Database: sudo systemctl enable slurmdbd
  * Compute Nodes: sudo systemctl enable slurmd

* Start the slurmctld and slurmd daemons.
  * eg. sudo systemctl start slurmctld
 
## reference ##
* https://slurm.schedmd.com/quickstart_admin.html
* https://github.com/lopentusska/slurm_ubuntu_gpu_cluster
* https://github.com/nateGeorge/slurm_gpu_ubuntu?tab=readme-ov-file
* https://github.com/mknoxnv/ubuntu-slurm
