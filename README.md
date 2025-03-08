# Docker SNAT Script

This repository contains a script to manage SNAT rules for Docker to set the outgoing ip.

## Files

- `snat.sh`: Main script to manage SNAT rules.

## Usage

To start on boot use cron.

sudo crontab -e

@reboot /opt/stacks/scripts/snat.sh -rq

### Running the Script

To run the script, use the following command:

```sh
sudo ./snat.sh [-h] [-r] [-i seconds] [-q]
```

### Script Help

The script supports the following options:

- `-h`: Display help information.
- `-r`: Repeat.
- `-i seconds`: Interval in seconds to check and apply SNAT rules.
- `-q`: Run in quiet mode, suppressing output.
