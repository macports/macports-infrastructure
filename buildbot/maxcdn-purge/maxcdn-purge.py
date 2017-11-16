#!/usr/bin/env python

from __future__ import print_function

import sys
import os
import pprint as pp
import json
from maxcdn import MaxCDN

if len(sys.argv) != 3:
    print("Usage: {} <zoneid> <secretsfile>".format(sys.argv[0]), file=sys.stderr)
    sys.exit(1)

zoneid = sys.argv[1]

with open(sys.argv[2]) as f:
    config = json.load(f)

if not all(k in config for k in ["key", "secret"]):
    print("Error: secretsfile does not contain key and/or secret!", file=sys.stderr)
    sys.exit(1)

MAXCDN_ALIAS = "macports"
MAXCDN_KEY = config['key']
MAXCDN_SECRET = config['secret']

# Initialize MaxCDN API
maxcdn = MaxCDN(MAXCDN_ALIAS, MAXCDN_KEY, MAXCDN_SECRET)

# Purge requested zone
res = maxcdn.purge(zoneid)
if not 'code' in res:
    print("Error: Unexpected response:", file=sys.stderr)
    pp.pprint(res, file=sys.stderr)
    sys.exit(1)
elif res['code'] == 200:
    print("Zone {} purged.".format(zoneid))
else:
    print("Purging of zone {} failed with code: " + res['code'], file=sys.stderr)
    sys.exit(1)
