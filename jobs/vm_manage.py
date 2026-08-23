#! /usr/bin/python3

# Start and stop UTM virtual machines based on buildbot queue length.

# Hypervisor.framework limit
maxvms = 2

import sys
import subprocess

discover_vms_script = """
tell app "UTM"
    set theResult to {}
    repeat with m in every virtual machine
        set end of theResult to {name of m, id of m, status of m}
    end repeat
    return theResult
end tell
"""

# Get info about available VMs
result = subprocess.run(['osascript', '-e', discover_vms_script], capture_output=True)
if result.returncode != 0:
    sys.exit(1)

import re
all_vm_props = re.findall(b'(?:^|, )([^,\n]+)', result.stdout)

from itertools import zip_longest

def grouper(iterable, n, fillvalue=None):
    "Collect data into fixed-length chunks or blocks"
    # grouper('ABCDEFG', 3, 'x') --> ABC DEF Gxx"
    args = [iter(iterable)] * n
    return zip_longest(*args, fillvalue=fillvalue)

class BuilderInfo:
    def __init__(self, id, name, osvers, status):
        self.id = id
        self.name = name
        self.osvers = osvers
        self.status = status
        self.queuelen = 0
        self.buildername = 'ports-'+str(osvers)+'_arm64-builder'
        self.watchername = 'ports-'+str(osvers)+'_arm64-watcher'

    def __str__(self):
        return "VM '"+ bytes.decode(self.name) + "', status = '"+bytes.decode(self.status)+"', queuelen = "+str(self.queuelen)

    def __lt__(self, other):
        if self.queuelen != other.queuelen:
            return (self.queuelen < other.queuelen)
        else:
            return (self.osvers < other.osvers)

builders = []
for name,id,status in grouper(all_vm_props, 3):
    name_components = name.split()
    if len(name_components) >= 3 and name_components[-1] == b'Builder':
        osvers = int(name_components[1])
        builders.append(BuilderInfo(id, name, osvers, status))

start_candidates = [b for b in builders if b.status == b"stopped"]
stop_candidates = [b for b in builders if b.status == b"started"]
# If all VMs are running, we're done. If any are starting or stopping,
# we shouldn't try to change anything right now.
if len(start_candidates) < 1 or (len(start_candidates) + len(stop_candidates)) != len(builders):
    sys.exit(0)

running_vm_count = len(stop_candidates)

import urllib.request
import urllib.parse

base_url = 'https://carola.macports.org/json/builders?%s'

query = [('select', b.watchername) for b in builders]
query += [('select', b.buildername) for b in builders]

params = urllib.parse.urlencode(query)
url = base_url % params

# Fetch info about the relevant builders from buildbot's JSON API
import json
with urllib.request.urlopen(url) as f:
    builder_status = json.load(f)

#print (builder_status)

# Running VMs are OK to stop if there are no pending or active builds for them
stop_candidates = [b for b in stop_candidates \
    if b.buildername in builder_status \
    and b.watchername in builder_status \
    and builder_status[b.buildername]["state"] == "idle" \
    and builder_status[b.watchername]["state"] == "idle" \
    and builder_status[b.buildername]["pendingBuilds"] == 0 \
    and builder_status[b.watchername]["pendingBuilds"] == 0]
# Prefer to stop older OS versions
stop_candidates.sort(reverse=True)

# We only want to start a VM if there are pending builds for it
for b in start_candidates:
    if b.watchername in builder_status:
        b.queuelen = builder_status[b.watchername]["pendingBuilds"]
start_candidates = [b for b in start_candidates if b.queuelen > 0]
# Prefer to start ones with more pending builds (preferring newer OS version to break ties)
start_candidates.sort()

start_vm_script = """
tell app "UTM"
    start virtual machine id "%s"           
end tell
"""

stop_vm_script = """
tell app "UTM"
    set vm to virtual machine id "%s"
    set vmName to name of vm
    suspend vm with saving
    repeat
        if status of vm is paused then exit repeat
    end repeat
    close window named vmName
end tell
"""

# Start VMs until we hit the limit, stopping any idle ones if needed to free a slot
while (running_vm_count < maxvms or len(stop_candidates) > 0) and len(start_candidates) > 0:
    if running_vm_count >= maxvms:
        stopvm = stop_candidates.pop()
        #print ("Stop "+bytes.decode(stopvm.name))
        subprocess.run(['osascript', '-e', stop_vm_script % bytes.decode(stopvm.id)])
        running_vm_count -= 1
    startvm = start_candidates.pop()
    #print ("Start "+bytes.decode(startvm.name))
    subprocess.run(['osascript', '-e', start_vm_script % bytes.decode(startvm.id)])
    running_vm_count += 1
