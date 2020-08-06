#!/usr/bin/env python
import os, sys, re, gzip, json
from argparse import ArgumentParser
from subprocess import  check_output

help_text = "%s <localtop> <USES|USED_BY|ORIGIN> <tool|package> [<arch>]" % sys.argv[0]
parser = ArgumentParser(usage=help_text)
parser.add_argument('localtop')
parser.add_argument('cmd')
parser.add_argument('pack')
parser.add_argument('arch', default = os.environ.get("SCRAM_ARCH"))
args = parser.parse_args()
localtop = args.localtop
cmd = args.cmd.upper()
if not re.search(r'^(USES|USED_BY|ORIGIN)$', cmd): parser.print_usage() & sys.exit(1)
pack = args.pack
arch = args.arch
os.environ["SCRAM_ARCH"] = arch
cache = {}
tools = {}
data = dict(DATA = {}, FILES = {}, PROD = {}, DEPS = {})


def scramVersion(dir):
  ver = ""
  path = os.path.join(dir, "config", "scram_version")
  if os.path.exists(path):
    with open(path) as file:
      ver = file.readline()
  return ver


def data2json(infile):
  jstr = ""
  rebs = re.compile(',\s+"BuildSystem::[a-zA-Z0-9]+"\s+\)')
  revar = re.compile("^\s*\$[a-zA-Z0-9]+\s*=")
  reundef = re.compile('\s*undef,')
  if (sys.version_info > (3, 0)):
    lines = [l.decode('utf8').strip().replace(" bless(","").replace("'",'"').replace('=>',' : ') for l in
    gzip.open(infile).readlines()]
  else:
    lines = [l.strip().replace(" bless(","").replace("'",'"').replace('=>',' : ') for l in
    gzip.open(infile).readlines()]
  lines[0] = revar.sub("",lines[0])
  lines[-1] = lines[-1].replace(";","")
  for l in lines:
    l = reundef.sub(' "",', rebs.sub("", l.rstrip()))
    jstr += l
  return json.loads(jstr)


def FixToolName(t):
  lct = t.lower()
  if lct in tools["SETUP"]: 
    return lct
  return t


def process_ORIGIN(data, prod):
  str = "%s_ORIGIN = " % prod
  if prod not in data["PROD"]: data["PROD"][prod] = {}
  if "ORIGIN" in data["PROD"][prod]:
    for dir in data["PROD"][prod]["ORIGIN"]:
      tool = data["PROD"][prod]["ORIGIN"][dir]
    str += os.path.join(tool, dir)
  print(str)


def process_USED_BY(data, pack):
  packs = []
  str = "%s_USED_BY = " % pack
  if "USED_BY" in data["DEPS"][pack]:
    for d in data["DEPS"][pack]["USED_BY"]:
      packs.append(os.path.join(data["DEPS"][d]["TYPE"],d))
    str += " ".join(sorted(packs))
  print(str)


def process_USES(data, pack):
  packs = []
  str = "%s_USES = " % pack
  if "USES" in data["DEPS"][pack]:
    for d in data["DEPS"][pack]["USES"]:
      packs.append(os.path.join(data["DEPS"][d]["TYPE"],d))
    str += " ".join(sorted(packs))
  print(str)


def updateSCRAMTool(tool, base, data):
  file = os.path.join(base, ".SCRAM", arch, "ProjectCache.%s" % cacheext)
  c = data2json(file)
  data["FILES"][file] = 1
  for dir in c["BUILDTREE"]:
    dc = c["BUILDTREE"][dir]
    if ("RAWDATA" in dc) and ("DEPENDENCIES" in dc["RAWDATA"]):
        _class = dc["CLASS"]
        prod = None
        if re.search(r'^(LIBRARY|CLASSLIB|SEAL_PLATFORM)$', _class):
          dir = dc["PARENT"]
          prod = dc["NAME"]
        if dir not in data["DATA"]: data["DATA"][dir] = {}
        if "USES" not in data["DATA"][dir]: data["DATA"][dir]["USES"] = {}
        data["DATA"][dir]["USES"] = {}
        data["DATA"][dir]["TYPE"] = tool
        dc = dc["RAWDATA"]["DEPENDENCIES"]
        for d in dc:
          data["DATA"][dir]["USES"][FixToolName(d)] = 1
        if prod: 
          if prod not in data["PROD"]: data["PROD"][prod] = {}
          if "ORIGIN" not in data["PROD"][prod]: data["PROD"][prod]["ORIGIN"] = {}
          if dir not in data["PROD"][prod]["ORIGIN"]: data["PROD"][prod]["ORIGIN"][dir] = {} 
          data["PROD"][prod]["ORIGIN"][dir] = tool
        else:
          dc = c["BUILDTREE"][dir]["RAWDATA"]
          if "BUILDPRODUCTS" in dc["content"]:
            dc = dc["content"]["BUILDPRODUCTS"]
            for type in ("LIBRARY", "BIN"):
              if type in dc:
                for prod in dc[type]:
                  if prod not in data["PROD"]: data["PROD"][prod] = {}
                  if "ORIGIN" not in data["PROD"][prod]: data["PROD"][prod]["ORIGIN"] = {}
                  if dir not in data["PROD"][prod]["ORIGIN"]: data["PROD"][prod]["ORIGIN"][dir] = {} 
                  data["PROD"][prod]["ORIGIN"][dir] = tool


