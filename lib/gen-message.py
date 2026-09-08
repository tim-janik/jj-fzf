#!/usr/bin/env -S python3 -B
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
import sys, os, re, argparse, json, subprocess
import urllib.request, urllib.parse
from typing import Generator, Dict, Any
from pathlib import Path

DEBUG = False
DEBUG_PROMPT = False
DUP_OUTPUT = False

def env_or_jj_config (env_var: str, jj_key: str, default: str = '') -> str:
  """Return the value of *env_var* if set, otherwise query `jj config get jj-fzf.<jj_key>`.
  Falls back to *default* if neither is available."""
  if os.environ.get (env_var):
    return os.environ[env_var]
  try:
    result = subprocess.check_output (
      ['jj', '--no-pager', '--ignore-working-copy', 'config', 'get', f'jj-fzf.{jj_key}'],
      text = True, stderr = subprocess.DEVNULL
    ).strip()
    if result:
      return result
  except (subprocess.CalledProcessError, FileNotFoundError):
    pass
  return default

# LLM setup help, repeated in the manual page
LLM_HELP = '''
Commit messages can be generated using different Large Language Models (LLMs).
The LLM is chosen based on environment variables (or jj config), in the following order of precedence:

Environment variables take precedence over jj config settings. Note that jj config
keys are case-sensitive, so use the exact spellings shown below (e.g. `jj-fzf.LLM_API_BASE`,
not `jj-fzf.llm-api-base`).

1. Generic llama.cpp-compatible API:
   Set the LLM_API_BASE environment variable to the base URL of your API endpoint.
   As a fallback, the jj config `jj-fzf.LLM_API_BASE` can be used instead.
   Optionally, set LLM_API_KEY (or jj config `jj-fzf.LLM_API_KEY`) if the API requires an authorization key.
   Example:
   ```
   export LLM_API_BASE="http://llm-server.local:8080/v1"
   export LLM_API_KEY="your-api-key"  # optional
   # Or via jj config:
   jj config set --user jj-fzf.LLM_API_BASE "http://llm-server.local:8080/v1"
   ```
2. Google Gemini:
   Set the GEMINI_API_KEY environment variable or jj config `jj-fzf.GEMINI_API_KEY` to your Google AI Studio API key.
   Get a free key from: https://aistudio.google.com/
   Example:
   ```
   export GEMINI_API_KEY="AI-gemini-api-key"
   # Or via jj config:
   jj config set --user jj-fzf.GEMINI_API_KEY "AI-gemini-api-key"
   ```

3. OpenAI:
   Set the OPENAI_API_KEY environment variable or jj config `jj-fzf.OPENAI_API_KEY` to your OpenAI API key.
   Optionally, set OPENAI_API_BASE (or jj config `jj-fzf.OPENAI_API_BASE`) to use a different endpoint
   (e.g., for Azure OpenAI or other compatible services).
   Example:
   ```
   export OPENAI_API_KEY="sk-openai-api-key"
   # Or via jj config:
   jj config set --user jj-fzf.OPENAI_API_KEY "sk-openai-api-key"
   # Optionally, to use a different endpoint:
   export OPENAI_API_BASE="https://api.llm-server.local/v1"
   # or: jj config set --user jj-fzf.OPENAI_API_BASE "https://api.llm-server.local/v1"
   ```

4. Local llama.cpp server (default):
   If none of the above are set, a connection attempt is made to a local
   llama.cpp server at http://localhost:8080/v1.
   You can set LLM_API_KEY (or jj config `jj-fzf.LLM_API_KEY`) if your local server requires it.
   For more info on llama.cpp server:

   https://github.com/ggml-org/llama.cpp/blob/master/tools/server
'''

def configure_model_stream():
  chcompl = '/chat/completions'
  base = env_or_jj_config ('LLM_API_BASE', 'LLM_API_BASE')
  if base:
    key = env_or_jj_config ('LLM_API_KEY', 'LLM_API_KEY')
    llm_name = f"llama.cpp-compatible API at {base}"
    stream_fn = lambda p: stream_text (base + chcompl, key, 'llama.cpp', p)
    return stream_fn, llm_name
  gemini_key = env_or_jj_config ('GEMINI_API_KEY', 'GEMINI_API_KEY')
  if gemini_key:
    # https://ai.google.dev/gemini-api/docs/models
    model = 'gemini-flash-lite-latest' # 'gemini-2.0-flash-lite'
    llm_name = f"Google Gemini model '{model}'"
    stream_fn = lambda p: gemini_stream (gemini_key, model, p)
    return stream_fn, llm_name
  openai_key = env_or_jj_config ('OPENAI_API_KEY', 'OPENAI_API_KEY')
  if openai_key:
    model = 'gpt-3.5-turbo' # 'gpt-4.1-nano' 'gpt-4o-mini'
    base = env_or_jj_config ('OPENAI_API_BASE', 'OPENAI_API_BASE', 'https://api.openai.com/v1')
    llm_name = f"OpenAI model '{model}' at {base}"
    stream_fn = lambda p: stream_text (base + chcompl, openai_key, model, p)
    return stream_fn, llm_name
  llm_name = "local llama.cpp server at http://localhost:8080/v1"
  local_key = env_or_jj_config ('LLM_API_KEY', 'LLM_API_KEY')
  stream_fn = lambda p: stream_text ('http://localhost:8080/v1' + chcompl, local_key, 'llama.cpp', p)
  return stream_fn, llm_name

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

