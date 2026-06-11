# Clients

This folder contains configuration for each client you manage with the Meta Ads CLI Harness.

## How to Add a New Client

1. Create a new folder inside `clients/` using a clean name for the company (e.g. `acme-co` or `client-name`).

2. Copy the example configuration:
   ```bash
   cp -r clients/example-client clients/your-client-name

Go into the new client folder and create the real config file:Bashcp clients/your-client-name/.env.example clients/your-client-name/.env
Open clients/your-client-name/.env and fill in the real values:
META_ADS_ACCESS_TOKEN
META_ADS_ACCOUNT_ID
(Optional) META_PAGE_ID and META_PIXEL_ID

You can now run commands for this client:Bashmeta your-client-name campaigns list
meta your-client-name campaign launch my-campaign

Important Rules

Never commit real .env files. They are gitignored.
Store client-specific values (tokens, account IDs, pixel IDs, etc.) only in that client’s .env file.
You can override the location of the Meta Ads CLI project per client by setting META_ADS_CLI_PROJECT in the client’s .env.

Recommended Workflow

Keep one folder per client.
Use clear, consistent folder names.
Start with the example-client folder as your template when onboarding new clients.
