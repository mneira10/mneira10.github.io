# mneira10.github.io - Personal web page

Personal web page with basic personal info, mini js projects and contact info.

### Objectives

- Create a great looking webpage
- Present some side projects
- Tell my story!

### Technologies

- html
- css
- js
- p5.js
- jquery
- AOS scrolling library (https://michalsnik.github.io/aos/)
- inkscape

### How to run

Just create a simple http server with node:http-server or node: reload and your're good to go!

### Agent skills

`box_setup.sh` installs the complete directories in `skills/` into
`~/.local/share/devtools/skills/` and links each one into both `~/.codex/skills/`
and `~/.claude/skills/`. Running the script from a checkout uses its bundled files;
the `curl | bash` installation downloads them from this repo's `master` branch.
Every run checks the bundled skills and replaces installed copies only when their
contents change.
Existing same-name directories are backed up under
`~/.local/share/devtools/skill-backups/` before linking. Unrelated skills are preserved.

- `upcodes-pr-review` keeps all review checks and guidance in one reference,
  with separate GitHub posting instructions and agent metadata. Security runs in
  its own independent subagent. Reviews respect the available subagent concurrency
  and use paths relative to the skill.
- `grill-me` consolidates the launcher and interview instructions from
  `mattpocock/skills` at commit `a496f5513d4a4cf889bc48e189e579f4b0bdf6aa`
  into one self-contained skill.
- Both skills require explicit invocation in both agents. Codex policies remain in
  `agents/openai.yaml`; Claude's equivalent is in `SKILL.md` frontmatter.

### CLI proxy

`box_setup.sh` uses `CLIPROXY_API_KEY` or the saved key and prompts only when neither
is available. Supply a new `CLIPROXY_API_KEY` to replace the saved key.

The script writes the proxy key into `~/.codex/config.toml` as the `cliproxy`
provider's `experimental_bearer_token`, so Codex doesn't depend on its environment.
The config is kept private with mode `0600`. At the end of a successful run, the
script restarts the Codex daemon when the proxy configuration changed or has not
been applied in the current container/boot. Unchanged reruns skip the restart;
failed restarts are retried on the next run. Older Codex versions print a reminder
to restart manually.

### Git identity

`box_setup.sh` sets the global git `user.name` (Mauro Neira) and `user.email`
(mauro@up.codes) when they aren't already set. Values that are already
configured, for example by hand or forwarded by the Dev Container, are kept.

### Re-running devbox setup

`box_setup.sh` still checks for the latest tool releases and updates shell and
Neovim plugins on each run. With unchanged upstream versions and inputs, managed
configuration files, skill copies, and shell startup entries retain their contents
and timestamps. Missing tools and skill links are repaired, existing same-name
skills are backed up once, and unrelated user configuration is preserved.

Run the isolated regression suite with `python3 -B -m unittest discover -s tests -v`.
It requires Bash, Python 3, and jq; downloads, tool installers, plugin updates, and
daemon restarts are mocked, and each test uses a temporary home directory.

### Authors

Me :D (Mauricio Neira) - https://mneira10.github.io/

### Screenshot

![alt myWebPage](./screenshot.png)

### Licence - See LICENCE file in repo

MIT License

Copyright (c) 2018 mneira10

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
