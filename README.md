# pi-print-cups-ql1100
Resources to get your Raspberry Pi as a print server for your Brother QL-1100 label printer

## Configuration

1. Copy the example configuration file to create your local configuration:
   ```bash
   cp deploy_config.example.sh deploy_config.sh
   ```

2. Edit `deploy_config.sh` to specify your Raspberry Pi's hostname and user:
   ```bash
   # Example deploy_config.sh
   REMOTE_USER="pi"
   REMOTE_HOST="pi.local"
   ```

   - `REMOTE_USER`: The username for the Raspberry Pi (default: `pi`).
   - `REMOTE_HOST`: The hostname or IP address of the Raspberry Pi (default: `pi.local`).

## Deployment

To deploy the `Brother_QL1100.ppd` file to your Raspberry Pi:

1. Ensure the `deploy_ppd.sh` script is executable:
   ```bash
   chmod +x deploy_ppd.sh
   ```

2. Run the deployment script:
   ```bash
   ./deploy_ppd.sh
   ```

   - The script will back up the existing PPD file on the Raspberry Pi before replacing it.
   - The new PPD file will be copied to `/etc/cups/ppd/Brother_QL1100.ppd` on the Raspberry Pi.
