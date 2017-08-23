#!/usr/bin/env python
import yaml
import json
from os import environ
from sys import argv, exit
from os.path import join
from commands import getstatusoutput as run_cmd

e, o = run_cmd ("find %s -name '*.yaml' -type f" % argv[1])
if e:
  print o
  exit (1)

localtop = environ["CMSSW_BASE"]
files = [ "/src/"+f.split(argv[1],1)[-1][:-5].strip("/") for f in o.split("\n") ]
print "files:",files
for f in o.split("\n"):
  obj = yaml.load(open(f))
  if not obj: obj={"Diagnostics":[]}
  change = 0
  new_dia = []
  for d in obj["Diagnostics"]:
    new_rep = []
    for r in d["Replacements"]:
      rf = "/"+r["FilePath"].split(localtop,1)[-1].strip("/")
      if rf in files: new_rep.append(r)
      else: change+=1
    if new_rep: new_dia.append(d)
  if new_dia:
    print "Clang Tidy cleanup: ",f,change
    if change>0:
      obj["Diagnostics"]=new_dia
      ref = open(f,"w")
      ref.write("---\n")
      yaml.dump(obj,ref,default_flow_style=False)
      ref.write("...\n")
      ref.close()

