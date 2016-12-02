#!/usr/bin/env python
from sys import exit, stdout, stderr, argv
from os import getenv
from os.path import join, exists
try: import json
except:import simplejson as json

try: from commands import getstatusoutput as run_cmd
except:
  try: from subprocess import getstatusoutput  as run_cmd
  except:
    def run_cmd(command2run):
      from subprocess import Popen, PIPE, STDOUT
      cmd = Popen(command2run, shell=True, stdout=PIPE, stderr=STDOUT)
      (output, errout) = cmd.communicate()
      if isinstance(output,bytes): output =  output.decode()
      if output[-1:] == '\n': output = output[:-1]
      return (cmd.returncode, output)

def print_msg(msg,stream=stdout,newline="\n"): stream.write(msg+newline)
try: LLVM_CCDB_NAME = argv[1]
except: LLVM_CCDB_NAME = "compile_commands.json"
#Read SCRAM Generated
llvm_ccdb = []
err, llvm_ccdb_files = run_cmd("find %s -name '*.%s' -type f" % (join(getenv("LOCALTOP"),"tmp",getenv("SCRAM_ARCH"),"src"), LLVM_CCDB_NAME))
if err:
  print_msg(llvm_ccdb_files)
  exit(err)

llvm_ccdb_uniq_files = []
for llvm_ccdb_file in llvm_ccdb_files.split("\n"):
  llvm_ccdb_obj = json.load(open(llvm_ccdb_file))
  llvm_ccdb.append(llvm_ccdb_obj)
  llvm_ccdb_uniq_files.append(llvm_ccdb_obj['file'])

reltop = getenv("RELEASETOP",None)
rel_llvm_ccdb = []
if reltop:
  rel_llvm_ccdb_file = join(reltop,LLVM_CCDB_NAME)
  if exists(rel_llvm_ccdb_file): 
    rel_llvm_ccdb = json.load(rel_llvm_ccdb_file)

for llvm_ccdb_item in rel_llvm_ccdb:
  if llvm_ccdb_item['file'] in llvm_ccdb_uniq_files: continue
  llvm_ccdb.append(llvm_ccdb_item)

print_msg(json.dumps(llvm_ccdb, indent=2, sort_keys=True, separators=(',',': ')),
          open(join(getenv("LOCALTOP"),LLVM_CCDB_NAME),"w"),newline="")

  
  

