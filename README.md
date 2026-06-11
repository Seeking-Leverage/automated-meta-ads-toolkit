# automated-meta-ads-toolkit

Context of this document:
This is the main README that appears when someone visits or clones the repo. It should clearly explain what the toolkit is, who it’s for, and how to get started. This is one of the most important files for making the project usable by other companies.

Copy and paste everything below into the root README.md file:
Markdown# automated-meta-ads-toolkit

A clean, reusable CLI harness for managing Meta Ads across multiple clients.

## What is this?

This toolkit provides a simple, professional way to run and manage Meta Ads campaigns using the official Meta Ads CLI. It is designed so that other companies can easily clone this repo and start using it with their own accounts.

The goal is to make Meta Ads work repeatable and consistent, without tying you to any single client’s setup.

## Quick Start

```bash
# Run a command for a specific client
meta client-example campaigns list

# Launch a campaign
meta client-example campaign launch my-campaign-slug
How to Get Started

Clone this repository
Go into the clients/ folder
Copy example-client and rename it to your client
Fill in your credentials in the new client’s .env file
Start running commands

See clients/README.md for detailed instructions on adding new clients.
Project Structure
textbin/meta                 → Main CLI wrapper
clients/                 → Configuration for each client
docs/                    → Guides, schemas, and playbooks
Requirements

uv installed
Python 3.12+
A Meta Ads CLI project installed locally (see setup instructions in the docs)

Why This Toolkit?

Keeps client credentials isolated and secure
Provides reusable documentation and schemas
Makes it easy to manage multiple ad accounts
Designed to be cloned and customized by other companies

Next Steps

Read clients/README.md to add your first client
Explore the guides in the docs/ folder
