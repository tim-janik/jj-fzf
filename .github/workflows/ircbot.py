#!/usr/bin/env python3
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
import sys, os, re, socket, select, time

# https://datatracker.ietf.org/doc/html/rfc1459

server = "irc.libera.chat"
port = 6667
channel = "#anklang2"
nickname = "YYBOT"
ircsock = None
timeout = 150
wait_timeout = 15000

def colors (how):
  E = '\u001b['
  C = '\u0003'
  if how == 0:          # NONE
    d = { 'YELLOW': '', 'ORANGE': '', 'RED': '', 'GREEN': '', 'CYAN': '', 'BLUE': '', 'MAGENTA': '', 'RESET': '' }
  elif how == 1:        # ANSI
    d = { 'YELLOW': E+'93m', 'ORANGE': E+'33m', 'RED': E+'31m', 'GREEN': E+'32m', 'CYAN': E+'36m', 'BLUE': E+'34m', 'MAGENTA': E+'35m', 'RESET': E+'m' }
  elif how == 2:        # mIRC
    d = { 'YELLOW': C+'08,99', 'ORANGE': C+'07,99', 'RED': C+'04,99', 'GREEN': C+'03,99', 'CYAN': C+'10,99', 'BLUE': C+'12,99', 'MAGENTA': C+'06,99', 'RESET': C+'' }
  from collections import namedtuple
  colors = namedtuple ("Colors", d.keys()) (*d.values())
  return colors

def status_color (txt, c):
  ER = r'false|\bno\b|\bnot|\bfail|fatal|error|\bwarn|\bbug|\bbad|\bred|broken'
  OK = r'true|\byes|\bok\b|success|\bpass|good|\bgreen'
  if re.search (ER, txt, flags = re.IGNORECASE):
    return c.RED
  if re.search (OK, txt, flags = re.IGNORECASE):
    return c.GREEN
  return c.YELLOW

def format_msg (args, how = 2):
  msg = ' '.join (args.message)
  c = colors (how)
  if args.S:
    msg = '[' + status_color (args.S, c) + args.S.upper() + c.RESET + '] ' + msg
  if args.D:
    msg = c.CYAN + args.D + c.RESET + ' ' + msg
  if args.U:
    msg = c.ORANGE + args.U + c.RESET + ' ' + msg
  if args.R:
    msg = '[' + c.BLUE + args.R + c.RESET + '] ' + msg
  return msg

def sendline (text):
  global args
  if not args.quiet:
    print (text, flush = True)
  msg = text + "\r\n"
  ircsock.send (msg.encode ('utf8'))

def connect (server, port):
  global ircsock
  ircsock = socket.socket (socket.AF_INET, socket.SOCK_STREAM)
  ircsock.connect ((server, port))
  ircsock.setblocking (True) # False

def canread (milliseconds):
  rs, ws, es = select.select ([ ircsock ], [], [], milliseconds * 0.001)
  return ircsock in rs

readall_buffer = b'' # unterminated start of next line
def readall (milliseconds = timeout):
  global readall_buffer
  gotlines = False
  while canread (milliseconds):
    milliseconds = 0
    buf = ircsock.recv (128 * 1024)
    if len (buf) == 0:
      # raise (Exception ('SOCKET BROKEN:', 'readable but has 0 data'))
      break # socket closed
    gotlines = True
    readall_buffer += buf
    if readall_buffer.find (b'\n') >= 0:
      lines, readall_buffer = readall_buffer.rsplit (b'\n', 1)
      lines = lines.decode ('utf8', 'replace')
      for l in lines.split ('\n'):
        if l:
          gotline (l.rstrip())
  return gotlines

def gotline (msg):
  global args
  if not args.quiet:
    print (msg, flush = True)
  cmdargs = re.split (' +', msg)
  if cmdargs:
    prefix = ''
    if cmdargs[0] and cmdargs[0][0] == ':':
      prefix = cmdargs[0]
      cmdargs = cmdargs[1:]
      if not cmdargs:
        return
    gotcmd (prefix, cmdargs[0], cmdargs[1:])

