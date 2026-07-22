#!/bin/sh
set -e

for domain in "$DOMAIN_1_DEFAULT" "$DOMAIN_2" "$DOMAIN_3" "$DOMAIN_4_REVERSE" "$DOMAIN_5_REVERSE"; do
    if [ -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]; then
        echo "[$domain] cert exists, skipping"
        continue
    fi
    echo "[$domain] issuing cert..."
    certbot certonly --standalone --non-interactive --agree-tos \
        --register-unsafely-without-email \
        -d "$domain"
done
