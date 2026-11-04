"""Exercise the complete installer without network access or changing the real HOME."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]

MOCK_COMMAND = r'''#!/usr/bin/env python3
import io
import os
from pathlib import Path
import sys
import tarfile

command = Path(sys.argv[0]).name
args = sys.argv[1:]
home = Path(os.environ["HOME"])
with open(os.environ["SETUP_EVENTS"], "a") as events:
    events.write(command + " " + " ".join(args) + "\n")

tool = b'#!/bin/sh\nprintf "mock tool 1.0.0\\n"\n'

if command == "curl":
    url = args[-1]
    if url.endswith("/releases/latest"):
        print(url.removesuffix("latest") + "tag/v1.0.0", end="")
    elif url.endswith("latest.json"):
        print('{"version":"1.0.0"}')
    elif url == "https://herdr.dev/install.sh":
        print('cp "$SETUP_MOCK_TOOL" "$HERDR_INSTALL_DIR/herdr"')
    elif url == "https://raw.githubusercontent.com/romkatv/zsh-bin/master/install":
        print('cp "$SETUP_MOCK_TOOL" "$HOME/.local/bin/zsh"')
    elif url.endswith("/master.tar.gz"):
        with tarfile.open(fileobj=sys.stdout.buffer, mode="w|gz") as archive:
            archive.add(os.environ["SETUP_SKILLS"], arcname="repo/skills")
    elif url.endswith(".tar.gz"):
        repo = url.split("/")[4]
        binary = {"neovim": "nvim", "ripgrep": "rg"}.get(repo, repo)
        name = "nvim/bin/nvim" if binary == "nvim" else binary
        with tarfile.open(fileobj=sys.stdout.buffer, mode="w|gz") as archive:
            info = tarfile.TarInfo(name)
            info.size = len(tool)
            info.mode = 0o755
            archive.addfile(info, io.BytesIO(tool))
    elif "-o" in args:
        # jq must actually process the proxy settings and release manifest.
        import shutil
        shutil.copyfile(os.environ["SETUP_REAL_JQ"], args[args.index("-o") + 1])
    else:
        raise SystemExit("Unexpected URL: " + url)
elif command == "git":
    if args[:1] == ["config"]:
        # The identity settings must actually be written to the test HOME.
        os.execv(os.environ["SETUP_REAL_GIT"], ["git"] + args)
    elif "clone" in args:
        destination = Path(args[-1])
        (destination / ".git").mkdir(parents=True)
        if destination.name == "antidote":
            (destination / "antidote.zsh").write_text("")
    elif "pull" not in args:
        raise SystemExit("Unexpected git command: " + repr(args))
elif command == "codex":
    if args == ["app-server", "daemon", "restart"]:
        if os.environ.get("SETUP_FAIL_RESTART"):
            raise SystemExit(1)
    elif args != ["app-server", "daemon", "restart", "--help"]:
        raise SystemExit("Unexpected codex command: " + repr(args))
else:
    raise SystemExit("Unexpected command: " + command)
'''


class BoxSetupTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="box-setup-test-")
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.home = self.base / "home"
        self.home.mkdir()
        self.checkout = self.base / "checkout"
        self.checkout.mkdir()
        shutil.copy2(ROOT / "box_setup.sh", self.checkout / "box_setup.sh")
        shutil.copytree(ROOT / "skills", self.checkout / "skills")
        mocks = self.base / "mocks"
        mocks.mkdir()
        for name in ("curl", "git", "codex"):
            path = mocks / name
            path.write_text(MOCK_COMMAND)
            path.chmod(0o755)
        tool = self.base / "tool"
        tool.write_text('#!/bin/sh\nprintf "mock tool 1.0.0\\n"\n')
        tool.chmod(0o755)
        self.events = self.base / "events"
        self.env = {
            **os.environ,
            "HOME": str(self.home),
            "PATH": str(mocks) + os.pathsep + os.environ["PATH"],
            "CLIPROXY_API_KEY": "test-key",
            "SETUP_EVENTS": str(self.events),
            "SETUP_MOCK_TOOL": str(tool),
            "SETUP_SKILLS": str(self.checkout / "skills"),
            "SETUP_REAL_JQ": shutil.which("jq"),
            "SETUP_REAL_GIT": shutil.which("git"),
            # Keep the real git away from the host's global and system config.
            "XDG_CONFIG_HOME": None,
            "GIT_CONFIG_NOSYSTEM": "1",
        }

    def run_setup(self, *, piped=False, succeeds=True, **environment):
        env = {**self.env, **environment}
        env = {key: value for key, value in env.items() if value is not None}
        script = self.checkout / "box_setup.sh"
        result = subprocess.run(
            ["bash"] if piped else ["bash", str(script)],
            input=script.read_text() if piped else None,
            cwd=self.base,
            env=env,
            text=True,
            capture_output=True,
            # No controlling tty: setup must use the supplied/saved key.
            start_new_session=True,
            timeout=30,
        )
        if succeeds:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def snapshot(self):
        result = {}
        for path in self.home.rglob("*"):
            if path.is_symlink():
                contents = ("symlink", os.readlink(path))
            elif path.is_file():
                contents = ("file", path.read_bytes())
            else:
                continue
            stat = path.lstat()
            result[str(path.relative_to(self.home))] = (
                contents, stat.st_mode, stat.st_mtime_ns, stat.st_ctime_ns
            )
        return result

    def restart_count(self):
        return self.events.read_text().splitlines().count("codex app-server daemon restart")

    def test_unchanged_rerun_preserves_files_and_skips_installers_and_restart(self):
        self.run_setup()
        before = self.snapshot()
        first_events = self.events.read_text()
        self.run_setup(CLIPROXY_API_KEY=None)
        after = self.snapshot()
        changed = [name for name in before.keys() | after.keys() if before.get(name) != after.get(name)]
        self.assertEqual(changed, [], "Changed on second run: " + ", ".join(changed))
        self.assertEqual(self.restart_count(), 1)
        rerun_events = self.events.read_text()[len(first_events):]
        self.assertNotIn("/releases/download/", rerun_events)
        self.assertNotIn("https://herdr.dev/install.sh", rerun_events)
        self.assertNotIn("https://raw.githubusercontent.com/romkatv/zsh-bin/master/install", rerun_events)

    def test_proxy_key_change_preserves_user_settings_and_restarts_once(self):
        config = self.home / ".codex/config.toml"
        config.parent.mkdir()
        config.write_text('model = "previous"\n[projects."/work"]\ntrust_level = "trusted"\n')
        settings = self.home / ".claude/settings.json"
        settings.parent.mkdir()
        settings.write_text('{"theme":"dark","env":{"CUSTOM":"kept"}}')
        self.run_setup()
        self.run_setup(CLIPROXY_API_KEY="replacement-key")
        self.assertEqual(self.restart_count(), 2)
        values = json.loads(settings.read_text())
        self.assertEqual(values["theme"], "dark")
        self.assertEqual(values["env"]["CUSTOM"], "kept")
        self.assertEqual(values["env"]["ANTHROPIC_AUTH_TOKEN"], "replacement-key")
        self.assertIn('[projects."/work"]\ntrust_level = "trusted"', config.read_text())
        self.assertEqual(config.read_text().count('model_provider = "cliproxy"'), 1)
        self.assertEqual(config.read_text().count('[model_providers.cliproxy]'), 1)
        self.assertIn('experimental_bearer_token = "replacement-key"', config.read_text())
        self.assertNotIn('env_key =', config.read_text())
        self.assertEqual(config.stat().st_mode & 0o777, 0o600)
        secrets = self.home / ".config/devtools/secrets"
        self.assertEqual(secrets.stat().st_mode & 0o777, 0o600)
        self.run_setup(CLIPROXY_API_KEY=None)
        self.assertEqual(self.restart_count(), 2)

    def test_failed_restart_is_retried(self):
        self.run_setup(SETUP_FAIL_RESTART="1", succeeds=False)
        self.run_setup()
        self.assertEqual(self.restart_count(), 2)
        self.run_setup()
        self.assertEqual(self.restart_count(), 2)

    def test_new_container_runtime_reapplies_proxy_even_when_home_is_unchanged(self):
        self.run_setup()
        stamp = self.home / ".local/share/devtools/versions/codex-proxy-restarted"
        stamp.write_text("previous-boot previous-pid-namespace\n")
        self.run_setup(CLIPROXY_API_KEY=None)
        self.assertEqual(self.restart_count(), 2)
        self.run_setup(CLIPROXY_API_KEY=None)
        self.assertEqual(self.restart_count(), 2)

    def test_changed_key_restart_failure_is_retried_with_saved_key(self):
        self.run_setup()
        self.run_setup(
            CLIPROXY_API_KEY="replacement-key", SETUP_FAIL_RESTART="1", succeeds=False
        )
        self.run_setup(CLIPROXY_API_KEY=None)
        self.assertEqual(self.restart_count(), 3)
        self.run_setup(CLIPROXY_API_KEY=None)
        self.assertEqual(self.restart_count(), 3)

    def test_skills_update_without_repeating_backups_and_missing_tools_are_repaired(self):
        old_skill = self.home / ".codex/skills/grill-me"
        old_skill.mkdir(parents=True)
        (old_skill / "personal.txt").write_text("keep me")
        self.run_setup()
        backup_dir = self.home / ".local/share/devtools/skill-backups"
        backups = list(backup_dir.iterdir())
        self.assertEqual(len(backups), 1)
        self.assertEqual((backups[0] / "grill-me/personal.txt").read_text(), "keep me")
        skill = self.checkout / "skills/grill-me/SKILL.md"
        skill.write_text(skill.read_text() + "\nUpdated test skill\n")
        binary = self.home / ".local/bin/rg"
        binary.unlink()
        self.run_setup()
        installed = self.home / ".local/share/devtools/skills/grill-me/SKILL.md"
        self.assertEqual(installed.read_text(), skill.read_text())
        self.assertEqual(list(backup_dir.iterdir()), backups)
        self.assertTrue(binary.is_file())

    def test_git_identity_is_set_only_when_missing(self):
        self.run_setup()
        gitconfig = (self.home / ".gitconfig").read_text()
        self.assertIn("name = Mauro Neira", gitconfig)
        self.assertIn("email = mauro@up.codes", gitconfig)
        (self.home / ".gitconfig").write_text("[user]\n\tname = Someone Else\n")
        self.run_setup(CLIPROXY_API_KEY=None)
        gitconfig = (self.home / ".gitconfig").read_text()
        self.assertIn("name = Someone Else", gitconfig)
        self.assertNotIn("Mauro Neira", gitconfig)
        self.assertIn("email = mauro@up.codes", gitconfig)

    def test_piped_setup_without_proxy_key_is_repeatable(self):
        self.run_setup(piped=True, CLIPROXY_API_KEY=None)
        before = self.snapshot()
        self.run_setup(piped=True, CLIPROXY_API_KEY=None)
        after = self.snapshot()
        changed = [name for name in before.keys() | after.keys() if before.get(name) != after.get(name)]
        self.assertEqual(changed, [], "Changed on second run: " + ", ".join(changed))
        self.assertEqual(self.restart_count(), 0)
        self.assertFalse((self.home / ".config/devtools/secrets").exists())


if __name__ == "__main__":
    unittest.main()
