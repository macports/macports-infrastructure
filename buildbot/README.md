# Hacking on the MacPorts buildbot


## Setting up a buildbot master for testing

### 1. Install buildbot

    sudo port install buildbot

### 2. Create new directory for buildbot configuration

    buildbot create-master ~/buildbot-master

### 3. Add and edit sample configuration files

    cd ~/buildbot-master
    ln -s .../path/to/contrib/buildbot-test/master.cfg
    cp .../path/to/contrib/buildbot-test/config.json.sample config.json
    cp .../path/to/contrib/buildbot-test/slaves.json.sample slaves.json

Check settings in config.json and adapt as needed.

### 4. Set up authentication

    cd ~/buildbot-master
    htpasswd -c -d ./htpasswd admin

### 5. Starting buildbot

To start buildbot, execute the `start` command. The OS X firewall will request you to allow access for Python. Then you can view the buildbot instance in your web browser. 

    buildbot start ~/buildbot-master
    open http://localhost:8010/

### 5. Testing changes

After making any changes to `master.cfg`, you can reload the configuration with the `reconfig` command. This is faster than doing a full `restart`. In a similar way, you can completely `stop` the buildbot.

    buildbot reconfig ~/buildbot-master
 
    buildbot restart ~/buildbot-master

    buildbot stop ~/buildbot-master



## Setting up a buildbot slave

TODO
