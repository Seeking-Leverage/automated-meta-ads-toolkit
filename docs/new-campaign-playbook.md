# New Campaign Playbook

A simple step-by-step guide to launching Meta Ads campaigns using this toolkit.

## Before You Start

Make sure you have:
- An ad image (minimum 1080×1080 pixels)
- Ad copy ready (primary text, headline, destination URL, and CTA)
- Basic decisions made (budget, targeting countries, campaign objective)

## Step 1: Create a Campaign Folder

Create a new folder for your campaign inside your client directory:

```bash
mkdir -p clients/your-client-name/campaigns/my-campaign-slug/{images,videos,insights}
Step 2: Create the campaign.yaml File
Inside the campaign folder, create a campaign.yaml file using the structure defined in campaign-spec-schema.md.
Fill in your details (ad account ID, pixel ID, creative, etc.).
Step 3: Add Your Creative Assets
Place your ad image in the images/ folder (or video in videos/).
Make sure the filename matches what you put in campaign.yaml.
Step 4: Launch the Campaign
Run the launch command:
Bashmeta your-client-name campaign launch my-campaign-slug
The harness will guide you through creating the campaign, ad set, creative, and ad. Everything will be created in PAUSED status.
Step 5: Review in Meta Ads Manager
After the launch completes:

Go to Meta Ads Manager
Find your new campaign
Review all settings, creatives, and targeting
Only activate the campaign when you’re happy with everything

Step 6: Monitor Performance
After the campaign has been running for 24–48 hours, pull insights:
Bashmeta your-client-name insights pull my-campaign-slug
Insights are saved in the insights/ folder and can be used for reporting.
Tips

Always keep campaigns paused until you’ve reviewed them
Use clear, consistent naming in campaign.yaml
Store repeated values (pixel ID, page ID) in your client’s .env file
Use the pause-campaign.sh script if you need to quickly pause everything later

Common Mistakes to Avoid

Forgetting to match creative_ref exactly with the creative name
Using an image smaller than 1080×1080
Activating the campaign before reviewing it in Ads Manager
