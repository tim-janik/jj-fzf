#!/usr/bin/env -S python3 -B
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
import sys, os, re, argparse, json, subprocess
import urllib.request, urllib.parse
from typing import Generator, Dict, Any

DEBUG = False
DEBUG_PROMPT = False
DUP_OUTPUT = False

# LLM setup help, repeated in the manual page
LLM_HELP = '''
Commit messages can be generated using different Large Language Models (LLMs).
The LLM is chosen based on environment variables, in the following order of precedence:

1. Generic llama.cpp-compatible API:
   Set LLM_API_BASE to the base URL of your API endpoint.
   Optionally, set LLM_API_KEY if the API requires an authorization key.
   Example:
   ```
   export LLM_API_BASE="http://llm-server.local:8080/v1"
   export LLM_API_KEY="your-api-key"  # optional
   ```
2. Google Gemini:
   Set GEMINI_API_KEY to your Google AI Studio API key.
   Get a free key from: https://aistudio.google.com/
   Example:
   ```
   export GEMINI_API_KEY="AI-gemini-api-key"
   ```

3. OpenAI:
   Set OPENAI_API_KEY to your OpenAI API key.
   Optionally, set OPENAI_API_BASE to use a different endpoint
   (e.g., for Azure OpenAI or other compatible services).
   Example:
   ```
   export OPENAI_API_KEY="sk-openai-api-key"
   # Optionally, to use a different endpoint:
   export OPENAI_API_BASE="https://api.llm-server.local/v1"
   ```

4. Local llama.cpp server (default):
   If none of the above are set, a connection attempt is made to a local
   llama.cpp server at http://localhost:8080/v1.
   You can set LLM_API_KEY if your local server requires it.
   For more info on llama.cpp server:

   https://github.com/ggml-org/llama.cpp/blob/master/tools/server
'''

def configure_model_stream():
  chcompl = '/chat/completions'
  if os.environ.get ('LLM_API_BASE'):
    base, key = os.environ['LLM_API_BASE'], os.environ.get ('LLM_API_KEY', '')
    return lambda p: stream_text (base + chcompl, key, 'llama.cpp', p)
  elif os.environ.get ('GEMINI_API_KEY'):
    # https://ai.google.dev/gemini-api/docs/models
    model = 'gemini-2.0-flash-lite' # 'gemini-1.5-flash-latest'
    return lambda p: gemini_stream (os.environ['GEMINI_API_KEY'], model, p)
  elif os.environ.get ('OPENAI_API_KEY'):
    model = 'gpt-3.5-turbo' # 'gpt-4.1-nano' 'gpt-4o-mini'
    base = os.environ.get ('OPENAI_API_BASE', 'https://api.openai.com/v1')
    return lambda p: stream_text (base + chcompl, os.environ['OPENAI_API_KEY'], model, p)
  return lambda p: stream_text ('http://localhost:8080/v1' + chcompl, os.environ.get ('LLM_API_KEY', ''), 'llama.cpp', p)

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
    'reasoning_format': 'none',
    'chat_template_kwargs': { 'enable_thinking': False },
    'stream': True
  }
  json_data = json.dumps (data).encode ('utf-8')
  req = urllib.request.Request (chat_url, data = json_data, headers = headers)
  try:
    response = urllib.request.urlopen (req)
  except Exception as e:
    yield f"ERROR: Failed to connect to endpoint: {chat_url} ({e})"
    return
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
  response.close()

def gemini_stream (api_key: str, model: str, prompt: str) -> Generator[str, None, None]:
  """Stream text from the Gemini API"""
  GOOGAPI_URL = "https://generativelanguage.googleapis.com/v1beta"
  url = f"{GOOGAPI_URL}/models/{model}:streamGenerateContent?key={api_key}"
  data: Dict[str, Any] = { "contents": [{"parts": [{"text": prompt}]}] }
  json_data = json.dumps (data).encode ('utf-8')
  req = urllib.request.Request (url, data = json_data, headers = {'Content-Type': 'application/json'})
  with urllib.request.urlopen (req) as response:
    buffer, decoder = "", json.JSONDecoder()
    for chunk_bytes in iter (lambda: response.read (512), b''):
      buffer = (buffer + chunk_bytes.decode ('utf-8')).lstrip (' \n\r,')
      if buffer.startswith ('['):                       # enter JSON list
        buffer = buffer[1:].lstrip (' \n\r,')
      while buffer:
        try:
          obj, idx = decoder.raw_decode (buffer)        # parse valid JSON object
        except json.JSONDecodeError:
          break                                         # buffer too short
        buffer = buffer[idx:].lstrip (' \n\r,')         # skip over JSON object
        candidates = obj.get ('candidates', [])
        if candidates:
          content = candidates[0].get ('content', {})
          parts = content.get ('parts', [])
          if parts and 'text' in parts[0]:
            yield parts[0]['text']
    if DEBUG and buffer.strip() and buffer.strip() != ']':
      print (f"\nWarning: unprocessed JSON: {buffer.strip()}", file = sys.stderr)

def generate_commit_message (commit_hash, max_count=99):
  """Generate a commit message for the given commit hash"""
  llm_stream = configure_model_stream()
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
    "Generate a brief commit title, a separate empty line and a suitable commit message body for the above commit & diff.\n" +
    "Focus on *why* something is done, especially for complex logic, rather than *what* is done. Generate nothing else.\n" +
    "/no-think" +
    "\n"
  )
  if DEBUG_PROMPT:
    print ("PROMPT:", file = sys.stderr)
    print (constructed_prompt, file = sys.stderr)
  iterable = llm_stream (constructed_prompt)
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
  if '--llm-help' in sys.argv:
    print (LLM_HELP.strip())
    sys.exit (0)        # used for man page generation

  parser = argparse.ArgumentParser (
    description = 'Generate a commit message using an LLM.',
    epilog = 'LLM Configuration:' + LLM_HELP,
    formatter_class = argparse.RawDescriptionHelpFormatter
  )
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
