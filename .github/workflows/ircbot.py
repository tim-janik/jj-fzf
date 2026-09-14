#!/usr/bin/env python3
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
import argparse, collections, json, os, re, socket, ssl, sys, time, unicodedata

server = 'irc.example.org'
port = 6697
use_tls = True
verbose = False
nickname = 'YYBOT'
socket_timeout = 30
reply_timeout = 15
max_line_bytes = 512
max_privmsg_bytes = 400
attempts = 3
Message = collections.namedtuple ('Message', 'prefix command params')
irc_casemap = str.maketrans ('ABCDEFGHIJKLMNOPQRSTUVWXYZ[]\\^', 'abcdefghijklmnopqrstuvwxyz{}|~')
command_errors = {
  'CAP': {'410', '421'},
  'NICK': {'432', '433', '436', '437', '451', '462', '464', '466'},
  'JOIN': {'403', '405', '437', '471', '473', '474', '475', '476', '477', '489'},
  'PRIVMSG': {'401', '402', '404', '407', '411', '412', '413', '414'},
}
ansi_colors = {
  'yellow': '\u001b[93m', 'orange': '\u001b[33m', 'red': '\u001b[31m', 'green': '\u001b[32m',
  'cyan': '\u001b[36m', 'blue': '\u001b[34m', 'reset': '\u001b[m',
}
irc_colors = {
  'yellow': '\u000308,99', 'orange': '\u000307,99', 'red': '\u000304,99', 'green': '\u000303,99',
  'cyan': '\u000310,99', 'blue': '\u000312,99', 'reset': '\u0003',
}


class Fatal (Exception):
  pass


def clean_text (text):
  return ''.join (' ' if unicodedata.category (char) == 'Cc' else char for char in text)


def irc_equal (left, right):
  return left.translate (irc_casemap) == right.translate (irc_casemap)


def status_color (status):
  if re.search (r'false|\bno\b|\bnot|\bfail|fatal|error|\bwarn|\bbug|\bbad|\bred|broken', status, re.IGNORECASE):
    return 'red'
  if re.search (r'true|\byes\b|\bok\b|success|\bpass|good|\bgreen', status, re.IGNORECASE):
    return 'green'
  return 'yellow'


def format_message (args):
  text = clean_text (' '.join (args.message))
  if args.S:
    text = '[' + irc_colors[status_color (args.S)] + clean_text (args.S).upper() + irc_colors['reset'] + '] ' + text
  if args.D:
    text = irc_colors['cyan'] + clean_text (args.D) + irc_colors['reset'] + ' ' + text
  if args.U:
    text = irc_colors['orange'] + clean_text (args.U) + irc_colors['reset'] + ' ' + text
  if args.R:
    text = '[' + irc_colors['blue'] + clean_text (args.R) + irc_colors['reset'] + '] ' + text
  return text


def ansi_message (text):
  for name, code in irc_colors.items():
    text = text.replace (code, ansi_colors[name])
  return text


def parse_line (line):
  if line.startswith ('@'):
    line = line.partition (' ')[2]
  prefix = ''
  if line.startswith (':'):
    prefix, _, line = line[1:].partition (' ')
  middle, separator, trailing = line.partition (' :')
  words = middle.split()
  params = words[1:] + ([trailing] if separator else [])
  return Message (prefix, words[0].upper() if words else '', params)


def encode_line (command, limit = max_line_bytes):
  if any (char in command for char in '\r\n\0'):
    raise Fatal ('IRC command contains CR, LF or NUL')
  data = (command + '\r\n').encode ('utf8')
  if len (data) > limit:
    raise Fatal ('IRC command exceeds the byte limit')
  return data


def valid_channel (channel):
  return (len (channel) > 1 and channel[0] in '#&+!' and len (channel.encode ('utf8')) <= 50 and
          all (char not in ' ,:\a' and unicodedata.category (char)[0] != 'C' for char in channel))


def privmsg_command (channel, text):
  if not valid_channel (channel):
    raise Fatal ('invalid IRC channel')
  text = text.replace ('\r', ' ').replace ('\n', ' ').replace ('\0', ' ').strip()
  prefix = 'PRIVMSG ' + channel + ' :'
  budget = max_privmsg_bytes - len ((prefix + '\r\n').encode ('utf8'))
  if not text or budget < 4:
    raise Fatal ('IRC message is empty or its target is too long')
  data = text.encode ('utf8')
  if len (data) > budget:
    text = data[:budget - 3].decode ('utf8', 'ignore') + '...'
  encode_line (prefix + text, max_privmsg_bytes)
  return prefix + text


def reply_error (reply):
  detail = ': ' + ' '.join (reply.params) if reply.params else ''
  return reply.command + detail


def command_failed (reply, command):
  return reply.command in command_errors[command] or (reply.command == 'FAIL' and reply.params and reply.params[0].upper() == command)


