#!/usr/bin/env awk -f
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0

BEGIN { # Defaults
  if (WIDTH < 1) WIDTH = 80
}

{ # Foreach line
  words[wc++] = $0
}

# Print words with optimal column width
END {
  # Try from max words down to 1 to fit layout
  for (cols = wc; cols >= 1; cols--) {
    rows = int((wc + cols - 1) / cols)
    # Reset maxlen array for columns
    for (c = 0; c < cols; c++) maxlen[c] = 0
    # Calculate max length per column
    for (i = 0; i < wc; i++) {
      # col = i % cols    # index for row-major
      col = int(i / rows) # index for column-major
      wl = length(words[i])
      if (wl > maxlen[col]) maxlen[col] = wl
    }
    # Compute total width needed, each column width + gap
    total = 0
    for (c = 0; c < cols; c++)
	total += (maxlen[c] += 1 * (c < cols - 1))
    if (total <= WIDTH || cols == 1) break
  }
  # Print rows, fill with cols
  for (r = 0; r < rows; r++) {
    line = ""
    for (c = 0; c < cols; c++) {
      # i = r * cols + c # index for row-major
      i = c * rows + r   # index for column-major
      if (i >= wc) continue
      fmt = "%-" maxlen[c] "s"
      line = line sprintf(fmt, words[i])
    }
    sub(/[ \t]+$/, "", line)
    print line
  }
}

# for W in `seq 120 -1 10` ; do ( printf "%*s|\n" $W "" && tr ' ' \\n < wordlist | awk -v WIDTH=$W -f ocolumns.awk | sed 's/$/|/') ; done
