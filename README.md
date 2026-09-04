# OpenWA Fixed

This is a Home Assistant add-on fork that fixes the default writable-path bug in the upstream OpenWA add-on.

It writes to writable Supervisor paths instead of hardcoding `/data/openwa`.

## Files

- `config.yaml`
- `Dockerfile`
- `run.sh`
- `helper_server.py`

## Why this exists

The upstream OpenWA add-on tries to create `/data/openwa`, which fails on many Home Assistant deployments because the directory mount is not writable.

This fork chooses a writable path such as `/share/openwa-data` and falls back to `/tmp/openwa-data`.

## Install

Add this repository as a local Add-on repository in Home Assistant and install `OpenWA Fixed`.

## Required config

Set these values in the add-on config:

- `api_master_key`
- `openwa_api_key`
- `session_id`
- `log_level`

Then open `http://<HOME_ASSISTANT_IP>:2786/qr` and scan with WhatsApp.
