#!/usr/bin/env python3
"""
Pre-commit hook: scan staged files for potential secrets / credentials.
Install: cp backend/scripts/check_secrets.py .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
"""

import subprocess
import sys
import re

# Patterns that look like secrets
SECRET_PATTERNS = [
    (r'-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----', "Private key"),
    (r'"private_key"\s*:\s*"-----BEGIN', "JSON private key"),
    (r'AIza[0-9A-Za-z\-_]{35}', "Google API key"),
    (r'AQ\.[a-zA-Z0-9_\-]{30,}', "Gemini/Google API key"),
    (r'"type"\s*:\s*"service_account"', "Service account JSON"),
    (r'GEMINI_API_KEY\s*=\s*[A-Za-z0-9._\-]{20,}', "Gemini API key in .env"),
    (r'JWT_SECRET_KEY\s*=\s*[a-f0-9]{32,}', "JWT secret in .env"),
]

# Files that should never be staged
BLOCKED_FILES = [
    'serviceAccountKey.json',
    'google-services.json',
    'GoogleService-Info.plist',
    '.env',
]


def get_staged_files():
    result = subprocess.run(
        ['git', 'diff', '--cached', '--name-only', '--diff-filter=ACM'],
        capture_output=True, text=True
    )
    return result.stdout.splitlines()


def get_file_content(filepath):
    result = subprocess.run(
        ['git', 'show', f':{filepath}'],
        capture_output=True, text=True
    )
    return result.stdout


def main():
    staged = get_staged_files()
    errors = []

    for filepath in staged:
        filename = filepath.split('/')[-1]
        if filename in BLOCKED_FILES:
            errors.append(f"BLOCKED FILE staged: {filepath}")
            continue

        content = get_file_content(filepath)
        for pattern, label in SECRET_PATTERNS:
            if re.search(pattern, content):
                errors.append(f"Potential secret ({label}) found in: {filepath}")
                break

    if errors:
        print("\nPRE-COMMIT SECURITY CHECK FAILED\n")
        for err in errors:
            print(f"  {err}")
        print("\nRemove the secrets before committing.\n")
        sys.exit(1)

    print("Pre-commit security check passed.")
    sys.exit(0)


if __name__ == '__main__':
    main()
