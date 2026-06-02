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
```

## Step 2: Create Campaign Folder
```meta [your-client] campaign create --slug your-campaign-slug```

## Step 3: Fill Campaign Details
Open this file and edit it:
```clients/[your-client]/campaigns/your-campaign-slug/campaign.yaml```
Fill in your ad account ID, budget, targeting, creative, and ad details.

## Step 4: Launch
```meta [your-client] campaign launch your-campaign-slug```
All items will be created as PAUSED.


Next Steps

Review in Meta Ads Manager
Activate the campaign when ready
Pull insights after 24–48 hours

```
---

Just create the file `docs/new-campaign-playbook.md` and paste the content above.
```
