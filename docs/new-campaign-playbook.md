# New Campaign Playbook

A simple step-by-step guide to launching Meta Ads campaigns using this toolkit.

> **Tip:** Replace `[your-client]` with your actual client folder name under `clients/`.

## Before You Start

Make sure you have:
- An ad image (JPG or PNG, at least 1080×1080 pixels)
- Ad copy ready (primary text, headline, destination URL, CTA)
- Basic decisions: daily budget, targeting countries, campaign objective

---

## Step 1: Health Check

Check that your client configuration is working.

```bash
meta [your-client] auth status
meta [your-client] ads campaign list
