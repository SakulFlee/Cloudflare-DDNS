# Cloudflare DDNS

TODO

## Running

Both files are important (last_ip & settings) and must be supplied.  
`last_ip` can be empty or `0.0.0.0` on first-run.  
`settings` should be a copy of `settings.template`.
Make sure to fill in all values.

```
docker run -it \
    --rm \
    --mount type=bind,source="$(pwd)"/last_ip,target=/last_ip \
    --mount type=bind,source="$(pwd)"/settings,target=/settings \
    ghcr.io/sakul6499/cloudflare_ddns:debian-latest
```