class IrcClient:
  def __init__ (self, ircsock):
    self.socket = ircsock
    self.buffer = b''
    self.messages = collections.deque()
    self.delivery_started = False

  def send (self, command):
    if verbose:
      print ('IRC: -> ' + command, file = sys.stderr)
    self.socket.settimeout (socket_timeout)
    self.socket.sendall (encode_line (command))

  def read (self, deadline):
    while True:
      while not self.messages:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
          raise TimeoutError ('no matching IRC reply')
        self.socket.settimeout (min (socket_timeout, remaining))
        data = self.socket.recv (4096)
        if not data:
          raise ConnectionError ('IRC connection closed')
        chunks = (self.buffer + data).split (b'\n')
        self.buffer = chunks.pop()
        for chunk in chunks:
          line = chunk.removesuffix (b'\r').decode ('utf8', 'replace')
          if verbose and line:
            print ('IRC: <- ' + line, file = sys.stderr)
          message = parse_line (line)
          if message.command:
            self.messages.append (message)
      message = self.messages.popleft()
      if message.command == 'PING' and message.params:
        self.send ('PONG ' + ' '.join (message.params[:-1] + [':' + message.params[-1]]))
      elif message.command == '465':
        raise Fatal ('server ban: ' + reply_error (message))
      elif message.command == 'ERROR':
        raise ConnectionError (reply_error (message))
      else:
        return message

  def wait (self, predicate):
    deadline = time.monotonic() + reply_timeout
    while True:
      message = self.read (deadline)
      if predicate (message):
        return message


def open_connection ():
  raw_socket = socket.create_connection ((server, port), timeout = socket_timeout)
  if not use_tls:
    return raw_socket
  try:
    return ssl.create_default_context().wrap_socket (raw_socket, server_hostname = server)
  except BaseException:
    raw_socket.close()
    raise


def register (client):
  client.send ('CAP REQ :echo-message')
  cap = client.wait (lambda reply: command_failed (reply, 'CAP') or
                     (reply.command == 'CAP' and len (reply.params) >= 3 and reply.params[1] in ('ACK', 'NAK') and
                      'echo-message' in reply.params[-1].split()))
  if command_failed (cap, 'CAP'):
    raise Fatal ('capability negotiation failed: ' + reply_error (cap))
  if cap.params[1] != 'ACK':
    raise Fatal ('server lacks echo-message')
  nick = nickname
  client.send ('NICK ' + nick)
  client.send ('USER ' + nick + ' 0 * :' + nick)
  client.send ('CAP END')
  for count in range (attempts):
    reply = client.wait (lambda message: message.command == '001' or command_failed (message, 'NICK'))
    if reply.command == '001':
      return reply.params[0]
    if reply.command == '432':
      raise Fatal ('invalid nickname: ' + reply_error (reply))
    if reply.command != '433':
      raise Fatal ('registration failed: ' + reply_error (reply))
    if count + 1 < attempts:
      nick += '_'
      client.send ('NICK ' + nick)
  raise Fatal ('nickname is already in use')


def deliver (client, channel, command):
  nick = register (client)
  client.send ('JOIN ' + channel)
  reply = client.wait (lambda message:
                       (message.command == 'JOIN' and irc_equal (message.prefix.split ('!', 1)[0], nick) and
                        len (message.params) == 1 and irc_equal (message.params[0], channel)) or
                       command_failed (message, 'JOIN'))
  if reply.command != 'JOIN':
    raise Fatal ('JOIN failed: ' + reply_error (reply))
  client.delivery_started = True
  client.send (command)
  reply = client.wait (lambda message:
                       (message.command == 'PRIVMSG' and irc_equal (message.prefix.split ('!', 1)[0], nick) and
                        bool (message.params) and irc_equal (message.params[0], channel)) or
                       command_failed (message, 'PRIVMSG'))
  if reply.command != 'PRIVMSG':
    raise Fatal ('PRIVMSG failed: ' + reply_error (reply))


class DryRunServer:
  def __init__ (self):
    self.buffer = []
    self.nick = nickname

  def settimeout (self, value):
    pass

  def sendall (self, data):
    command = data.decode ('utf8').removesuffix ('\r\n')
    if command == 'CAP REQ :echo-message':
      self.queue (f':{server} CAP * ACK :echo-message')
    elif command.startswith ('NICK '):
      self.nick = command[5:]
    elif command == 'CAP END':
      self.queue (f':{server} 001 {self.nick} :welcome')
    elif command.startswith ('JOIN '):
      self.queue (f':{self.nick}!user@{server} JOIN :' + command[5:])
    elif command.startswith ('PRIVMSG '):
      self.queue (f':{self.nick}!user@{server} ' + command)

  def recv (self, size):
    if self.buffer:
      return self.buffer.pop (0)
    raise TimeoutError ('no simulated reply')

  def queue (self, *lines):
    self.buffer.append (('\r\n'.join (lines) + '\r\n').encode ('utf8'))

  def close (self):
    pass