def updateDeps(data, pack=None):
  if not pack:
    for d in data["DATA"]: updateDeps(data, d)
    return 0
  if pack in data["DEPS"]: return 0
  if pack not in data["DEPS"]: data["DEPS"][pack] = {}
  if "USES" not in data["DEPS"][pack]: data["DEPS"][pack]["USES"] = {}
  data["DEPS"][pack]["USES"] = {}
  data["DEPS"][pack]["USED_BY"] = {}
  data["DEPS"][pack]["TYPE"] = data["DATA"][pack]["TYPE"]
  for u in data["DATA"][pack]["USES"]:
    if u in data["DATA"]: updateDeps(data, u)
    data["DEPS"][pack]["USES"][u] = 1
    if u not in data["DEPS"]: data["DEPS"][u] = {}
    if "USED_BY" not in data["DEPS"][u]: data["DEPS"][u]["USED_BY"] = {}
    data["DEPS"][u]["USED_BY"][pack] = 1
    if "USES" not in data["DEPS"][u]: data["DEPS"][u]["USES"] = {}
    for d in data["DEPS"][u]["USES"]:
      data["DEPS"][pack]["USES"][d] = 1
      data["DEPS"][d]["USED_BY"][pack] = 1


def updateExternals():
  tfile = os.path.join(localtop, ".SCRAM", arch, "ToolCache.%s" % cacheext)
  global tools
  tools = data2json(tfile)
  if tfile not in data["FILES"]: data["FILES"][tfile] = {}
  data["FILES"][tfile] = 1
  for t in tools["SETUP"]:
    file = os.path.join(localtop, ".SCRAM", arch, "timestamps", t)
    if not os.path.exists(file): print("No such file: %s" % file) & sys.exit(1)
    if file not in data["FILES"]: data["FILES"][file] = 1
    if t not in data["DATA"]: data["DATA"][t] = {}
    if "USES" not in data["DATA"][t]: data["DATA"][t]["USES"] = {}
    if "TYPE" not in data["DATA"][t]: data["DATA"][t]["TYPE"] = "tool"
    tc = tools["SETUP"][t]
    if "USE" in tc:
      for d in tc["USE"]:
        data["DATA"][t]["USES"][FixToolName(d)] = 1
    if "LIB" in tc:
      for l in tc["LIB"]:
        if l not in data["PROD"]: data["PROD"][l] = {}
        if "ORIGIN" not in data["PROD"][l]: data["PROD"][l]["ORIGIN"] = {}
        if t not in data["PROD"][l]["ORIGIN"]: data["PROD"][l]["ORIGIN"][t] = {}
        data["PROD"][l]["ORIGIN"][t] = "tool"
  order_path = os.path.join(localtop, ".SCRAM", arch, "MakeData", "Tools", "SCRAMBased", "order")
  if os.path.exists(order_path):
    for t in check_output('sort -r %s' % order_path, shell=True).decode().rstrip().splitlines():
      t = re.sub(r'^\d+:', r'', t)
      base = ""
      if t == "self": 
        base = reltop
      else: 
        base = "%s_BASE" % t.upper()
        base = tools["SETUP"][t][base]
      updateSCRAMTool(t, base, data)
  updateSCRAMTool("self", localtop, data)
  updateDeps(data)
  del data["DATA"]
  tools = None
  return data


envfile = os.path.join(localtop, ".SCRAM", arch, "Environment")
if not os.path.exists(envfile): envfile = os.path.join(localtop, ".SCRAM", "Environment")
reltop = check_output("grep RELEASETOP= %s | sed 's|RELEASETOP=||'" % envfile, shell=True).decode().rstrip()
cacheext="db"
if re.search(r'^V[2-9]' ,scramVersion(localtop)): cacheext="db.gz"
cfile = os.path.join(localtop, ".SCRAM", arch, "ToolsDepsCache.%s" % cacheext)
if os.path.exists(cfile):
  cache = data2json(cfile)
  s = os.stat(cfile)
  for file in cache["FILES"]:
    if os.path.exists(file):
      s1 = os.stat(file)
      if s[9] > s1[9]: continue
    cache = None
    break
if not cache:
  cache = updateExternals()

func = globals()["process_" + cmd]
for pk in pack.split(":"): func(cache, pk)
