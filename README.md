# homelab
## PBS
1. apt install cifs-utils
2. mkdir /mnt/nas
3. nano /etc/samba/.smbcreds
   - format: username=smb_username, password=smb_password
4. chmod 400 /etc/samba/.smbcreds
5. mount -t cifs -o rw,vers=3.0,credentials=/etc/samba/.smbcreds,uid=34,gid=34 //IP-OF-NAS/SHARE-NAME /mnt/pbs-backups
6. nano /etc/fstab
   - //IP-OF-NAS/SHARE-NAME /mnt/test-pbs cifs vers=3.0,credentials=/etc/samba/.smbcreds,uid=34,gid=34,defaults 0 0
## Immich NAS MNT
1. grep immich /etc/passwd in LXC
2. mkdir /mnt/immich-nas in PVE
3. //192.168.178.134/immich /mnt/immich-nas cifs vers=3.0,credentials=/etc/samba/.smbcreds_immich,dir_mode=0777,file_mode=0777,uid=100999,gid=100991,defaults 0 0
4. mount -a
5. systemctl daemon-reload
6. ls -lF /mnt/immich-nas check for error
7. mount | grep immich check if mounted
   If mount is shown correct, we know that the line in fstab was added correctly
### Now pass mount to lxc
1. pct set [CONTAINER ID] --mp0 /mnt/immich-nas,mp=/mnt/nas
   #### Check if all correct
   -  more /etc/pve/lxc/[CONTAINER ID].conf
   -  scroll down and look for line: mp0: /mnt/immich-nas,mp=/mnt/nas
2. Head over to LXC shell and look if NAS is visible to the LXC
   - ls -lF /mnt/nas
   - should return no error
### Replicate datastructure
1. Copy over immich datastructure:  cp -ar /opt/immich/upload /mnt/nas
2. look at files: ls -lf /mnt/nas/upload

### Change config file bc. it should look at the nas instead of local storage
1. cd /opt/immich
2. nano .env
   - makte following changes(copy first line and comment out, paste line and change path to nas:
     - #IMMICH_MEDIA_LOCATION=/opt/immich/upload
     - IMMICH_MEDIA_LOCATION=/mnt/nas/upload
### create new upload link in app folder
1. cd /opt/immich/app
2. ls -l
   - this: upload -> /opt/immich/upload
3. backup file: mv upload upload-original
4. create new link: ln -s /mnt/nas/upload upload
   - verify with: ls -l and check for the new link
5. change owner of file: chown -R immich:immich upload
6. ls -l and now you should see upload is now owned by: immich immich instead of root root
### create new upload link in machine-learning folder
1. cd /opt/immich/app/machine-learning
2. ls -l
3. mv upload upload-original
4. ln -s /mnt/nas/upload upload
5. ls -l
6. chown -R immich:immich upload
7. ls -l to verify your changes
   
