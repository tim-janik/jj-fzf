#!/usr/bin/env python3
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
import sys, os, re, argparse, json, subprocess
import urllib.request, urllib.parse
from typing import Generator, Dict, Any

DEBUG = False
DEBUG_PROMPT = False
DUP_OUTPUT = False

def get_api_config():
  """Get API configuration from environment variables"""
  if os.environ.get ('LLM_API_BASE'):
    base, key = os.environ['LLM_API_BASE'], os.environ.get ('LLM_API_KEY', '')
  elif os.environ.get ('OPENAI_API_KEY'):
    base, key = os.environ.get ('OPENAI_API_BASE', 'https://api.openai.com/v1'), os.environ['OPENAI_API_KEY']
  else:
    base, key = 'http://localhost:8080/v1', os.environ.get ('LLM_API_KEY', '')
  return f"{base}/chat/completions", key

def stream_text (chat_url, api_key, model, prompt):
  """Stream text from the llama.cpp API"""
  headers = { 'Content-Type': 'application/json' }
  if api_key:
    headers['Authorization'] = f'Bearer {api_key}'
  if DEBUG:
    print ("ENDPOINT:", chat_url, 'with Authorization' if api_key else 'without key', file = sys.stderr)
  data = {
    'model': model,
    'messages': [{'role': 'user', 'content': prompt}],
    'stream': True
  }
  json_data = json.dumps (data).encode ('utf-8')
  req = urllib.request.Request (chat_url, data = json_data, headers = headers)
  with urllib.request.urlopen (req) as response:
    for line in response:
      line = line.decode ('utf-8').strip()
      if not line:
        continue
      if line.startswith ('data: '):
        data_str = line[6:]  # Remove 'data: ' prefix
        if data_str == '[DONE]':
          break
        try:
          obj = json.loads (data_str)                   # parse JSON fully
        except json.JSONDecodeError:
          continue                                      # skip malformed JSON
        if 'choices' in obj and len (obj['choices']) > 0:
          choice = obj['choices'][0]
          if ('delta' in choice and 'content' in choice['delta'] and
               choice['delta']['content']):
            yield choice['delta']['content']

def generate_commit_message (commit_hash, max_count=99):
  """Generate a commit message for the given commit hash"""
  chat_url, api_key = get_api_config()
  if DEBUG:
    print ("EXEC: Running `git log ...`", file = sys.stderr)
  try:
    git_log = "git -P log --no-color --format='%n========%nAuthor: %an <%ae>%n%n%B' --stat"

    # Get the diff for the specific commit
    diff_cmd = f"{git_log} -p '{commit_hash}^!'"
    diff = subprocess.check_output (diff_cmd, shell = True, text = True)

    # Get examples from recent commits
    examples_cmd = f"{git_log} --reverse -n{max_count}"
    examples = subprocess.check_output (examples_cmd, shell = True, text = True)
  except subprocess.CalledProcessError as e:
    print (f"{sys.argv[0]}: Failed to execute git command: {e}", file = sys.stderr)
    sys.exit (2)
  constructed_prompt = (
    "======== EXAMPLES ========\n" +
    examples + "\n\n" +
    "======== COMMIT & DIFF ========\n" +
    diff + "\n\n" +
    "======== REQUEST ========\n" +
    "Generate a brief commit title, a seperate empty line and a suitable commit message body for the above commit & diff, generate nothing else.\n" +
    "/no-think" +
    "\n"
  )
  if DEBUG_PROMPT:
    print ("PROMPT:", file = sys.stderr)
    print (constructed_prompt, file = sys.stderr)
  iterable = stream_text (chat_url, api_key, 'llama.cpp', constructed_prompt)
  if DEBUG:
    print ("HTTP: Starting LLM request", file = sys.stderr)
  tidy_print (iterable)

def output (text_to_print: str):
  """Writes the given text to standard output and flushes."""
  sys.stdout.write (text_to_print)
  sys.stdout.flush()
  if DUP_OUTPUT:
    sys.stderr.write (text_to_print)

def tidy_print (iterable):
  """Remove reasoning blocks from iterable text and add terminating newline."""
  # Read up to the first reasoning tag
  buffer = ""
  for chunk in iterable:
    if DEBUG: sys.stderr.write (chunk)
    buffer += chunk
    buffer = buffer.lstrip()
    if len (buffer) >= 12: # min size to detect thinking
      break
  # Keep reading until reasoning is done
  while (think := buffer.find ('<think>')) >= 0 and (chunk := next (iterable, None)):
    if DEBUG: sys.stderr.write (chunk)
    buffer += chunk
    if (closing := buffer.find ('</think>')) > think:
      buffer = buffer[closing + len ('</think>'):]
      break
  # Normal text output
  buffer = buffer.lstrip()
  if len (buffer) > 0:
    output (buffer)
  for chunk in iterable:
    buffer = chunk
    output (buffer)
  if not buffer.endswith ('\n'):
    output ('\n')

def main():
  parser = argparse.ArgumentParser (description = 'Generate a commit message using an LLM.')
  parser.add_argument ('commit_hash', help = 'The hash of the commit to generate a message for.')
  parser.add_argument ('--max-count', type=int, default=19, help = 'The maximum number of recent commits to use as examples.')
  parser.add_argument ('--dup-output', action = 'store_true', help = 'Duplicate output to stderr.')
  parser.add_argument ('--debug', action = 'store_true', help = 'Debug operational status to stderr.')
  parser.add_argument ('--debug-prompt', action = 'store_true', help = 'Print the generated prompt to stderr.')
  args = parser.parse_args()
  global DEBUG, DEBUG_PROMPT, DUP_OUTPUT
  DEBUG = args.debug
  DEBUG_PROMPT = args.debug_prompt
  DUP_OUTPUT = args.dup_output

  generate_commit_message (args.commit_hash, args.max_count)

if __name__ == '__main__':
  main()