def send_notification (channel, text, connection = None):
  command = privmsg_command (channel, text)
  last_error = None
  for attempt in range (1, attempts + 1):
    ircsock = None
    client = None
    try:
      ircsock = (connection or open_connection) ()
      client = IrcClient (ircsock)
      deliver (client, channel, command)
      suffix = ' (dry run)' if connection else ''
      print (f'IRC: delivered{suffix} on attempt {attempt}/{attempts}', file = sys.stderr)
      return
    except Fatal:
      raise
    except Exception as error:
      last_error = error
      if client and client.delivery_started:
        raise Fatal ('delivery may have occurred: ' + str (error))
      print (f'IRC: attempt {attempt}/{attempts} failed: {error}', file = sys.stderr)
      if attempt < attempts:
        time.sleep (5 * 2 ** (attempt - 1))
    finally:
      if ircsock:
        ircsock.close()
  raise Fatal (f'connection to {server}:{port} failed after {attempts} attempts: {last_error}')


def read_github_event (args):
  event_path = os.environ.get ('GITHUB_EVENT_PATH')
  if not event_path:
    raise Fatal ('GITHUB_EVENT_PATH is required with -G')
  with open (event_path, encoding = 'utf8') as event_file:
    event = json.load (event_file)
  head = event.get ('head_commit') or {}
  pull_request = event.get ('pull_request') or {}
  args.R = (event.get ('repository') or {}).get ('full_name', '') or args.R
  args.U = (event.get ('pusher') or {}).get ('name', '') or (event.get ('sender') or {}).get ('login', '') or args.U
  args.D = re.sub (r'^refs/(heads|tags)/', '', event.get ('ref') or '') or args.D
  subject = (head.get ('message', '').splitlines() or ['update'])[0]
  if pull_request and not head.get ('message'):
    number = pull_request.get ('number') or event.get ('number')
    if number:
      args.D = '#' + str (number)
    subject = pull_request.get ('title') or subject
    if event.get ('action'):
      subject = event['action'] + ': ' + subject
  if not args.message:
    args.message = [subject]
  url = head.get ('url') or pull_request.get ('html_url') or event.get ('compare') or ''
  if url:
    args.message += ['-', url]
  results = os.environ.get ('IRCBOT_JOBS', '').split()
  if results and not args.S:
    args.S = 'FAILURE' if any (result not in ('success', 'skipped') for result in results) else 'SUCCESS'


address_pattern = re.compile (r'^(?:\[([0-9A-Fa-f:.]+)\]|([^:\s]+))(?::([0-9]+))?$')


def parse_server (text):
  match = address_pattern.match (text)
  if match:
    host, port = match.group (1) or match.group (2), match.group (3)
  elif text.count (':') > 1:
    host, port = text, None
  else:
    raise argparse.ArgumentTypeError ('invalid server address: ' + text)
  port = int (port) if port else 6697
  if not host or not 0 < port < 65536:
    raise argparse.ArgumentTypeError ('invalid server address: ' + text)
  return host, port


def parse_args (arguments):
  parser = argparse.ArgumentParser (description = 'Send one message to one IRC channel')
  parser.add_argument ('channel')
  parser.add_argument ('message', nargs = '*')
  parser.add_argument ('-s', '--server', type = parse_server, metavar = 'HOST[:PORT]',
                       help = 'server to connect to [irc.example.org:6697]')
  parser.add_argument ('--no-tls', dest = 'tls', action = 'store_false',
                       help = 'connect without TLS encryption')
  parser.add_argument ('-v', '--verbose', action = 'store_true',
                       help = 'print IRC protocol traffic')
  parser.add_argument ('-n', '--dry-run', action = 'store_true',
                       help = 'print a color preview and a simulated session without connecting')
  parser.add_argument ('-G', action = 'store_true', help = 'read message fields from GITHUB_EVENT_PATH')
  parser.add_argument ('-R', default = '', metavar = 'REPOSITORY')
  parser.add_argument ('-U', default = '', metavar = 'USER')
  parser.add_argument ('-D', default = '', metavar = 'REF')
  parser.add_argument ('-S', default = '', metavar = 'STATUS')
  return parser.parse_args (arguments)


def main (arguments):
  global server, port, use_tls, verbose
  args = parse_args (arguments)
  if args.server:
    server, port = args.server
  use_tls = args.tls
  verbose = args.verbose
  try:
    if args.G:
      read_github_event (args)
    message = format_message (args)
    if args.dry_run:
      command = privmsg_command (args.channel, message)
      print (ansi_message (command.partition (' :')[2]))
      send_notification (args.channel, message, DryRunServer)
    else:
      send_notification (args.channel, message)
  except Fatal as error:
    print ('IRC: ' + str (error), file = sys.stderr)
    return 1
  return 0


if __name__ == '__main__':
  sys.exit (main (sys.argv[1:]))