COMMIT_MESSAGE_PROMPT = """
Goal:
Write the best commit message for the changes in the current diff below.
Match the style, tone, and structure of the previous commits and keep wording minimal.

Instructions:

* Study the previous commit messages to understand tone, tense, prefixes, formatting, level of detail, etc.
* Then read the changes of the current diff.
* Write a commit message that fits naturally with the existing messages.
* Prefer explaining what exactly the changes are rather than speculating.
* If the change is simple, keep the message concise.
* If the change is complex or non-obvious, summarize appropriately.

Output requirements:

* Output only the commit message.
* Do not include commentary or explanations outside the commit message.
* The message must contain:

  1. A single-line title.
  2. One empty line.
  3. A body paragraph (or paragraphs) explaining the reasoning.
* Do not add markdown formatting, labels, or extra text.

### Current diff:

{commit_diff}
----- 8< -----

### Previous commit messages:

{commit_examples}

### Instruction:

Now, write the commit message for the current diff:
"""

def generate_commit_message (commit_hash, max_count=99):
  """Generate a commit message for the given commit hash"""
  llm_stream, llm_name = configure_model_stream()
  use_jj = locate_dominating_file (".", ".jj") != None
  if DEBUG:
    print (f"EXEC: Running `{'jj' if use_jj else 'git'} log ...`", file = sys.stderr)
  try:
    # Commands to list example history and diff
    if use_jj:
      vcs_log = """jj log --no-pager --no-graph --color=never """
      vcs_log += """-T '"\n----- 8< -----\n"++description++"\n"' """
      vcs_diff = vcs_log + f"""--git -r '{commit_hash}' """
      vcs_log += f"""-n {max_count} -r '..{commit_hash}' --reversed """
    else:
      vcs_log = """git -P log --no-color --format='%n----- 8< -----%n%B' """
      vcs_diff = vcs_log + f"""-p '{commit_hash}^!' """
      vcs_log += f"""-n {max_count} '{commit_hash}' --reverse """
    # Get the diff for the specific commit
    diff = subprocess.check_output (vcs_diff, shell = True, text = True)
    # Get example messages from recent commits
    examples = subprocess.check_output (vcs_log, shell = True, text = True)
  except subprocess.CalledProcessError as e:
    print (f"{sys.argv[0]}: Failed to execute git command: {e}", file = sys.stderr)
    sys.exit (2)
  # Remove noise from log
  examples = re.sub (r'(?mi)(?:\n\s*)*^\s*Signed-off-by:.*$(?:\n*)*', '\n', examples).strip()
  # Fill in prompt template
  constructed_prompt = COMMIT_MESSAGE_PROMPT.format (
    commit_examples = examples.strip(),
    commit_diff = diff.strip()
    ).strip()
  if DEBUG:
    print (f"LLM: {llm_name}", file = sys.stderr)
  if DEBUG_PROMPT:
    print ("PROMPT:", file = sys.stderr)
    print (constructed_prompt, file = sys.stderr)
    # Path('/tmp/prompt.txt').write_text (constructed_prompt) # 'a'
  iterable = llm_stream (constructed_prompt)
  if DEBUG:
    print ("HTTP: Starting LLM request", file = sys.stderr)
  tidy_print (iterable) # thinking_tags

def output (text_to_print: str):
  """Writes the given text to standard output and flushes."""
  text_to_print = re.sub (r' +(?=\n)', '', text_to_print)
  sys.stdout.write (text_to_print)
  sys.stdout.flush()
  if DUP_OUTPUT:
    sys.stderr.write (text_to_print)

thinking_tags = [
  ('<'+'think>', '</'+'think>'),                # Qwen
  ('<|'+'channel>thought', '<channel'+'|>'),    # Gemma
]
def tidy_print (iterable):
  """Remove reasoning blocks from iterable text and add terminating newline."""
  col, line = 0, 0
  def output_wrapped (text):
    nonlocal col, line
    res = []
    for char in text:
      if char == '\n':
        col = 0
        line += 1
        res.append (char)
      elif line >= 1 and col >= 100 and char == ' ':
        res.append ('\n')
        col = 0
        line += 1
      else:
        res.append (char)
        col += 1
    output ("".join (res))
  # Read up to the first reasoning tag
  buffer = ""
  for chunk in iterable:
    if DEBUG: sys.stderr.write (chunk)
    buffer += chunk
    buffer = buffer.lstrip()
    if len (buffer) >= 12: # min size to detect thinking
      break
  # Keep reading until reasoning is done
  while (match := next(( (s, e, buffer.find (s)) for s, e in thinking_tags if s in buffer ), None)) \
        and (chunk := next (iterable, None)):
    s, e, think = match
    if DEBUG: sys.stderr.write (chunk)
    buffer += chunk
    if (closing := buffer.find (e, think)) > think:
      buffer = buffer[closing + len (e):]
      break
  # Normal text output
  buffer = buffer.lstrip()
  if len (buffer) > 0:
    output_wrapped (buffer)
  for chunk in iterable:
    buffer = chunk
    output_wrapped (buffer)
  if not buffer.endswith ('\n'):
    output_wrapped ('\n')

def locate_dominating_file (start, name):
  p = Path (start).resolve()
  while p != p.parent:
    if (p / name).exists():
      return str (p)
    p = p.parent
  return None

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
  parser.add_argument ('--max-count', type=int, default=7, help = 'The maximum number of recent commits to use as examples.')
  parser.add_argument ('--dup-output', action = 'store_true', help = 'Duplicate output to stderr.')
  parser.add_argument ('--debug-prompt', action = 'store_true', help = 'Print the generated prompt to stderr.')
  parser.add_argument ('-x', '--debug', action = 'store_true', help = 'Debug operational status to stderr.')
  args = parser.parse_args()
  global DEBUG, DEBUG_PROMPT, DUP_OUTPUT
  DEBUG = args.debug
  DEBUG_PROMPT = args.debug_prompt
  DUP_OUTPUT = args.dup_output

  generate_commit_message (args.commit_hash, args.max_count)

if __name__ == '__main__':
  main()
