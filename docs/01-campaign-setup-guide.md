# Campaign Setup Guide

A step-by-step guide to creating Meta Ads campaigns using the CLI.

This guide produces a fully built campaign (campaign → ad set → creative → ad) in **PAUSED** status, ready for review before spending money.

## Prerequisites

Before starting, make sure you have:

- The Meta Ads CLI installed and working
- A valid system user access token with `ads_management` scope
- An ad account ID (`act_XXXXXXXX`)
- A Facebook Page ID (for creating creatives)
- A Meta Pixel ID (if optimizing for conversions)
- An ad image (minimum 1080×1080 pixels)

## Step 1: Verify Access

Check that your credentials are working:

```bash
meta [your-client] auth status
meta [your-client] ads campaign list
```
If auth status returns exit code 3, your access token has expired. Generate a new one in Meta Business Manager.

## Step 2: Create the Campaign
Create a new campaign in PAUSED status:
```
meta [your-client] ads campaign create \
  --name "Your Campaign Name" \
  --objective OUTCOME_SALES \
  --daily-budget 5000
Note: Budget is in cents. 5000 = $50/day.
Save the campaign ID returned by the command.
```

## Step 3: Create the Ad Set
Create an ad set under the campaign:

```
meta [your-client] ads adset create [CAMPAIGN_ID] \
  --name "Your Ad Set Name" \
  --optimization-goal OFFSITE_CONVERSIONS \
  --billing-event IMPRESSIONS \
  --targeting-countries [US] \
  --pixel-id [YOUR_PIXEL_ID] \
  --custom-event-type Purchase
```
Save the ad set ID.
Common optimization goals:

OFFSITE_CONVERSIONS (for sales/leads)
LINK_CLICKS
IMPRESSIONS

## Step 4: Create the Creative
Create an ad creative:
```
meta [your-client] ads creative create \
  --name "Your Creative Name" \
  --page-id [YOUR_PAGE_ID] \
  --image ./clients/[your-client]/campaigns/[campaign-slug]/images/your-image.jpg \
  --body "Your primary ad text here" \
  --title "Your headline here" \
  --link-url "https://yourwebsite.com/landing-page" \
  --call-to-action LEARN_MORE
```
Save the creative ID.
Available CTAs: LEARN_MORE, SIGN_UP, SHOP_NOW, BUY_NOW, CONTACT_US, DOWNLOAD, etc.

## Step 5: Create the Ad
Link the ad set and creative together:

```
meta [your-client] ads ad create [ADSET_ID] \
  --name "Your Ad Name" \
  --creative-id [CREATIVE_ID]
```

## Step 6: Verify Everything Was Created

Check that all objects exist and are in PAUSED status:
```
meta [your-client] ads campaign list
meta [your-client] ads adset list --campaign-id [CAMPAIGN_ID]
meta [your-client] ads ad list --adset-id [ADSET_ID]
```
Tips

All objects are created as PAUSED by default. You must manually activate them in Meta Ads Manager.
Company-specific values (ad account ID, pixel ID, page ID) should be stored in your client’s .env file when possible.
Always double-check the destination URL and UTM parameters before activating a campaign.

Auth status fails (exit code 3)
Your access token has expired. Go to Meta Business Manager → System Users → Generate New Token, then update it in your client’s .env file.
Creative creation fails
The image is probably too small or in the wrong format. Use a JPG or PNG that is at least 1080×1080 pixels.
Ad set creation fails
Your pixel may not have enough conversion data yet. Try using LINK_CLICKS instead of OFFSITE_CONVERSIONS for the first 1–2 weeks.
Wrong ad account is being used
Add the --ad-account-id flag to your command:
```
meta [your-client] --ad-account-id act_XXXXXXXX ads campaign list
```

Command not found or "uv" error
Make sure uv is installed and the Meta Ads CLI project path is correct in your client’s .env file.

```
---

You can now create the new file `docs/campaign-setup-guide.md` in GitHub and paste the content above.

Would you like me to adjust anything in this version before you add it?
```
