#!/bin/sh
# Nightly backup of the web root
tar -czf /var/backups/www-$(date +%F).tar.gz /var/www/html
