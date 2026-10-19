# MeTube native package (experimental)

Installs the upstream MeTube source and built Angular UI under /usr/lib/metube,
Python dependencies in a private virtual environment, configuration under
/etc/metube, and a systemd unit. No Docker involved. The service is installed
**disabled**, and it is not started during package installation.

Requires a Debian system with Python 3.13+ (Debian trixie). Runtime is pinned
to an upstream Git commit in build.sh; update it deliberately before rebuilding.
The Python dependencies are resolved at build time; maintain a dependency
lock for reproducible subsequent releases.

The yt-dlp-sabr package provides a Python zipapp; PYTHONPATH=/usr/bin/yt-dlp
lets MeTube import its yt_dlp package while using the separately managed
/usr/bin/yt-dlp binary. Do not pip install another yt-dlp into the venv.

Initial deployment on slagg:

1. Verify /nas/youtube is mounted and writable by UID 1000.
2. Back up /opt/metube/state. Inspect ownership of /var/lib/metube.
3. Copy completed.json and queue.json from /opt/metube/state/ into
   /var/lib/metube/ while the old instances are stopped.
4. Verify the state files are owned by UID/GID 1000 and mode 0600.
5. Review /etc/metube/metube.conf and yt-dlp-options.json.
6. sudo systemctl enable --now metube
7. sudo journalctl -u metube -f

Be careful: an old native instance or another service may already listen on
8082. Avoid simultaneously running two MeTube instances against the same state.

This package does not install upstream's optional bgutil POT server or static
FFmpeg 8.x binaries. Evaluate those separately if required for particular
YouTube formats or clipping.
