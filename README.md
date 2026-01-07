# homelab
## PBS
1. apt install cifs-uitils
2. mkdir /mnt/nas
3. nano /etc/samba/.smbcreds
   - format: username=smb_username, password=smb_password
4. chmod 400 /etc/samba/.smbcreds
5. mount -t cifs -o rw,vers=3.0,credentials=/etc/samba/.smbcreds,uid=34,gid=34 //IP-OF-NAS/SHARE-NAME /mnt/pbs-backups
6. nano /etc/fstab
   - //IP-OF-NAS/SHARE-NAME /mnt/test-pbs cifs vers=3.0,credentials=/etc/samba/.smbcreds,uid=34,gid=34,defaults 0 0
