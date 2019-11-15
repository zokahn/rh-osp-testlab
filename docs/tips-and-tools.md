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

## Benchmarking!

### max throughput with uperf
Install uperf for benchmark test

Configure repositories
```
curl https://copr.fedorainfracloud.org/coprs/jtudelag/uperf/repo/epel-7/jtudelag-uperf-epel-7.repo -o /etc/yum.repos.d/jtudelag-uperf-epel-7.repo\
```

Install uperf
```
yum install -y uperf
```

Run uperf as a server

```
uperf -s
```
*Ignore message stat:client.pem:No such file or directory*
Run uperf as a client (replace the IP with your partners')

```
proto=tcp h=<ip> nthr=2500  uperf  -t -m /usr/share/uperf/iperf.xml
```
Result should look something like
```
stat:server.pem:No such file or directory
Starting 2500 threads running profile:iperf ...   0.10 seconds
Txn1          0 /   1.01(s) =            0        2486op/s
Txn2     3.37GB /  30.25(s) =   957.36Mb/s       15049op/s
Txn3          0 /   0.00(s) =            0      315326op/s
-------------------------------------------------------------------------------------------------------------------------------
Total    3.37GB /  32.26(s) =   897.71Mb/s       14223op/s

Txn                Count         avg         cpu         max         min
-------------------------------------------------------------------------------------------------------------------------------
Txn0                2500    112.65ms      0.00ns    219.52ms    176.31us
Txn1               46690       1.61s      0.00ns       2.74s     43.75us
Txn2                1803      6.77us      0.00ns    136.05us      0.00ns


Netstat statistics for this run
-------------------------------------------------------------------------------------------------------------------------------
Nic       opkts/s     ipkts/s      obits/s      ibits/s
bond1           1          44     2.36Kb/s    22.06Kb/s
eth0        76398       41125   923.23Mb/s    21.72Mb/s
eth1            0          23     97.70b/s    11.43Kb/s
eth3            1          21     2.26Kb/s    10.63Kb/s
-------------------------------------------------------------------------------------------------------------------------------

Run Statistics
Hostname            Time       Data   Throughput   Operations      Errors
-------------------------------------------------------------------------------------------------------------------------------
172.16.100.221    32.46s     3.20GB   847.45Mb/s       437584        0.00
master            32.26s     3.37GB   897.71Mb/s       462736        0.00
-------------------------------------------------------------------------------------------------------------------------------
Difference(%)     -0.62%      5.01%        5.60%        5.44%       0.00%

** 2500 Warnings Send buffer: 100.00KB (Requested:50.00KB)
** 2500 Warnings Recv buffer: 100.00KB (Requested:50.00KB)
** [172.16.100.221] 5000 Warnings  Send buffer: 100.00KB (Requested:50.00KB) No such file or directory
5000 Warnings  Recv buffer: 100.00KB (Requested:50.00KB) No such file or directory
```