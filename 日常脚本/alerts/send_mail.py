#!/usr/bin/env python3
"""Small SMTP sender used by the daily check scripts."""

import argparse
import os
import smtplib
import sys
from email.message import EmailMessage


def main() -> int:
    """main 功能说明。"""
    parser = argparse.ArgumentParser(
        description="Send a plain-text alert email.")
    parser.add_argument("--subject", required=True)
    args = parser.parse_args()

    mail_to = os.environ.get("MAIL_TO")
    smtp_host = os.environ.get("SMTP_HOST")
    if not mail_to or not smtp_host:
        return 0

    smtp_port = int(os.environ.get("SMTP_PORT", "587"))
    mail_from = os.environ.get("MAIL_FROM") or os.environ.get(
        "SMTP_USER") or "monitor@localhost"
    body = sys.stdin.read()

    message = EmailMessage()
    message["From"] = mail_from
    message["To"] = mail_to
    message["Subject"] = args.subject
    message.set_content(body)

    with smtplib.SMTP(smtp_host, smtp_port, timeout=10) as smtp:
        if os.environ.get("SMTP_TLS", "1") != "0":
            smtp.starttls()
        smtp_user = os.environ.get("SMTP_USER")
        smtp_pass = os.environ.get("SMTP_PASS")
        if smtp_user and smtp_pass:
            smtp.login(smtp_user, smtp_pass)
        smtp.send_message(message)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
