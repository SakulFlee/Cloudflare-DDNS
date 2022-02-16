# Cloudflare DDNS

TODO

## Running

Both files are important (ip.last & settings) and must be supplied.  
`ip.last` can be empty or `0.0.0.0` on first-run.  
`settings` should be a copy of `settings.template`.
Make sure to fill in all values.

> Warning: If `ip.last` does not exist on the host system the script will read it as an empty file and will assume there hasn't been a `ip.last` file.
> Without the file on the host no IP-changes will be written down.
> I.e. with each script call, the script assumes it's running for the first time and will update all entries. This can burn though your API Rate Limits pretty quickly depending on your scheduling.

```
docker run -it \
    --rm \
    --mount type=bind,source="$(pwd)"/ip.last,target=/ip.last \
    --mount type=bind,source="$(pwd)"/settings,target=/settings \
    ghcr.io/sakul6499/cloudflare_ddns:debian-latest
```
