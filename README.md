# Cloudflare DDNS (DynDNS)

This is a simple script that dynamically can update a chosen (sub-)domain with your current IPv4 (Type A) and/or IPv6 (Type AAAA).

Each run, this script checks for your current IPv4 & IPv6, compares them to a cache and only updates your CloudFlare entries if a mismatch is found.
You can freely choose which (sub-)domains are being run.

> [!WARNING]  
> Please use this script with proper care.  
> I do not endorse spamming [CloudFlare](https://cloudflare.com) or [ICanHazIP.com](https://icanhazip.com/)!
> Running this script every 15-30m should be more than enough, if you need quicker updates consider changing the IP provider, [ICanHazIP.com](https://icanhazip.com/), to a service of your own or replace it with a locally known public IP address.

## Setup

To get started you only need to download the [cf_ddns.sh](./cf_ddns.sh) script and run it.  
A `settings` file should be generated with instructions.
Change the `settings` file to your needs and rerun the script.

Once the script ran at least once with proper `settings`, two more files should be created:

- `ipv4.last`: A local cache of your last IPv4 address
- `ipv6.last`: A local cache of your last IPv6 address

Do not remove those files!
These store your last IP and are used to compare your current IP's against your last ones.
This is done to prevent even more API calls to CloudFlare.  
**However, this does not track changes done by other tools!**

If you need to force an update, simply call the script with `--force`.

**This script is intended to be run regularly as a one-shot script.**  
You may wanna setup a local Cron task to run this script e.g. every 30m.

## Docker

If you want to run this script inside Docker, you can use a ready made container!  
Make sure to read through the [Setup](#setup) section first and create your setting file as it will be needed to run the Docker container!

```bash
docker run -it \
    --rm \
    --mount type=bind,source="$(pwd)"/ipv4.last,target=/opt/cf_ddns/ipv4.last \
    --mount type=bind,source="$(pwd)"/ipv6.last,target=/opt/cf_ddns/ipv6.last \
    --mount type=bind,source="$(pwd)"/settings,target=/opt/cf_ddns/settings \
    ghcr.io/sakul6499/cloudflare_ddns:latest
```

> [!NOTE]  
> This is still a one-shot script!  
> The container will execute the script, then exit and destroy itself (if `--rm` is used).
>
> You will still need to use something like Cron to schedule this container to be run.

Alternatively, you could create the container once and simply rerun it every time:

```bash
docker create -it \
    --name cf_ddns \
    --mount type=bind,source="$(pwd)"/ipv4.last,target=/opt/cf_ddns/ipv4.last \
    --mount type=bind,source="$(pwd)"/ipv6.last,target=/opt/cf_ddns/ipv6.last \
    --mount type=bind,source="$(pwd)"/settings,target=/opt/cf_ddns/settings \
    ghcr.io/sakul6499/cloudflare_ddns:latest
```

And every iteration simply call:

```bash
docker start cf_ddns
```

> [!NOTE]  
> This is still a one-shot script!  
> The only difference is that there now is a container lingering around waiting to be started.
>
> You will still need to use something like Cron to schedule this container to be run.
