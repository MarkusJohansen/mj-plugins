"""Split a shell command line into simple commands, following `cd` along the way.

Shared by the PreToolUse guards. An approximation of the shell grammar: it tokenises with
shlex, splits on ; & | ( ) and newlines, drops redirect targets, and strips wrappers such as
`sudo` and `VAR=value` prefixes. A `cd` moves the directory the following commands are judged
from, which is what lets a guard see through `cd elsewhere && git commit`.
"""

import os
import re
import shlex

SEPARATOR_CHARACTERS = set(";&|()\n")
REDIRECT_CHARACTERS = set("<>")
PUNCTUATION = SEPARATOR_CHARACTERS | REDIRECT_CHARACTERS
WRAPPERS = {"sudo", "command", "builtin", "exec", "time", "nohup", "env"}
ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
# ${VAR:?}, ${VAR:-x} and friends carry their own handling of an empty value.
GUARDED_VARIABLE = re.compile(r"\$\{[A-Za-z_][A-Za-z0-9_]*[:?+=#%-]")
VARIABLE = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}|\$([A-Za-z_][A-Za-z0-9_]*)")
SET_IN_COMMAND = re.compile(
    r"\b([A-Za-z_][A-Za-z0-9_]*)="
    r"|\bfor\s+([A-Za-z_][A-Za-z0-9_]*)\b"
    r"|\bread\s+(?:-\w+\s+)*([A-Za-z_][A-Za-z0-9_ ]*)"
)


def tokenize(command):
    lexer = shlex.shlex(command, posix=True, punctuation_chars="".join(PUNCTUATION))
    lexer.whitespace = " \t\r"
    lexer.whitespace_split = True
    lexer.commenters = ""
    try:
        return list(lexer)
    except ValueError:
        # An unbalanced quote (an apostrophe in a heredoc body). Fall back to a plain split so
        # the commands around it are still seen.
        raw = re.findall(r"[();<>|&\n]+|[^\s();<>|&]+", command)
        return [token.strip("'\"") for token in raw]


def is_punctuation(token):
    return bool(token) and all(character in PUNCTUATION for character in token)


def strip_wrappers(argv):
    index = 0
    while index < len(argv):
        word = argv[index]
        if ASSIGNMENT.match(word):
            index += 1
        elif os.path.basename(word) in WRAPPERS:
            index += 1
            while index < len(argv) and argv[index].startswith("-"):
                index += 1
        else:
            break
    return argv[index:]


def variables_set_in(command):
    """Names the command itself gives a value: `name=`, `for name in`, `read name`.

    Their values exist only when the command runs, so a path built from one is unknowable
    here. Treating it as empty would block every `for dir in ...; do rm -rf "$dir/build"`.
    """
    names = set()
    for match in SET_IN_COMMAND.finditer(command):
        names.update((match.group(1) or match.group(2) or match.group(3)).split())
    return names


def expand_variables(path, directory, set_in_command=frozenset()):
    """Expand ~ and environment variables. Returns None when the value cannot be known:
    the path guards its own variable, or uses one the command sets itself.

    A variable neither the environment nor the command defines expands to nothing, as it
    would in the shell: that is how `rm -rf "$BUILD/"` becomes `rm -rf /`.
    """
    if GUARDED_VARIABLE.search(path):
        return None
    used = {first or second for first, second in VARIABLE.findall(path)}
    if used & set(set_in_command):
        return None
    known = {**os.environ, "PWD": directory}

    def value(match):
        return known.get(match.group(1) or match.group(2), "")

    return os.path.expanduser(VARIABLE.sub(value, path))


def resolve(path, directory, set_in_command=frozenset()):
    """Absolute, normalised form of `path` as seen from `directory`, or None if unknowable."""
    expanded = expand_variables(path, directory, set_in_command)
    if expanded is None or expanded == "":
        return None
    return os.path.normpath(os.path.join(directory, expanded))


def simple_commands(command, directory):
    """Yield (argv, directory) for each simple command, in order."""
    argv, skip_next = [], False
    for token in [*tokenize(command), ";"]:
        if is_punctuation(token):
            if REDIRECT_CHARACTERS & set(token):
                skip_next = True
                continue
            argv = strip_wrappers(argv)
            if argv:
                yield argv, directory
                if argv[0] == "cd" and len(argv) > 1:
                    directory = resolve(argv[-1], directory) or directory
            argv, skip_next = [], False
        elif skip_next:
            skip_next = False
        else:
            argv.append(token)
