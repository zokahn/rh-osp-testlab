# Ownership of a public linux server

## Protect your SSH
https://community.hetzner.com/tutorials/securing-ssh

# Managing a cluster of many nodes

## tmux for when you may leave before done
https://www.hamvocke.com/blog/a-quick-and-easy-guide-to-tmux/
https://leanpub.com/the-tao-of-tmux/read

```
yum -y install tmux
```

**Start a session**
```
tmux
```
**Detaching from a session**
ctrl-b then d

**Listing active session**
```
tmux ls
```

**attaching a running session, if only one is Running**
```
tmux a
```
**attaching a particular session (where 0 is the session id found in tmux ls)**
```
tmux attach -t 0
```

**Scrolling through a session**
Ctrl-b then [ then you can use your normal navigation keys to scroll around (eg. Up Arrow or PgDn). Press q to quit scroll mode.

## notepad automation and oneliners

Oneliner: Creating a file with contents
```
cat << EOF > servers.txt
ctrl01.example.com
ctrl02.example.com
ctrl03.example.com
comp00.example.com
comp01.example.com
comp02.example.com
comp03.example.com
ceph00.example.com
ceph01.example.com
ceph02.example.com
ceph03.example.com
EOF
```

Running commands over many machines
```
while read HOST ssh $HOST "uname -a" < /dev/null; done < servers.txt
```

## ssh tunnelling to access services directly behind a jump host

```
 ssh -L 443:server-running-service-on-https:443 root@jumphost.example.com
```
The https service on 'server-running-service-on-https' will be available on https://localhost
https://www.ssh.com/ssh/tunneling/example