expecting_commands = []
check_cmds = []
def gotcmd (prefix, cmd, args):
  global expecting_commands, check_cmds
  if check_cmds:
    try: check_cmds.remove (cmd)
    except: pass
  if cmd in expecting_commands:
    expecting_commands = []
  if cmd == 'PING':
    return sendline ('PONG ' + ' '.join (args))

def expect (what = []):
  global expecting_commands
  expecting_commands = what if isinstance (what, (list, tuple)) else [ what ]
  while readall (wait_timeout) and expecting_commands: pass
  if expecting_commands:
    raise (Exception ('MISSING REPLY: ' + ' | '.join (expecting_commands)))

usage_help = '''
Simple IRC bot for short messages.
A password for authentication can be set via $IRCBOT_PASS.
'''

def parse_args (sysargs):
  import argparse
  global server, port, nickname
  parser = argparse.ArgumentParser (description = usage_help)
  parser.add_argument ('message', metavar = 'messages', type = str, nargs = '*',
                       help = 'Message to post on IRC')
  parser.add_argument ('-j', metavar = 'CHANNEL', default = '',
                       help = 'Channel to join on IRC')
  parser.add_argument ('-J', metavar = 'CHANNEL', default = '',
                       help = 'Message channel without joining')
  parser.add_argument ('-n', metavar = 'NICK', default = nickname,
                       help = 'Nickname to use on IRC [' + nickname + ']')
  parser.add_argument ('-s', metavar = 'SERVER', default = server,
                       help = 'Server for IRC connection [' + server + ']')
  parser.add_argument ('-p', metavar = 'PORT', default = port, type = int,
                       help = 'Port to connect to [' + str (port) + ']')
  parser.add_argument ('-l', action = "store_true",
                       help = 'List channels')
  parser.add_argument ('-R', metavar = 'REPOSITORY', default = '',
                       help = 'Initiating repository name')
  parser.add_argument ('-U', metavar = 'NAME', default = '',
                       help = 'Initiating user name')
  parser.add_argument ('-D', metavar = 'DEPARTMENT', default = '',
                       help = 'Initiating department')
  parser.add_argument ('-S', metavar = 'STATUS', default = '',
                       help = 'Initiating status code')
  parser.add_argument ('--ping', action = "store_true",
                       help = 'Require PING/PONG after connecting')
  parser.add_argument ('--quiet', '-q', action = "store_true",
                       help = 'Avoid unnecessary output')
  args = parser.parse_args (sysargs)
  #print ('ARGS:', repr (args), flush = True)
  return args

args = parse_args (sys.argv[1:])
if args.message and not args.quiet:
  print (format_msg (args, 1))
connect (args.s, args.p)
readall (500)

ircbot_pass = os.getenv ("IRCBOT_PASS")
if ircbot_pass:
  sendline ("PASS " + ircbot_pass)
sendline ("USER " + args.n + " localhost " + server + " :" + args.n)
readall()
sendline ("NICK " + args.n)
expect ('251') # LUSER reply

if args.ping:
  sendline ("PING :pleasegetbacktome")
  expect ('PONG')

if args.j:
  #sendline ("PING :ircbotpyping")
  #expect ('PONG')
  sendline ("JOIN " + args.j)
  expect ('JOIN')

msg = format_msg (args)
for line in re.split ('\n ?', msg):
  channel = args.j or args.J or args.n
  if line:
    sendline ("PRIVMSG " + channel + " :" + line)
    readall()

if args.l:
  sendline ("LIST")
  check_cmds = [ '322' ]
  expect ('323')
  if check_cmds:
    # empty list, retry after 60seconds
    time.sleep (30)
    check_cmds = [ 'PING' ]
    readall()
    if check_cmds:
      sendline ("PING :pleasegetbacktome")
      expect ('PONG')
    time.sleep (30)
    readall()
    sendline ("LIST")
    expect ('323')

readall (500)

sendline ("QUIT :Bye Bye")
expect (['QUIT', 'ERROR'])
ircsock.close()
