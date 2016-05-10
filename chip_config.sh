#! /bin/bash
# Initialising Carelink Automation
# Proof of concept ONLY - 640g csv to NightScout
# ****************************************************************************************
# USER SPECIFIC Variables - Please enter your values here
# ****************************************************************************************
api_secret_hash='2ce212ef676099da17ec5aff64db0c83bf3f7b4f' # This is the SHA-1 Hash of your API-SECRET string - eg "ASANEXAMPLE1" is transformed into...
your_nightscout='https://yourwebsite.azurewebsites.net' #'https://something.azurewebsites.net'
gap_seconds=240 # between polling pump
cron_ok=1 # change to 0 if you don't want to run as cron (set to run at boot time is recommended)
cron_delay=20 # seconds to test if cron started