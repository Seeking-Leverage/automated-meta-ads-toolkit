Context:
This document gives new users (especially other companies cloning the repo) a clear, step-by-step guide on how to set up the toolkit from scratch. It’s the practical “how do I actually start using this?” document.

Copy and paste everything below into docs/getting-started.md:
Markdown# Getting Started

This guide walks you through setting up the Meta Ads CLI Harness so you can start managing campaigns.

## 1. Prerequisites

- [uv](https://docs.astral.sh/uv/) installed
- Python 3.12 or higher
- A Meta Business Manager account with access to an ad account, pixel, and Facebook Page

## 2. Clone the Repository

```bash
git clone https://github.com/Seeking-Leverage/automated-meta-ads-toolkit.git
cd automated-meta-ads-toolkit
3. Set Up Your First Client

Go to the clients/ folder
Copy the example client:Bashcp -r clients/example-client clients/your-client-name
Create the real config file:Bashcp clients/your-client-name/.env.example clients/your-client-name/.env
Edit clients/your-client-name/.env and add your credentials:
META_ADS_ACCESS_TOKEN
META_ADS_ACCOUNT_ID
(Optional) META_PAGE_ID and META_PIXEL_ID


4. Install the Meta Ads CLI (External)
The actual Meta Ads CLI runs from a separate uv project (recommended location: ~/meta-ads-cli).
Follow the official Meta Ads CLI installation if you don’t have it yet.
You can change the location per client by setting META_ADS_CLI_PROJECT in that client’s .env file.
5. Test Your Setup
Run a simple command to verify everything works:
Bashmeta your-client-name auth status
meta your-client-name ads campaign list
If both commands work without errors, you’re ready to go.
6. Next Steps

Read clients/README.md for managing multiple clients
Check the guides in the docs/ folder
Start creating campaigns using the campaign.yaml schema

Common Issues
"uv: command not found"
Install uv from https://docs.astral.sh/uv/
Auth fails with exit code 3
Your access token has expired. Generate a new one in Meta Business Manager.
Wrong ad account being used
Make sure META_ADS_ACCOUNT_ID is set correctly in the client’s .env file.
